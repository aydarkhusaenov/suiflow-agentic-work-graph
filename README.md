# SuiFlow Agentic Work Graph

SuiFlow is an Agentic Web project for Sui Overflow 2026. It turns autonomous-agent work into Sui-native settlement objects: funded work orders, bounded agent capabilities, Walrus evidence pointers, service bonds, timeout refunds, split settlement, receipt hashes, and validator attestations.

The core idea is simple: an agent should not be trusted with broad wallet authority. It should receive a narrow Sui object capability that lets it perform one settlement action on one work order, with an expiry, policy hash, and on-chain audit trail.

## Hackathon Fit

- Event: Sui Overflow 2026
- Primary track: Agentic Web
- Secondary fit: DeFi & Payments, Walrus, Payments & Wallets
- Chain target: Sui Testnet
- Core contract: `suiflow::agent_settlement`
- Frontend: TypeScript app shell prepared for Sui wallet and PTB flows

## Why This Is Sui-Native

- Each work engagement is a shared Sui object, not only a database row.
- Agent authority is represented as an owned `AgentPolicy` object with one-order, one-action-surface limits.
- Escrow and service bonds are held as `Balance<SUI>` inside the work object.
- Evidence and receipts are object fields that can point to Walrus blobs and Seal-encrypted evidence envelopes.
- Final settlement emits events for receipt, feedback, and validator-attestation indexing.

## Current Workspace

```text
contracts/suiflow/       Move package
app/                     frontend/agent UI shell
agent/                   agent skill and policy interface notes
docs/                    research, product, submission, and build plan
scripts/                 helper scripts
assets/                  logo/screenshots/video assets
```

## Immediate Commands

```bash
export PATH="$HOME/.suiup/bin:$HOME/.local/bin:$PATH"
cd /home/legat/work/hackaton/Sui-Overflow-2026/contracts/suiflow
sui move build
```

## Project Thesis

The winning angle is not "escrow on another chain." The winning angle is object-capability commerce for agents:

1. A human or AI agent creates a funded Sui work order.
2. A provider posts a service bond.
3. A bounded agent policy object grants exact action authority.
4. Delivery/dispute evidence is stored as Walrus/Seal references.
5. Settlement produces a portable receipt hash.
6. Review and validation events turn final receipts into an agent reputation graph.

## Submission Links To Fill

- GitHub: fill after repo creation/push
- Sui package ID: fill after testnet publish
- Demo site: fill after deployment
- Demo video: fill after recording
- X/social proof: fill after posting
