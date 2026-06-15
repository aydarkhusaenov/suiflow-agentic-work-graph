# SuiFlow Agent Interface

The agent layer should operate as a non-custodial planner.

## Inputs

- `workOrderId`
- connected Sui address
- current Sui object state
- Walrus blob metadata
- optional Seal policy ID
- requested action

## Actions

- `inspect_work_order`
- `issue_policy`
- `build_mark_delivered_ptb`
- `build_release_ptb`
- `build_refund_ptb`
- `build_split_settlement_ptb`
- `build_validation_ptb`
- `check_policy_status`
- `record_policy_denial`

## Safety Rules

- Never accept or store private keys.
- Never broadcast without explicit wallet confirmation.
- Every generated PTB must target exactly one `WorkOrder`.
- Agent actions require an `AgentPolicy` object when the actor is not the payer/provider.
- Policy objects should be one-use by default. Multi-use policies must state the exact usage budget.
- Delegated split-settlement proposals must respect `max_provider_amount`.
- Evidence blobs should be hashed locally before object fields are updated.

## Novel Demo Moment

Show the same agent failing to act on a different work order because the `AgentPolicy.work_order_id` does not match. Then record that failed attempt as a denial receipt. That is the core Sui object-capability story.
