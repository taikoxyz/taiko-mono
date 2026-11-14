# Etna per-node L1 trust: first bounded increment

Continue `formal/etna/` on the existing local branch. Source: Etna SPEC at
`d18357214fab30ea512ae9858a11699806d72ba1`, rechecked 2026-11-14.

## Objective and chosen boundary

Explore startup/session checkpoint authentication and sign/serve gates when
nodes observe different progress on one canonical finalized L1 history. This is
the first part of worklist M02, not all anchor-validity or startup behavior.

Use a new `EtnaL1Trust.tla` and `l1-trust-*.cfg`, the existing runner unchanged.
The root chooses a small finite L1 snapshot trace rather than a full Cartesian
product with the settlement model: initial g0/c0, landing g0/c1, recovery g1/c1,
landing g1/c2. These are interface events already exercised by M01/M08, not a
claim of formal composition or a second implementation of land/recover. Include
separate canonical inclusion/finalization, provider-visible snapshot and actual
authenticated target; a provider may lag and cannot manufacture finality.

Start with exhaustive single-node cases and one small two-node case/witness.
Use finite constants and action domains, not hidden state constraints. Limit
per-node fields and configurable evidence dimensions to keep runs bounded.

## Normative obligations and explicit assumptions

- Every app startup/signer session starts untrusted (SYNC-9-4).
- A trust target comes from an authenticated snapshot in the node's own L1
  finalized view. Merely seeing included data cannot grant trust.
- Reaching a height is insufficient: exact EL, Comet and actual recorded
  current-generation validator-state identities must match (SYNC-9-5/5b/5c).
- At current generation start, the retained old validator state is not compared
  against new genesis; retain the EL and historical Comet proving boundary,
  distinct from the new chain's empty initial LastBlockID (9-5/8.4).
- Missing local evidence, lag/RPC timeout and authenticated unsupported header
  parsing are retry/upgrade pauses. Authenticated contradictions halt. Invalid
  untrusted peer inputs/import packages are not modeled as own-source evidence.
- Authenticated newer-generation observations revoke trust; startup/session
  generation mismatch halts. No further old-domain signing after supersession
  is learned (RECOV-8-14..16, 8.2-4/5). Global recovery alone is not knowledge.
- Every signature, including nil and retained-block signatures, requires current
  app trust confirmation; app-status timeout means refusal without fallback
  (SYNC-9-10/11). Serving follows app trust (9-15).
- Do not require a new L1 RPC on every vote. Own-L1 availability is distinct from
  app-status query availability. Do not invent an unspecified refresh frequency.
- Continuous-process knowledge fences only; crash durability, HRS/ABCI replay,
  supervisor reconnect/restart ordering belong to M03. No claim to verify them.
- One canonical L1 finality history, authentic proof checks and collision-free
  symbolic hashes assumed. No L1 finality violation, QC/cryptography, switching
  network start checks, anchor age, STF, queue, code refinement or liveness claim.

## Evidence

Properties must inspect trust certificates/current node state, not merely mirror
an action guard. Keep observation-only audit state for successful sign/serve
and error classification. Negative controls independently omit finality,
checkpoint components, app trust/timeout, supersession and pause/halt handling.
Positive witnesses: valid startup, missing then retry then trust, unsupported
header pause, differing legitimate node views, signing from a stale but
not-yet-superseded view, supersession revoking prior trust, and recovery-origin
validator exception. Retain a complete failing trace and explain its assumptions.

First write named configuration expectations, then implement, demonstrate
negative controls, independently challenge the assertions and run all prior
31 configurations unchanged. Record exact hashes/bounds/results and any source
ambiguities; do not modify the protocol SPEC to resolve them. Keep work local.

## Source ambiguity kept outside this increment

RECOV-8-16 says a startup/session Inbox generation different from the chain's
causes a safety halt, while RECOV-8-5/SYNC-9-2 classify own-L1 lag as a retry.
RECOV-8.2-4 requires recovery/origin authentication before new-domain signing but
does not explicitly order a pre-R view check before the generation comparison.
For a node configured for generation 1 whose provider still predates R, first
checking the fixed-origin floor is a reasonable interpretation, not a uniquely
specified rule. This increment scopes new-generation startup to snapshots at or
after its fixed origin. Pre-R startup handling remains unverified and needs a
normative ordering decision; no protocol defect is claimed from this ambiguity.
