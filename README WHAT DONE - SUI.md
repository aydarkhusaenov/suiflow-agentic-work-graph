# Sui Overflow 2026 - What Done

## Workspace

- Ubuntu: `/home/legat/work/hackaton/Sui-Overflow-2026`
- Windows mirror: `C:\Users\NITRO 5\Downloads\!!!!Новая папка\!hackaton\Sui-Overflow-2026`
- Project: `SuiFlow Agentic Work Graph`
- Primary track: Agentic Web
- Deadline target: submit by June 20, 2026 to avoid timezone risk.

## Latest Status - 2026-06-17

- Sui Testnet deployment is complete.
- Package ID: `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`.
- Publish tx: `3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn`.
- Package Explorer: https://suiexplorer.com/object/0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d?network=testnet
- Live demo trail with object IDs and transaction IDs is written in `docs/ONCHAIN.md`.
- `app/.env` is set to the published package ID.
- Public GitHub repo is live: https://github.com/aydarkhusaenov/suiflow-agentic-work-graph
- Public frontend is configured through GitHub Pages: https://aydarkhusaenov.github.io/suiflow-agentic-work-graph/
- Core verification is green after the publishability refactor: `sui move build`, `sui move test` 36/36, frontend `npm run build`, `npm audit --omit=dev` with 0 vulnerabilities, and `git diff --check`.
- The contract had to be refactored into nested WorkOrder state structs because Sui Testnet rejects structs above `max_fields_in_struct = 32`. The refactor preserved behavior and the full test suite still passes.
- Windows mirror has been updated after the latest implementation pass.
- Important honesty rule for submission: claim the on-chain Origin Critic Firewall, execution binding, privacy budgeting, underwriting, Work Graph, and frontend PTB builders as implemented; do not claim live Walrus/Seal/Nautilus/Sui Prover/isolated critic service unless real live IDs or successful transactions are produced.

## Concept

SuiFlow is object-capability settlement for autonomous agents on Sui:

- funded `WorkOrder` shared objects;
- owned `AgentPolicy` capability objects;
- recursive Work Graph child `WorkOrder`/`AgentPolicy` objects;
- `GenerationRegistry` revocation lattice over policy ancestry;
- one-use/usage-limited delegated agent actions;
- transferable `DenialReceipt` objects for invalid policy attempts;
- SUI escrow and service bonds;
- metered settlement with usage proof hashes;
- execution-bound metered settlement with service receipt nullifiers;
- Origin Critic Firewall for origin/tool manifests, critic risk budgets, critic receipts, release quarantine, and payer-cleared resolution;
- privacy-budgeted agent trace receipts and privacy breach claim receipts;
- `UnderwritingVault` stake, premiums, claim payout, and validator-bond slashing;
- `ExposureAggregator` controller-window risk pricing;
- sealed-bid child-task auction and award flow;
- branch binding, co-sign bonds, abandoned-branch reaping, and delivery-confirmation release;
- delivery/dispute evidence hashes;
- Walrus blob IDs and Seal policy IDs;
- Walrus availability proof fields and retention checks;
- Seal-style delivery/dispute/timelock access predicates;
- TEE-required release with Ed25519-signed `WorkReceipt` verification;
- attestation denial receipts for bad/stale/mismatched signed receipts;
- release, timeout refund, and split-settlement paths;
- BLAKE2b receipt, feedback, and validator-attestation events;
- bonded validation with validator stake-derived weight.

## Files Created

- `contracts/suiflow/sources/agent_settlement.move`
- `contracts/suiflow/tests/agent_settlement_tests.move`
- `app/src/main.tsx`
- `app/src/styles.css`
- `agent/AGENT_INTERFACE.md`
- `docs/RESEARCH.md`
- `docs/PRODUCT_SPEC.md`
- `docs/BUILD_PLAN.md`
- `docs/SUBMISSION_DRAFT.md`
- `docs/SECURITY.md`
- `docs/NOVELTY_AND_SCORECARD.md`
- `docs/ONCHAIN.md`
- `docs/FORMAL_VERIFICATION.md`
- `contracts/suiflow/specs/agent_settlement_formal_specs.move`

## Verification

- Sui CLI installed with `suiup`.
- Active Sui CLI used: `sui 1.73.1`.
- Current pass ran `sui move test`: 36/36 passing.
- Current pass ran `npm run build` in `app`: passing.
- Current pass ran `sui move build`: passing, with 8 known self-transfer lints intentionally suppressed at module level.
- Current pass ran `npm audit --omit=dev`: 0 vulnerabilities.
- Current pass ran `git diff --check`: passing.
- Final full build/audit should be rerun after deploy env values are added or package IDs are changed.

## Implemented From "README WHAT need to do more"

- P0 wallet/PTB layer: app now uses `@mysten/dapp-kit`, `@mysten/sui`, React Query, and Sui Testnet config.
- P0 lifecycle PTBs: frontend builders for create+fund+policy, configure TEE, require Walrus, post bond, agent delivery, policy denial, attestation denial, refund, timeout refund, split settlement, plain release, and attested release.
- P0 combined create path: added `create_work_order_with_policy` so one PTB can fund a WorkOrder and transfer the first AgentPolicy.
- P1.1 attestation gate: added `WorkReceipt`, BCS digest/message helpers, `configure_attestation`, `release_with_attestation`, field-based PTB wrapper, and `record_attestation_denial`.
- P1.1 bypass prevention: plain `release` and `agent_release` abort for `requires_tee_proof` orders.
- P1.2 Seal predicate: added canonical WorkOrder-derived Seal identities, `seal_approve`, `seal_approve_as_agent`, `ACTION_READ_EVIDENCE`, and `seal_approve_tle`.
- P1.3 Walrus PoA adapter: added `WalrusAvailabilityProof`, required blob end epoch, verified certified/end epoch fields, and delivery wrappers.
- Round 2 recursive Work Graph: added child work-order spawning with parent escrow split, inherited safety fields, attenuated child policy, ancestry, depth cap, root principal, and `SubDelegation` event.
- Round 2 GenerationRegistry revocation lattice: added generation snapshots, ancestor checks, subtree revocation, fleet pause/unpause, caretaker branch receipt, branch binding into policy ancestry, branch generation bump, and registry-aware policy assertions.
- Round 3 metered settlement: added `ACTION_METER_RELEASE`, `meter_release`, usage proof hash, running paid totals, remaining-budget/cap checks, and premium accounting.
- Frontier addition: added `ExecutionBindingRegistry`, execution context digest, one-use nullifier registry, and `meter_release_with_execution_binding` so service execution and x402-style payment intent cannot be replayed across settlement.
- Frontier addition: added SPILLGuard privacy budgeting with content/behavior weighted scoring, privacy receipts, privacy breach receipts, and privacy breach vault claims.
- Round 3 underwriting: added `UnderwritingVault`, underwriter positions, premium-funded backing, `DenialReceipt` claim flow, claim payout, and validator-bond slashing into vault stake.
- Round 3 exposure aggregation: added `ExposureAggregator`, exposure tickets, window exposure accounting, and convex capped premium ramping by controller exposure.
- Round 3 bonded validation: added `ValidatorBondCap`, stake-derived bond weight, last validated work order/agent linkage, bonded validation event, and constrained slashing hook.
- Round 2 sealed-bid sub-agent auction: added bid market, commitment helper, stored bidder commitments, reveal verification, and child WorkOrder award flow.
- Round 3 architect originals: added abandoned-branch reaper, cold-start co-sign bond and slashing/release paths, and signed delivery-confirmation release.
- Architect-original negative evidence: policy denial and attestation denial are both explicit events.
- Architect-original timelock reveal: `seal_approve_tle` binds reveal time to the WorkOrder deadline.
- Receipts strengthened: final BLAKE2b receipt now also includes TEE, delivered output, Walrus retention, parent order/policy IDs, root principal, depth, child budget, metered paid, premium paid, release condition, expected delivery commitment, proof-chain root, privacy budget/used/manifest/trace, execution context, execution receipt, and related evidence fields.
- Frontend expanded: app PTB builders expose registry create/register/revoke/pause/unpause, branch create/bind/revoke, child spawn, sealed-bid auction, metered draw, execution-bound metered draw, privacy budget/receipt/breach/claim, vaults, exposure, denial claims, bonded validation/slashing, co-signing, delivery confirmation, Walrus, TEE, refund, split, and release flows.
- Tests expanded: Move suite now covers auction award, branch pause/unpause/revoke, bad delivery proof rejection, co-sign and validator slashing, exposure premium ramp, recursive attenuation, generation revocation, vault metering, denial claims, bonded validation, privacy weighted scoring, privacy breach claim, and execution nullifier replay rejection.
- Frontier addition: added Origin Critic Firewall with WorkOrder origin/tool manifest hashes, critic policy hash, risk threshold, policy risk budget allocation, `OriginCriticReceipt`, release quarantine on origin/tool drift or threshold breach, payer-cleared resolution, frontend PTB builders, and 3 Move tests.

## Important Gaps

- No real Nautilus enclave signer has produced a valid `WorkReceipt` signature yet.
- Origin Critic Firewall has Move and frontend surfaces. It should still be described honestly: the on-chain manifest/risk/quarantine layer is implemented, while a live isolated critic service is a runbook/demo integration unless connected before submission.
- Walrus availability is implemented as contract adapter fields; a real `walrus::blob::Blob` package object should be wired after publish/service setup.
- Seal predicates are implemented; real Seal encryption/decryption must be exercised against the published package.
- Formal spec artifact exists at `contracts/suiflow/specs/agent_settlement_formal_specs.move`; machine-checked Sui Prover output is not claimed because the local prover binary is not installed.
- The compact live demo proves the highest-signal path: registry, execution binding, privacy, origin critic receipt, metered release, Walrus availability adapter, agent delivery, and final release. Broader Round 2/3 demo IDs for sealed-bid auctions, vault claims, exposure tickets, and bonded validation are optional extra proof if time remains.
- Need demo video and submission.

## Remaining User Steps

1. Wait a few minutes if GitHub Pages is still building.
2. Record the demo video using `docs/SUBMISSION_DRAFT.md`, `docs/ONCHAIN.md`, and `README SUBMIT STEPS - SUI.md`.
3. Submit to Sui Overflow under Agentic Web.
