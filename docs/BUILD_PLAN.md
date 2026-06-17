# Build Plan

## Current Done

- Current Move tests cover funded order, policy constraints, delivery, release, refund, split settlement, denial receipts, BCS receipt layout, Walrus availability checks, Seal predicates, timelock reveal, attestation-denial paths, recursive Work Graph attenuation, generation revocation, sealed-bid auction award, branch revoke, metered vault release, execution nullifier replay rejection, privacy weighted scoring, privacy breach claims, origin critic quarantine, exposure pricing, underwriting claim, co-sign slashing, delivery-proof rejection, and bonded validator slashing.
- Current verification: `sui move build` passes, `sui move test` passes 36/36, `npm run build` passes, and `npm audit --omit=dev` reports 0 production vulnerabilities.
- Sui Testnet package is deployed at `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`.
- Live demo transaction/object trail is recorded in `docs/ONCHAIN.md`.
- Combined `create_work_order_with_policy` supports create+fund+policy in one PTB.
- Round 2 recursive Work Graph surface is implemented in Move: `spawn_child_work_order`, parent/child object links, budget split, inherited safety fields, ancestry, depth cap, and `SubDelegation`.
- Round 2 revocation surface is implemented in Move: `GenerationRegistry`, generation snapshots, subtree revocation, fleet pause/unpause, branch binding/revocation, and registry-aware delegated checks.
- Round 3 settlement/risk surface is implemented in Move: metered release, execution-bound metering, SPILLGuard privacy budgeting, Origin Critic Firewall, `UnderwritingVault`, transferable `DenialReceipt`, `PrivacyBreachReceipt`, and `OriginCriticReceipt`, convex `ExposureAggregator`, vault claims, validator bond caps, bonded validation, constrained validator-bond slashing, co-sign bonds, reaper GC, and delivery-confirmation release.
- Sui Prover spec artifact exists, but Sui Prover and live Walrus/Seal/Nautilus/isolated-critic checks are not claimed unless installed and run; keep them in the runbook until then.

## Deploy Day - Done

1. Published to Sui Testnet.
2. Added the package ID to `app/.env` as `VITE_SUIFLOW_PACKAGE_ID=0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`.
3. Ran a compact live sequence covering registry creation, WorkOrder/AgentPolicy creation, execution binding, privacy budget, Origin Critic Firewall, metered release, Walrus availability adapter, agent delivery, and final release.
4. Recorded package/object/transaction IDs in `docs/ONCHAIN.md`.
5. Optional broader Round 2/3 on-chain sequence to run only if extra demo time remains:
   - `create_generation_registry`
   - `register_policy_generation`
   - `spawn_child_work_order`
   - `revoke_subtree` or `emergency_pause`/`emergency_unpause`
   - `create_caretaker`, `bind_policy_branch`, `revoke_branch`
   - `create_bid_market`, `submit_sealed_bid`, `open_bid`, `award_bid_child_work_order`
   - `create_exposure_aggregator`
   - `record_exposure`
   - `create_execution_binding_registry`
   - `configure_execution_context`
   - `meter_release_with_execution_binding`
   - `configure_privacy_budget`
   - `allocate_policy_privacy_budget`
   - `record_privacy_receipt`
   - `record_privacy_breach_receipt`
   - `file_privacy_claim`
   - `configure_origin_firewall`
   - `allocate_policy_origin_risk_budget`
   - `record_origin_critic_receipt`
   - `clear_origin_quarantine`
   - `create_underwriting_vault`
   - `stake_backing`
   - `meter_release_with_vault`
   - `record_policy_denial_receipt`
   - `file_claim`
   - `create_validator_bond`
   - `submit_bonded_validation`
   - `slash_validator_to_vault`
   - `cosign`, `slash_cosign_to_vault`, `configure_delivery_confirmation`
6. Record the demo video with Sui Explorer tabs visible.

## Submission Day

1. Wait a few minutes if GitHub Pages is still building.
2. Record the demo video with Sui Explorer tabs visible.
3. Submit under Agentic Web.
4. Mention Walrus/Seal/Nautilus as implemented contract surfaces and be precise about which live services were exercised.
5. Mention Sui Prover only if it was installed and run; otherwise describe formal verification as planned/runbook work.

## Highest-ROI Demo

1. Create funded WorkOrder and first AgentPolicy in one PTB.
2. Create GenerationRegistry and register the root policy generation.
3. Spawn a child WorkOrder with attenuated policy and show the parent/child graph.
4. Bind a branch, revoke that branch, then revoke a subtree or pause/unpause the registry to show the revocation lattice.
5. Configure TEE expectations and require Walrus retention.
6. Provider posts service bond.
7. Create/stake UnderwritingVault and record exposure.
8. Agent marks delivery with Walrus availability fields.
9. Run metered settlement with a usage proof hash and vault premium.
10. Create a sealed-bid market, submit/open a bid, and award a child WorkOrder.
11. Record a policy DenialReceipt and file a vault claim.
12. Create validator bond, submit bonded validation, and slash only against a matching denial receipt.
13. Co-sign a new policy and show sponsor slash/release paths.
14. Configure delivery confirmation and show bad proof rejection or signed proof release when a signer is available.
15. Record a bad attestation denial receipt.
16. Configure Origin Critic Firewall manifests, submit a safe critic receipt, then submit mismatched-origin/tool evidence and show release quarantined until payer review.
17. Use Seal approval/timelock predicate in the story.
18. Finalize with release, refund, or split settlement.

## User Inputs Needed Later

- Optional Walrus/Seal CLI setup if we include live storage proof.
- Optional Nautilus/off-chain Ed25519 signer for a successful live attested release.
- Optional isolated critic service for a live off-chain critic receipt story.
- Optional Sui Prover setup if we include formal verification output.
