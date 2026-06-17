/// SuiFlow Agentic Work Graph.
///
/// A Sui-native settlement object for autonomous service agents. Work orders
/// hold funded SUI escrow, service bonds, bounded agent policy objects,
/// evidence pointers, final receipt hashes, and validator attestations.
#[allow(lint(self_transfer))]
module suiflow::agent_settlement;

use std::bcs;
use std::option::{Self, Option};
use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::ed25519;
use sui::event;
use sui::hash;
use sui::object::{Self, ID, UID};
use sui::sui::SUI;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

const STATE_CREATED: u8 = 0;
const STATE_FUNDED: u8 = 1;
const STATE_DELIVERED: u8 = 2;
const STATE_REFUND_REQUESTED: u8 = 3;
const STATE_RELEASED: u8 = 4;
const STATE_REFUNDED: u8 = 5;
const STATE_SETTLED: u8 = 6;
const STATE_CANCELLED: u8 = 7;
const STATE_ATTESTATION_FAILED: u8 = 8;

const ACTION_MARK_DELIVERED: u64 = 1;
const ACTION_RELEASE: u64 = 2;
const ACTION_REQUEST_REFUND: u64 = 4;
const ACTION_PROPOSE_SETTLEMENT: u64 = 8;
const ACTION_ACCEPT_SETTLEMENT: u64 = 16;
const ACTION_READ_EVIDENCE: u64 = 32;
const ACTION_METER_RELEASE: u64 = 64;
const ACTION_REPORT_PRIVACY: u64 = 128;
const ACTION_BIND_EXECUTION: u64 = 256;
const ACTION_REPORT_ORIGIN_RISK: u64 = 512;

const E_NO_PAYMENT: u64 = 1;
const E_BAD_STATE: u64 = 2;
const E_UNAUTHORIZED: u64 = 3;
const E_BAD_BOND: u64 = 4;
const E_BAD_POLICY: u64 = 5;
const E_POLICY_EXPIRED: u64 = 6;
const E_BAD_SETTLEMENT: u64 = 7;
const E_TOO_EARLY: u64 = 8;
const E_BAD_VALIDATION: u64 = 9;
const E_POLICY_ALLOWED: u64 = 10;
const E_BAD_ATTESTATION: u64 = 11;
const E_BAD_SEAL_ID: u64 = 12;
const E_BAD_AVAILABILITY: u64 = 13;
const E_ATTESTATION_VALID: u64 = 14;
const E_BAD_ATTENUATION: u64 = 15;
const E_TOO_DEEP: u64 = 16;
const E_REVOKED_BY_GENERATION: u64 = 17;
const E_PAUSED: u64 = 18;
const E_BAD_VAULT: u64 = 19;
const E_BAD_EXPOSURE: u64 = 20;
const E_BAD_DENIAL_RECEIPT: u64 = 21;
const E_BAD_AUCTION: u64 = 22;
const E_BAD_COSIGN: u64 = 23;
const E_BAD_DELIVERY_PROOF: u64 = 24;
const E_BAD_PRIVACY_BUDGET: u64 = 25;
const E_BAD_EXECUTION_BINDING: u64 = 26;
const E_BAD_ORIGIN_CRITIC: u64 = 27;

const DENY_OK: u64 = 0;
const DENY_REVOKED: u64 = 1;
const DENY_WRONG_ORDER: u64 = 2;
const DENY_WRONG_AGENT: u64 = 3;
const DENY_ACTION_NOT_ALLOWED: u64 = 4;
const DENY_EXPIRED: u64 = 5;
const DENY_USAGE_EXHAUSTED: u64 = 6;
const DENY_ORIGIN_QUARANTINED: u64 = 7;

const ATTEST_OK: u64 = 0;
const ATTEST_TEE_NOT_REQUIRED: u64 = 1;
const ATTEST_WRONG_ORDER: u64 = 2;
const ATTEST_WRONG_AGENT: u64 = 3;
const ATTEST_WRONG_INPUT: u64 = 4;
const ATTEST_WRONG_OUTPUT: u64 = 5;
const ATTEST_WRONG_MODEL: u64 = 6;
const ATTEST_WRONG_STATE: u64 = 7;
const ATTEST_STALE: u64 = 8;
const ATTEST_BAD_SIGNATURE: u64 = 9;

const EVIDENCE_DELIVERY: u8 = 0;
const EVIDENCE_DISPUTE: u8 = 1;
const EVIDENCE_TIMELOCK: u8 = 2;

const MAX_DEPTH: u8 = 8;
const BASIS_POINTS: u64 = 10_000;
const RELEASE_CONDITION_NONE: u8 = 0;
const RELEASE_CONDITION_DELIVERY_PROOF: u8 = 1;

public struct AttestationState has store {
    requires_tee_proof: bool,
    expected_attester_pubkey: vector<u8>,
    expected_model_pcr: vector<u8>,
    expected_input_hash: vector<u8>,
    freshness_ms: u64
}

public struct EvidenceState has store {
    delivered_output_hash: vector<u8>,
    dispute_validator: address,
    required_blob_end_epoch: u64,
    verified_blob_certified_epoch: u64,
    verified_blob_end_epoch: u64,
    delivery_evidence_hash: vector<u8>,
    dispute_evidence_hash: vector<u8>,
    receipt_hash: vector<u8>
}

public struct GraphState has store {
    parent_order_id: Option<ID>,
    parent_policy_id: Option<ID>,
    root_principal: address,
    depth: u8,
    child_budget_allocated: u64
}

public struct MeteredState has store {
    paid: u64,
    premium_paid: u64
}

public struct ReleaseState has store {
    condition: u8,
    expected_output_commitment: vector<u8>,
    proof_chain_root: vector<u8>
}

public struct PrivacyState has store {
    budget: u64,
    used: u64,
    manifest_hash: vector<u8>,
    trace_root: vector<u8>
}

public struct ExecutionState has store {
    context_hash: vector<u8>,
    receipt_hash: vector<u8>
}

public struct OriginCriticState has store {
    manifest_hash: vector<u8>,
    tool_manifest_hash: vector<u8>,
    critic_policy_hash: vector<u8>,
    risk_score: u64,
    risk_threshold: u64,
    quarantined: bool,
    trace_root: vector<u8>
}

public struct WorkOrder has key {
    id: UID,
    payer: address,
    provider: address,
    amount: u64,
    escrow: Balance<SUI>,
    service_bond: Balance<SUI>,
    state: u8,
    created_ms: u64,
    deadline_ms: u64,
    refund_requested_ms: u64,
    settlement_proposed_by: address,
    settlement_provider_amount: u64,
    metadata_hash: vector<u8>,
    mandate_hash: vector<u8>,
    policy_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    attestation: AttestationState,
    evidence: EvidenceState,
    feedback_count: u64,
    validation_count: u64,
    validation_root: vector<u8>,
    graph: GraphState,
    metered: MeteredState,
    release: ReleaseState,
    privacy: PrivacyState,
    execution: ExecutionState,
    origin: OriginCriticState
}

public struct WorkReceipt has copy, drop {
    work_order_id: ID,
    agent: address,
    input_hash: vector<u8>,
    output_hash: vector<u8>,
    model_pcr: vector<u8>,
    state: u8
}

public struct WalrusAvailabilityProof has copy, drop {
    blob_id: vector<u8>,
    certified_epoch: u64,
    end_epoch: u64
}

public struct AgentPolicy has key, store {
    id: UID,
    work_order_id: ID,
    owner: address,
    agent: address,
    allowed_actions: u64,
    expires_ms: u64,
    max_uses: u64,
    uses: u64,
    max_provider_amount: u64,
    policy_hash: vector<u8>,
    revoked: bool,
    parent_policy_id: Option<ID>,
    root_principal: address,
    depth: u8,
    ancestors: vector<ID>,
    gen_snapshot: u64,
    remaining_budget: u64,
    controller_id: ID,
    lease_expiry_ms: u64,
    branch_id: Option<ID>,
    privacy_budget_remaining: u64,
    origin_risk_budget_remaining: u64
}

public struct WorkOrderCreated has copy, drop {
    work_order_id: ID,
    payer: address,
    provider: address,
    amount: u64,
    deadline_ms: u64,
    metadata_hash: vector<u8>,
    mandate_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>
}

public struct AgentPolicyIssued has copy, drop {
    policy_id: ID,
    work_order_id: ID,
    owner: address,
    agent: address,
    allowed_actions: u64,
    expires_ms: u64,
    max_uses: u64,
    max_provider_amount: u64,
    policy_hash: vector<u8>
}

public struct WorkOrderEvent has copy, drop {
    work_order_id: ID,
    actor: address,
    state: u8,
    label: String,
    evidence_hash: vector<u8>,
    receipt_hash: vector<u8>
}

public struct ValidationSubmitted has copy, drop {
    work_order_id: ID,
    validator: address,
    agent: address,
    score_bps: u64,
    evidence_hash: vector<u8>,
    validation_root: vector<u8>,
    validation_count: u64
}

public struct PolicyDenialRecorded has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    agent: address,
    attempted_action: u64,
    reason_code: u64,
    evidence_hash: vector<u8>,
    observed_ms: u64
}

public struct AttestationConfigured has copy, drop {
    work_order_id: ID,
    expected_attester_pubkey: vector<u8>,
    expected_model_pcr: vector<u8>,
    expected_input_hash: vector<u8>,
    freshness_ms: u64
}

public struct AttestationDenialRecorded has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    agent: address,
    reason_code: u64,
    output_hash: vector<u8>,
    observed_ms: u64
}

public struct AttestationReleaseRecorded has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    agent: address,
    receipt_digest: vector<u8>,
    attested_ms: u64
}

public struct SealAccessApproved has copy, drop {
    work_order_id: ID,
    actor: address,
    evidence_class: u8,
    seal_identity: vector<u8>,
    delegated: bool
}

public struct WalrusAvailabilityRecorded has copy, drop {
    work_order_id: ID,
    actor: address,
    blob_id: vector<u8>,
    certified_epoch: u64,
    end_epoch: u64
}

public struct TimeLockedRevealApproved has copy, drop {
    work_order_id: ID,
    actor: address,
    reveal_at_ms: u64,
    seal_identity: vector<u8>
}

public struct GenerationRegistry has key {
    id: UID,
    generations: Table<ID, u64>,
    owners: Table<ID, address>,
    paused: bool,
    window_started_ms: u64,
    window_drawn: u64,
    breaker_window_ms: u64,
    breaker_amount: u64
}

public struct KillCap has key, store {
    id: UID,
    root_principal: address
}

public struct Caretaker has key, store {
    id: UID,
    branch_id: ID,
    root_principal: address,
    live: bool,
    scope_hash: vector<u8>
}

public struct DenialReceipt has key, store {
    id: UID,
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    agent: address,
    attempted_action: u64,
    reason_code: u64,
    evidence_hash: vector<u8>,
    observed_ms: u64
}

public struct UnderwritingVault has key {
    id: UID,
    policy_id: ID,
    staked: Balance<SUI>,
    coverage_cap: u64,
    premium_bps: u64,
    active_exposure: u64,
    claims_paid: u64,
    controller_id: ID,
    window_exposure: u64
}

public struct UnderwriterPosition has key, store {
    id: UID,
    vault_id: ID,
    owner: address,
    principal: u64,
    shares: u64
}

public struct ExposureAggregator has key {
    id: UID,
    controller_id: ID,
    window_exposure: u64,
    premium_bps: u64
}

public struct ExposureTicket has drop {
    controller_id: ID,
    amount: u64,
    premium_bps: u64
}

public struct ValidatorBondCap has key, store {
    id: UID,
    validator: address,
    bond: Balance<SUI>,
    live: bool,
    weight: u64,
    last_work_order_id: Option<ID>,
    last_agent: address
}

public struct BondedValidationSubmitted has copy, drop {
    work_order_id: ID,
    validator: address,
    agent: address,
    score_bps: u64,
    bond_weight: u64,
    evidence_hash: vector<u8>
}

public struct SubDelegation has copy, drop {
    parent_order_id: ID,
    child_order_id: ID,
    parent_policy_id: ID,
    child_policy_id: ID,
    root_principal: address,
    sub_agent: address,
    depth: u8,
    child_amount: u64,
    child_actions: u64
}

public struct RevocationEvent has copy, drop {
    policy_id: ID,
    new_generation: u64,
    scope: String,
    actor: address,
    at_ms: u64
}

public struct RevocationReceipt has copy, drop {
    branch_id: ID,
    revoked_at_ms: u64,
    scope_hash: vector<u8>
}

public struct MeteredDraw has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    agent: address,
    units: u64,
    unit_price: u64,
    paid: u64,
    premium: u64,
    running_total: u64,
    usage_proof_hash: vector<u8>
}

public struct UnderwritingVaultCreated has copy, drop {
    vault_id: ID,
    policy_id: ID,
    coverage_cap: u64,
    premium_bps: u64,
    controller_id: ID
}

public struct ClaimPaid has copy, drop {
    vault_id: ID,
    work_order_id: ID,
    policy_id: ID,
    payer: address,
    amount: u64
}

public struct ExposureRecorded has copy, drop {
    aggregator_id: ID,
    controller_id: ID,
    amount: u64,
    window_exposure: u64,
    premium_bps: u64
}

public struct BidMarket has key {
    id: UID,
    parent_order_id: ID,
    parent_policy_id: ID,
    root_principal: address,
    task_hash: vector<u8>,
    reveal_deadline_ms: u64,
    best_agent: address,
    best_bid: u64,
    bid_count: u64,
    awarded: bool,
    commitments: Table<address, vector<u8>>
}

public struct CoSignBond has key, store {
    id: UID,
    sponsor_policy_id: ID,
    sponsoree_policy_id: ID,
    sponsor: address,
    stake: Balance<SUI>,
    decay_ms: u64,
    live: bool
}

public struct DeliveryProof has copy, drop {
    work_order_id: ID,
    deliverable_hash: vector<u8>,
    proof_chain_root: vector<u8>,
    signer_pubkey: vector<u8>
}

public struct SealedBidSubmitted has copy, drop {
    market_id: ID,
    bidder: address,
    sealed_bid_hash: vector<u8>
}

public struct BidOpened has copy, drop {
    market_id: ID,
    bidder: address,
    bid_amount: u64,
    best_agent: address,
    best_bid: u64
}

public struct BidAwarded has copy, drop {
    market_id: ID,
    child_order_id: ID,
    child_policy_id: ID,
    winner: address,
    bid_amount: u64
}

public struct ReaperBountyPaid has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    reaper: address,
    bounty: u64
}

public struct CoSignCreated has copy, drop {
    cosign_id: ID,
    sponsor_policy_id: ID,
    sponsoree_policy_id: ID,
    sponsor: address,
    stake: u64,
    decay_ms: u64
}

public struct CoSignSlashed has copy, drop {
    cosign_id: ID,
    vault_id: ID,
    sponsoree_policy_id: ID,
    amount: u64
}

public struct DeliveryProofAccepted has copy, drop {
    work_order_id: ID,
    signer: vector<u8>,
    proof_chain_root: vector<u8>,
    receipt_hash: vector<u8>
}

public struct PrivacyReceipt has key, store {
    id: UID,
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    content_leak_score: u64,
    behavior_leak_score: u64,
    weighted_score: u64,
    trace_commitment: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    evidence_hash: vector<u8>,
    observed_ms: u64
}

public struct PrivacyBreachReceipt has key, store {
    id: UID,
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    weighted_score: u64,
    remaining_budget: u64,
    evidence_hash: vector<u8>,
    observed_ms: u64
}

public struct PrivacyBudgetConfigured has copy, drop {
    work_order_id: ID,
    privacy_budget: u64,
    privacy_manifest_hash: vector<u8>,
    privacy_trace_root: vector<u8>
}

public struct PrivacyReceiptRecorded has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    weighted_score: u64,
    privacy_used: u64,
    privacy_budget_remaining: u64,
    evidence_hash: vector<u8>
}

public struct PrivacyBreachRecorded has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    weighted_score: u64,
    remaining_budget: u64,
    evidence_hash: vector<u8>
}

public struct ExecutionBindingRegistry has key {
    id: UID,
    used_nullifiers: Table<vector<u8>, bool>
}

public struct ExecutionContextBound has copy, drop {
    work_order_id: ID,
    execution_context_hash: vector<u8>,
    service_endpoint_hash: vector<u8>,
    payment_intent_hash: vector<u8>,
    quote_hash: vector<u8>
}

public struct ExecutionReceiptConsumed has copy, drop {
    work_order_id: ID,
    actor: address,
    execution_context_hash: vector<u8>,
    service_receipt_hash: vector<u8>,
    nullifier_hash: vector<u8>
}

public struct OriginFirewallConfigured has copy, drop {
    work_order_id: ID,
    origin_manifest_hash: vector<u8>,
    tool_manifest_hash: vector<u8>,
    critic_policy_hash: vector<u8>,
    critic_risk_threshold: u64
}

public struct OriginCriticReceipt has key, store {
    id: UID,
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    observed_origin_hash: vector<u8>,
    observed_tool_hash: vector<u8>,
    user_intent_hash: vector<u8>,
    tool_call_hash: vector<u8>,
    risk_score: u64,
    quarantined: bool,
    evidence_hash: vector<u8>,
    observed_ms: u64
}

public struct OriginCriticRecorded has copy, drop {
    work_order_id: ID,
    policy_id: ID,
    reporter: address,
    risk_score: u64,
    running_risk_score: u64,
    quarantined: bool,
    critic_trace_root: vector<u8>,
    evidence_hash: vector<u8>
}

public struct OriginQuarantineCleared has copy, drop {
    work_order_id: ID,
    actor: address,
    risk_score: u64,
    resolution_hash: vector<u8>
}

public fun create_work_order(
    provider: address,
    payment: Coin<SUI>,
    metadata_hash: vector<u8>,
    mandate_hash: vector<u8>,
    policy_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    deadline_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let amount = coin::value(&payment);
    assert!(amount > 0, E_NO_PAYMENT);

    let payer = tx_context::sender(ctx);
    let escrow = coin::into_balance(payment);
    let id = object::new(ctx);
    let work_order_id = object::uid_to_inner(&id);
    let order = WorkOrder {
        id,
        payer,
        provider,
        amount,
        escrow,
        service_bond: balance::zero<SUI>(),
        state: STATE_FUNDED,
        created_ms: clock::timestamp_ms(clock),
        deadline_ms,
        refund_requested_ms: 0,
        settlement_proposed_by: @0x0,
        settlement_provider_amount: 0,
        metadata_hash,
        mandate_hash,
        policy_hash,
        walrus_blob_id,
        seal_policy_id,
        attestation: AttestationState {
            requires_tee_proof: false,
            expected_attester_pubkey: vector[],
            expected_model_pcr: vector[],
            expected_input_hash: vector[],
            freshness_ms: 0
        },
        evidence: EvidenceState {
            delivered_output_hash: vector[],
            dispute_validator: @0x0,
            required_blob_end_epoch: 0,
            verified_blob_certified_epoch: 0,
            verified_blob_end_epoch: 0,
            delivery_evidence_hash: vector[],
            dispute_evidence_hash: vector[],
            receipt_hash: vector[]
        },
        feedback_count: 0,
        validation_count: 0,
        validation_root: vector[],
        graph: GraphState {
            parent_order_id: option::none<ID>(),
            parent_policy_id: option::none<ID>(),
            root_principal: payer,
            depth: 0,
            child_budget_allocated: 0
        },
        metered: MeteredState { paid: 0, premium_paid: 0 },
        release: ReleaseState {
            condition: RELEASE_CONDITION_NONE,
            expected_output_commitment: vector[],
            proof_chain_root: vector[]
        },
        privacy: PrivacyState {
            budget: 0,
            used: 0,
            manifest_hash: vector[],
            trace_root: vector[]
        },
        execution: ExecutionState {
            context_hash: vector[],
            receipt_hash: vector[]
        },
        origin: OriginCriticState {
            manifest_hash: vector[],
            tool_manifest_hash: vector[],
            critic_policy_hash: vector[],
            risk_score: 0,
            risk_threshold: 0,
            quarantined: false,
            trace_root: vector[]
        }
    };

    event::emit(WorkOrderCreated {
        work_order_id,
        payer,
        provider,
        amount,
        deadline_ms,
        metadata_hash: order.metadata_hash,
        mandate_hash: order.mandate_hash,
        walrus_blob_id: order.walrus_blob_id,
        seal_policy_id: order.seal_policy_id
    });

    transfer::share_object(order);
}

public fun create_work_order_with_policy(
    provider: address,
    payment: Coin<SUI>,
    metadata_hash: vector<u8>,
    mandate_hash: vector<u8>,
    policy_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    deadline_ms: u64,
    agent: address,
    allowed_actions: u64,
    expires_ms: u64,
    max_uses: u64,
    max_provider_amount: u64,
    agent_policy_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let amount = coin::value(&payment);
    assert!(amount > 0, E_NO_PAYMENT);
    assert!(allowed_actions > 0, E_BAD_POLICY);
    assert!(max_uses > 0, E_BAD_POLICY);

    let payer = tx_context::sender(ctx);
    let escrow = coin::into_balance(payment);
    let id = object::new(ctx);
    let work_order_id = object::uid_to_inner(&id);
    let order = WorkOrder {
        id,
        payer,
        provider,
        amount,
        escrow,
        service_bond: balance::zero<SUI>(),
        state: STATE_FUNDED,
        created_ms: clock::timestamp_ms(clock),
        deadline_ms,
        refund_requested_ms: 0,
        settlement_proposed_by: @0x0,
        settlement_provider_amount: 0,
        metadata_hash,
        mandate_hash,
        policy_hash,
        walrus_blob_id,
        seal_policy_id,
        attestation: AttestationState {
            requires_tee_proof: false,
            expected_attester_pubkey: vector[],
            expected_model_pcr: vector[],
            expected_input_hash: vector[],
            freshness_ms: 0
        },
        evidence: EvidenceState {
            delivered_output_hash: vector[],
            dispute_validator: @0x0,
            required_blob_end_epoch: 0,
            verified_blob_certified_epoch: 0,
            verified_blob_end_epoch: 0,
            delivery_evidence_hash: vector[],
            dispute_evidence_hash: vector[],
            receipt_hash: vector[]
        },
        feedback_count: 0,
        validation_count: 0,
        validation_root: vector[],
        graph: GraphState {
            parent_order_id: option::none<ID>(),
            parent_policy_id: option::none<ID>(),
            root_principal: payer,
            depth: 0,
            child_budget_allocated: 0
        },
        metered: MeteredState { paid: 0, premium_paid: 0 },
        release: ReleaseState {
            condition: RELEASE_CONDITION_NONE,
            expected_output_commitment: vector[],
            proof_chain_root: vector[]
        },
        privacy: PrivacyState {
            budget: 0,
            used: 0,
            manifest_hash: vector[],
            trace_root: vector[]
        },
        execution: ExecutionState {
            context_hash: vector[],
            receipt_hash: vector[]
        },
        origin: OriginCriticState {
            manifest_hash: vector[],
            tool_manifest_hash: vector[],
            critic_policy_hash: vector[],
            risk_score: 0,
            risk_threshold: 0,
            quarantined: false,
            trace_root: vector[]
        }
    };

    let policy_id = object::new(ctx);
    let policy_inner_id = object::uid_to_inner(&policy_id);
    let mut ancestors = vector[];
    vector::push_back(&mut ancestors, policy_inner_id);
    let policy = AgentPolicy {
        id: policy_id,
        work_order_id,
        owner: payer,
        agent,
        allowed_actions,
        expires_ms,
        max_uses,
        uses: 0,
        max_provider_amount,
        policy_hash: agent_policy_hash,
        revoked: false,
        parent_policy_id: option::none<ID>(),
        root_principal: payer,
        depth: 0,
        ancestors,
        gen_snapshot: 0,
        remaining_budget: amount,
        controller_id: policy_inner_id,
        lease_expiry_ms: expires_ms,
        branch_id: option::none<ID>(),
        privacy_budget_remaining: 0,
        origin_risk_budget_remaining: 0
    };

    event::emit(WorkOrderCreated {
        work_order_id,
        payer,
        provider,
        amount,
        deadline_ms,
        metadata_hash: order.metadata_hash,
        mandate_hash: order.mandate_hash,
        walrus_blob_id: order.walrus_blob_id,
        seal_policy_id: order.seal_policy_id
    });

    event::emit(AgentPolicyIssued {
        policy_id: policy_inner_id,
        work_order_id,
        owner: payer,
        agent,
        allowed_actions,
        expires_ms,
        max_uses,
        max_provider_amount,
        policy_hash: policy.policy_hash
    });

    transfer::public_transfer(policy, agent);
    transfer::share_object(order);
}

public fun new_work_receipt(
    work_order_id: ID,
    agent: address,
    input_hash: vector<u8>,
    output_hash: vector<u8>,
    model_pcr: vector<u8>,
    state: u8
): WorkReceipt {
    WorkReceipt {
        work_order_id,
        agent,
        input_hash,
        output_hash,
        model_pcr,
        state
    }
}

public fun new_walrus_availability_proof(
    blob_id: vector<u8>,
    certified_epoch: u64,
    end_epoch: u64
): WalrusAvailabilityProof {
    WalrusAvailabilityProof {
        blob_id,
        certified_epoch,
        end_epoch
    }
}

public fun configure_attestation(
    order: &mut WorkOrder,
    expected_attester_pubkey: vector<u8>,
    expected_model_pcr: vector<u8>,
    expected_input_hash: vector<u8>,
    freshness_ms: u64,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(!expected_attester_pubkey.is_empty(), E_BAD_ATTESTATION);
    assert!(!expected_model_pcr.is_empty(), E_BAD_ATTESTATION);
    assert!(freshness_ms > 0, E_BAD_ATTESTATION);

    order.attestation.requires_tee_proof = true;
    order.attestation.expected_attester_pubkey = expected_attester_pubkey;
    order.attestation.expected_model_pcr = expected_model_pcr;
    order.attestation.expected_input_hash = expected_input_hash;
    order.attestation.freshness_ms = freshness_ms;

    event::emit(AttestationConfigured {
        work_order_id: object::id(order),
        expected_attester_pubkey: order.attestation.expected_attester_pubkey,
        expected_model_pcr: order.attestation.expected_model_pcr,
        expected_input_hash: order.attestation.expected_input_hash,
        freshness_ms
    });
}

public fun configure_dispute_validator(
    order: &mut WorkOrder,
    validator: address,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(validator != @0x0, E_UNAUTHORIZED);
    order.evidence.dispute_validator = validator;
}

public fun require_walrus_availability_until(
    order: &mut WorkOrder,
    required_blob_end_epoch: u64,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(required_blob_end_epoch > 0, E_BAD_AVAILABILITY);
    order.evidence.required_blob_end_epoch = required_blob_end_epoch;
}

public fun create_generation_registry(
    breaker_window_ms: u64,
    breaker_amount: u64,
    ctx: &mut TxContext
) {
    let registry = GenerationRegistry {
        id: object::new(ctx),
        generations: table::new<ID, u64>(ctx),
        owners: table::new<ID, address>(ctx),
        paused: false,
        window_started_ms: 0,
        window_drawn: 0,
        breaker_window_ms,
        breaker_amount
    };
    let kill_cap = KillCap {
        id: object::new(ctx),
        root_principal: tx_context::sender(ctx)
    };
    transfer::public_transfer(kill_cap, tx_context::sender(ctx));
    transfer::share_object(registry);
}

public fun register_policy_generation(
    registry: &mut GenerationRegistry,
    policy: &AgentPolicy,
    ctx: &TxContext
) {
    assert!(
        tx_context::sender(ctx) == policy.owner ||
        tx_context::sender(ctx) == policy.root_principal ||
        tx_context::sender(ctx) == policy.agent,
        E_UNAUTHORIZED
    );
    let policy_id = object::id(policy);
    if (!table::contains(&registry.generations, policy_id)) {
        table::add(&mut registry.generations, policy_id, 0);
    };
    if (!table::contains(&registry.owners, policy_id)) {
        table::add(&mut registry.owners, policy_id, policy.root_principal);
    };
}

public fun current_generation(registry: &GenerationRegistry, policy_id: ID): u64 {
    if (table::contains(&registry.generations, policy_id)) {
        *table::borrow(&registry.generations, policy_id)
    } else {
        0
    }
}

public fun policy_is_live(policy: &AgentPolicy, registry: &GenerationRegistry): bool {
    if (policy.revoked || registry.paused) {
        return false
    };
    let mut i = 0;
    let len = vector::length(&policy.ancestors);
    while (i < len) {
        let ancestor = *vector::borrow(&policy.ancestors, i);
        if (current_generation(registry, ancestor) > policy.gen_snapshot) {
            return false
        };
        i = i + 1;
    };
    true
}

public fun revoke_subtree(
    registry: &mut GenerationRegistry,
    policy_id: ID,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(table::contains(&registry.owners, policy_id), E_UNAUTHORIZED);
    assert!(*table::borrow(&registry.owners, policy_id) == tx_context::sender(ctx), E_UNAUTHORIZED);
    let next = bump_generation(registry, policy_id);
    event::emit(RevocationEvent {
        policy_id,
        new_generation: next,
        scope: b"subtree".to_string(),
        actor: tx_context::sender(ctx),
        at_ms: clock::timestamp_ms(clock)
    });
}

public fun emergency_pause(
    registry: &mut GenerationRegistry,
    cap: &KillCap,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == cap.root_principal, E_UNAUTHORIZED);
    registry.paused = true;
    event::emit(RevocationEvent {
        policy_id: object::id(cap),
        new_generation: 0,
        scope: b"fleet_pause".to_string(),
        actor: tx_context::sender(ctx),
        at_ms: clock::timestamp_ms(clock)
    });
}

public fun emergency_unpause(registry: &mut GenerationRegistry, cap: &KillCap, ctx: &TxContext) {
    assert!(tx_context::sender(ctx) == cap.root_principal, E_UNAUTHORIZED);
    registry.paused = false;
}

public fun create_caretaker(scope_hash: vector<u8>, ctx: &mut TxContext) {
    let branch_uid = object::new(ctx);
    let branch_id = object::uid_to_inner(&branch_uid);
    object::delete(branch_uid);
    let caretaker = Caretaker {
        id: object::new(ctx),
        branch_id,
        root_principal: tx_context::sender(ctx),
        live: true,
        scope_hash
    };
    transfer::public_transfer(caretaker, tx_context::sender(ctx));
}

public fun bind_policy_branch(
    registry: &mut GenerationRegistry,
    policy: &mut AgentPolicy,
    caretaker: &Caretaker,
    ctx: &TxContext
) {
    assert!(caretaker.live, E_REVOKED_BY_GENERATION);
    assert!(caretaker.root_principal == policy.root_principal, E_UNAUTHORIZED);
    assert!(
        tx_context::sender(ctx) == policy.owner ||
        tx_context::sender(ctx) == policy.root_principal ||
        tx_context::sender(ctx) == policy.agent,
        E_UNAUTHORIZED
    );
    let branch_id = caretaker.branch_id;
    if (option::is_some(&policy.branch_id)) {
        assert!(*option::borrow(&policy.branch_id) == branch_id, E_BAD_POLICY);
    } else {
        policy.branch_id = option::some(branch_id);
        vector::push_back(&mut policy.ancestors, branch_id);
    };
    register_policy_id(registry, branch_id, policy.root_principal);
    policy.gen_snapshot = max_generation(registry, &policy.ancestors);
}

public fun revoke_branch(
    registry: &mut GenerationRegistry,
    caretaker: &mut Caretaker,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == caretaker.root_principal, E_UNAUTHORIZED);
    caretaker.live = false;
    let next = bump_generation(registry, caretaker.branch_id);
    event::emit(RevocationReceipt {
        branch_id: caretaker.branch_id,
        revoked_at_ms: clock::timestamp_ms(clock),
        scope_hash: caretaker.scope_hash
    });
    event::emit(RevocationEvent {
        policy_id: caretaker.branch_id,
        new_generation: next,
        scope: b"branch".to_string(),
        actor: tx_context::sender(ctx),
        at_ms: clock::timestamp_ms(clock)
    });
}

public fun create_bid_market(
    parent_order: &WorkOrder,
    parent_policy: &AgentPolicy,
    task_hash: vector<u8>,
    reveal_deadline_ms: u64,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == parent_policy.agent || tx_context::sender(ctx) == parent_policy.root_principal, E_UNAUTHORIZED);
    assert!(parent_policy.work_order_id == object::id(parent_order), E_BAD_POLICY);
    let market = BidMarket {
        id: object::new(ctx),
        parent_order_id: object::id(parent_order),
        parent_policy_id: object::id(parent_policy),
        root_principal: parent_policy.root_principal,
        task_hash,
        reveal_deadline_ms,
        best_agent: @0x0,
        best_bid: 0,
        bid_count: 0,
        awarded: false,
        commitments: table::new<address, vector<u8>>(ctx)
    };
    transfer::share_object(market);
}

public fun submit_sealed_bid(
    market: &mut BidMarket,
    sealed_bid_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(clock::timestamp_ms(clock) < market.reveal_deadline_ms, E_BAD_AUCTION);
    let bidder = tx_context::sender(ctx);
    assert!(!table::contains(&market.commitments, bidder), E_BAD_AUCTION);
    table::add(&mut market.commitments, bidder, sealed_bid_hash);
    market.bid_count = market.bid_count + 1;
    event::emit(SealedBidSubmitted {
        market_id: object::id(market),
        bidder,
        sealed_bid_hash
    });
}

public fun sealed_bid_commitment(
    bidder: address,
    bid_amount: u64,
    nonce_hash: vector<u8>
): vector<u8> {
    let mut bid_material = bcs::to_bytes(&bidder);
    vector::append(&mut bid_material, bcs::to_bytes(&bid_amount));
    vector::append(&mut bid_material, nonce_hash);
    hash::blake2b256(&bid_material)
}

public fun open_bid(
    market: &mut BidMarket,
    bid_amount: u64,
    nonce_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(clock::timestamp_ms(clock) >= market.reveal_deadline_ms, E_TOO_EARLY);
    assert!(!market.awarded, E_BAD_AUCTION);
    assert!(bid_amount > 0, E_BAD_AUCTION);
    let bidder = tx_context::sender(ctx);
    assert!(table::contains(&market.commitments, bidder), E_BAD_AUCTION);
    let bid_hash = sealed_bid_commitment(bidder, bid_amount, nonce_hash);
    assert!(bid_hash == *table::borrow(&market.commitments, bidder), E_BAD_AUCTION);
    if (market.best_bid == 0 || bid_amount < market.best_bid) {
        market.best_agent = bidder;
        market.best_bid = bid_amount;
    };
    event::emit(BidOpened {
        market_id: object::id(market),
        bidder,
        bid_amount,
        best_agent: market.best_agent,
        best_bid: market.best_bid
    });
}

public fun award_bid_child_work_order(
    market: &mut BidMarket,
    parent_order: &mut WorkOrder,
    parent_policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    child_provider: address,
    child_actions: u64,
    child_expiry_ms: u64,
    child_cap: u64,
    child_max_uses: u64,
    metadata_hash: vector<u8>,
    mandate_hash: vector<u8>,
    policy_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    child_deadline_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(!market.awarded, E_BAD_AUCTION);
    assert!(market.best_agent != @0x0 && market.best_bid > 0, E_BAD_AUCTION);
    assert!(market.parent_order_id == object::id(parent_order), E_BAD_AUCTION);
    assert!(market.parent_policy_id == object::id(parent_policy), E_BAD_AUCTION);
    market.awarded = true;
    let (child_order_id, child_policy_id) = spawn_child_work_order(
        parent_order,
        parent_policy,
        registry,
        market.best_agent,
        child_provider,
        market.best_bid,
        child_actions,
        child_expiry_ms,
        child_cap,
        child_max_uses,
        metadata_hash,
        mandate_hash,
        policy_hash,
        walrus_blob_id,
        seal_policy_id,
        child_deadline_ms,
        clock,
        ctx
    );
    event::emit(BidAwarded {
        market_id: object::id(market),
        child_order_id,
        child_policy_id,
        winner: market.best_agent,
        bid_amount: market.best_bid
    });
}

public fun reap_abandoned_branch(
    order: &mut WorkOrder,
    policy: &AgentPolicy,
    registry: &mut GenerationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(policy.work_order_id == object::id(order), E_BAD_POLICY);
    let expired = policy.lease_expiry_ms != 0 && clock::timestamp_ms(clock) >= policy.lease_expiry_ms;
    let exhausted = policy.uses >= policy.max_uses;
    assert!(expired || exhausted, E_TOO_EARLY);
    let policy_id = object::id(policy);
    let _new_gen = bump_generation(registry, policy_id);
    if (order.state == STATE_FUNDED || order.state == STATE_DELIVERED || order.state == STATE_REFUND_REQUESTED) {
        order.state = STATE_REFUNDED;
        order.evidence.receipt_hash = derive_receipt(order, b"reaped");
        let payer = order.payer;
        pay_all_escrow(order, payer, ctx);
        let bond_value = balance::value(&order.service_bond);
        let mut bounty = 0;
        if (bond_value > 0) {
            bounty = bond_value / 10;
            if (bounty == 0) {
                bounty = bond_value;
            };
            let reaper = tx_context::sender(ctx);
            let bounty_balance = balance::split(&mut order.service_bond, bounty);
            transfer::public_transfer(coin::from_balance(bounty_balance, ctx), reaper);
            let payer2 = order.payer;
            pay_all_bond(order, payer2, ctx);
        };
        event::emit(ReaperBountyPaid {
            work_order_id: object::id(order),
            policy_id,
            reaper: tx_context::sender(ctx),
            bounty
        });
    };
}

public fun cosign(
    sponsor_policy: &AgentPolicy,
    sponsoree_policy: &AgentPolicy,
    stake: Coin<SUI>,
    decay_ms: u64,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == sponsor_policy.agent || tx_context::sender(ctx) == sponsor_policy.root_principal, E_UNAUTHORIZED);
    assert!(sponsor_policy.root_principal == sponsoree_policy.root_principal, E_BAD_COSIGN);
    assert!(decay_ms > 0, E_BAD_COSIGN);
    let stake_value = coin::value(&stake);
    assert!(stake_value > 0, E_BAD_COSIGN);
    let id = object::new(ctx);
    let cosign_id = object::uid_to_inner(&id);
    let bond = CoSignBond {
        id,
        sponsor_policy_id: object::id(sponsor_policy),
        sponsoree_policy_id: object::id(sponsoree_policy),
        sponsor: tx_context::sender(ctx),
        stake: coin::into_balance(stake),
        decay_ms,
        live: true
    };
    event::emit(CoSignCreated {
        cosign_id,
        sponsor_policy_id: object::id(sponsor_policy),
        sponsoree_policy_id: object::id(sponsoree_policy),
        sponsor: tx_context::sender(ctx),
        stake: stake_value,
        decay_ms
    });
    transfer::public_transfer(bond, tx_context::sender(ctx));
}

public fun slash_cosign_to_vault(
    vault: &mut UnderwritingVault,
    cosign_bond: &mut CoSignBond,
    receipt: &DenialReceipt
) {
    assert!(cosign_bond.live, E_BAD_COSIGN);
    assert!(receipt.policy_id == cosign_bond.sponsoree_policy_id, E_BAD_DENIAL_RECEIPT);
    assert!(vault.policy_id == receipt.policy_id, E_BAD_VAULT);
    let amount = balance::value(&cosign_bond.stake);
    let stake = balance::withdraw_all(&mut cosign_bond.stake);
    balance::join(&mut vault.staked, stake);
    cosign_bond.live = false;
    event::emit(CoSignSlashed {
        cosign_id: object::id(cosign_bond),
        vault_id: object::id(vault),
        sponsoree_policy_id: cosign_bond.sponsoree_policy_id,
        amount
    });
}

public fun release_cosign_after_decay(
    cosign_bond: &mut CoSignBond,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(cosign_bond.live, E_BAD_COSIGN);
    assert!(tx_context::sender(ctx) == cosign_bond.sponsor, E_UNAUTHORIZED);
    assert!(clock::timestamp_ms(clock) >= cosign_bond.decay_ms, E_TOO_EARLY);
    cosign_bond.live = false;
    let stake = balance::withdraw_all(&mut cosign_bond.stake);
    transfer::public_transfer(coin::from_balance(stake, ctx), tx_context::sender(ctx));
}

public fun configure_delivery_confirmation(
    order: &mut WorkOrder,
    expected_output_commitment: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(!expected_output_commitment.is_empty(), E_BAD_DELIVERY_PROOF);
    order.release.condition = RELEASE_CONDITION_DELIVERY_PROOF;
    order.release.expected_output_commitment = expected_output_commitment;
}

public fun new_delivery_proof(
    work_order_id: ID,
    deliverable_hash: vector<u8>,
    proof_chain_root: vector<u8>,
    signer_pubkey: vector<u8>
): DeliveryProof {
    DeliveryProof { work_order_id, deliverable_hash, proof_chain_root, signer_pubkey }
}

public fun delivery_proof_message(proof: &DeliveryProof): vector<u8> {
    let mut payload = b"suiflow-delivery-proof-v1";
    vector::append(&mut payload, bcs::to_bytes(proof));
    hash::blake2b256(&payload)
}

public fun verify_and_release_delivery_proof(
    order: &mut WorkOrder,
    proof: DeliveryProof,
    signature: vector<u8>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.release.condition == RELEASE_CONDITION_DELIVERY_PROOF, E_BAD_DELIVERY_PROOF);
    assert!(proof.work_order_id == object::id(order), E_BAD_DELIVERY_PROOF);
    assert!(proof.deliverable_hash == order.release.expected_output_commitment, E_BAD_DELIVERY_PROOF);
    let msg = delivery_proof_message(&proof);
    assert!(ed25519::ed25519_verify(&signature, &proof.signer_pubkey, &msg), E_BAD_DELIVERY_PROOF);
    order.release.proof_chain_root = proof.proof_chain_root;
    order.evidence.delivered_output_hash = proof.deliverable_hash;
    order.state = STATE_DELIVERED;
    order.evidence.receipt_hash = derive_receipt(order, b"delivery_proof_released");
    event::emit(DeliveryProofAccepted {
        work_order_id: object::id(order),
        signer: proof.signer_pubkey,
        proof_chain_root: order.release.proof_chain_root,
        receipt_hash: order.evidence.receipt_hash
    });
    do_release(order, tx_context::sender(ctx), ctx);
}

public fun create_execution_binding_registry(ctx: &mut TxContext) {
    let registry = ExecutionBindingRegistry {
        id: object::new(ctx),
        used_nullifiers: table::new<vector<u8>, bool>(ctx)
    };
    transfer::share_object(registry);
}

public fun execution_context_digest(
    order: &WorkOrder,
    service_endpoint_hash: vector<u8>,
    payment_intent_hash: vector<u8>,
    quote_hash: vector<u8>
): vector<u8> {
    let mut payload = b"suiflow-execution-context-v1";
    vector::append(&mut payload, bcs::to_bytes(&object::id(order)));
    vector::append(&mut payload, service_endpoint_hash);
    vector::append(&mut payload, payment_intent_hash);
    vector::append(&mut payload, quote_hash);
    hash::blake2b256(&payload)
}

public fun configure_execution_context(
    order: &mut WorkOrder,
    service_endpoint_hash: vector<u8>,
    payment_intent_hash: vector<u8>,
    quote_hash: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(!service_endpoint_hash.is_empty(), E_BAD_EXECUTION_BINDING);
    assert!(!payment_intent_hash.is_empty(), E_BAD_EXECUTION_BINDING);
    assert!(!quote_hash.is_empty(), E_BAD_EXECUTION_BINDING);
    let digest = execution_context_digest(order, service_endpoint_hash, payment_intent_hash, quote_hash);
    order.execution.context_hash = digest;
    event::emit(ExecutionContextBound {
        work_order_id: object::id(order),
        execution_context_hash: digest,
        service_endpoint_hash,
        payment_intent_hash,
        quote_hash
    });
}

public fun consume_execution_receipt(
    registry: &mut ExecutionBindingRegistry,
    order: &mut WorkOrder,
    service_receipt_hash: vector<u8>,
    nullifier_hash: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer || tx_context::sender(ctx) == order.provider, E_UNAUTHORIZED);
    do_consume_execution_receipt(registry, order, service_receipt_hash, nullifier_hash, tx_context::sender(ctx));
}

public fun meter_release_with_execution_binding(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    execution_registry: &mut ExecutionBindingRegistry,
    units: u64,
    unit_price: u64,
    usage_proof_hash: vector<u8>,
    service_receipt_hash: vector<u8>,
    nullifier_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    do_consume_execution_receipt(execution_registry, order, service_receipt_hash, nullifier_hash, tx_context::sender(ctx));
    meter_release(order, policy, registry, units, unit_price, usage_proof_hash, clock, ctx);
}

public fun configure_privacy_budget(
    order: &mut WorkOrder,
    privacy_budget: u64,
    privacy_manifest_hash: vector<u8>,
    privacy_trace_root: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(privacy_budget > 0, E_BAD_PRIVACY_BUDGET);
    assert!(!privacy_manifest_hash.is_empty(), E_BAD_PRIVACY_BUDGET);
    order.privacy.budget = privacy_budget;
    order.privacy.manifest_hash = privacy_manifest_hash;
    order.privacy.trace_root = privacy_trace_root;
    event::emit(PrivacyBudgetConfigured {
        work_order_id: object::id(order),
        privacy_budget,
        privacy_manifest_hash: order.privacy.manifest_hash,
        privacy_trace_root: order.privacy.trace_root
    });
}

public fun allocate_policy_privacy_budget(
    order: &WorkOrder,
    policy: &mut AgentPolicy,
    privacy_budget: u64,
    ctx: &TxContext
) {
    assert!(policy.work_order_id == object::id(order), E_BAD_POLICY);
    assert!(
        tx_context::sender(ctx) == policy.owner ||
        tx_context::sender(ctx) == policy.root_principal ||
        tx_context::sender(ctx) == policy.agent,
        E_UNAUTHORIZED
    );
    assert!(order.privacy.budget > 0, E_BAD_PRIVACY_BUDGET);
    assert!(privacy_budget > 0 && privacy_budget <= order.privacy.budget - order.privacy.used, E_BAD_PRIVACY_BUDGET);
    policy.privacy_budget_remaining = privacy_budget;
}

public fun privacy_weighted_score(content_leak_score: u64, behavior_leak_score: u64): u64 {
    assert!(behavior_leak_score <= (18446744073709551615 - content_leak_score) / 5, E_BAD_PRIVACY_BUDGET);
    content_leak_score + (behavior_leak_score * 5)
}

public fun record_privacy_receipt(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    content_leak_score: u64,
    behavior_leak_score: u64,
    trace_commitment: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_REPORT_PRIVACY, clock, ctx);
    assert!(order.privacy.budget > 0, E_BAD_PRIVACY_BUDGET);
    assert!(!trace_commitment.is_empty(), E_BAD_PRIVACY_BUDGET);
    let weighted_score = privacy_weighted_score(content_leak_score, behavior_leak_score);
    assert!(weighted_score > 0, E_BAD_PRIVACY_BUDGET);
    assert!(weighted_score <= policy.privacy_budget_remaining, E_BAD_PRIVACY_BUDGET);
    assert!(order.privacy.used + weighted_score <= order.privacy.budget, E_BAD_PRIVACY_BUDGET);
    policy.privacy_budget_remaining = policy.privacy_budget_remaining - weighted_score;
    order.privacy.used = order.privacy.used + weighted_score;
    order.privacy.trace_root = trace_commitment;
    let receipt = PrivacyReceipt {
        id: object::new(ctx),
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter: tx_context::sender(ctx),
        content_leak_score,
        behavior_leak_score,
        weighted_score,
        trace_commitment: order.privacy.trace_root,
        walrus_blob_id,
        seal_policy_id,
        evidence_hash,
        observed_ms: clock::timestamp_ms(clock)
    };
    event::emit(PrivacyReceiptRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter: tx_context::sender(ctx),
        weighted_score,
        privacy_used: order.privacy.used,
        privacy_budget_remaining: policy.privacy_budget_remaining,
        evidence_hash
    });
    transfer::public_transfer(receipt, order.payer);
}

public fun record_privacy_breach_receipt(
    order: &WorkOrder,
    policy: &AgentPolicy,
    content_leak_score: u64,
    behavior_leak_score: u64,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(policy.work_order_id == object::id(order), E_BAD_POLICY);
    assert!(order.privacy.budget > 0, E_BAD_PRIVACY_BUDGET);
    let weighted_score = privacy_weighted_score(content_leak_score, behavior_leak_score);
    let remaining = if (order.privacy.budget > order.privacy.used) {
        order.privacy.budget - order.privacy.used
    } else {
        0
    };
    assert!(weighted_score > policy.privacy_budget_remaining || weighted_score > remaining, E_BAD_PRIVACY_BUDGET);
    let receipt = PrivacyBreachReceipt {
        id: object::new(ctx),
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter: tx_context::sender(ctx),
        weighted_score,
        remaining_budget: policy.privacy_budget_remaining,
        evidence_hash,
        observed_ms: clock::timestamp_ms(clock)
    };
    event::emit(PrivacyBreachRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter: tx_context::sender(ctx),
        weighted_score,
        remaining_budget: policy.privacy_budget_remaining,
        evidence_hash
    });
    transfer::public_transfer(receipt, order.payer);
}

public fun file_privacy_claim(
    vault: &mut UnderwritingVault,
    order: &WorkOrder,
    receipt: PrivacyBreachReceipt,
    ctx: &mut TxContext
) {
    let PrivacyBreachReceipt {
        id,
        work_order_id,
        policy_id,
        reporter: _,
        weighted_score: _,
        remaining_budget: _,
        evidence_hash: _,
        observed_ms: _
    } = receipt;
    object::delete(id);
    assert!(policy_id == vault.policy_id, E_BAD_PRIVACY_BUDGET);
    assert!(work_order_id == object::id(order), E_BAD_PRIVACY_BUDGET);
    let mut payout = vault.coverage_cap;
    if (payout > order.amount) {
        payout = order.amount;
    };
    let available = balance::value(&vault.staked);
    if (payout > available) {
        payout = available;
    };
    assert!(payout > 0, E_BAD_VAULT);
    vault.claims_paid = vault.claims_paid + payout;
    let paid = balance::split(&mut vault.staked, payout);
    transfer::public_transfer(coin::from_balance(paid, ctx), order.payer);
    event::emit(ClaimPaid {
        vault_id: object::id(vault),
        work_order_id,
        policy_id,
        payer: order.payer,
        amount: payout
    });
}

public fun configure_origin_firewall(
    order: &mut WorkOrder,
    origin_manifest_hash: vector<u8>,
    tool_manifest_hash: vector<u8>,
    critic_policy_hash: vector<u8>,
    critic_risk_threshold: u64,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(!origin_manifest_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(!tool_manifest_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(!critic_policy_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(critic_risk_threshold > 0, E_BAD_ORIGIN_CRITIC);
    order.origin.manifest_hash = origin_manifest_hash;
    order.origin.tool_manifest_hash = tool_manifest_hash;
    order.origin.critic_policy_hash = critic_policy_hash;
    order.origin.risk_threshold = critic_risk_threshold;
    order.origin.risk_score = 0;
    order.origin.quarantined = false;
    event::emit(OriginFirewallConfigured {
        work_order_id: object::id(order),
        origin_manifest_hash: order.origin.manifest_hash,
        tool_manifest_hash: order.origin.tool_manifest_hash,
        critic_policy_hash: order.origin.critic_policy_hash,
        critic_risk_threshold
    });
}

public fun allocate_policy_origin_risk_budget(
    order: &WorkOrder,
    policy: &mut AgentPolicy,
    risk_budget: u64,
    ctx: &TxContext
) {
    assert!(policy.work_order_id == object::id(order), E_BAD_POLICY);
    assert!(
        tx_context::sender(ctx) == policy.owner ||
        tx_context::sender(ctx) == policy.root_principal ||
        tx_context::sender(ctx) == policy.agent,
        E_UNAUTHORIZED
    );
    assert!(order.origin.risk_threshold > 0, E_BAD_ORIGIN_CRITIC);
    assert!(risk_budget > 0 && risk_budget <= order.origin.risk_threshold, E_BAD_ORIGIN_CRITIC);
    policy.origin_risk_budget_remaining = risk_budget;
}

public fun record_origin_critic_receipt(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    observed_origin_hash: vector<u8>,
    observed_tool_hash: vector<u8>,
    user_intent_hash: vector<u8>,
    tool_call_hash: vector<u8>,
    risk_score: u64,
    critic_trace_root: vector<u8>,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_REPORT_ORIGIN_RISK, clock, ctx);
    assert!(order.origin.risk_threshold > 0, E_BAD_ORIGIN_CRITIC);
    assert!(!observed_origin_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(!observed_tool_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(!user_intent_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(!tool_call_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(!critic_trace_root.is_empty(), E_BAD_ORIGIN_CRITIC);
    assert!(risk_score > 0, E_BAD_ORIGIN_CRITIC);
    assert!(risk_score <= policy.origin_risk_budget_remaining, E_BAD_ORIGIN_CRITIC);
    assert!(order.origin.risk_score <= 18446744073709551615 - risk_score, E_BAD_ORIGIN_CRITIC);
    order.origin.risk_score = order.origin.risk_score + risk_score;
    policy.origin_risk_budget_remaining = policy.origin_risk_budget_remaining - risk_score;
    order.origin.trace_root = critic_trace_root;
    let quarantined =
        observed_origin_hash != order.origin.manifest_hash ||
        observed_tool_hash != order.origin.tool_manifest_hash ||
        order.origin.risk_score >= order.origin.risk_threshold;
    if (quarantined) {
        order.origin.quarantined = true;
    };
    let receipt = OriginCriticReceipt {
        id: object::new(ctx),
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter: tx_context::sender(ctx),
        observed_origin_hash,
        observed_tool_hash,
        user_intent_hash,
        tool_call_hash,
        risk_score,
        quarantined,
        evidence_hash,
        observed_ms: clock::timestamp_ms(clock)
    };
    event::emit(OriginCriticRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter: tx_context::sender(ctx),
        risk_score,
        running_risk_score: order.origin.risk_score,
        quarantined,
        critic_trace_root: order.origin.trace_root,
        evidence_hash
    });
    transfer::public_transfer(receipt, order.payer);
}

public fun clear_origin_quarantine(
    order: &mut WorkOrder,
    resolution_hash: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.origin.quarantined, E_BAD_ORIGIN_CRITIC);
    assert!(!resolution_hash.is_empty(), E_BAD_ORIGIN_CRITIC);
    order.origin.quarantined = false;
    order.origin.risk_score = 0;
    order.origin.trace_root = resolution_hash;
    event::emit(OriginQuarantineCleared {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        risk_score: order.origin.risk_score,
        resolution_hash
    });
}

public fun spawn_child_work_order(
    parent_order: &mut WorkOrder,
    parent_policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    sub_agent: address,
    child_provider: address,
    child_amount: u64,
    child_actions: u64,
    child_expiry_ms: u64,
    child_cap: u64,
    child_max_uses: u64,
    metadata_hash: vector<u8>,
    mandate_hash: vector<u8>,
    policy_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    seal_policy_id: vector<u8>,
    child_deadline_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext
): (ID, ID) {
    assert_agent_policy_live(parent_order, parent_policy, registry, ACTION_PROPOSE_SETTLEMENT, clock, ctx);
    assert!(child_amount > 0 && child_amount <= parent_policy.remaining_budget, E_BAD_ATTENUATION);
    assert!(child_amount <= balance::value(&parent_order.escrow), E_BAD_ATTENUATION);
    assert!((child_actions & parent_policy.allowed_actions) == child_actions, E_BAD_ATTENUATION);
    assert!(parent_policy.expires_ms == 0 || child_expiry_ms <= parent_policy.expires_ms, E_BAD_ATTENUATION);
    assert!(parent_policy.max_provider_amount == 0 || child_cap <= parent_policy.max_provider_amount, E_BAD_ATTENUATION);
    assert!(parent_policy.depth + 1 <= MAX_DEPTH, E_TOO_DEEP);
    assert!(child_max_uses > 0, E_BAD_POLICY);

    parent_policy.remaining_budget = parent_policy.remaining_budget - child_amount;
    parent_order.graph.child_budget_allocated = parent_order.graph.child_budget_allocated + child_amount;
    let child_escrow = balance::split(&mut parent_order.escrow, child_amount);

    let child_id = object::new(ctx);
    let child_order_id = object::uid_to_inner(&child_id);
    let parent_order_id = object::id(parent_order);
    let parent_policy_id = object::id(parent_policy);
    let child_policy_uid = object::new(ctx);
    let child_policy_id = object::uid_to_inner(&child_policy_uid);
    let mut ancestors = parent_policy.ancestors;
    vector::push_back(&mut ancestors, child_policy_id);
    let gen_snapshot = max_generation(registry, &ancestors);

    let child_order = WorkOrder {
        id: child_id,
        payer: parent_order.payer,
        provider: child_provider,
        amount: child_amount,
        escrow: child_escrow,
        service_bond: balance::zero<SUI>(),
        state: STATE_FUNDED,
        created_ms: clock::timestamp_ms(clock),
        deadline_ms: child_deadline_ms,
        refund_requested_ms: 0,
        settlement_proposed_by: @0x0,
        settlement_provider_amount: 0,
        metadata_hash,
        mandate_hash,
        policy_hash,
        walrus_blob_id,
        seal_policy_id,
        attestation: AttestationState {
            requires_tee_proof: parent_order.attestation.requires_tee_proof,
            expected_attester_pubkey: parent_order.attestation.expected_attester_pubkey,
            expected_model_pcr: parent_order.attestation.expected_model_pcr,
            expected_input_hash: parent_order.attestation.expected_input_hash,
            freshness_ms: parent_order.attestation.freshness_ms
        },
        evidence: EvidenceState {
            delivered_output_hash: vector[],
            dispute_validator: parent_order.evidence.dispute_validator,
            required_blob_end_epoch: parent_order.evidence.required_blob_end_epoch,
            verified_blob_certified_epoch: 0,
            verified_blob_end_epoch: 0,
            delivery_evidence_hash: vector[],
            dispute_evidence_hash: vector[],
            receipt_hash: vector[]
        },
        feedback_count: 0,
        validation_count: 0,
        validation_root: vector[],
        graph: GraphState {
            parent_order_id: option::some(parent_order_id),
            parent_policy_id: option::some(parent_policy_id),
            root_principal: parent_policy.root_principal,
            depth: parent_policy.depth + 1,
            child_budget_allocated: 0
        },
        metered: MeteredState { paid: 0, premium_paid: 0 },
        release: ReleaseState {
            condition: parent_order.release.condition,
            expected_output_commitment: parent_order.release.expected_output_commitment,
            proof_chain_root: parent_order.release.proof_chain_root
        },
        privacy: PrivacyState {
            budget: parent_order.privacy.budget,
            used: parent_order.privacy.used,
            manifest_hash: parent_order.privacy.manifest_hash,
            trace_root: parent_order.privacy.trace_root
        },
        execution: ExecutionState {
            context_hash: parent_order.execution.context_hash,
            receipt_hash: vector[]
        },
        origin: OriginCriticState {
            manifest_hash: parent_order.origin.manifest_hash,
            tool_manifest_hash: parent_order.origin.tool_manifest_hash,
            critic_policy_hash: parent_order.origin.critic_policy_hash,
            risk_score: parent_order.origin.risk_score,
            risk_threshold: parent_order.origin.risk_threshold,
            quarantined: parent_order.origin.quarantined,
            trace_root: parent_order.origin.trace_root
        }
    };

    let child_policy = AgentPolicy {
        id: child_policy_uid,
        work_order_id: child_order_id,
        owner: tx_context::sender(ctx),
        agent: sub_agent,
        allowed_actions: child_actions,
        expires_ms: child_expiry_ms,
        max_uses: child_max_uses,
        uses: 0,
        max_provider_amount: child_cap,
        policy_hash,
        revoked: false,
        parent_policy_id: option::some(parent_policy_id),
        root_principal: parent_policy.root_principal,
        depth: parent_policy.depth + 1,
        ancestors,
        gen_snapshot,
        remaining_budget: child_amount,
        controller_id: parent_policy.controller_id,
        lease_expiry_ms: child_expiry_ms,
        branch_id: parent_policy.branch_id,
        privacy_budget_remaining: 0,
        origin_risk_budget_remaining: parent_policy.origin_risk_budget_remaining
    };

    register_policy_id(registry, child_policy_id, parent_policy.root_principal);

    event::emit(SubDelegation {
        parent_order_id,
        child_order_id,
        parent_policy_id,
        child_policy_id,
        root_principal: parent_policy.root_principal,
        sub_agent,
        depth: parent_policy.depth + 1,
        child_amount,
        child_actions
    });

    transfer::public_transfer(child_policy, sub_agent);
    transfer::share_object(child_order);
    (child_order_id, child_policy_id)
}

public fun issue_agent_policy(
    order: &WorkOrder,
    agent: address,
    allowed_actions: u64,
    expires_ms: u64,
    max_uses: u64,
    max_provider_amount: u64,
    policy_hash: vector<u8>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == order.payer || sender == order.provider, E_UNAUTHORIZED);
    assert!(allowed_actions > 0, E_BAD_POLICY);
    assert!(max_uses > 0, E_BAD_POLICY);

    let id = object::new(ctx);
    let policy_id = object::uid_to_inner(&id);
    let work_order_id = object::id(order);
    let mut ancestors = vector[];
    vector::push_back(&mut ancestors, policy_id);
    let policy = AgentPolicy {
        id,
        work_order_id,
        owner: sender,
        agent,
        allowed_actions,
        expires_ms,
        max_uses,
        uses: 0,
        max_provider_amount,
        policy_hash,
        revoked: false,
        parent_policy_id: option::none<ID>(),
        root_principal: order.graph.root_principal,
        depth: order.graph.depth,
        ancestors,
        gen_snapshot: 0,
        remaining_budget: order.amount,
        controller_id: policy_id,
        lease_expiry_ms: expires_ms,
        branch_id: option::none<ID>(),
        privacy_budget_remaining: 0,
        origin_risk_budget_remaining: 0
    };

    event::emit(AgentPolicyIssued {
        policy_id,
        work_order_id,
        owner: sender,
        agent,
        allowed_actions,
        expires_ms,
        max_uses,
        max_provider_amount,
        policy_hash: policy.policy_hash
    });

    transfer::public_transfer(policy, agent);
}

public fun revoke_agent_policy(policy: &mut AgentPolicy, ctx: &TxContext) {
    assert!(tx_context::sender(ctx) == policy.owner, E_UNAUTHORIZED);
    policy.revoked = true;
}

public fun post_service_bond(order: &mut WorkOrder, bond: Coin<SUI>, ctx: &TxContext) {
    assert!(tx_context::sender(ctx) == order.provider, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED || order.state == STATE_CREATED, E_BAD_STATE);
    let value = coin::value(&bond);
    assert!(value > 0, E_BAD_BOND);
    balance::join(&mut order.service_bond, coin::into_balance(bond));

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        state: order.state,
        label: b"service_bond_posted".to_string(),
        evidence_hash: vector[],
        receipt_hash: vector[]
    });
}

public fun mark_delivered(
    order: &mut WorkOrder,
    evidence_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.provider, E_UNAUTHORIZED);
    do_mark_delivered(order, evidence_hash, walrus_blob_id, tx_context::sender(ctx));
}

public fun agent_mark_delivered(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    evidence_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy(order, policy, ACTION_MARK_DELIVERED, clock, ctx);
    do_mark_delivered(order, evidence_hash, walrus_blob_id, tx_context::sender(ctx));
}

public fun agent_mark_delivered_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    evidence_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_MARK_DELIVERED, clock, ctx);
    do_mark_delivered(order, evidence_hash, walrus_blob_id, tx_context::sender(ctx));
}

public fun mark_delivered_with_availability(
    order: &mut WorkOrder,
    evidence_hash: vector<u8>,
    proof: WalrusAvailabilityProof,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.provider, E_UNAUTHORIZED);
    do_mark_delivered_with_availability(order, evidence_hash, proof, tx_context::sender(ctx));
}

public fun mark_delivered_with_availability_fields(
    order: &mut WorkOrder,
    evidence_hash: vector<u8>,
    blob_id: vector<u8>,
    certified_epoch: u64,
    end_epoch: u64,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.provider, E_UNAUTHORIZED);
    let proof = new_walrus_availability_proof(blob_id, certified_epoch, end_epoch);
    do_mark_delivered_with_availability(order, evidence_hash, proof, tx_context::sender(ctx));
}

public fun agent_mark_delivered_with_availability(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    evidence_hash: vector<u8>,
    proof: WalrusAvailabilityProof,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy(order, policy, ACTION_MARK_DELIVERED, clock, ctx);
    do_mark_delivered_with_availability(order, evidence_hash, proof, tx_context::sender(ctx));
}

public fun agent_mark_delivered_with_availability_fields(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    evidence_hash: vector<u8>,
    blob_id: vector<u8>,
    certified_epoch: u64,
    end_epoch: u64,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy(order, policy, ACTION_MARK_DELIVERED, clock, ctx);
    let proof = new_walrus_availability_proof(blob_id, certified_epoch, end_epoch);
    do_mark_delivered_with_availability(order, evidence_hash, proof, tx_context::sender(ctx));
}

public fun agent_mark_delivered_with_availability_fields_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    evidence_hash: vector<u8>,
    blob_id: vector<u8>,
    certified_epoch: u64,
    end_epoch: u64,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_MARK_DELIVERED, clock, ctx);
    let proof = new_walrus_availability_proof(blob_id, certified_epoch, end_epoch);
    do_mark_delivered_with_availability(order, evidence_hash, proof, tx_context::sender(ctx));
}

public fun release(order: &mut WorkOrder, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(!order.attestation.requires_tee_proof, E_BAD_ATTESTATION);
    do_release(order, tx_context::sender(ctx), ctx);
}

public fun agent_release(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy(order, policy, ACTION_RELEASE, clock, ctx);
    assert!(!order.attestation.requires_tee_proof, E_BAD_ATTESTATION);
    do_release(order, tx_context::sender(ctx), ctx);
}

public fun agent_release_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_RELEASE, clock, ctx);
    assert!(!order.attestation.requires_tee_proof, E_BAD_ATTESTATION);
    record_registry_draw(registry, balance::value(&order.escrow), clock, tx_context::sender(ctx));
    do_release(order, tx_context::sender(ctx), ctx);
}

public fun release_with_attestation(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    receipt: WorkReceipt,
    attested_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy(order, policy, ACTION_RELEASE, clock, ctx);
    let (valid, _) = attestation_status(order, policy, tx_context::sender(ctx), &receipt, attested_ms, &signature, clock);
    assert!(valid, E_BAD_ATTESTATION);

    let receipt_digest = work_receipt_digest(&receipt);
    event::emit(AttestationReleaseRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        agent: tx_context::sender(ctx),
        receipt_digest,
        attested_ms
    });

    do_release(order, tx_context::sender(ctx), ctx);
}

public fun release_with_attestation_fields(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    input_hash: vector<u8>,
    output_hash: vector<u8>,
    model_pcr: vector<u8>,
    attested_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let receipt = new_work_receipt(
        object::id(order),
        tx_context::sender(ctx),
        input_hash,
        output_hash,
        model_pcr,
        STATE_DELIVERED
    );
    release_with_attestation(order, policy, receipt, attested_ms, signature, clock, ctx);
}

public fun release_with_attestation_fields_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    input_hash: vector<u8>,
    output_hash: vector<u8>,
    model_pcr: vector<u8>,
    attested_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_RELEASE, clock, ctx);
    let receipt = new_work_receipt(
        object::id(order),
        tx_context::sender(ctx),
        input_hash,
        output_hash,
        model_pcr,
        STATE_DELIVERED
    );
    let (valid, _) = attestation_status(order, policy, tx_context::sender(ctx), &receipt, attested_ms, &signature, clock);
    assert!(valid, E_BAD_ATTESTATION);
    record_registry_draw(registry, balance::value(&order.escrow), clock, tx_context::sender(ctx));
    let receipt_digest = work_receipt_digest(&receipt);
    event::emit(AttestationReleaseRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        agent: tx_context::sender(ctx),
        receipt_digest,
        attested_ms
    });
    do_release(order, tx_context::sender(ctx), ctx);
}

public fun request_refund(
    order: &mut WorkOrder,
    dispute_evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    do_request_refund(order, dispute_evidence_hash, clock, tx_context::sender(ctx));
}

public fun agent_request_refund(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    dispute_evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy(order, policy, ACTION_REQUEST_REFUND, clock, ctx);
    do_request_refund(order, dispute_evidence_hash, clock, tx_context::sender(ctx));
}

public fun agent_request_refund_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    dispute_evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_REQUEST_REFUND, clock, ctx);
    do_request_refund(order, dispute_evidence_hash, clock, tx_context::sender(ctx));
}

public fun timeout_refund(order: &mut WorkOrder, clock: &Clock, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_REFUND_REQUESTED || order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(clock::timestamp_ms(clock) >= order.deadline_ms, E_TOO_EARLY);

    order.state = STATE_REFUNDED;
    order.evidence.receipt_hash = derive_receipt(order, b"refunded");
    let payer = order.payer;
    pay_all_escrow(order, payer, ctx);

    let slashed = balance::value(&order.service_bond) > 0;
    if (slashed) {
        pay_all_bond(order, payer, ctx);
    };

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        state: order.state,
        label: b"timeout_refund".to_string(),
        evidence_hash: order.evidence.dispute_evidence_hash,
        receipt_hash: order.evidence.receipt_hash
    });
}

public fun propose_split_settlement(
    order: &mut WorkOrder,
    provider_amount: u64,
    evidence_hash: vector<u8>,
    ctx: &TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == order.payer || sender == order.provider, E_UNAUTHORIZED);
    assert!(order.state == STATE_FUNDED || order.state == STATE_DELIVERED || order.state == STATE_REFUND_REQUESTED, E_BAD_STATE);
    assert!(provider_amount <= order.amount, E_BAD_SETTLEMENT);

    order.settlement_proposed_by = sender;
    order.settlement_provider_amount = provider_amount;
    order.evidence.dispute_evidence_hash = evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: sender,
        state: order.state,
        label: b"split_settlement_proposed".to_string(),
        evidence_hash: order.evidence.dispute_evidence_hash,
        receipt_hash: vector[]
    });
}

public fun agent_propose_split_settlement(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    provider_amount: u64,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy(order, policy, ACTION_PROPOSE_SETTLEMENT, clock, ctx);
    assert!(provider_amount <= order.amount, E_BAD_SETTLEMENT);
    assert!(policy.max_provider_amount == 0 || provider_amount <= policy.max_provider_amount, E_BAD_SETTLEMENT);
    order.settlement_proposed_by = tx_context::sender(ctx);
    order.settlement_provider_amount = provider_amount;
    order.evidence.dispute_evidence_hash = evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        state: order.state,
        label: b"agent_split_settlement_proposed".to_string(),
        evidence_hash: order.evidence.dispute_evidence_hash,
        receipt_hash: vector[]
    });
}

public fun agent_propose_split_settlement_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    provider_amount: u64,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_PROPOSE_SETTLEMENT, clock, ctx);
    assert!(provider_amount <= order.amount, E_BAD_SETTLEMENT);
    assert!(policy.max_provider_amount == 0 || provider_amount <= policy.max_provider_amount, E_BAD_SETTLEMENT);
    order.settlement_proposed_by = tx_context::sender(ctx);
    order.settlement_provider_amount = provider_amount;
    order.evidence.dispute_evidence_hash = evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        state: order.state,
        label: b"agent_split_settlement_proposed_live".to_string(),
        evidence_hash: order.evidence.dispute_evidence_hash,
        receipt_hash: vector[]
    });
}

public fun accept_split_settlement(order: &mut WorkOrder, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(sender == order.payer || sender == order.provider, E_UNAUTHORIZED);
    assert!(order.settlement_proposed_by != @0x0, E_BAD_SETTLEMENT);
    assert!(sender != order.settlement_proposed_by, E_UNAUTHORIZED);
    do_accept_split_settlement(order, sender, ctx);
}

public fun agent_accept_split_settlement(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy(order, policy, ACTION_ACCEPT_SETTLEMENT, clock, ctx);
    assert!(order.settlement_proposed_by != @0x0, E_BAD_SETTLEMENT);
    do_accept_split_settlement(order, tx_context::sender(ctx), ctx);
}

public fun agent_accept_split_settlement_live(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_ACCEPT_SETTLEMENT, clock, ctx);
    assert!(order.settlement_proposed_by != @0x0, E_BAD_SETTLEMENT);
    record_registry_draw(registry, order.settlement_provider_amount, clock, tx_context::sender(ctx));
    do_accept_split_settlement(order, tx_context::sender(ctx), ctx);
}

public fun create_exposure_aggregator(
    controller_id: ID,
    base_premium_bps: u64,
    ctx: &mut TxContext
) {
    assert!(base_premium_bps <= BASIS_POINTS, E_BAD_EXPOSURE);
    let aggregator = ExposureAggregator {
        id: object::new(ctx),
        controller_id,
        window_exposure: 0,
        premium_bps: base_premium_bps
    };
    transfer::share_object(aggregator);
}

public fun record_exposure(
    aggregator: &mut ExposureAggregator,
    controller_id: ID,
    amount: u64,
    ctx: &TxContext
): ExposureTicket {
    assert!(controller_id == aggregator.controller_id, E_BAD_EXPOSURE);
    aggregator.window_exposure = aggregator.window_exposure + amount;
    let premium_bps = aggregator.premium_bps + exposure_ramp_bps(aggregator.window_exposure);
    assert!(premium_bps <= BASIS_POINTS, E_BAD_EXPOSURE);
    event::emit(ExposureRecorded {
        aggregator_id: object::id(aggregator),
        controller_id,
        amount,
        window_exposure: aggregator.window_exposure,
        premium_bps
    });
    let _sender = tx_context::sender(ctx);
    ExposureTicket { controller_id, amount, premium_bps }
}

public fun create_underwriting_vault(
    policy: &AgentPolicy,
    coverage_cap: u64,
    premium_bps: u64,
    ctx: &mut TxContext
) {
    assert!(
        tx_context::sender(ctx) == policy.owner ||
        tx_context::sender(ctx) == policy.root_principal ||
        tx_context::sender(ctx) == policy.agent,
        E_UNAUTHORIZED
    );
    assert!(coverage_cap > 0, E_BAD_VAULT);
    assert!(premium_bps <= BASIS_POINTS, E_BAD_VAULT);
    let id = object::new(ctx);
    let vault_id = object::uid_to_inner(&id);
    let vault = UnderwritingVault {
        id,
        policy_id: object::id(policy),
        staked: balance::zero<SUI>(),
        coverage_cap,
        premium_bps,
        active_exposure: 0,
        claims_paid: 0,
        controller_id: policy.controller_id,
        window_exposure: 0
    };
    event::emit(UnderwritingVaultCreated {
        vault_id,
        policy_id: object::id(policy),
        coverage_cap,
        premium_bps,
        controller_id: policy.controller_id
    });
    transfer::share_object(vault);
}

public fun stake_backing(
    vault: &mut UnderwritingVault,
    backing: Coin<SUI>,
    ctx: &mut TxContext
) {
    let principal = coin::value(&backing);
    assert!(principal > 0, E_BAD_VAULT);
    balance::join(&mut vault.staked, coin::into_balance(backing));
    let position = UnderwriterPosition {
        id: object::new(ctx),
        vault_id: object::id(vault),
        owner: tx_context::sender(ctx),
        principal,
        shares: principal
    };
    transfer::public_transfer(position, tx_context::sender(ctx));
}

public fun meter_release(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    units: u64,
    unit_price: u64,
    usage_proof_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy_live(order, policy, registry, ACTION_METER_RELEASE, clock, ctx);
    assert_not_origin_quarantined(order);
    let amount = units * unit_price;
    assert!(amount > 0, E_BAD_SETTLEMENT);
    assert!(amount <= balance::value(&order.escrow), E_BAD_SETTLEMENT);
    assert!(amount <= policy.remaining_budget, E_BAD_SETTLEMENT);
    assert!(policy.max_provider_amount == 0 || amount <= policy.max_provider_amount, E_BAD_SETTLEMENT);
    record_registry_draw(registry, amount, clock, tx_context::sender(ctx));
    policy.remaining_budget = policy.remaining_budget - amount;
    order.metered.paid = order.metered.paid + amount;
    let provider = order.provider;
    pay_escrow_amount(order, provider, amount, ctx);
    event::emit(MeteredDraw {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        agent: tx_context::sender(ctx),
        units,
        unit_price,
        paid: amount,
        premium: 0,
        running_total: order.metered.paid,
        usage_proof_hash
    });
}

public fun meter_release_with_vault(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    registry: &mut GenerationRegistry,
    vault: &mut UnderwritingVault,
    ticket: ExposureTicket,
    units: u64,
    unit_price: u64,
    usage_proof_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(vault.policy_id == object::id(policy), E_BAD_VAULT);
    assert!(ticket.controller_id == policy.controller_id, E_BAD_EXPOSURE);
    let ExposureTicket { controller_id: _, amount: ticket_amount, premium_bps } = ticket;
    let amount = units * unit_price;
    assert!(ticket_amount >= amount, E_BAD_EXPOSURE);
    assert_agent_policy_live(order, policy, registry, ACTION_METER_RELEASE, clock, ctx);
    assert_not_origin_quarantined(order);
    assert!(amount > 0, E_BAD_SETTLEMENT);
    assert!(amount <= balance::value(&order.escrow), E_BAD_SETTLEMENT);
    assert!(amount <= policy.remaining_budget, E_BAD_SETTLEMENT);
    assert!(policy.max_provider_amount == 0 || amount <= policy.max_provider_amount, E_BAD_SETTLEMENT);
    record_registry_draw(registry, amount, clock, tx_context::sender(ctx));

    let premium = amount * premium_bps / BASIS_POINTS;
    let provider_amount = amount - premium;
    policy.remaining_budget = policy.remaining_budget - amount;
    order.metered.paid = order.metered.paid + amount;
    order.metered.premium_paid = order.metered.premium_paid + premium;
    vault.active_exposure = vault.active_exposure + amount;
    vault.window_exposure = vault.window_exposure + amount;

    if (premium > 0) {
        let premium_balance = balance::split(&mut order.escrow, premium);
        balance::join(&mut vault.staked, premium_balance);
    };
    if (provider_amount > 0) {
        let provider = order.provider;
        pay_escrow_amount(order, provider, provider_amount, ctx);
    };

    event::emit(MeteredDraw {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        agent: tx_context::sender(ctx),
        units,
        unit_price,
        paid: provider_amount,
        premium,
        running_total: order.metered.paid,
        usage_proof_hash
    });
}

public fun record_policy_denial_receipt(
    order: &WorkOrder,
    policy: &AgentPolicy,
    attempted_action: u64,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let reporter = tx_context::sender(ctx);
    let (allowed, reason_code) = policy_status(order, policy, reporter, attempted_action, clock);
    assert!(!allowed, E_POLICY_ALLOWED);
    emit_policy_denial(order, policy, reporter, attempted_action, reason_code, evidence_hash, clock);
    let receipt = DenialReceipt {
        id: object::new(ctx),
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter,
        agent: policy.agent,
        attempted_action,
        reason_code,
        evidence_hash,
        observed_ms: clock::timestamp_ms(clock)
    };
    transfer::public_transfer(receipt, reporter);
}

public fun file_claim(
    vault: &mut UnderwritingVault,
    order: &WorkOrder,
    receipt: DenialReceipt,
    ctx: &mut TxContext
) {
    let DenialReceipt {
        id,
        work_order_id,
        policy_id,
        reporter: _,
        agent: _,
        attempted_action: _,
        reason_code: _,
        evidence_hash: _,
        observed_ms: _
    } = receipt;
    assert!(work_order_id == object::id(order), E_BAD_DENIAL_RECEIPT);
    assert!(policy_id == vault.policy_id, E_BAD_DENIAL_RECEIPT);
    let available = balance::value(&vault.staked);
    let mut payout = vault.coverage_cap;
    if (payout > available) {
        payout = available;
    };
    if (payout > order.amount) {
        payout = order.amount;
    };
    assert!(payout > 0, E_BAD_VAULT);
    vault.claims_paid = vault.claims_paid + payout;
    if (vault.active_exposure >= payout) {
        vault.active_exposure = vault.active_exposure - payout;
    } else {
        vault.active_exposure = 0;
    };
    let claim_balance = balance::split(&mut vault.staked, payout);
    transfer::public_transfer(coin::from_balance(claim_balance, ctx), order.payer);
    object::delete(id);
    event::emit(ClaimPaid {
        vault_id: object::id(vault),
        work_order_id,
        policy_id,
        payer: order.payer,
        amount: payout
    });
}

public fun create_validator_bond(bond: Coin<SUI>, ctx: &mut TxContext) {
    let value = coin::value(&bond);
    assert!(value > 0, E_BAD_BOND);
    let cap = ValidatorBondCap {
        id: object::new(ctx),
        validator: tx_context::sender(ctx),
        bond: coin::into_balance(bond),
        live: true,
        weight: sqrt_floor(value),
        last_work_order_id: option::none<ID>(),
        last_agent: @0x0
    };
    transfer::public_transfer(cap, tx_context::sender(ctx));
}

public fun submit_bonded_validation(
    order: &mut WorkOrder,
    bond_cap: &mut ValidatorBondCap,
    agent: address,
    score_bps: u64,
    evidence_hash: vector<u8>,
    new_validation_root: vector<u8>,
    ctx: &TxContext
) {
    assert!(tx_context::sender(ctx) == bond_cap.validator, E_UNAUTHORIZED);
    assert!(bond_cap.live, E_BAD_VALIDATION);
    assert!(balance::value(&bond_cap.bond) > 0, E_BAD_BOND);
    bond_cap.last_work_order_id = option::some(object::id(order));
    bond_cap.last_agent = agent;
    submit_validation(order, agent, score_bps, evidence_hash, new_validation_root, ctx);
    event::emit(BondedValidationSubmitted {
        work_order_id: object::id(order),
        validator: tx_context::sender(ctx),
        agent,
        score_bps,
        bond_weight: bond_cap.weight,
        evidence_hash
    });
}

public fun slash_validator_to_vault(
    vault: &mut UnderwritingVault,
    bond_cap: &mut ValidatorBondCap,
    receipt: &DenialReceipt,
    ctx: &TxContext
) {
    assert!(receipt.policy_id == vault.policy_id, E_BAD_DENIAL_RECEIPT);
    assert!(bond_cap.live, E_BAD_VALIDATION);
    assert!(option::is_some(&bond_cap.last_work_order_id), E_BAD_VALIDATION);
    assert!(*option::borrow(&bond_cap.last_work_order_id) == receipt.work_order_id, E_BAD_DENIAL_RECEIPT);
    assert!(bond_cap.last_agent == receipt.agent, E_BAD_DENIAL_RECEIPT);
    let slashed = balance::withdraw_all(&mut bond_cap.bond);
    balance::join(&mut vault.staked, slashed);
    bond_cap.live = false;
    bond_cap.weight = 0;
    let _sender = tx_context::sender(ctx);
}

public fun policy_status(
    order: &WorkOrder,
    policy: &AgentPolicy,
    actor: address,
    action: u64,
    clock: &Clock
): (bool, u64) {
    if (policy.revoked) {
        return (false, DENY_REVOKED)
    };
    if (policy.work_order_id != object::id(order)) {
        return (false, DENY_WRONG_ORDER)
    };
    if (policy.agent != actor) {
        return (false, DENY_WRONG_AGENT)
    };
    if ((policy.allowed_actions & action) != action) {
        return (false, DENY_ACTION_NOT_ALLOWED)
    };
    if (policy.expires_ms != 0 && clock::timestamp_ms(clock) > policy.expires_ms) {
        return (false, DENY_EXPIRED)
    };
    if (policy.uses >= policy.max_uses) {
        return (false, DENY_USAGE_EXHAUSTED)
    };
    if (
        order.origin.quarantined &&
        (action == ACTION_RELEASE || action == ACTION_ACCEPT_SETTLEMENT || action == ACTION_METER_RELEASE)
    ) {
        return (false, DENY_ORIGIN_QUARANTINED)
    };
    (true, DENY_OK)
}

public fun record_policy_denial(
    order: &WorkOrder,
    policy: &AgentPolicy,
    attempted_action: u64,
    evidence_hash: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    let reporter = tx_context::sender(ctx);
    let (allowed, reason_code) = policy_status(order, policy, reporter, attempted_action, clock);
    assert!(!allowed, E_POLICY_ALLOWED);
    emit_policy_denial(order, policy, reporter, attempted_action, reason_code, evidence_hash, clock);
}

public fun attestation_status(
    order: &WorkOrder,
    _policy: &AgentPolicy,
    actor: address,
    receipt: &WorkReceipt,
    attested_ms: u64,
    signature: &vector<u8>,
    clock: &Clock
): (bool, u64) {
    if (!order.attestation.requires_tee_proof) {
        return (false, ATTEST_TEE_NOT_REQUIRED)
    };
    if (receipt.work_order_id != object::id(order)) {
        return (false, ATTEST_WRONG_ORDER)
    };
    if (receipt.agent != actor) {
        return (false, ATTEST_WRONG_AGENT)
    };
    if (receipt.input_hash != order.attestation.expected_input_hash) {
        return (false, ATTEST_WRONG_INPUT)
    };
    if (receipt.output_hash != order.evidence.delivered_output_hash) {
        return (false, ATTEST_WRONG_OUTPUT)
    };
    if (receipt.model_pcr != order.attestation.expected_model_pcr) {
        return (false, ATTEST_WRONG_MODEL)
    };
    if (receipt.state != STATE_DELIVERED || order.state != STATE_DELIVERED) {
        return (false, ATTEST_WRONG_STATE)
    };

    let now_ms = clock::timestamp_ms(clock);
    if (attested_ms > now_ms) {
        return (false, ATTEST_STALE)
    };
    if (now_ms - attested_ms > order.attestation.freshness_ms) {
        return (false, ATTEST_STALE)
    };
    if (attested_ms > order.deadline_ms + order.attestation.freshness_ms) {
        return (false, ATTEST_STALE)
    };

    let message = signed_work_receipt_message(receipt, attested_ms);
    if (!ed25519::ed25519_verify(signature, &order.attestation.expected_attester_pubkey, &message)) {
        return (false, ATTEST_BAD_SIGNATURE)
    };

    (true, ATTEST_OK)
}

public fun record_attestation_denial(
    order: &WorkOrder,
    policy: &AgentPolicy,
    receipt: WorkReceipt,
    attested_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    let reporter = tx_context::sender(ctx);
    let (valid, reason_code) = attestation_status(order, policy, reporter, &receipt, attested_ms, &signature, clock);
    assert!(!valid, E_ATTESTATION_VALID);

    event::emit(AttestationDenialRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter,
        agent: policy.agent,
        reason_code,
        output_hash: receipt.output_hash,
        observed_ms: clock::timestamp_ms(clock)
    });
}

public fun record_attestation_denial_fields(
    order: &WorkOrder,
    policy: &AgentPolicy,
    input_hash: vector<u8>,
    output_hash: vector<u8>,
    model_pcr: vector<u8>,
    attested_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &TxContext
) {
    let receipt = new_work_receipt(
        object::id(order),
        tx_context::sender(ctx),
        input_hash,
        output_hash,
        model_pcr,
        STATE_DELIVERED
    );
    record_attestation_denial(order, policy, receipt, attested_ms, signature, clock, ctx);
}

public fun seal_identity(order: &WorkOrder, evidence_class: u8): vector<u8> {
    expected_seal_id(order, evidence_class)
}

public fun seal_timelock_identity(order: &WorkOrder, reveal_at_ms: u64): vector<u8> {
    expected_timelock_seal_id(order, reveal_at_ms)
}

public fun seal_approve(
    id: vector<u8>,
    order: &WorkOrder,
    evidence_class: u8,
    _clock: &Clock,
    ctx: &TxContext
) {
    assert!(id == expected_seal_id(order, evidence_class), E_BAD_SEAL_ID);
    assert_seal_role(order, evidence_class, tx_context::sender(ctx));

    event::emit(SealAccessApproved {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        evidence_class,
        seal_identity: id,
        delegated: false
    });
}

public fun seal_approve_as_agent(
    id: vector<u8>,
    order: &WorkOrder,
    policy: &mut AgentPolicy,
    evidence_class: u8,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(id == expected_seal_id(order, evidence_class), E_BAD_SEAL_ID);
    assert_agent_policy(order, policy, ACTION_READ_EVIDENCE, clock, ctx);
    assert_seal_state(order, evidence_class);

    event::emit(SealAccessApproved {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        evidence_class,
        seal_identity: id,
        delegated: true
    });
}

public fun seal_approve_as_agent_live(
    id: vector<u8>,
    order: &WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    evidence_class: u8,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(id == expected_seal_id(order, evidence_class), E_BAD_SEAL_ID);
    assert_agent_policy_live(order, policy, registry, ACTION_READ_EVIDENCE, clock, ctx);
    assert_seal_state(order, evidence_class);

    event::emit(SealAccessApproved {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        evidence_class,
        seal_identity: id,
        delegated: true
    });
}

public fun seal_approve_tle(
    id: vector<u8>,
    order: &WorkOrder,
    reveal_at_ms: u64,
    clock: &Clock,
    ctx: &TxContext
) {
    assert!(id == expected_timelock_seal_id(order, reveal_at_ms), E_BAD_SEAL_ID);
    assert!(reveal_at_ms == order.deadline_ms, E_BAD_SEAL_ID);
    assert!(clock::timestamp_ms(clock) >= reveal_at_ms, E_TOO_EARLY);

    event::emit(TimeLockedRevealApproved {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        reveal_at_ms,
        seal_identity: id
    });
}

public fun submit_feedback(
    order: &mut WorkOrder,
    feedback_hash: vector<u8>,
    ctx: &TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == order.payer || sender == order.provider, E_UNAUTHORIZED);
    assert!(is_final(order.state), E_BAD_STATE);
    order.feedback_count = order.feedback_count + 1;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: sender,
        state: order.state,
        label: b"feedback_submitted".to_string(),
        evidence_hash: feedback_hash,
        receipt_hash: order.evidence.receipt_hash
    });
}

public fun submit_validation(
    order: &mut WorkOrder,
    agent: address,
    score_bps: u64,
    evidence_hash: vector<u8>,
    new_validation_root: vector<u8>,
    ctx: &TxContext
) {
    assert!(is_final(order.state), E_BAD_STATE);
    assert!(score_bps <= 10000, E_BAD_VALIDATION);

    order.validation_count = order.validation_count + 1;
    order.validation_root = new_validation_root;

    event::emit(ValidationSubmitted {
        work_order_id: object::id(order),
        validator: tx_context::sender(ctx),
        agent,
        score_bps,
        evidence_hash,
        validation_root: order.validation_root,
        validation_count: order.validation_count
    });
}

public fun work_order_state(order: &WorkOrder): u8 {
    order.state
}

public fun work_order_amount(order: &WorkOrder): u64 {
    order.amount
}

public fun work_order_payer(order: &WorkOrder): address {
    order.payer
}

public fun work_order_provider(order: &WorkOrder): address {
    order.provider
}

public fun work_order_receipt_hash(order: &WorkOrder): vector<u8> {
    order.evidence.receipt_hash
}

public fun work_order_requires_tee(order: &WorkOrder): bool {
    order.attestation.requires_tee_proof
}

public fun work_order_delivered_output_hash(order: &WorkOrder): vector<u8> {
    order.evidence.delivered_output_hash
}

public fun work_order_verified_blob_end_epoch(order: &WorkOrder): u64 {
    order.evidence.verified_blob_end_epoch
}

public fun work_order_verified_blob_certified_epoch(order: &WorkOrder): u64 {
    order.evidence.verified_blob_certified_epoch
}

public fun work_receipt_digest(receipt: &WorkReceipt): vector<u8> {
    hash::blake2b256(&bcs::to_bytes(receipt))
}

public fun signed_work_receipt_message(receipt: &WorkReceipt, attested_ms: u64): vector<u8> {
    let mut payload = b"suiflow-work-receipt-v1";
    vector::append(&mut payload, bcs::to_bytes(&attested_ms));
    vector::append(&mut payload, bcs::to_bytes(receipt));
    hash::blake2b256(&payload)
}

public fun policy_action_mark_delivered(): u64 { ACTION_MARK_DELIVERED }
public fun policy_action_release(): u64 { ACTION_RELEASE }
public fun policy_action_request_refund(): u64 { ACTION_REQUEST_REFUND }
public fun policy_action_propose_settlement(): u64 { ACTION_PROPOSE_SETTLEMENT }
public fun policy_action_accept_settlement(): u64 { ACTION_ACCEPT_SETTLEMENT }
public fun policy_action_read_evidence(): u64 { ACTION_READ_EVIDENCE }
public fun policy_action_meter_release(): u64 { ACTION_METER_RELEASE }
public fun policy_action_report_privacy(): u64 { ACTION_REPORT_PRIVACY }
public fun policy_action_bind_execution(): u64 { ACTION_BIND_EXECUTION }
public fun policy_action_report_origin_risk(): u64 { ACTION_REPORT_ORIGIN_RISK }

public fun max_depth(): u8 { MAX_DEPTH }

public fun policy_depth(policy: &AgentPolicy): u8 { policy.depth }
public fun policy_remaining_budget(policy: &AgentPolicy): u64 { policy.remaining_budget }
public fun policy_root_principal(policy: &AgentPolicy): address { policy.root_principal }
public fun policy_generation_snapshot(policy: &AgentPolicy): u64 { policy.gen_snapshot }
public fun policy_controller_id(policy: &AgentPolicy): ID { policy.controller_id }
public fun policy_privacy_budget_remaining(policy: &AgentPolicy): u64 { policy.privacy_budget_remaining }
public fun policy_origin_risk_budget_remaining(policy: &AgentPolicy): u64 { policy.origin_risk_budget_remaining }

public fun work_order_depth(order: &WorkOrder): u8 { order.graph.depth }
public fun work_order_child_budget_allocated(order: &WorkOrder): u64 { order.graph.child_budget_allocated }
public fun work_order_metered_paid(order: &WorkOrder): u64 { order.metered.paid }
public fun work_order_premium_paid(order: &WorkOrder): u64 { order.metered.premium_paid }
public fun work_order_validation_count(order: &WorkOrder): u64 { order.validation_count }
public fun work_order_privacy_budget(order: &WorkOrder): u64 { order.privacy.budget }
public fun work_order_privacy_used(order: &WorkOrder): u64 { order.privacy.used }
public fun work_order_privacy_trace_root(order: &WorkOrder): vector<u8> { order.privacy.trace_root }
public fun work_order_execution_context_hash(order: &WorkOrder): vector<u8> { order.execution.context_hash }
public fun work_order_execution_receipt_hash(order: &WorkOrder): vector<u8> { order.execution.receipt_hash }
public fun work_order_origin_manifest_hash(order: &WorkOrder): vector<u8> { order.origin.manifest_hash }
public fun work_order_tool_manifest_hash(order: &WorkOrder): vector<u8> { order.origin.tool_manifest_hash }
public fun work_order_critic_policy_hash(order: &WorkOrder): vector<u8> { order.origin.critic_policy_hash }
public fun work_order_critic_risk_score(order: &WorkOrder): u64 { order.origin.risk_score }
public fun work_order_critic_risk_threshold(order: &WorkOrder): u64 { order.origin.risk_threshold }
public fun work_order_critic_quarantined(order: &WorkOrder): bool { order.origin.quarantined }
public fun work_order_critic_trace_root(order: &WorkOrder): vector<u8> { order.origin.trace_root }
public fun exposure_ticket_premium_bps(ticket: &ExposureTicket): u64 { ticket.premium_bps }
public fun exposure_window_exposure(aggregator: &ExposureAggregator): u64 { aggregator.window_exposure }

public fun evidence_class_delivery(): u8 { EVIDENCE_DELIVERY }
public fun evidence_class_dispute(): u8 { EVIDENCE_DISPUTE }
public fun evidence_class_timelock(): u8 { EVIDENCE_TIMELOCK }

public fun deny_reason_ok(): u64 { DENY_OK }
public fun deny_reason_revoked(): u64 { DENY_REVOKED }
public fun deny_reason_wrong_order(): u64 { DENY_WRONG_ORDER }
public fun deny_reason_wrong_agent(): u64 { DENY_WRONG_AGENT }
public fun deny_reason_action_not_allowed(): u64 { DENY_ACTION_NOT_ALLOWED }
public fun deny_reason_expired(): u64 { DENY_EXPIRED }
public fun deny_reason_usage_exhausted(): u64 { DENY_USAGE_EXHAUSTED }
public fun deny_reason_origin_quarantined(): u64 { DENY_ORIGIN_QUARANTINED }

public fun attestation_reason_ok(): u64 { ATTEST_OK }
public fun attestation_reason_bad_signature(): u64 { ATTEST_BAD_SIGNATURE }
public fun attestation_reason_wrong_output(): u64 { ATTEST_WRONG_OUTPUT }
public fun attestation_reason_stale(): u64 { ATTEST_STALE }

fun do_mark_delivered(
    order: &mut WorkOrder,
    evidence_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    actor: address
) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_REFUND_REQUESTED, E_BAD_STATE);
    order.state = STATE_DELIVERED;
    order.evidence.delivery_evidence_hash = evidence_hash;
    order.evidence.delivered_output_hash = order.evidence.delivery_evidence_hash;
    order.walrus_blob_id = walrus_blob_id;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"delivered".to_string(),
        evidence_hash: order.evidence.delivery_evidence_hash,
        receipt_hash: vector[]
    });
}

fun do_mark_delivered_with_availability(
    order: &mut WorkOrder,
    evidence_hash: vector<u8>,
    proof: WalrusAvailabilityProof,
    actor: address
) {
    assert!(proof.certified_epoch > 0, E_BAD_AVAILABILITY);
    assert!(proof.end_epoch > 0, E_BAD_AVAILABILITY);
    if (order.evidence.required_blob_end_epoch > 0) {
        assert!(proof.end_epoch >= order.evidence.required_blob_end_epoch, E_BAD_AVAILABILITY);
    };

    let blob_id = proof.blob_id;
    let certified_epoch = proof.certified_epoch;
    let end_epoch = proof.end_epoch;
    do_mark_delivered(order, evidence_hash, blob_id, actor);
    order.evidence.verified_blob_certified_epoch = certified_epoch;
    order.evidence.verified_blob_end_epoch = end_epoch;

    event::emit(WalrusAvailabilityRecorded {
        work_order_id: object::id(order),
        actor,
        blob_id: order.walrus_blob_id,
        certified_epoch,
        end_epoch
    });
}

fun do_release(order: &mut WorkOrder, actor: address, ctx: &mut TxContext) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_DELIVERED, E_BAD_STATE);
    assert_not_origin_quarantined(order);
    order.state = STATE_RELEASED;
    order.evidence.receipt_hash = derive_receipt(order, b"released");
    let provider = order.provider;
    pay_all_escrow(order, provider, ctx);
    pay_all_bond(order, provider, ctx);

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"released".to_string(),
        evidence_hash: order.evidence.delivery_evidence_hash,
        receipt_hash: order.evidence.receipt_hash
    });
}

fun do_request_refund(
    order: &mut WorkOrder,
    dispute_evidence_hash: vector<u8>,
    clock: &Clock,
    actor: address
) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_DELIVERED, E_BAD_STATE);
    order.state = STATE_REFUND_REQUESTED;
    order.refund_requested_ms = clock::timestamp_ms(clock);
    order.evidence.dispute_evidence_hash = dispute_evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"refund_requested".to_string(),
        evidence_hash: order.evidence.dispute_evidence_hash,
        receipt_hash: vector[]
    });
}

fun do_accept_split_settlement(order: &mut WorkOrder, actor: address, ctx: &mut TxContext) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_DELIVERED || order.state == STATE_REFUND_REQUESTED, E_BAD_STATE);
    assert_not_origin_quarantined(order);
    let provider_amount = order.settlement_provider_amount;
    assert!(provider_amount <= order.amount, E_BAD_SETTLEMENT);

    order.state = STATE_SETTLED;
    order.evidence.receipt_hash = derive_receipt(order, b"settled");

    if (provider_amount > 0) {
        let provider_balance = balance::split(&mut order.escrow, provider_amount);
        transfer::public_transfer(coin::from_balance(provider_balance, ctx), order.provider);
    };

    let payer_refund = balance::value(&order.escrow);
    if (payer_refund > 0) {
        let payer = order.payer;
        pay_all_escrow(order, payer, ctx);
    };

    let provider = order.provider;
    pay_all_bond(order, provider, ctx);

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"split_settled".to_string(),
        evidence_hash: order.evidence.dispute_evidence_hash,
        receipt_hash: order.evidence.receipt_hash
    });
}

fun assert_not_origin_quarantined(order: &WorkOrder) {
    assert!(!order.origin.quarantined, E_BAD_ORIGIN_CRITIC);
}

fun pay_all_escrow(order: &mut WorkOrder, recipient: address, ctx: &mut TxContext) {
    let value = balance::value(&order.escrow);
    if (value > 0) {
        let payout = balance::withdraw_all(&mut order.escrow);
        transfer::public_transfer(coin::from_balance(payout, ctx), recipient);
    };
}

fun pay_escrow_amount(order: &mut WorkOrder, recipient: address, amount: u64, ctx: &mut TxContext) {
    assert!(amount <= balance::value(&order.escrow), E_BAD_SETTLEMENT);
    if (amount > 0) {
        let payout = balance::split(&mut order.escrow, amount);
        transfer::public_transfer(coin::from_balance(payout, ctx), recipient);
    };
}

fun pay_all_bond(order: &mut WorkOrder, recipient: address, ctx: &mut TxContext) {
    let value = balance::value(&order.service_bond);
    if (value > 0) {
        let payout = balance::withdraw_all(&mut order.service_bond);
        transfer::public_transfer(coin::from_balance(payout, ctx), recipient);
    };
}

fun emit_policy_denial(
    order: &WorkOrder,
    policy: &AgentPolicy,
    reporter: address,
    attempted_action: u64,
    reason_code: u64,
    evidence_hash: vector<u8>,
    clock: &Clock
) {
    event::emit(PolicyDenialRecorded {
        work_order_id: object::id(order),
        policy_id: object::id(policy),
        reporter,
        agent: policy.agent,
        attempted_action,
        reason_code,
        evidence_hash,
        observed_ms: clock::timestamp_ms(clock)
    });
}

fun assert_agent_policy(
    order: &WorkOrder,
    policy: &mut AgentPolicy,
    action: u64,
    clock: &Clock,
    ctx: &TxContext
) {
    let (allowed, reason_code) = policy_status(order, policy, tx_context::sender(ctx), action, clock);
    if (!allowed) {
        if (reason_code == DENY_WRONG_AGENT) {
            abort E_UNAUTHORIZED
        };
        if (reason_code == DENY_EXPIRED) {
            abort E_POLICY_EXPIRED
        };
        abort E_BAD_POLICY
    };
    policy.uses = policy.uses + 1;
}

fun assert_agent_policy_live(
    order: &WorkOrder,
    policy: &mut AgentPolicy,
    registry: &GenerationRegistry,
    action: u64,
    clock: &Clock,
    ctx: &TxContext
) {
    if (registry.paused) {
        abort E_PAUSED
    };
    if (!policy_is_live(policy, registry)) {
        abort E_REVOKED_BY_GENERATION
    };
    assert_agent_policy(order, policy, action, clock, ctx);
}

fun bump_generation(registry: &mut GenerationRegistry, policy_id: ID): u64 {
    if (!table::contains(&registry.generations, policy_id)) {
        table::add(&mut registry.generations, policy_id, 1);
        return 1
    };
    let gen = table::borrow_mut(&mut registry.generations, policy_id);
    *gen = *gen + 1;
    *gen
}

fun register_policy_id(registry: &mut GenerationRegistry, policy_id: ID, owner: address) {
    if (!table::contains(&registry.generations, policy_id)) {
        table::add(&mut registry.generations, policy_id, 0);
    };
    if (!table::contains(&registry.owners, policy_id)) {
        table::add(&mut registry.owners, policy_id, owner);
    };
}

fun record_registry_draw(
    registry: &mut GenerationRegistry,
    amount: u64,
    clock: &Clock,
    actor: address
) {
    let now_ms = clock::timestamp_ms(clock);
    if (registry.window_started_ms == 0 || now_ms > registry.window_started_ms + registry.breaker_window_ms) {
        registry.window_started_ms = now_ms;
        registry.window_drawn = 0;
    };
    registry.window_drawn = registry.window_drawn + amount;
    if (registry.breaker_amount > 0 && registry.window_drawn > registry.breaker_amount) {
        registry.paused = true;
        event::emit(RevocationEvent {
            policy_id: object::id(registry),
            new_generation: registry.window_drawn,
            scope: b"velocity_breaker".to_string(),
            actor,
            at_ms: now_ms
        });
    };
}

fun do_consume_execution_receipt(
    registry: &mut ExecutionBindingRegistry,
    order: &mut WorkOrder,
    service_receipt_hash: vector<u8>,
    nullifier_hash: vector<u8>,
    actor: address
) {
    assert!(!order.execution.context_hash.is_empty(), E_BAD_EXECUTION_BINDING);
    assert!(!service_receipt_hash.is_empty(), E_BAD_EXECUTION_BINDING);
    assert!(!nullifier_hash.is_empty(), E_BAD_EXECUTION_BINDING);
    assert!(!table::contains(&registry.used_nullifiers, nullifier_hash), E_BAD_EXECUTION_BINDING);
    table::add(&mut registry.used_nullifiers, nullifier_hash, true);
    order.execution.receipt_hash = service_receipt_hash;
    event::emit(ExecutionReceiptConsumed {
        work_order_id: object::id(order),
        actor,
        execution_context_hash: order.execution.context_hash,
        service_receipt_hash: order.execution.receipt_hash,
        nullifier_hash
    });
}

fun max_generation(registry: &GenerationRegistry, ancestors: &vector<ID>): u64 {
    let mut max = 0;
    let mut i = 0;
    let len = vector::length(ancestors);
    while (i < len) {
        let ancestor = *vector::borrow(ancestors, i);
        let gen = current_generation(registry, ancestor);
        if (gen > max) {
            max = gen;
        };
        i = i + 1;
    };
    max
}

fun exposure_ramp_bps(window_exposure: u64): u64 {
    let millions = (window_exposure + 999_999) / 1_000_000;
    if (millions > 31) {
        1_000
    } else {
        millions * millions
    }
}

fun sqrt_floor(value: u64): u64 {
    let mut x = 0;
    while ((x + 1) * (x + 1) <= value) {
        x = x + 1;
    };
    x
}

fun derive_receipt(order: &WorkOrder, label: vector<u8>): vector<u8> {
    let mut receipt = label;
    vector::append(&mut receipt, bcs::to_bytes(&object::id(order)));
    vector::append(&mut receipt, bcs::to_bytes(&order.payer));
    vector::append(&mut receipt, bcs::to_bytes(&order.provider));
    vector::append(&mut receipt, bcs::to_bytes(&order.amount));
    vector::append(&mut receipt, bcs::to_bytes(&order.state));
    vector::append(&mut receipt, bcs::to_bytes(&order.settlement_provider_amount));
    vector::append(&mut receipt, order.metadata_hash);
    vector::append(&mut receipt, order.mandate_hash);
    vector::append(&mut receipt, order.policy_hash);
    vector::append(&mut receipt, order.evidence.delivery_evidence_hash);
    vector::append(&mut receipt, order.evidence.dispute_evidence_hash);
    vector::append(&mut receipt, order.walrus_blob_id);
    vector::append(&mut receipt, order.seal_policy_id);
    vector::append(&mut receipt, bcs::to_bytes(&order.attestation.requires_tee_proof));
    vector::append(&mut receipt, order.attestation.expected_attester_pubkey);
    vector::append(&mut receipt, order.attestation.expected_model_pcr);
    vector::append(&mut receipt, order.attestation.expected_input_hash);
    vector::append(&mut receipt, order.evidence.delivered_output_hash);
    vector::append(&mut receipt, bcs::to_bytes(&order.evidence.required_blob_end_epoch));
    vector::append(&mut receipt, bcs::to_bytes(&order.evidence.verified_blob_certified_epoch));
    vector::append(&mut receipt, bcs::to_bytes(&order.evidence.verified_blob_end_epoch));
    vector::append(&mut receipt, bcs::to_bytes(&order.graph.parent_order_id));
    vector::append(&mut receipt, bcs::to_bytes(&order.graph.parent_policy_id));
    vector::append(&mut receipt, bcs::to_bytes(&order.graph.root_principal));
    vector::append(&mut receipt, bcs::to_bytes(&order.graph.depth));
    vector::append(&mut receipt, bcs::to_bytes(&order.graph.child_budget_allocated));
    vector::append(&mut receipt, bcs::to_bytes(&order.metered.paid));
    vector::append(&mut receipt, bcs::to_bytes(&order.metered.premium_paid));
    vector::append(&mut receipt, bcs::to_bytes(&order.release.condition));
    vector::append(&mut receipt, order.release.expected_output_commitment);
    vector::append(&mut receipt, order.release.proof_chain_root);
    vector::append(&mut receipt, bcs::to_bytes(&order.privacy.budget));
    vector::append(&mut receipt, bcs::to_bytes(&order.privacy.used));
    vector::append(&mut receipt, order.privacy.manifest_hash);
    vector::append(&mut receipt, order.privacy.trace_root);
    vector::append(&mut receipt, order.execution.context_hash);
    vector::append(&mut receipt, order.execution.receipt_hash);
    vector::append(&mut receipt, order.origin.manifest_hash);
    vector::append(&mut receipt, order.origin.tool_manifest_hash);
    vector::append(&mut receipt, order.origin.critic_policy_hash);
    vector::append(&mut receipt, bcs::to_bytes(&order.origin.risk_score));
    vector::append(&mut receipt, bcs::to_bytes(&order.origin.risk_threshold));
    vector::append(&mut receipt, bcs::to_bytes(&order.origin.quarantined));
    vector::append(&mut receipt, order.origin.trace_root);
    hash::blake2b256(&receipt)
}

fun is_final(state: u8): bool {
    state == STATE_RELEASED || state == STATE_REFUNDED || state == STATE_SETTLED || state == STATE_CANCELLED || state == STATE_ATTESTATION_FAILED
}

fun expected_seal_id(order: &WorkOrder, evidence_class: u8): vector<u8> {
    assert!(evidence_class == EVIDENCE_DELIVERY || evidence_class == EVIDENCE_DISPUTE, E_BAD_SEAL_ID);
    let mut id = bcs::to_bytes(&object::id(order));
    vector::push_back(&mut id, evidence_class);
    id
}

fun expected_timelock_seal_id(order: &WorkOrder, reveal_at_ms: u64): vector<u8> {
    let mut id = bcs::to_bytes(&object::id(order));
    vector::push_back(&mut id, EVIDENCE_TIMELOCK);
    vector::append(&mut id, bcs::to_bytes(&reveal_at_ms));
    id
}

fun assert_seal_role(order: &WorkOrder, evidence_class: u8, actor: address) {
    assert_seal_state(order, evidence_class);
    if (evidence_class == EVIDENCE_DELIVERY) {
        assert!(actor == order.payer, E_UNAUTHORIZED);
    } else {
        assert!(order.evidence.dispute_validator != @0x0, E_UNAUTHORIZED);
        assert!(actor == order.evidence.dispute_validator, E_UNAUTHORIZED);
    };
}

fun assert_seal_state(order: &WorkOrder, evidence_class: u8) {
    if (evidence_class == EVIDENCE_DELIVERY) {
        assert!(order.state >= STATE_FUNDED, E_BAD_STATE);
    } else {
        assert!(evidence_class == EVIDENCE_DISPUTE, E_BAD_SEAL_ID);
        assert!(order.state == STATE_REFUND_REQUESTED, E_BAD_STATE);
    };
}
