#[test_only]
module suiflow::agent_settlement_tests;

use suiflow::agent_settlement::{Self, AgentPolicy, WorkOrder};
use sui::clock;
use sui::coin;
use sui::object;
use sui::sui::SUI;
use sui::test_scenario::{Self, Scenario};

const PAYER: address = @0xA11CE;
const PROVIDER: address = @0xB0B;
const AGENT: address = @0xCAFE;

const STATE_DELIVERED: u8 = 2;
const STATE_RELEASED: u8 = 4;
const STATE_REFUNDED: u8 = 5;
const E_BAD_POLICY: u64 = 5;
const E_BAD_SETTLEMENT: u64 = 7;

#[test]
fun policy_bit_constants_exist() {
    assert!(agent_settlement::policy_action_mark_delivered() == 1, 0);
    assert!(agent_settlement::policy_action_release() == 2, 1);
    assert!(agent_settlement::policy_action_request_refund() == 4, 2);
    assert!(agent_settlement::policy_action_propose_settlement() == 8, 3);
    assert!(agent_settlement::policy_action_accept_settlement() == 16, 4);
    assert!(agent_settlement::deny_reason_wrong_order() == 2, 5);
    assert!(agent_settlement::deny_reason_usage_exhausted() == 6, 6);
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
