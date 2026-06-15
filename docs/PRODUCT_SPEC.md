# Product Spec

## Name

SuiFlow Agentic Work Graph

## One-Liner

Object-capability settlement for autonomous agents on Sui.

## Problem

AI agents can negotiate and trigger work, but real commerce needs bounded authority, escrow, delivery evidence, dispute handling, refund paths, settlement receipts, and reputation.

## Solution

SuiFlow creates one shared Sui object per work order and one owned capability object per delegated agent. Funds, bonds, evidence pointers, deadlines, receipts, denials, and validations live in the object graph. Agents prepare actions, but Sui wallet signing enforces user control.

## User Flow

1. Payer creates a funded SUI work order.
2. Provider posts a service bond.
3. Payer or provider issues an `AgentPolicy` object to an agent address.
4. Agent uses the policy once or until the usage limit is exhausted.
5. Invalid delegated actions can be recorded as denial receipts.
6. Agent attaches delivery evidence by referencing a Walrus blob and local hash.
7. Payer releases, asks for refund, or accepts a split settlement.
8. Final state emits BLAKE2b receipt events.
9. Counterparties submit feedback.
10. Validators submit attestations for agent reputation.

## Judge Demo

Show two objects:

- Work order `A`
- Agent policy scoped to work order `A`

Then show:

- The agent can mark delivered on `A`.
- The same policy cannot act on work order `B`.
- The invalid attempt can be recorded as a denial receipt.
- The final receipt includes evidence and policy references.

This demonstrates Sui-native object security rather than generic web app logic.
