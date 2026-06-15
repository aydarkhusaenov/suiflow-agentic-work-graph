/// SuiFlow Agentic Work Graph.
///
/// A Sui-native settlement object for autonomous service agents. Work orders
/// hold funded SUI escrow, service bonds, bounded agent policy objects,
/// evidence pointers, final receipt hashes, and validator attestations.
module suiflow::agent_settlement;

use std::bcs;
use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::hash;
use sui::object::{Self, ID, UID};
use sui::sui::SUI;
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

const ACTION_MARK_DELIVERED: u64 = 1;
const ACTION_RELEASE: u64 = 2;
const ACTION_REQUEST_REFUND: u64 = 4;
const ACTION_PROPOSE_SETTLEMENT: u64 = 8;
const ACTION_ACCEPT_SETTLEMENT: u64 = 16;

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

const DENY_OK: u64 = 0;
const DENY_REVOKED: u64 = 1;
const DENY_WRONG_ORDER: u64 = 2;
const DENY_WRONG_AGENT: u64 = 3;
const DENY_ACTION_NOT_ALLOWED: u64 = 4;
const DENY_EXPIRED: u64 = 5;
const DENY_USAGE_EXHAUSTED: u64 = 6;

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
    delivery_evidence_hash: vector<u8>,
    dispute_evidence_hash: vector<u8>,
    receipt_hash: vector<u8>,
    feedback_count: u64,
    validation_count: u64,
    validation_root: vector<u8>
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
    revoked: bool
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
        delivery_evidence_hash: vector[],
        dispute_evidence_hash: vector[],
        receipt_hash: vector[],
        feedback_count: 0,
        validation_count: 0,
        validation_root: vector[]
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
        revoked: false
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

public fun release(order: &mut WorkOrder, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    do_release(order, tx_context::sender(ctx), ctx);
}

public fun agent_release(
    order: &mut WorkOrder,
    policy: &mut AgentPolicy,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert_agent_policy(order, policy, ACTION_RELEASE, clock, ctx);
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

public fun timeout_refund(order: &mut WorkOrder, clock: &Clock, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == order.payer, E_UNAUTHORIZED);
    assert!(order.state == STATE_REFUND_REQUESTED || order.state == STATE_FUNDED, E_BAD_STATE);
    assert!(clock::timestamp_ms(clock) >= order.deadline_ms, E_TOO_EARLY);

    order.state = STATE_REFUNDED;
    order.receipt_hash = derive_receipt(order, b"refunded");
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
        evidence_hash: order.dispute_evidence_hash,
        receipt_hash: order.receipt_hash
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
    order.dispute_evidence_hash = evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: sender,
        state: order.state,
        label: b"split_settlement_proposed".to_string(),
        evidence_hash: order.dispute_evidence_hash,
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
    order.dispute_evidence_hash = evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor: tx_context::sender(ctx),
        state: order.state,
        label: b"agent_split_settlement_proposed".to_string(),
        evidence_hash: order.dispute_evidence_hash,
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
        receipt_hash: order.receipt_hash
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
    order.receipt_hash
}

public fun policy_action_mark_delivered(): u64 { ACTION_MARK_DELIVERED }
public fun policy_action_release(): u64 { ACTION_RELEASE }
public fun policy_action_request_refund(): u64 { ACTION_REQUEST_REFUND }
public fun policy_action_propose_settlement(): u64 { ACTION_PROPOSE_SETTLEMENT }
public fun policy_action_accept_settlement(): u64 { ACTION_ACCEPT_SETTLEMENT }

public fun deny_reason_ok(): u64 { DENY_OK }
public fun deny_reason_revoked(): u64 { DENY_REVOKED }
public fun deny_reason_wrong_order(): u64 { DENY_WRONG_ORDER }
public fun deny_reason_wrong_agent(): u64 { DENY_WRONG_AGENT }
public fun deny_reason_action_not_allowed(): u64 { DENY_ACTION_NOT_ALLOWED }
public fun deny_reason_expired(): u64 { DENY_EXPIRED }
public fun deny_reason_usage_exhausted(): u64 { DENY_USAGE_EXHAUSTED }

fun do_mark_delivered(
    order: &mut WorkOrder,
    evidence_hash: vector<u8>,
    walrus_blob_id: vector<u8>,
    actor: address
) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_REFUND_REQUESTED, E_BAD_STATE);
    order.state = STATE_DELIVERED;
    order.delivery_evidence_hash = evidence_hash;
    order.walrus_blob_id = walrus_blob_id;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"delivered".to_string(),
        evidence_hash: order.delivery_evidence_hash,
        receipt_hash: vector[]
    });
}

fun do_release(order: &mut WorkOrder, actor: address, ctx: &mut TxContext) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_DELIVERED, E_BAD_STATE);
    order.state = STATE_RELEASED;
    order.receipt_hash = derive_receipt(order, b"released");
    let provider = order.provider;
    pay_all_escrow(order, provider, ctx);
    pay_all_bond(order, provider, ctx);

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"released".to_string(),
        evidence_hash: order.delivery_evidence_hash,
        receipt_hash: order.receipt_hash
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
    order.dispute_evidence_hash = dispute_evidence_hash;

    event::emit(WorkOrderEvent {
        work_order_id: object::id(order),
        actor,
        state: order.state,
        label: b"refund_requested".to_string(),
        evidence_hash: order.dispute_evidence_hash,
        receipt_hash: vector[]
    });
}

fun do_accept_split_settlement(order: &mut WorkOrder, actor: address, ctx: &mut TxContext) {
    assert!(order.state == STATE_FUNDED || order.state == STATE_DELIVERED || order.state == STATE_REFUND_REQUESTED, E_BAD_STATE);
    let provider_amount = order.settlement_provider_amount;
    assert!(provider_amount <= order.amount, E_BAD_SETTLEMENT);

    order.state = STATE_SETTLED;
    order.receipt_hash = derive_receipt(order, b"settled");

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
        evidence_hash: order.dispute_evidence_hash,
        receipt_hash: order.receipt_hash
    });
}

fun pay_all_escrow(order: &mut WorkOrder, recipient: address, ctx: &mut TxContext) {
    let value = balance::value(&order.escrow);
    if (value > 0) {
        let payout = balance::withdraw_all(&mut order.escrow);
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
    vector::append(&mut receipt, order.delivery_evidence_hash);
    vector::append(&mut receipt, order.dispute_evidence_hash);
    vector::append(&mut receipt, order.walrus_blob_id);
    vector::append(&mut receipt, order.seal_policy_id);
    hash::blake2b256(&receipt)
}

fun is_final(state: u8): bool {
    state == STATE_RELEASED || state == STATE_REFUNDED || state == STATE_SETTLED || state == STATE_CANCELLED
}
