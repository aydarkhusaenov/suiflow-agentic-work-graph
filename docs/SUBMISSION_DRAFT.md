# Sui Overflow Submission Draft

## BUIDL Name

SuiFlow Agentic Work Graph

## Primary Track

Agentic Web

## Short Description

SuiFlow is object-capability settlement for autonomous agents on Sui: funded WorkOrders, owned AgentPolicies, recursive Work Graph delegation, GenerationRegistry revocation, execution-bound metered settlement, privacy-budgeted agent traces, Origin Critic Firewall quarantine, underwriting vaults, denial receipts, exposure aggregation, sealed-bid child-task auctions, co-sign bonds, bonded validation, delivery-confirmation proofs, TEE-signed WorkReceipts, Walrus availability, Seal-style evidence gates, service bonds, refunds, split settlement, final receipts, and validator attestations.

## Vision

AI agents need more than payment triggers. They need bounded authority, recursive delegation, revocation, usage-metered payouts bound to real service execution, privacy leakage budgets, private-yet-available evidence, disputes, refunds, denial proofs, underwriting, validation, delivery confirmation, receipts, and reputation. SuiFlow enforces this with Sui shared WorkOrders and owned AgentPolicy capability objects.

## What Was Built

- Sui Move package for funded work orders and agent policy objects.
- Recursive Work Graph support: parent work orders can spawn child work orders with attenuated policies, escrow split, ancestry, root principal, and depth limits.
- `GenerationRegistry` revocation lattice with generation snapshots, subtree revocation, fleet pause/unpause, branch binding, and branch revocation.
- Sealed-bid sub-agent auction with stored commitments, reveal verification, and child WorkOrder award.
- SUI escrow, service bond, release, refund, and split-settlement paths.
- Metered settlement with usage proof hash, remaining-budget checks, optional provider cap, running paid totals, and vault premium accounting.
- Execution-bound metered settlement with service endpoint/payment intent/quote digest, service receipt hash, and one-time nullifier replay protection.
- SPILLGuard privacy budgeting with content/behavior leakage scoring, privacy receipts, breach receipts, and privacy breach vault claims.
- Origin Critic Firewall with origin/tool manifest hashes, critic policy hash, risk threshold, bounded policy risk budget, critic receipts, release quarantine, and payer-cleared resolution.
- `UnderwritingVault` with staked backing, premium accrual, capped claims, `DenialReceipt` claim flow, and validator-bond slashing.
- `ExposureAggregator` for controller-scoped exposure windows and convex premium ramping.
- Bonded validation with validator stake-derived weight, weighted validation events, and matching denial-receipt slashing.
- Cold-start co-sign bonds, abandoned-branch reaper flow, and signed delivery-confirmation release.
- One-use or usage-limited agent policies with optional settlement caps.
- Non-aborting denial receipts for invalid delegated action attempts.
- Transferable `DenialReceipt` objects for claim-backed invalid delegated attempts.
- `WorkReceipt` attestation gate with Ed25519 verification and bad-attestation denial receipts.
- Walrus availability adapter fields with certified/end epoch checks.
- Seal-style delivery, dispute, delegated-read, and timelock reveal predicates.
- BLAKE2b receipt and validator-attestation events.
- Sui wallet frontend with PTB builders for create, configure, deliver, registry revocation, branch binding, auction, metered settlement, execution binding, privacy budgets/receipts, origin firewall/critic/quarantine, vault, exposure, denial, claim, validation, co-sign, delivery proof, refund, split, and release flows.
- Agent interface for non-custodial action planning.

## Why It Is Novel

The agent does not receive broad wallet authority. It receives a Sui object capability scoped to one work order, one action set, one usage budget, one expiry, one optional maximum settlement amount, one optional evidence-read authority, one privacy budget, and one origin-risk budget. That capability can recursively spawn only attenuated child work, bid into child-task markets, and be revoked through branch/subtree/fleet generation checks. Metered payment can be bound to one service execution receipt/nullifier, privacy leakage can be scored into claimable breach receipts, and origin/tool drift can quarantine settlement until payer review. A TEE-required order cannot be released by trust; it needs a signed WorkReceipt or delivery-confirmation proof. Invalid policy or attestation attempts can still leave denial receipts, and denial receipts can feed underwriting claims and slash matching validator/co-sign capital.

## Honest Status

Implemented in Move: recursive Work Graph, GenerationRegistry revocation lattice, sealed-bid auction, execution-bound metered settlement, SPILLGuard privacy budgeting, Origin Critic Firewall quarantine, UnderwritingVault/DenialReceipt/PrivacyBreach claim paths, ExposureAggregator, bonded validation, co-sign bonds, abandoned-branch reaping, and delivery-confirmation release. Sui Testnet deployment is live. Verification: 36/36 Move tests pass; frontend production build passes; production npm audit reports 0 vulnerabilities.

Live Testnet proof: package `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`, publish tx `3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn`, and demo transaction trail in `docs/ONCHAIN.md`.

Runbook unless installed and exercised: machine-checked Sui Prover output, live Walrus storage proof, live Seal encrypt/decrypt, live Nautilus/off-chain attested release, and a live isolated critic service. A prover-spec artifact is included for the formal proof work.

## Links

- GitHub: https://github.com/aydarkhusaenov/suiflow-agentic-work-graph
- Package ID: `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`
- Package Explorer: https://suiexplorer.com/object/0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d?network=testnet
- Demo site: https://aydarkhusaenov.github.io/suiflow-agentic-work-graph/
- Video: fill after recording
