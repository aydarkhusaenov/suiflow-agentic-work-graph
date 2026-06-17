# Security Notes

## Core Security Model

- Agent authority is object-bound. Delegated actions require an `AgentPolicy` object.
- Every `AgentPolicy` is scoped to one `WorkOrder` through `work_order_id`.
- Policies include exact allowed-action bitmasks, expiry timestamps, usage limits, and optional settlement caps.
- Recursive Work Graph delegation is attenuating: child work orders can only receive budget, action bits, settlement caps, expiry, and depth that fit under the parent policy.
- Parent escrow is split into child escrow during sub-delegation, so child work does not receive open-ended spend authority.
- `AgentPolicy` ancestry and generation snapshots are checked through `GenerationRegistry` for registry-aware delegated paths.
- Subtree generation bumps invalidate descendants whose snapshots are stale; branch IDs can be bound into policy ancestry and revoked through the same generation check; emergency pause disables registry-aware delegated actions fleet-wide.
- Origin Critic Firewall pins origin/tool manifests and critic policy hashes on the WorkOrder, lets policies spend a bounded origin-risk budget through critic receipts, and quarantines settlement when origin/tool drift or cumulative risk crosses the configured threshold.
- Sealed-bid markets store bidder commitments and require the reveal hash to match before a bid can win a child WorkOrder award.
- Policy status can be checked without aborting, and invalid delegated attempts can be recorded as denial receipts.
- `DenialReceipt` objects bind work order, policy, reporter, attempted action, reason code, evidence hash, and timestamp before they can be used for vault claims.
- Metered release is bounded by escrow balance, policy remaining budget, optional provider cap, liveness in `GenerationRegistry`, and a usage proof hash.
- Execution-bound metered release additionally requires a configured execution context and consumes a one-time nullifier, preventing replay of the same web-service execution receipt.
- Privacy receipts score both content leakage and behavior-trace leakage; behavior leakage is weighted more heavily and consumes a bounded policy/WorkOrder privacy budget.
- Privacy breach receipts are separate claim evidence and can pay only through matching vault/order/policy checks.
- Vault-backed metered release routes premium into `UnderwritingVault` stake and records running paid/premium totals on the work order.
- `ExposureAggregator` tickets are controller-bound so a ticket from one policy controller cannot price another controller's draw; premium ramping is convex and capped.
- Underwriting claims require a matching `DenialReceipt`, matching vault policy, available staked backing, coverage cap, and order amount cap.
- Bonded validation requires a live `ValidatorBondCap`; bond weight is derived from stake, the bond records the last validated work order/agent, and slashing requires a matching denial receipt.
- Co-sign bonds are first-loss capital for a sponsoree policy and can be slashed into the matching vault before pool capital.
- Delivery-confirmation release binds the expected output commitment, proof-chain root, signer key, and Ed25519 signature before release.
- `ACTION_READ_EVIDENCE` extends least-authority delegation from spending/settlement into Seal-style evidence access.
- A provider can post a service bond; missed-deadline refunds can slash that bond to the payer.
- A `requires_tee_proof` work order cannot use the plain release path. It must use `release_with_attestation`.
- `WorkReceipt` signatures bind order ID, agent, input hash, output hash, model PCR, delivered state, and attestation timestamp.
- Walrus availability fields require a certified epoch and sufficient retention before availability-gated delivery.
- Seal identities are derived from `WorkOrder` ID + evidence class, and timelock reveal IDs are bound to the refund deadline.
- Final settlement moves escrow and bond balances out of the shared object, leaving no stranded active funds in finalized paths.
- Final receipts are BLAKE2b digests over work-order ID, parties, amount, state, settlement amount, metadata/mandate/policy hashes, evidence hashes, Walrus blob ID, Seal policy ID, TEE settings, delivered output hash, verified Walrus retention fields, parent order/policy IDs, root principal, depth, child budget, metered paid, premium paid, release condition, expected delivery commitment, proof-chain root, privacy budget/used/manifest/trace, execution context, execution receipt, origin/tool manifests, critic policy, critic risk, quarantine flag, and critic trace root.

## Implemented Security Properties

- Clean release path returns escrow and service bond correctly.
- Agent delivery requires a matching `AgentPolicy`.
- A policy scoped to work order `A` cannot mutate work order `B`.
- A one-use policy cannot be reused for a second delegated action.
- A delegated split-settlement agent cannot propose a provider payout above its cap.
- A wrong-order policy can be checked and recorded as a denial receipt without mutating funds.
- Timeout refund works after the deadline and slashes the service bond.
- `WorkReceipt` BCS digest is stable and field-sensitive.
- Walrus delivery succeeds with sufficient certified retention and rejects short retention.
- Delivery Seal identity approval succeeds only for the canonical WorkOrder identity.
- Delegated Seal read approval requires a valid `AgentPolicy` with `ACTION_READ_EVIDENCE`.
- Timelock reveal only opens at the WorkOrder deadline.
- Attestation denial records bad signatures without releasing funds.
- TEE-required orders reject plain release.
- Recursive child work orders are budget/action/cap/depth attenuated from their parent policy.
- Registry-aware policy checks fail when the registry is paused or an ancestor generation is newer than the policy snapshot.
- Branch revocation is enforced when the branch ID is bound into policy ancestry.
- Sealed-bid reveal requires a stored commitment match before award.
- Metered release cannot exceed escrow, remaining policy budget, or provider cap.
- Vault-backed metered release separates provider payment from premium and updates vault exposure.
- Execution-bound metered release rejects reused nullifiers.
- Privacy receipts decrement policy privacy budget using behavior-weighted scoring.
- Privacy breach receipts can trigger matching vault claims.
- Origin critic receipts decrement policy origin-risk budget, record origin/tool/user-intent/tool-call commitments, and quarantine release on manifest mismatch or threshold breach.
- Origin quarantine blocks direct release, split acceptance, and metered drawdowns until the payer clears it with a resolution hash.
- Claims require a matching `DenialReceipt` and cannot pay beyond coverage cap, available stake, or order amount.
- Exposure tickets are scoped to the policy controller that created the exposure window, and pricing rises as controller exposure rises.
- Bonded validation requires a live validator bond and emits stake-weighted validation evidence.
- Validator slashing requires the validator bond to have attested the same work order and agent named in the denial receipt.
- Co-sign slashing routes sponsor first-loss capital into the matching vault.
- Bad delivery-confirmation signatures are rejected.

## Known Gaps Before Submission

- Add live successful attested release with a real Nautilus/off-chain Ed25519 signer.
- Connect a live isolated critic service if claiming off-chain critic isolation beyond on-chain manifest/risk/quarantine enforcement.
- Add live Seal encrypt/decrypt flow against the published package.
- Replace the Walrus adapter fields with a direct `walrus::blob::Blob` verification path when the exact testnet package API is pinned.
- Formal spec artifact is included under `contracts/suiflow/specs`; run Sui Prover when installed. No formal Sui Prover result is claimed in this repo snapshot.
- Re-run the Move test suite after any non-doc changes to the Round 2/3 surfaces and record the exact command output before submission.
- Do not claim live Walrus, Seal, Nautilus, or isolated critic production integration until real blob/policy/signature/critic IDs are produced.

## Live Testnet Proof

- Package ID: `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`.
- Publish tx: `3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn`.
- Live object and transaction trail: `docs/ONCHAIN.md`.
- The deployment required a WorkOrder publishability refactor into nested state structs to satisfy Sui Testnet `max_fields_in_struct = 32`; `sui move build` and the full `36/36` Move test suite passed after that refactor.

## Current Agent-Security Sources

- Google Chrome agentic security architecture: Agent Origin Sets and an isolated User Alignment Critic for browser agents.
- Chrome WebMCP agent/tool security guidance: restrict cross-origin interactions, label untrusted content, use confirmations, classifiers, and critics.
- Unit42 observations: indirect prompt injection is visible in the wild, but many observed cases are still opportunistic or low-impact.
- arXiv 2606.10525: automated prompt injection is a credible but model-dependent threat in agentic environments.
- NDSS 2026 ToolHijacker: prompt injection can target tool retrieval/selection, not only final text output.
