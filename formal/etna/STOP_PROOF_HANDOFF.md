# Positive-stop / queued-proof handoff

`EtnaStopProofHandoff` is a thin, selected composition over unchanged
`EtnaCandidateHandoff` → `EtnaRulesSchedule` → `EtnaSettlement`. It executes
actual `Setup`, `PrepareCall`, `Invoke` (including `Recover`), `Hold`,
`PrepareProof(2)`, and `Land(pendingProof)` actions. It does not implement a
second acceptance or landing engine. The normative source remains SPEC commit
`d18357214fab30ea512ae9858a11699806d72ba1`.

## Added product and fixed premises

The original positive-stop programs cannot queue a proof: inherited `QueueProof`
requires `program = "HandoffRecovery"`. Their original configs and engines remain
unchanged. This companion selects only `StopDueRecovery`, `StopFutureRecovery`
and `StopOffGridRecovery` with the same public-call fixtures and retained header.

Each program seeds actual checkpoint1 (public checkpoint12 under `H(h)=6+6h`),
executes accepted Stop and Rules calls, then holds generation0 candidate
`(parentHeight18 or13, parentTime2, time3, anchor3)`. Due is stopped by the
historical schedule. Future and OffGrid initially wait for rule1 support.

After the hold, actual `PrepareProof(2)` supplies a separate, opaque,
otherwise-valid generation0 proof `(parent1, terminal2)`. **This proof is
independent of the held unlanded candidate.** In particular, the stopped Due
candidate is never claimed to have produced it. Proof validity, matching cuts,
and continued availability of the proof and retained landing reference are
fixed environment premises inherited from settlement. Its proof record has no
reference-age field: this lane measures neither retention time nor M07 resources,
real proving, STF execution or concrete anchor authentication.

## Actual action chronology and independent receipts

1. `stopProofCalls` appends the raw receipt from each actual public `InvokeStep`.
   All three selected calls must be accepted.
2. `StopProofQueueOld` calls unchanged `PrepareProof(2)` once and captures its
   resulting raw proof, frontier, generation, origin, landing prefix and held
   history in immutable `stopProofQueue`.
3. `StopProofObservePre` records actual `ENABLED Land(pendingProof)` in
   `stopProofPre` before preparing Recover. It must be TRUE. The proof remains
   queued; no pre-recovery landing is executed.
4. Actual public Recover increments generation/nonce to1, preserves checkpoint1
   and the landing prefix, sets origin1/public12, clears the current stop and
   appends history entry4. The old candidate and proof retain generation0.
5. `StopProofAttemptOld` records actual post-recovery enabledness and executes
   **that same inherited `Land(pendingProof)` iff it is enabled**. Otherwise it
   frames settlement variables. Expected rejection appears only in independent
   audits and witnesses, never in its action guard. `stopProofAttempt` captures
   complete raw settlement before/after states, including the live reference.
   The inherited `proofReceipt` receives the same observation.
6. Existing support installation remains independently available as soon as the
   candidate is held, including before public recovery. This preserves the
   pre-recovery eligibility seam for a composed signer. The authenticated-knowledge
   abstraction, retained retries, authorization observations and exact fresh-candidate
   observation execute after the proof attempt. Both support-before-knowledge and
   knowledge-before-support remain possible. A terminal receipt records actual inputs and results after their
   workflow milestones, without guarding on expected refusal or historical outcome.

`StopProofGenerationAudit` independently requires the attempted proof's literal
old generation0/current generation1 observation to be disabled. Other new audits
check immutable proof identity, pre-recovery enabledness, raw public receipts,
retained reference/prefix and framed refusal. Normal profiles also retain all
inherited positive-stop normal audits, including historical derivation, current
stop clearing, public writes, fresh identity and proof/signature fences.

## Finite profiles and non-vacuity controls

Bounds are checkpoint heights0..2, generations0..1, nonce0..2 and time0..6,
with one selected public program per config. There are three normal safety
profiles, six full terminal witnesses (both knowledge/support orders for each
program), and one focused generation-audit profile. Each support-first witness
also requires support installed at index2, before recovery; knowledge-first
requires installation after the learned floor reaches1. Every terminal witness
requires the complete raw queue, pre-enabled receipt, all three accepted calls,
actual attempted refusal, unchanged retained reference/prefix, historical retry,
revoked old authorization, support/knowledge order and fresh generation1 candidate
`(parent12,time1; time3,anchor4)`. Due must still report Stop; Future and OffGrid
must report Accept for the held historical candidate after support.

Witnesses intentionally violate exactly `StopProofSupportFirstNotReached` or
`StopProofKnowledgeFirstNotReached`. These are existential finite reachability
certificates, not eventual-progress claims. Normal safety profiles must exhaust
with queue0. The focused source-fault profile selects only
`StopProofGenerationAudit`; removing solely the actual settlement generation
conjunct then executes the bad old-proof landing and must violate that exact
new audit. A different inherited public-state violation is not accepted as this
control's result.

Omitted-queue and omitted-attempt controls must instead **lose the required
terminal witness**: the checker exhausts with no invariant violation and rejects
the config's required witness outcome. They are missing-reachability controls,
not safety kills or additions to the assessed mutation denominator. Their
baseline, source-disabled and actual same-copy restored runs retain exact
source maps and raw logs. No parse, incomplete action, setup, timeout or
wrong-invariant result is credited.

## Composition interface and remaining scope

`StopProofVars`, `StopProofInit` and `StopProofNext` are stable composition entry
points. `StopProofLocal` frames the added receipt variables.
`stopProofQueue`, `stopProofPre`, `stopProofAttempt`, `stopProofCalls` and
`stopProofTerminal` are immutable once present (the call sequence only appends).
`StopProofTerminalComplete` checks the terminal's raw contents; the two order
witnesses add independent ordering observations. A consumer must frame any
additional state around `StopProofNext` and frame `StopProofVars` around its own
actions. It must not replace actual signer or settlement actions with these
receipts.

The new assessed obligation is specifically this selected positive-stop/old-proof
product's generation binding. Broader `handoff-positive-stop-composition` and
other unassessed inventory categories remain open. This lane does not establish
an actual M03 signer, crash/restart behavior, authenticated concrete L1 recovery,
M07-produced proof, runtime retention, full replay or complete protocol liveness.
