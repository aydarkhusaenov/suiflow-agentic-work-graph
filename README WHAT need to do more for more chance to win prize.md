# Sui Overflow - Final Submission Checklist

This file is the live checklist for the remaining work before submission.

## Done

- Move contract for SuiFlow Agentic Work Graph.
- Recursive WorkOrders and attenuated AgentPolicies.
- GenerationRegistry subtree/branch/fleet revocation.
- Metered settlement, execution-bound nullifiers, SPILLGuard privacy budgets, Origin Critic Firewall quarantine, underwriting vaults, exposure tickets, sealed-bid child auctions, validator bonds, co-sign bonds, delivery proof release, Walrus adapter fields, Seal predicates, TEE receipt gates, denial receipts, and final receipt hashes.
- Frontend PTB builders for the full local lifecycle, including privacy, execution binding, and origin critic quarantine.
- Sui Testnet deployment is live.
- Package ID: `0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d`.
- Publish tx: `3Q6ez9cNeUDYvnCGsEsT1LMpUX43Geh229Hzkx5ecMxn`.
- Explorer package: https://suiexplorer.com/object/0x58f21090f31c0e5630f27ae0e802995cbc0c0984fb3ac8803398cfa602f1764d?network=testnet
- Live demo trail is written in `docs/ONCHAIN.md`.
- Local frontend env is set in `app/.env`.
- Public GitHub repo is live: https://github.com/aydarkhusaenov/suiflow-agentic-work-graph
- Public frontend is configured through GitHub Pages: https://aydarkhusaenov.github.io/suiflow-agentic-work-graph/
- Local verification: `sui move build` passes, `sui move test` passes 36/36, `npm run build` passes, and `npm audit --omit=dev` has 0 production vulnerabilities.

## Still Needed From User

1. Wait a few minutes if GitHub Pages is still building.
2. Record a short demo video with the app and Sui Explorer tabs visible.
3. Submit under the Agentic Web track.

## Optional Stronger Proofs

- Run Sui Prover only if the prover toolchain is installed; otherwise keep the included formal spec as a proof artifact, not a machine-checked proof claim.
- Connect real Walrus storage only if live blob/package IDs are available.
- Connect real Seal encryption/decryption only if live policy/decrypt IDs are available.
- Connect a real Nautilus/off-chain attester only if a successful signed release transaction can be shown.
- Connect a real isolated critic service only if it can produce the critic trace/evidence used in the Origin Critic Firewall demo.

## Do Not Overclaim

- Do not claim live Walrus, Seal, Nautilus, Sui Prover, or isolated critic integration until there are real successful transaction/tool outputs.
- It is correct to claim the Sui Testnet package, live demo transactions in `docs/ONCHAIN.md`, on-chain Walrus/Seal/Nautilus-compatible surfaces, frontend builders, tests, and runbooks already implemented in this repo.
