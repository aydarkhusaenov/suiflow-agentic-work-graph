# Novelty And Scorecard Fit

## Primary Track

SuiFlow targets the Sui Overflow 2026 Agentic Web track.

The core pitch: autonomous agents should not receive broad wallet authority. They should receive explicit Sui object capabilities that are scoped to one work order, one action set, one usage budget, one expiry, and optionally one settlement cap.

## What Is New

### 1. One-Use Object Capabilities For Agents

Most agent-payment demos treat the agent as a signer, relayer, or off-chain policy engine. SuiFlow represents delegated authority as an owned `AgentPolicy` object. The policy is checked on-chain against:

- work-order ID;
- agent address;
- action bitmask;
- expiry timestamp;
- usage limit;
- settlement amount cap.

### 2. Denial Receipts

Real agent systems need negative evidence, not only successful receipts. SuiFlow exposes `policy_status` for non-aborting checks and `record_policy_denial` for auditable failed delegated attempts. A judge can see that a policy for work order `A` cannot act on work order `B`, and that the failed attempt can still leave a verifiable record.

### 3. Digest-Bound Settlement Receipts

Final receipts are BLAKE2b digests over the work-order ID, parties, amount, state, settlement amount, mandate/policy hashes, evidence hashes, Walrus blob ID, and Seal policy ID. This makes the receipt portable for feedback, validator attestations, and future reputation systems.

### 4. Evidence Privacy + Availability Path

The Move object keeps lightweight anchors:

- `walrus_blob_id` for large delivery or dispute evidence;
- `seal_policy_id` for encrypted/private evidence access;
- evidence hashes for verification.

This lets the demo tell a credible story about verifiable evidence without exposing sensitive work artifacts directly on-chain.

## Why It Fits Sui

- Shared objects: the work order is touched by payer, provider, agent, and validator.
- Owned objects: agent authority is an owned capability, not a server session.
- PTBs: agent-prepared actions can be built as wallet-approved transaction blocks.
- Low-latency object settlement: small work-order actions are practical on Sui.

## Demo Moment To Prioritize

1. Create two work orders.
2. Issue one `AgentPolicy` for work order `A`.
3. Use it successfully on `A`.
4. Try to use it on `B`.
5. Show `policy_status` returns `DENY_WRONG_ORDER`.
6. Record a denial receipt.
7. Finalize `A` and show the digest-bound receipt.

That is stronger than a normal escrow demo because it proves safe autonomy, failure auditability, and Sui object-capability design in one sequence.

## Sources

- Sui Overflow: https://overflow.sui.io/
- Sui object model: https://docs.sui.io/develop/sui-architecture/object-model
- Programmable transaction blocks: https://docs.sui.io/develop/transactions/ptbs/prog-txn-blocks
- Sui TypeScript SDK: https://docs.sui.io/guides/developer/sui-101/client-tssdk
- Walrus docs: https://docs.wal.app/
