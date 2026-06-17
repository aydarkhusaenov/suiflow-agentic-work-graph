# SuiFlow Agentic Work Graph

SuiFlow is an Agentic Web project for Sui Overflow 2026. It turns autonomous-agent work into Sui-native settlement objects: funded work orders, bounded agent capabilities, recursive Work Graph sub-orders, GenerationRegistry revocation, metered settlement, execution-bound payment receipts, privacy-budgeted agent traces, origin/tool critic receipts, underwriting vaults, denial receipts, exposure aggregation, sealed-bid child-task auctions, bonded validation, co-sign bonds, delivery-confirmation proofs, Walrus availability proofs, Seal-style evidence predicates, TEE-signed WorkReceipts, service bonds, timeout refunds, split settlement, final receipts, and validator attestations.

The core idea is simple: an agent should not be trusted with broad wallet authority. It should receive a narrow Sui object capability that lets it perform exact actions on one work order, with expiry, usage limits, read delegation, settlement caps, evidence gates, and an on-chain audit trail.

## Hackathon Fit

- Event: Sui Overflow 2026
- Primary track: Agentic Web
- Secondary fit: DeFi & Payments, Walrus, Payments & Wallets
- Chain target: Sui Testnet
- Core contract: `suiflow::agent_settlement`
- Frontend: TypeScript Sui wallet app with PTB builders for the lifecycle

## Why This Is Sui-Native

- Each work engagement is a shared Sui object, not only a database row.
- Agent authority is represented as an owned `AgentPolicy` object with one-order, one-action-surface, usage-limit, expiry, and settlement-cap controls.
- Recursive Work Graphs are represented by child `WorkOrder` objects and child `AgentPolicy` objects that inherit root principal, ancestry, budget, and safety constraints.
- The `GenerationRegistry` gives the graph a revocation lattice: ancestor generation bumps invalidate descendants by snapshot, branch IDs can be bound into policy ancestry, and emergency pause stops the fleet.
- Escrow and service bonds are held as `Balance<SUI>` inside the work object.
- Metered settlement pays per verified usage unit from escrow, optionally routing premium into an underwriting vault.
- Execution-bound metering can consume a one-time service receipt/nullifier so payment is tied to a specific web execution.
- Privacy budgets score content and behavior leakage against the WorkOrder, with breach receipts claimable against vault backing.
- `UnderwritingVault`, `DenialReceipt`, and `ExposureAggregator` turn failed delegated attempts and risk exposure into claimable, priced on-chain objects.
- Evidence and receipts are object fields that can point to Walrus blobs and Seal-encrypted evidence envelopes.
- TEE-required work orders reject plain release and require an Ed25519-signed `WorkReceipt` over BCS-pinned fields.
- Seal-style read approval is derived from the `WorkOrder` state and optional `AgentPolicy` read delegation.
- Walrus delivery can require a certified blob epoch before the state moves to delivered.
- Final settlement emits digest-bound receipt events for feedback and validator-attestation indexing.
- Invalid delegated attempts can be recorded as non-aborting denial receipts, giving judges an auditable negative-evidence story.
- Validators can post bonded validation capability objects, emit weighted validation events, and be slashed only when a denial receipt contradicts the same work order and agent.
- Origin Critic Firewall binds sensitive delegated actions to origin/tool manifests and off-chain critic receipts; risky or mismatched receipts quarantine release until payer review, mirroring current browser-agent guidance around origin gating and content-isolated critics.

## Round 2/3 Implementation Status

Implemented in the Move package after the main settlement surface:

- Recursive Work Graph: `spawn_child_work_order` splits parent escrow into a child `WorkOrder`, issues an attenuated child `AgentPolicy`, preserves ancestry/root principal, enforces budget/action/cap/depth limits, and emits `SubDelegation`.
- GenerationRegistry revocation lattice: `GenerationRegistry` tracks policy generations and owners; `policy_is_live` checks ancestor generations against a policy snapshot; `revoke_subtree`, `emergency_pause`, `emergency_unpause`, `Caretaker`, `bind_policy_branch`, and `revoke_branch` cover enforced subtree/fleet/branch revocation.
- Metered settlement: `ACTION_METER_RELEASE`, `meter_release`, and `meter_release_with_vault` pay `units * unit_price` from escrow with remaining-budget, settlement-cap, registry-liveness, proof-hash, running-total, and premium accounting.
- Execution binding: `ExecutionBindingRegistry`, `configure_execution_context`, and `meter_release_with_execution_binding` bind metered payment to service endpoint, payment intent, quote, service receipt, and one-time nullifier.
- SPILLGuard privacy budgeting: `configure_privacy_budget`, `allocate_policy_privacy_budget`, `record_privacy_receipt`, `record_privacy_breach_receipt`, and `file_privacy_claim` track weighted content/behavior leakage and turn over-budget leakage into claim evidence.
- Underwriting and denial receipts: `record_policy_denial_receipt` mints a transferable `DenialReceipt`; `UnderwritingVault` accepts stake, caps coverage, accrues premiums, pays claims, and can receive slashed validator bonds.
- ExposureAggregator: `record_exposure` tracks controller-window exposure, uses a convex capped premium ramp, and passes an `ExposureTicket` into vault-backed metered release.
- Bonded validation: `ValidatorBondCap` records validator stake/weight and the last work order/agent it validated; `submit_bonded_validation` emits a weighted validation event; `slash_validator_to_vault` moves only a contradicted matching validator bond into underwriting backing.
- Sealed-bid sub-agent auction: `create_bid_market`, `sealed_bid_commitment`, `submit_sealed_bid`, `open_bid`, and `award_bid_child_work_order` store commitments, verify reveals, and award an attenuated child WorkOrder to the winning bidder.
- Architect-original safety layer: `reap_abandoned_branch`, `cosign`, `slash_cosign_to_vault`, `release_cosign_after_decay`, `configure_delivery_confirmation`, and `verify_and_release_delivery_proof` cover abandoned-branch GC, cold-start surety capital, and signed delivery-confirmation release.

Formal prover specs are drafted in `contracts/suiflow/specs/agent_settlement_formal_specs.move`, but the local Sui Prover binary is not installed, so no machine-checked proof output is claimed. Live Walrus storage proof, live Seal encrypt/decrypt, and a live Nautilus/off-chain attester are service/runbook items unless configured and exercised on Testnet.

Origin Critic Firewall status: implemented in Move and frontend PTB builders for manifest configuration, critic risk-budget allocation, critic receipt recording, quarantine, and payer-cleared resolution. The isolated critic model itself remains an off-chain demo/runbook component unless a live critic service is connected.

Research sources for that layer: Google Chrome agentic security architecture, Chrome WebMCP agent/tool security guidance, Unit42 indirect prompt-injection observations, arXiv 2606.10525 on automated prompt injection, and NDSS 2026 ToolHijacker on prompt injection to tool selection.

## Current Workspace

```text
contracts/suiflow/       Move package
app/                     frontend/agent UI shell
agent/                   agent skill and policy interface notes
docs/                    research, product, submission, and build plan
scripts/                 helper scripts
assets/                  logo/screenshots/video assets
```

## Testnet Deployment

```text
Package ID:
0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d

Publish tx:
3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn
```

- Package Explorer: https://suiexplorer.com/object/0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d?network=testnet
- Publish Explorer: https://suiexplorer.com/txblock/3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn?network=testnet
- Full live demo trail: `docs/ONCHAIN.md`

## Immediate Commands

```bash
export PATH="$HOME/.suiup/bin:$HOME/.local/bin:$PATH"
cd /home/legat/work/hackaton/Sui-Overflow-2026/contracts/suiflow
sui move build
sui move test

cd /home/legat/work/hackaton/Sui-Overflow-2026/app
npm run build
```

Current verification: `sui move build` passes, `sui move test` passes 36/36, `npm run build` passes for the frontend, and `npm audit --omit=dev` reports 0 production vulnerabilities.

## Project Thesis

The winning angle is not "escrow on another chain." The winning angle is object-capability commerce for agents:

1. A human or AI agent creates a funded Sui work order.
2. A provider posts a service bond.
3. A bounded agent policy object grants exact action authority.
4. The policy can spawn attenuated child work orders, creating a recursive Work Graph without handing a sub-agent broad wallet authority.
5. A GenerationRegistry revocation lattice lets the root principal revoke a subtree, bind/revoke a branch, or pause the fleet.
6. Delivery/dispute evidence is stored as Walrus/Seal references and can be gated by Seal predicates.
7. Availability-sensitive delivery requires a Walrus proof object/adapter fields.
8. TEE-required release uses a signed `WorkReceipt`; invalid signatures can produce denial receipts.
9. Settlement can be final, split, refunded, metered by usage, or metered through an execution-bound receipt/nullifier.
10. Privacy budgets make content and behavior leakage auditable and insurable.
11. Origin Critic Firewall constrains web-agent data/action flow through origin/tool manifests, critic receipts, risk budgets, and quarantine.
12. Exposure aggregation, co-sign bonds, and bonded validation turn risk, validator weight, and failures into auditable on-chain events.
13. Settlement produces a portable receipt hash.
14. Review and validation events turn final receipts into an agent reputation graph.

## Submission Links To Fill

- GitHub: https://github.com/aydarkhusaenov/suiflow-agentic-work-graph
- Sui package ID: `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`
- Demo site: https://aydarkhusaenov.github.io/suiflow-agentic-work-graph/
- Demo video: https://aydarkhusaenov.github.io/suiflow-agentic-work-graph/suiflow-demo.webm
- X/social proof: fill after posting
