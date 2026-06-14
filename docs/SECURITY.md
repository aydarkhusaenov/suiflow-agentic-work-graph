# Security Notes

## Core Security Model

- Agent authority is object-bound. Delegated actions require an `AgentPolicy` object.
- Every `AgentPolicy` is scoped to one `WorkOrder` through `work_order_id`.
- Policies include exact allowed-action bitmasks and expiry timestamps.
- A provider can post a service bond; missed-deadline refunds can slash that bond to the payer.
- Final settlement moves escrow and bond balances out of the shared object, leaving no stranded active funds in finalized paths.

## Tested Security Properties

- Clean release path returns escrow and service bond correctly.
- Agent delivery requires a matching `AgentPolicy`.
- A policy scoped to work order `A` cannot mutate work order `B`.
- Timeout refund works after the deadline and slashes the service bond.

## Known Gaps Before Submission

- Add more scenario tests for split settlement and validator attestations.
- Add frontend PTB builders after the package ID is published.
- Add live Sui testnet transaction proof.
- Upgrade frontend dev tooling when wiring real Sui wallet SDKs; production audit is clean, but full dev audit flags Vite/esbuild.
- Do not claim live Walrus or Seal integration until real blob/policy IDs are produced.
