# Formal Verification Runbook

SuiFlow includes executable tests for the load-bearing properties, plus a draft prover-spec artifact at `contracts/suiflow/specs/agent_settlement_formal_specs.move` for Sui Prover once the prover toolchain is installed.

## Local Tooling Status

Checked locally on 2026-06-16:

- `sui move --help` has no `prove` subcommand in the installed Sui CLI.
- `sui-prover`, `move-prover`, `boogie`, and `z3` were not found in the local binary paths.

## Properties To Prove

1. **Attenuation soundness**
   - A child `AgentPolicy` can only be minted if `child_actions` is a subset of the parent mask.
   - Child expiry, child payout cap, child budget, and depth are all less than or equal to parent authority.

2. **Generation revocation**
   - Registry-aware `*_live` functions abort if any ancestor generation exceeds the policy snapshot.
   - `emergency_pause` and the velocity breaker halt registry-aware drawdown paths.

3. **Escrow conservation**
   - Parent escrow is reduced when a child WorkOrder is funded.
   - Metered drawdown plus premium skim never exceeds escrow balance or policy remaining budget.

4. **Insurance claim soundness**
   - `file_claim` only pays when the `DenialReceipt` matches the vault policy and WorkOrder.
   - Payout is bounded by vault stake, coverage cap, and work-order amount.

5. **Positive attestation bond safety**
   - Bonded validations require a live validator bond.
   - A contradictory denial receipt can slash only a validator bond that previously attested to the same work order and agent.

6. **Sealed-bid auction soundness**
   - A revealed bid must match the bidder's stored commitment.
   - Awarding creates a child WorkOrder through the same attenuation checks as direct child spawning.

7. **Branch revocation soundness**
   - A branch can be bound into policy ancestry.
   - Revoking the branch bumps the branch generation so registry-aware paths reject the policy at next use.

8. **Execution binding**
   - A service nullifier can be consumed only once.
   - Execution-bound metered release requires a configured execution context and records the consumed service receipt.

9. **Privacy budget soundness**
   - Privacy receipts cannot spend more than the policy privacy budget or WorkOrder privacy budget.
   - Privacy breach claims require a matching WorkOrder/policy/vault receipt.

10. **Origin critic quarantine soundness**
   - Critic receipts cannot spend more than the policy origin-risk budget.
   - Origin/tool manifest mismatches or threshold breaches set the quarantine flag.
   - Release, split acceptance, and metered drawdowns abort while the WorkOrder is quarantined.

## Suggested Prover Commands

After installing Sui Prover/Boogie/Z3, use the command exposed by that distribution. Expected shapes:

```bash
cd /home/legat/work/hackaton/Sui-Overflow-2026/contracts/suiflow
sui move prove
```

or:

```bash
move-prover --package .
```

Until those tools are installed and a proof run is captured, do not claim machine-checked proof output in the submission. Claim the implemented invariants, the prover-spec artifact, and the `36/36` Move test coverage instead.
