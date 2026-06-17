# Novelty And Scorecard Fit

## Primary Track

SuiFlow targets the Sui Overflow 2026 Agentic Web track.

The core pitch: autonomous agents should not receive broad wallet authority. They should receive explicit Sui object capabilities that are scoped to one work order, one action set, one usage budget, one expiry, one settlement cap, one evidence-read authority, one privacy budget, one origin/tool risk budget, and an attenuated place in a recursive Work Graph. Release can be upgraded from trust to a signed WorkReceipt or delivery-confirmation proof over BCS-pinned fields, while revocation, execution-bound metering, privacy leakage budgeting, origin critic quarantine, underwriting, exposure pricing, co-signing, auctions, and bonded validation stay on-chain.

## What Is New

### 1. One-Use Object Capabilities For Agents

Most agent-payment demos treat the agent as a signer, relayer, or off-chain policy engine. SuiFlow represents delegated authority as an owned `AgentPolicy` object. The policy is checked on-chain against:

- work-order ID;
- agent address;
- action bitmask;
- expiry timestamp;
- usage limit;
- settlement amount cap.

### 2. Recursive Work Graph

SuiFlow can spawn a child `WorkOrder` from a parent `WorkOrder` through a parent `AgentPolicy`. The child receives split escrow, an attenuated child policy, inherited root principal and safety fields, parent/child object links, and a depth cap. This is more Sui-native than a flat task list because every delegated branch is an object with bounded funds and capability ancestry.

### 3. GenerationRegistry Revocation Lattice

The `GenerationRegistry` tracks policy generations and root owners. Policies store ancestor IDs and a generation snapshot. Registry-aware delegated calls fail if any ancestor generation has moved past the snapshot or if the registry is paused. Branch IDs can be bound into policy ancestry, so branch revocation is enforced by the same generation check. That gives the demo a concrete branch/subtree/fleet revocation story instead of a purely off-chain allowlist.

### 4. Origin Critic Firewall

SuiFlow adds an Origin Critic Firewall: each WorkOrder can pin an origin manifest, tool manifest, critic policy hash, and risk threshold. A delegated policy can receive a bounded origin-risk budget and submit `OriginCriticReceipt` objects that bind observed origin, observed tool, user intent, tool call, risk score, trace root, and evidence hash. If the observed origin/tool differs from the manifest or the cumulative risk reaches the threshold, the WorkOrder is quarantined and release, split acceptance, and metered drawdowns are blocked until the payer clears the quarantine with a resolution hash.

This translates current browser-agent safety guidance into Sui object state: the planner can propose work, but settlement authority is gated by origin/tool manifests and a separate critic receipt path. The isolated critic service itself is off-chain/runbook unless connected live; the on-chain manifest, budget, receipt, quarantine, and resolution gates are implemented.

### 5. Metered Settlement

`ACTION_METER_RELEASE` lets an agent release escrow by verified usage units. The contract checks registry liveness, remaining policy budget, escrow balance, optional provider cap, usage proof hash, and running totals. This supports services that should be paid incrementally instead of through one final release.

### 6. Execution-Bound Metering

SuiFlow adds an `ExecutionBindingRegistry` and one-time nullifiers so a metered payment can be tied to a specific service endpoint, payment intent, quote, and service receipt. This targets a live agent-commerce problem: payment protocols can prove money moved, while service APIs still need a replay-resistant binding between execution and settlement.

### 7. SPILLGuard Privacy Budgeting

Agent systems leak through behavior traces as well as content. SuiFlow lets a WorkOrder define a privacy manifest and budget, lets an agent policy spend that budget through weighted content/behavior leakage receipts, and turns over-budget leakage into a `PrivacyBreachReceipt` claim against underwriting backing. This makes privacy leakage auditable and economically backed instead of a vague off-chain policy.

### 8. UnderwritingVault, DenialReceipt, And ExposureAggregator

Invalid delegated attempts can mint transferable `DenialReceipt` objects. A matching `UnderwritingVault` can accept staked backing, collect premiums from metered release, cap claims, pay the payer on receipt-backed claims, and receive slashed validator or co-sign bonds. `ExposureAggregator` records controller-window exposure and returns convex premium-priced tickets, turning risk into an auditable on-chain primitive.

### 9. Bonded Validation

Validators can post a `ValidatorBondCap`, receive stake-derived weight, and submit bonded validation events. A validator can be slashed into the underwriting vault only when the denial receipt matches the same work order and agent the bond attested.

### 10. Sealed-Bid Agent Labor Market

Parents can create sealed-bid child-task markets. Bidders submit stored commitments, reveals must match the commitment hash, and the winning bid is awarded through the same `spawn_child_work_order` attenuation path. The result is a private agent labor market that still preserves Work Graph authority bounds.

### 11. Co-signing, Reaping, And Delivery Confirmation

SuiFlow adds cold-start co-sign bonds for new agents, abandoned-branch reaping to recover stranded capital, and delivery-confirmation release that binds expected output, proof-chain root, signer key, and signature before settlement.

### 12. Denial Receipts

Real agent systems need negative evidence, not only successful receipts. SuiFlow exposes `policy_status` for non-aborting checks, `record_policy_denial` for event-level failed attempts, and `record_policy_denial_receipt` for transferable claim evidence. A judge can see that a policy for work order `A` cannot act on work order `B`, and that the failed attempt can still leave a verifiable record.

### 13. Digest-Bound Settlement Receipts

Final receipts are BLAKE2b digests over the work-order ID, parties, amount, state, settlement amount, mandate/policy hashes, evidence hashes, Walrus blob ID, Seal policy ID, TEE settings, delivered output, Walrus retention, metered paid total, premium paid total, recursive work fields, delivery commitments, proof-chain roots, privacy budgets/traces, execution receipts, origin/tool manifests, critic policy, critic risk, quarantine flag, and critic trace root. This makes the receipt portable for feedback, validator attestations, and future reputation systems.

### 14. Attestation-Gated Release

TEE-required orders reject plain release. They require an Ed25519-signed `WorkReceipt` that binds the order ID, agent, input hash, output hash, model PCR, delivered state, and timestamp. Bad signatures or mismatched fields can produce `AttestationDenialRecorded` events.

### 15. Evidence Privacy + Availability Path

The Move object keeps lightweight anchors:

- `walrus_blob_id` for large delivery or dispute evidence;
- `seal_policy_id` for encrypted/private evidence access;
- evidence hashes for verification.
- required and verified Walrus retention epochs;
- WorkOrder-derived Seal identities for delivery, dispute, delegated read, and timelock reveal.

This lets the demo tell a credible story about verifiable evidence without exposing sensitive work artifacts directly on-chain.

## Why It Fits Sui

- Shared objects: the work order is touched by payer, provider, agent, and validator.
- Owned objects: agent authority is an owned capability, not a server session.
- Object composition: recursive work orders and policy ancestry make delegation inspectable as Sui object graph state.
- PTBs: the frontend now builds wallet-approved transaction blocks for the lifecycle.
- Low-latency object settlement: small work-order actions are practical on Sui.

## Demo Moment To Prioritize

1. Create a `GenerationRegistry`, funded root WorkOrder, and first owned `AgentPolicy`.
2. Spawn a child WorkOrder/AgentPolicy from the parent to show recursive Work Graph attenuation.
3. Revoke or pause through the registry to show descendant liveness checks.
4. Configure TEE expectations and Walrus retention.
5. Create execution registry/context and run execution-bound metering with a one-time nullifier.
6. Configure privacy budget, record a weighted privacy receipt, then show a privacy breach receipt and claim.
7. Configure Origin Critic Firewall, submit a safe critic receipt, then submit mismatched-origin/tool evidence to quarantine release until payer review.
8. Record exposure, create/stake an `UnderwritingVault`, then run a metered release.
9. Try a bad policy and mint a transferable `DenialReceipt`; file a vault claim from it.
10. Create a sealed-bid child-task market and award the child policy.
11. Create a validator bond, submit bonded validation, and slash only against a matching denial receipt.
12. Co-sign a new policy and show sponsor first-loss capital.
13. Try a bad delivery proof or bad attestation signature and record the rejection/denial.
14. Use Seal read approval to show evidence access is policy/state gated.
15. Finalize and show the digest-bound receipt.

That is stronger than a normal escrow demo because it proves safe autonomy, failure auditability, and Sui object-capability design in one sequence.

## Honest Integration Status

The Move implementation includes the Round 2/3 object surfaces and event flows above, with 36/36 Move tests passing locally and a live Sui Testnet deployment at `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`. A formal spec artifact is included for Sui Prover, but machine-checked Sui Prover output, live Walrus blob verification, live Seal encryption/decryption, live Nautilus/off-chain attestation, and a live isolated critic service are not claimed unless those tools/services are installed, configured, and exercised against the published package.

## Sources

- Sui Overflow: https://overflow.sui.io/
- Sui object model: https://docs.sui.io/develop/sui-architecture/object-model
- Programmable transaction blocks: https://docs.sui.io/develop/transactions/ptbs/prog-txn-blocks
- Sui TypeScript SDK: https://docs.sui.io/guides/developer/sui-101/client-tssdk
- Walrus docs: https://docs.wal.app/
- Sui Nitro attestation framework: https://docs.sui.io/references/framework/sui_sui/nitro_attestation
- Seal programmable access control: https://blog.sui.io/seal-programmable-access-control/
- Object-capability security survey: https://arxiv.org/abs/1907.07154
- Capability Myths Demolished: https://papers.agoric.com/assets/pdf/papers/capability-myths-demolished.pdf
- SPILLage web-agent privacy leakage: https://arxiv.org/abs/2602.01127
- x402 attack surfaces: https://arxiv.org/abs/2601.12336
- A402 binding payments to service execution: https://arxiv.org/abs/2603.01179
- Hardened x402 firewall research: https://arxiv.org/abs/2604.07712
- Google Chrome agentic security architecture: https://blog.google/security/architecting-security-for-agentic/
- Chrome WebMCP agent security guidance: https://developer.chrome.com/docs/agents/security
- Chrome WebMCP tool security guidance: https://developer.chrome.com/docs/ai/webmcp/secure-tools
- Unit42 indirect prompt injection observations: https://unit42.paloaltonetworks.com/ai-agent-prompt-injection/
- Automated prompt injection in agentic environments: https://arxiv.org/abs/2606.10525
- NDSS 2026 prompt injection to tool selection: https://www.ndss-symposium.org/ndss-paper/prompt-injection-attack-to-tool-selection-in-llm-agents/
