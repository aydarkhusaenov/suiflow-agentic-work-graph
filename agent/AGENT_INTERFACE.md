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

## Safety Rules

- Never accept or store private keys.
- Never broadcast without explicit wallet confirmation.
- Every generated PTB must target exactly one `WorkOrder`.
- Agent actions require an `AgentPolicy` object when the actor is not the payer/provider.
- Evidence blobs should be hashed locally before object fields are updated.

## Novel Demo Moment

Show the same agent failing to release a different work order because the `AgentPolicy.work_order_id` does not match. That is the core Sui object-capability story.
