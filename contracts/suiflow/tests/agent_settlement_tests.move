#[test_only]
module suiflow::agent_settlement_tests;

use suiflow::agent_settlement::{
    Self,
    AgentPolicy,
    BidMarket,
    Caretaker,
    CoSignBond,
    DenialReceipt,
    ExecutionBindingRegistry,
    ExposureAggregator,
    GenerationRegistry,
    PrivacyBreachReceipt,
    UnderwritingVault,
    ValidatorBondCap,
    WorkOrder
};
use sui::clock;
use sui::coin;
use sui::object;
use sui::sui::SUI;
use sui::test_scenario::{Self, Scenario};

const PAYER: address = @0xA11CE;
const PROVIDER: address = @0xB0B;
const AGENT: address = @0xCAFE;
const SUB_AGENT: address = @0xDAD;
const VALIDATOR: address = @0xA77E57;

const STATE_DELIVERED: u8 = 2;
const STATE_RELEASED: u8 = 4;
const STATE_REFUNDED: u8 = 5;
const E_BAD_POLICY: u64 = 5;
const E_BAD_SETTLEMENT: u64 = 7;
const E_TOO_EARLY: u64 = 8;
const E_BAD_ATTESTATION: u64 = 11;
const E_BAD_SEAL_ID: u64 = 12;
const E_BAD_AVAILABILITY: u64 = 13;
const E_BAD_ATTENUATION: u64 = 15;
const E_REVOKED_BY_GENERATION: u64 = 17;
const E_BAD_DELIVERY_PROOF: u64 = 24;
const E_BAD_EXECUTION_BINDING: u64 = 26;
const E_BAD_ORIGIN_CRITIC: u64 = 27;

#[test]
fun policy_bit_constants_exist() {
    assert!(agent_settlement::policy_action_mark_delivered() == 1, 0);
    assert!(agent_settlement::policy_action_release() == 2, 1);
    assert!(agent_settlement::policy_action_request_refund() == 4, 2);
    assert!(agent_settlement::policy_action_propose_settlement() == 8, 3);
    assert!(agent_settlement::policy_action_accept_settlement() == 16, 4);
    assert!(agent_settlement::policy_action_read_evidence() == 32, 5);
    assert!(agent_settlement::policy_action_meter_release() == 64, 6);
    assert!(agent_settlement::policy_action_report_privacy() == 128, 7);
    assert!(agent_settlement::policy_action_bind_execution() == 256, 8);
    assert!(agent_settlement::policy_action_report_origin_risk() == 512, 9);
    assert!(agent_settlement::evidence_class_delivery() == 0, 10);
    assert!(agent_settlement::evidence_class_dispute() == 1, 11);
    assert!(agent_settlement::evidence_class_timelock() == 2, 12);
    assert!(agent_settlement::deny_reason_wrong_order() == 2, 13);
    assert!(agent_settlement::deny_reason_usage_exhausted() == 6, 14);
    assert!(agent_settlement::deny_reason_origin_quarantined() == 7, 15);
}

#[test]
fun work_receipt_bcs_digest_is_stable_and_field_sensitive() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        let receipt = agent_settlement::new_work_receipt(
            object::id(&order),
            AGENT,
            b"input-hash",
            b"output-a",
            b"pcr0",
            STATE_DELIVERED
        );
        let same_digest = agent_settlement::work_receipt_digest(&receipt);
        assert!(same_digest == agent_settlement::work_receipt_digest(&receipt), 11);
        assert!(!agent_settlement::signed_work_receipt_message(&receipt, 123).is_empty(), 12);

        let changed = agent_settlement::new_work_receipt(
            object::id(&order),
            AGENT,
            b"input-hash",
            b"output-b",
            b"pcr0",
            STATE_DELIVERED
        );
        assert!(same_digest != agent_settlement::work_receipt_digest(&changed), 13);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun clean_settlement_flow_releases_funds() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let bond = coin::mint_for_testing<SUI>(100, scenario.ctx());
        agent_settlement::post_service_bond(&mut order, bond, scenario.ctx());
        agent_settlement::mark_delivered(&mut order, b"delivery-hash", b"walrus-delivery", scenario.ctx());
        assert!(agent_settlement::work_order_state(&order) == STATE_DELIVERED, 10);
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::release(&mut order, scenario.ctx());
        assert!(agent_settlement::work_order_state(&order) == STATE_RELEASED, 11);
        assert!(!agent_settlement::work_order_receipt_hash(&order).is_empty(), 12);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun delegated_agent_can_mark_delivery_with_policy_object() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_mark_delivered(),
            9_000,
            1,
            0,
            b"agent-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::agent_mark_delivered(
            &mut order,
            &mut policy,
            b"agent-delivery",
            b"walrus-agent-delivery",
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_state(&order) == STATE_DELIVERED, 20);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun walrus_availability_proof_marks_delivery() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 900, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::require_walrus_availability_until(&mut order, 30, scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let proof = agent_settlement::new_walrus_availability_proof(b"certified-blob", 7, 40);
        agent_settlement::mark_delivered_with_availability(
            &mut order,
            b"available-output",
            proof,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_state(&order) == STATE_DELIVERED, 21);
        assert!(agent_settlement::work_order_delivered_output_hash(&order) == b"available-output", 22);
        assert!(agent_settlement::work_order_verified_blob_certified_epoch(&order) == 7, 23);
        assert!(agent_settlement::work_order_verified_blob_end_epoch(&order) == 40, 24);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_AVAILABILITY, location = suiflow::agent_settlement)]
fun walrus_availability_rejects_short_retention() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 900, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::require_walrus_availability_until(&mut order, 50, scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let proof = agent_settlement::new_walrus_availability_proof(b"short-blob", 7, 49);
        agent_settlement::mark_delivered_with_availability(
            &mut order,
            b"short-output",
            proof,
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun timeout_refund_slashes_bond_after_deadline() {
    let mut scenario = test_scenario::begin(PAYER);
    let mut clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 500, 100);

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let bond = coin::mint_for_testing<SUI>(50, scenario.ctx());
        agent_settlement::post_service_bond(&mut order, bond, scenario.ctx());
        test_scenario::return_shared(order);
    };

    clock.set_for_testing(200);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::timeout_refund(&mut order, &clock, scenario.ctx());
        assert!(agent_settlement::work_order_state(&order) == STATE_REFUNDED, 30);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_POLICY, location = suiflow::agent_settlement)]
fun agent_policy_cannot_control_a_different_work_order() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 600, 10_000);

    scenario.next_tx(PAYER);
    let first_order_id = {
        let order = scenario.take_shared<WorkOrder>();
        let id = object::id(&order);
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_mark_delivered(),
            9_000,
            1,
            0,
            b"first-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
        id
    };

    create_demo_order(&mut scenario, &clock, 800, 10_000);

    scenario.next_tx(PAYER);
    let second_order_id = {
        let order = scenario.take_shared<WorkOrder>();
        let id = object::id(&order);
        test_scenario::return_shared(order);
        id
    };

    scenario.next_tx(AGENT);
    {
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        let mut second_order = scenario.take_shared_by_id<WorkOrder>(second_order_id);
        assert!(first_order_id != second_order_id, 40);
        agent_settlement::agent_mark_delivered(
            &mut second_order,
            &mut policy,
            b"wrong-order",
            b"walrus-wrong-order",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(second_order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun policy_status_exposes_wrong_order_without_abort() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 600, 10_000);

    scenario.next_tx(PAYER);
    let _first_order_id = {
        let order = scenario.take_shared<WorkOrder>();
        let id = object::id(&order);
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_mark_delivered(),
            9_000,
            1,
            0,
            b"first-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
        id
    };

    create_demo_order(&mut scenario, &clock, 800, 10_000);

    scenario.next_tx(PAYER);
    let second_order_id = {
        let order = scenario.take_shared<WorkOrder>();
        let id = object::id(&order);
        test_scenario::return_shared(order);
        id
    };

    scenario.next_tx(AGENT);
    {
        let policy = scenario.take_from_sender<AgentPolicy>();
        let second_order = scenario.take_shared_by_id<WorkOrder>(second_order_id);
        let (allowed, reason) = agent_settlement::policy_status(
            &second_order,
            &policy,
            AGENT,
            agent_settlement::policy_action_mark_delivered(),
            &clock
        );
        assert!(!allowed, 50);
        assert!(reason == agent_settlement::deny_reason_wrong_order(), 51);
        agent_settlement::record_policy_denial(
            &second_order,
            &policy,
            agent_settlement::policy_action_mark_delivered(),
            b"denied-wrong-order",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(second_order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun seal_delivery_predicate_uses_work_order_identity() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        let id = agent_settlement::seal_identity(&order, agent_settlement::evidence_class_delivery());
        agent_settlement::seal_approve(
            id,
            &order,
            agent_settlement::evidence_class_delivery(),
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_SEAL_ID, location = suiflow::agent_settlement)]
fun seal_predicate_rejects_wrong_identity() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::seal_approve(
            b"wrong-id",
            &order,
            agent_settlement::evidence_class_delivery(),
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun delegated_agent_can_receive_seal_read_authority() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_read_evidence(),
            9_000,
            1,
            0,
            b"read-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        let id = agent_settlement::seal_identity(&order, agent_settlement::evidence_class_delivery());
        agent_settlement::seal_approve_as_agent(
            id,
            &order,
            &mut policy,
            agent_settlement::evidence_class_delivery(),
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun timelock_reveal_opens_at_deadline() {
    let mut scenario = test_scenario::begin(PAYER);
    let mut clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 100);
    clock.set_for_testing(100);

    scenario.next_tx(PROVIDER);
    {
        let order = scenario.take_shared<WorkOrder>();
        let id = agent_settlement::seal_timelock_identity(&order, 100);
        agent_settlement::seal_approve_tle(id, &order, 100, &clock, scenario.ctx());
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_TOO_EARLY, location = suiflow::agent_settlement)]
fun timelock_reveal_rejects_before_deadline() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 100);

    scenario.next_tx(PROVIDER);
    {
        let order = scenario.take_shared<WorkOrder>();
        let id = agent_settlement::seal_timelock_identity(&order, 100);
        agent_settlement::seal_approve_tle(id, &order, 100, &clock, scenario.ctx());
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_POLICY, location = suiflow::agent_settlement)]
fun one_shot_agent_policy_cannot_be_reused() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 700, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_mark_delivered() | agent_settlement::policy_action_request_refund(),
            9_000,
            1,
            0,
            b"one-shot-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::agent_mark_delivered(
            &mut order,
            &mut policy,
            b"agent-delivery",
            b"walrus-agent-delivery",
            &clock,
            scenario.ctx()
        );
        agent_settlement::agent_request_refund(
            &mut order,
            &mut policy,
            b"second-use-denied",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_SETTLEMENT, location = suiflow::agent_settlement)]
fun agent_split_settlement_respects_provider_amount_cap() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_propose_settlement(),
            9_000,
            1,
            400,
            b"capped-settlement-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::agent_propose_split_settlement(
            &mut order,
            &mut policy,
            700,
            b"over-cap",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun attestation_denial_records_bad_signature() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        configure_demo_attestation(&mut order, scenario.ctx());
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_release(),
            9_000,
            1,
            0,
            b"release-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::mark_delivered(&mut order, b"attested-output", b"walrus-attested", scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        let receipt = agent_settlement::new_work_receipt(
            object::id(&order),
            AGENT,
            b"input-hash",
            b"attested-output",
            b"pcr0",
            STATE_DELIVERED
        );
        let (valid, reason) = agent_settlement::attestation_status(
            &order,
            &policy,
            AGENT,
            &receipt,
            0,
            &b"bad-signature",
            &clock
        );
        assert!(!valid, 60);
        assert!(reason == agent_settlement::attestation_reason_bad_signature(), 61);
        agent_settlement::record_attestation_denial(
            &order,
            &policy,
            receipt,
            0,
            b"bad-signature",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_ATTESTATION, location = suiflow::agent_settlement)]
fun attested_release_rejects_bad_signature() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        configure_demo_attestation(&mut order, scenario.ctx());
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_release(),
            9_000,
            1,
            0,
            b"release-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::mark_delivered(&mut order, b"attested-output", b"walrus-attested", scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        let receipt = agent_settlement::new_work_receipt(
            object::id(&order),
            AGENT,
            b"input-hash",
            b"attested-output",
            b"pcr0",
            STATE_DELIVERED
        );
        agent_settlement::release_with_attestation(
            &mut order,
            &mut policy,
            receipt,
            1,
            b"bad-signature",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_ATTESTATION, location = suiflow::agent_settlement)]
fun tee_required_order_rejects_plain_release() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        configure_demo_attestation(&mut order, scenario.ctx());
        agent_settlement::release(&mut order, scenario.ctx());
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun recursive_child_work_order_attenuates_budget_and_depth() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_propose_settlement() | agent_settlement::policy_action_meter_release(),
            9_000,
            3,
            500,
            b"root-work-graph-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::spawn_child_work_order(
            &mut order,
            &mut policy,
            &mut registry,
            SUB_AGENT,
            PROVIDER,
            300,
            agent_settlement::policy_action_meter_release(),
            8_000,
            200,
            2,
            b"child-metadata",
            b"child-mandate",
            b"child-policy",
            b"child-walrus",
            b"child-seal",
            8_000,
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_child_budget_allocated(&order) == 300, 70);
        assert!(agent_settlement::policy_remaining_budget(&policy) == 700, 71);
        assert!(agent_settlement::policy_depth(&policy) == 0, 72);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_ATTENUATION, location = suiflow::agent_settlement)]
fun child_work_order_cannot_amplify_actions() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_propose_settlement(),
            9_000,
            3,
            500,
            b"root-work-graph-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::spawn_child_work_order(
            &mut order,
            &mut policy,
            &mut registry,
            SUB_AGENT,
            PROVIDER,
            300,
            agent_settlement::policy_action_release(),
            8_000,
            200,
            2,
            b"child-metadata",
            b"child-mandate",
            b"child-policy",
            b"child-walrus",
            b"child-seal",
            8_000,
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_REVOKED_BY_GENERATION, location = suiflow::agent_settlement)]
fun generation_revocation_blocks_live_metered_use() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_meter_release(),
            9_000,
            3,
            500,
            b"meter-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    let policy_id = {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        let id = object::id(&policy);
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        id
    };

    scenario.next_tx(PAYER);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        agent_settlement::revoke_subtree(&mut registry, policy_id, &clock, scenario.ctx());
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::meter_release(
            &mut order,
            &mut policy,
            &mut registry,
            2,
            100,
            b"usage-proof",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun metered_release_with_vault_charges_premium_and_exposure() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_meter_release(),
            9_000,
            3,
            500,
            b"meter-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        agent_settlement::create_underwriting_vault(&policy, 300, 100, scenario.ctx());
        agent_settlement::create_exposure_aggregator(
            agent_settlement::policy_controller_id(&policy),
            100,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let mut aggregator = scenario.take_shared<ExposureAggregator>();
        let ticket = agent_settlement::record_exposure(
            &mut aggregator,
            agent_settlement::policy_controller_id(&policy),
            200,
            scenario.ctx()
        );
        agent_settlement::meter_release_with_vault(
            &mut order,
            &mut policy,
            &mut registry,
            &mut vault,
            ticket,
            2,
            100,
            b"usage-proof",
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_metered_paid(&order) == 200, 80);
        assert!(agent_settlement::work_order_premium_paid(&order) == 2, 81);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(aggregator);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun exposure_pricing_ramps_with_controller_total() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    let controller_id = {
        let order = scenario.take_shared<WorkOrder>();
        let id = object::id(&order);
        agent_settlement::create_exposure_aggregator(id, 100, scenario.ctx());
        test_scenario::return_shared(order);
        id
    };

    scenario.next_tx(PAYER);
    {
        let mut aggregator = scenario.take_shared<ExposureAggregator>();
        let ticket_one = agent_settlement::record_exposure(&mut aggregator, controller_id, 1_000_000, scenario.ctx());
        let ticket_two = agent_settlement::record_exposure(&mut aggregator, controller_id, 1_000_000, scenario.ctx());
        assert!(agent_settlement::exposure_ticket_premium_bps(&ticket_one) == 101, 82);
        assert!(agent_settlement::exposure_ticket_premium_bps(&ticket_two) == 104, 83);
        assert!(agent_settlement::exposure_window_exposure(&aggregator) == 2_000_000, 84);
        test_scenario::return_shared(aggregator);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun denial_receipt_can_trigger_underwriting_claim() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_mark_delivered(),
            9_000,
            3,
            500,
            b"insured-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::create_underwriting_vault(&policy, 200, 100, scenario.ctx());
        agent_settlement::record_policy_denial_receipt(
            &order,
            &policy,
            agent_settlement::policy_action_release(),
            b"denied-release",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let backing = coin::mint_for_testing<SUI>(300, scenario.ctx());
        agent_settlement::stake_backing(&mut vault, backing, scenario.ctx());
        test_scenario::return_shared(vault);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let receipt = scenario.take_from_sender<DenialReceipt>();
        agent_settlement::file_claim(&mut vault, &order, receipt, scenario.ctx());
        test_scenario::return_shared(vault);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun bonded_validator_attestation_increments_validation_count() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::mark_delivered(&mut order, b"delivery-hash", b"walrus-delivery", scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::release(&mut order, scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(VALIDATOR);
    {
        let bond = coin::mint_for_testing<SUI>(400, scenario.ctx());
        agent_settlement::create_validator_bond(bond, scenario.ctx());
    };

    scenario.next_tx(VALIDATOR);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut bond_cap = scenario.take_from_sender<ValidatorBondCap>();
        agent_settlement::submit_bonded_validation(
            &mut order,
            &mut bond_cap,
            AGENT,
            9_500,
            b"positive-validation",
            b"validation-root",
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_validation_count(&order) == 1, 90);
        scenario.return_to_sender(bond_cap);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun sealed_bid_market_awards_child_work_order() {
    let mut scenario = test_scenario::begin(PAYER);
    let mut clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 2_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_propose_settlement() | agent_settlement::policy_action_meter_release(),
            9_000,
            5,
            1_500,
            b"auction-parent-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        agent_settlement::create_bid_market(&order, &policy, b"sealed-agent-task", 10, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
    };

    scenario.next_tx(SUB_AGENT);
    {
        let mut market = scenario.take_shared<BidMarket>();
        let commitment = agent_settlement::sealed_bid_commitment(SUB_AGENT, 400, b"bid-nonce");
        agent_settlement::submit_sealed_bid(&mut market, commitment, &clock, scenario.ctx());
        test_scenario::return_shared(market);
    };

    clock::set_for_testing(&mut clock, 10);

    scenario.next_tx(SUB_AGENT);
    {
        let mut market = scenario.take_shared<BidMarket>();
        agent_settlement::open_bid(&mut market, 400, b"bid-nonce", &clock, scenario.ctx());
        test_scenario::return_shared(market);
    };

    scenario.next_tx(AGENT);
    {
        let mut market = scenario.take_shared<BidMarket>();
        let mut order = scenario.take_shared<WorkOrder>();
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::award_bid_child_work_order(
            &mut market,
            &mut order,
            &mut policy,
            &mut registry,
            PROVIDER,
            agent_settlement::policy_action_meter_release(),
            8_000,
            400,
            2,
            b"auction-child-metadata",
            b"auction-child-mandate",
            b"auction-child-policy",
            b"auction-child-walrus",
            b"auction-child-seal",
            8_000,
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_child_budget_allocated(&order) == 400, 91);
        assert!(agent_settlement::policy_remaining_budget(&policy) == 1_600, 92);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
        test_scenario::return_shared(market);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun branch_lattice_pause_unpause_and_revoke_paths_work() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
        agent_settlement::create_caretaker(b"branch-scope", scenario.ctx());
    };

    scenario.next_tx(PAYER);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let kill_cap = scenario.take_from_sender<suiflow::agent_settlement::KillCap>();
        agent_settlement::emergency_pause(&mut registry, &kill_cap, &clock, scenario.ctx());
        agent_settlement::emergency_unpause(&mut registry, &kill_cap, scenario.ctx());
        scenario.return_to_sender(kill_cap);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(PAYER);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let mut caretaker = scenario.take_from_sender<Caretaker>();
        agent_settlement::revoke_branch(&mut registry, &mut caretaker, &clock, scenario.ctx());
        scenario.return_to_sender(caretaker);
        test_scenario::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_DELIVERY_PROOF, location = suiflow::agent_settlement)]
fun delivery_confirmation_rejects_bad_signature() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_delivery_confirmation(&mut order, b"expected-output", scenario.ctx());
        let proof = agent_settlement::new_delivery_proof(
            object::id(&order),
            b"expected-output",
            b"proof-chain-root",
            x"cc62332e34bb2d5cd69f60efbb2a36cb916c7eb458301ea36636c4dbb012bd88"
        );
        agent_settlement::verify_and_release_delivery_proof(
            &mut order,
            proof,
            x"00",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun cosign_and_validator_slash_capital_to_vault() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_mark_delivered(),
            9_000,
            3,
            500,
            b"sponsor-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    let sponsor_policy_id = {
        let policy = scenario.take_from_sender<AgentPolicy>();
        let id = object::id(&policy);
        scenario.return_to_sender(policy);
        id
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_meter_release(),
            9_000,
            3,
            500,
            b"sponsoree-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    let sponsoree_policy_id = {
        let policy = scenario.take_from_sender<AgentPolicy>();
        let id = object::id(&policy);
        scenario.return_to_sender(policy);
        id
    };

    scenario.next_tx(AGENT);
    {
        let sponsor = scenario.take_from_sender_by_id<AgentPolicy>(sponsor_policy_id);
        let sponsoree = scenario.take_from_sender_by_id<AgentPolicy>(sponsoree_policy_id);
        let stake = coin::mint_for_testing<SUI>(250, scenario.ctx());
        agent_settlement::cosign(&sponsor, &sponsoree, stake, 9_500, scenario.ctx());
        scenario.return_to_sender(sponsor);
        scenario.return_to_sender(sponsoree);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let policy = scenario.take_from_sender_by_id<AgentPolicy>(sponsoree_policy_id);
        agent_settlement::create_underwriting_vault(&policy, 300, 100, scenario.ctx());
        agent_settlement::record_policy_denial_receipt(
            &order,
            &policy,
            agent_settlement::policy_action_release(),
            b"denied-release",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let mut cosign_bond = scenario.take_from_sender<CoSignBond>();
        let receipt = scenario.take_from_sender<DenialReceipt>();
        agent_settlement::slash_cosign_to_vault(&mut vault, &mut cosign_bond, &receipt);
        scenario.return_to_sender(receipt);
        scenario.return_to_sender(cosign_bond);
        test_scenario::return_shared(vault);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::mark_delivered(&mut order, b"delivery-hash", b"walrus-delivery", scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::release(&mut order, scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(VALIDATOR);
    {
        let bond = coin::mint_for_testing<SUI>(400, scenario.ctx());
        agent_settlement::create_validator_bond(bond, scenario.ctx());
    };

    scenario.next_tx(VALIDATOR);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let mut bond_cap = scenario.take_from_sender<ValidatorBondCap>();
        agent_settlement::submit_bonded_validation(
            &mut order,
            &mut bond_cap,
            AGENT,
            9_500,
            b"positive-validation",
            b"validation-root",
            scenario.ctx()
        );
        scenario.return_to_sender(bond_cap);
        test_scenario::return_shared(order);
    };

    scenario.next_tx(VALIDATOR);
    {
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let mut bond_cap = scenario.take_from_sender<ValidatorBondCap>();
        let receipt = test_scenario::take_from_address<DenialReceipt>(&scenario, AGENT);
        agent_settlement::slash_validator_to_vault(&mut vault, &mut bond_cap, &receipt, scenario.ctx());
        test_scenario::return_to_address(AGENT, receipt);
        scenario.return_to_sender(bond_cap);
        test_scenario::return_shared(vault);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun privacy_receipt_weights_behavior_and_decrements_budget() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_privacy_budget(
            &mut order,
            50,
            b"privacy-manifest",
            b"privacy-root",
            scenario.ctx()
        );
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_report_privacy(),
            9_000,
            3,
            500,
            b"privacy-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        agent_settlement::allocate_policy_privacy_budget(&order, &mut policy, 50, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        let registry = scenario.take_shared<GenerationRegistry>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::record_privacy_receipt(
            &mut order,
            &mut policy,
            &registry,
            1,
            2,
            b"privacy-trace-v2",
            b"walrus-privacy",
            b"seal-privacy",
            b"privacy-evidence",
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_privacy_used(&order) == 11, 95);
        assert!(agent_settlement::policy_privacy_budget_remaining(&policy) == 39, 96);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun privacy_breach_receipt_can_trigger_vault_claim() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_privacy_budget(
            &mut order,
            20,
            b"privacy-manifest",
            b"privacy-root",
            scenario.ctx()
        );
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_report_privacy(),
            9_000,
            3,
            500,
            b"privacy-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::allocate_policy_privacy_budget(&order, &mut policy, 5, scenario.ctx());
        agent_settlement::create_underwriting_vault(&policy, 100, 100, scenario.ctx());
        agent_settlement::record_privacy_breach_receipt(
            &order,
            &policy,
            1,
            2,
            b"privacy-breach-evidence",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let backing = coin::mint_for_testing<SUI>(120, scenario.ctx());
        agent_settlement::stake_backing(&mut vault, backing, scenario.ctx());
        test_scenario::return_shared(vault);
    };

    scenario.next_tx(PAYER);
    {
        let order = scenario.take_shared<WorkOrder>();
        let mut vault = scenario.take_shared<UnderwritingVault>();
        let receipt = scenario.take_from_sender<PrivacyBreachReceipt>();
        agent_settlement::file_privacy_claim(&mut vault, &order, receipt, scenario.ctx());
        test_scenario::return_shared(vault);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun origin_critic_receipt_tracks_safe_tool_call_budget() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_origin_firewall(
            &mut order,
            b"allowed-origins",
            b"allowed-tools",
            b"critic-policy",
            50,
            scenario.ctx()
        );
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_report_origin_risk(),
            9_000,
            3,
            500,
            b"origin-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        agent_settlement::allocate_policy_origin_risk_budget(&order, &mut policy, 20, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let registry = scenario.take_shared<GenerationRegistry>();
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::record_origin_critic_receipt(
            &mut order,
            &mut policy,
            &registry,
            b"allowed-origins",
            b"allowed-tools",
            b"user-intent",
            b"tool-call",
            7,
            b"critic-trace",
            b"critic-evidence",
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_critic_risk_score(&order) == 7, 170);
        assert!(!agent_settlement::work_order_critic_quarantined(&order), 171);
        assert!(agent_settlement::policy_origin_risk_budget_remaining(&policy) == 13, 172);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_ORIGIN_CRITIC, location = suiflow::agent_settlement)]
fun origin_critic_quarantine_blocks_release() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_origin_firewall(
            &mut order,
            b"allowed-origins",
            b"allowed-tools",
            b"critic-policy",
            50,
            scenario.ctx()
        );
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_report_origin_risk(),
            9_000,
            3,
            500,
            b"origin-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::mark_delivered(&mut order, b"delivery", b"walrus-delivery", scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        agent_settlement::allocate_policy_origin_risk_budget(&order, &mut policy, 20, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let registry = scenario.take_shared<GenerationRegistry>();
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::record_origin_critic_receipt(
            &mut order,
            &mut policy,
            &registry,
            b"untrusted-origin",
            b"allowed-tools",
            b"user-intent",
            b"tool-call",
            5,
            b"critic-trace",
            b"critic-evidence",
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_critic_quarantined(&order), 180);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::release(&mut order, scenario.ctx());
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun payer_can_clear_origin_quarantine_then_release() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_origin_firewall(
            &mut order,
            b"allowed-origins",
            b"allowed-tools",
            b"critic-policy",
            50,
            scenario.ctx()
        );
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_report_origin_risk(),
            9_000,
            3,
            500,
            b"origin-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(PROVIDER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::mark_delivered(&mut order, b"delivery", b"walrus-delivery", scenario.ctx());
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut registry = scenario.take_shared<GenerationRegistry>();
        let order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut registry, &policy, scenario.ctx());
        agent_settlement::allocate_policy_origin_risk_budget(&order, &mut policy, 20, scenario.ctx());
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(AGENT);
    {
        let registry = scenario.take_shared<GenerationRegistry>();
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::record_origin_critic_receipt(
            &mut order,
            &mut policy,
            &registry,
            b"allowed-origins",
            b"unapproved-tool",
            b"user-intent",
            b"tool-call",
            5,
            b"critic-trace",
            b"critic-evidence",
            &clock,
            scenario.ctx()
        );
        assert!(agent_settlement::work_order_critic_quarantined(&order), 190);
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(registry);
    };

    scenario.next_tx(PAYER);
    {
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::clear_origin_quarantine(&mut order, b"human-reviewed", scenario.ctx());
        assert!(!agent_settlement::work_order_critic_quarantined(&order), 191);
        agent_settlement::release(&mut order, scenario.ctx());
        assert!(agent_settlement::work_order_state(&order) == STATE_RELEASED, 192);
        test_scenario::return_shared(order);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = E_BAD_EXECUTION_BINDING, location = suiflow::agent_settlement)]
fun execution_binding_rejects_nullifier_replay() {
    let mut scenario = test_scenario::begin(PAYER);
    let clock = clock::create_for_testing(scenario.ctx());

    create_demo_order(&mut scenario, &clock, 1_000, 10_000);

    scenario.next_tx(PAYER);
    {
        agent_settlement::create_generation_registry(1_000, 10_000, scenario.ctx());
        agent_settlement::create_execution_binding_registry(scenario.ctx());
        let mut order = scenario.take_shared<WorkOrder>();
        agent_settlement::configure_execution_context(
            &mut order,
            b"https-api-service",
            b"x402-payment-intent",
            b"service-quote",
            scenario.ctx()
        );
        agent_settlement::issue_agent_policy(
            &order,
            AGENT,
            agent_settlement::policy_action_meter_release(),
            9_000,
            3,
            500,
            b"execution-policy",
            scenario.ctx()
        );
        test_scenario::return_shared(order);
    };

    scenario.next_tx(AGENT);
    {
        let mut generation_registry = scenario.take_shared<GenerationRegistry>();
        let mut execution_registry = scenario.take_shared<ExecutionBindingRegistry>();
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::register_policy_generation(&mut generation_registry, &policy, scenario.ctx());
        agent_settlement::meter_release_with_execution_binding(
            &mut order,
            &mut policy,
            &mut generation_registry,
            &mut execution_registry,
            1,
            100,
            b"usage-proof",
            b"service-receipt-1",
            b"execution-nullifier",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(execution_registry);
        test_scenario::return_shared(generation_registry);
    };

    scenario.next_tx(AGENT);
    {
        let mut generation_registry = scenario.take_shared<GenerationRegistry>();
        let mut execution_registry = scenario.take_shared<ExecutionBindingRegistry>();
        let mut order = scenario.take_shared<WorkOrder>();
        let mut policy = scenario.take_from_sender<AgentPolicy>();
        agent_settlement::meter_release_with_execution_binding(
            &mut order,
            &mut policy,
            &mut generation_registry,
            &mut execution_registry,
            1,
            100,
            b"usage-proof-2",
            b"service-receipt-2",
            b"execution-nullifier",
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(policy);
        test_scenario::return_shared(order);
        test_scenario::return_shared(execution_registry);
        test_scenario::return_shared(generation_registry);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

fun create_demo_order(scenario: &mut Scenario, clock: &clock::Clock, amount: u64, deadline_ms: u64) {
    scenario.next_tx(PAYER);
    let payment = coin::mint_for_testing<SUI>(amount, scenario.ctx());
    agent_settlement::create_work_order(
        PROVIDER,
        payment,
        b"metadata",
        b"mandate",
        b"policy",
        b"walrus-blob",
        b"seal-policy",
        deadline_ms,
        clock,
        scenario.ctx()
    );
}

fun configure_demo_attestation(order: &mut WorkOrder, ctx: &sui::tx_context::TxContext) {
    agent_settlement::configure_attestation(
        order,
        x"cc62332e34bb2d5cd69f60efbb2a36cb916c7eb458301ea36636c4dbb012bd88",
        b"pcr0",
        b"input-hash",
        1_000,
        ctx
    );
}
