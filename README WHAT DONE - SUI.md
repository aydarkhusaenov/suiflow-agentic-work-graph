# Sui Overflow 2026 - What Done

## Workspace

- Ubuntu: `/home/legat/work/hackaton/Sui-Overflow-2026`
- Windows mirror: `C:\Users\NITRO 5\Downloads\!!!!Новая папка\!hackaton\Sui-Overflow-2026`
- Project: `SuiFlow Agentic Work Graph`
- Primary track: Agentic Web
- Deadline target: submit by June 20, 2026 to avoid timezone risk.

## Concept

SuiFlow is object-capability settlement for autonomous agents on Sui:

- funded `WorkOrder` shared objects;
- owned `AgentPolicy` capability objects;
- SUI escrow and service bonds;
- delivery/dispute evidence hashes;
- Walrus blob IDs and Seal policy IDs;
- release, timeout refund, and split-settlement paths;
- receipt, feedback, and validator-attestation events.

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
- `docs/ONCHAIN.md`

## Verification

- Sui CLI installed with `suiup`.
- Active Sui CLI used: `sui 1.73.1`.
- `sui move build`: passed.
- `sui move test`: `5` passed.
- `npm run build` in `app`: passed.
- `npm audit --omit=dev`: `0` vulnerabilities.

## Important Gaps

- Not deployed to Sui testnet yet.
- No package ID yet.
- Wallet/PTB builders are not wired yet.
- Walrus/Seal fields are in the contract, but no real blob or Seal policy has been created yet.
- Need demo video and submission.

## Next Steps

1. Add Sui wallet/PTB builders in the app.
2. Publish package to Sui testnet.
3. Run live demo transactions.
4. Fill `docs/ONCHAIN.md`.
5. Push GitHub repo.
6. Record demo video.
7. Submit to Sui Overflow under Agentic Web.
