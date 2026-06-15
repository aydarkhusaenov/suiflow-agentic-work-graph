# Research Notes

## Official Hackathon Context

- Sui Overflow 2026 runs through June 2026 with submissions due around June 20-21 depending on listing timezone. Safest working deadline: June 20, 2026.
- The official page lists core tracks including Agentic Web and DeFi & Payments.
- Core-track prizes shown on the official page: first `30,000`, second `15,000`, third `10,000`, community favorite `7,500`.
- One project can only be submitted to one track, so SuiFlow targets Agentic Web as the primary track.

Primary source:

- https://overflow.sui.io/

## Sui-Specific Product Lessons

- Sui shared objects are a natural fit for multi-party agent coordination because payer, provider, validator, and delegated agent can all touch the same work object.
- Owned objects are a natural fit for bounded agent permissions. `AgentPolicy` is intentionally an owned object, not an off-chain JWT.
- Programmable transaction blocks are the right execution surface for agent-prepared workflows: create order, upload evidence, issue policy, and settle can become composable wallet-approved steps.
- Walrus is the right place for large evidence payloads. The Move object stores blob IDs and hashes, not bulky service artifacts.
- Seal-style access control fits private delivery/dispute evidence. The object can reveal proof hashes while the encrypted material stays access-gated.
- zkLogin and sponsored transactions are strong roadmap items for non-crypto users, but the 5-day build should prioritize the object settlement core and demo.

Technical sources:

- Sui object model: https://docs.sui.io/develop/sui-architecture/object-model
- Sui programmable transaction blocks: https://docs.sui.io/develop/transactions/ptbs/prog-txn-blocks
- Sui TypeScript SDK and dApp Kit: https://docs.sui.io/guides/developer/sui-101/client-tssdk
- Walrus docs: https://docs.wal.app/

## Novel Ideas To Implement

1. Work order as a shared settlement object.
2. Agent authority as an owned object capability.
3. Cross-check `AgentPolicy.work_order_id` on every delegated action.
4. Walrus blob ID plus evidence hash as object fields.
5. Seal policy ID for private evidence envelopes.
6. Service bond inside the work object, slashable on missed deadline.
7. Split settlement for partial delivery/dispute compromise.
8. Final receipt hash composed from mandate, policy, evidence, and settlement outcome.
9. Receipt-bound feedback events.
10. Validator attestations that build a future agent reputation graph.
11. Usage-limited policies, because persistent agent authority is a major practical risk.
12. Denial receipts, because failed agent actions are negative evidence and should not live only in server logs.
13. Settlement caps for delegated split offers, because agents should not be able to negotiate arbitrary payouts.

## Build Priority

P0:

- Move package compiles. Done.
- Create work order with funded SUI escrow.
- Issue `AgentPolicy`.
- Enforce one-use/usage-limited `AgentPolicy` objects.
- Post service bond.
- Mark delivered.
- Release/refund/split-settle.
- Emit receipt and validation events.
- Scenario tests for release, delegated delivery, timeout refund, mismatched policy rejection, policy denial status, one-use policy exhaustion, and delegated settlement-cap enforcement. Done.

P1:

- Vite app with wallet connection and PTB builders.
- Demo with Sui testnet package ID.
- One Walrus CLI upload path or documented blob placeholder.

P2:

- Seal-encrypted evidence demo.
- zkLogin/sponsored transaction flow.
- Public hosted frontend.

## Current Verification

- `sui move build`: passed cleanly with Sui CLI `1.73.1`.
- `sui move test`: `8` tests passed.
- App `npm run build`: passed.
- App production audit: `npm audit --omit=dev` found `0` vulnerabilities.
- Full npm audit still reports a Vite/esbuild development-server advisory; it is not in production dependencies and should be fixed when the wallet SDK is wired with a newer Node/Vite stack.
