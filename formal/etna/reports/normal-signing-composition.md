# Normal rotation, recovery and current signing

> **Historical report.** This document describes the original model and the baseline identified below. Any use of “current” refers to that historical baseline. For the current `Etna.Design.Current` claims and evidence, read the [current scope](../README.md) and [latest alignment](latest-design-alignment.md).

This extension connects ordinary protocol history to an actual fresh signing event without
changing H1-H3, their seven premises or a production rule. Its assumptions are classified in
[premise responsibilities](premise-responsibilities.md).

## General theorems

`EtnaModel/NormalSigning.lean` defines `Run` and `ConfirmationSource` using the original
operations. `Run`'s landings add actual batch/construction/snapshot provenance and the existing
reference bound. Other steps are original non-advancing `OrdinaryStep`s, so registration,
request/confirm/withdraw, top-up/activation, slash/forfeit, FI enqueue/sweep, nonce invalidation
and normal recovery remain available. Operation identity is preserved even when two different
operations can have identical output states. "Normal" means only "without verifier-failure
rollback": a recovery here is any accepted `recover` call, including one whose reselection a late
registration captured (`RecoveryCapture`).

`EtnaProofs/NormalSigning.lean` proves:

- `run_ordinary`, `run_trace`: projection into the original ordinary and full machines.
- `landing_snapshot_monotone`, `run_snapshot_trace`, `run_covered`: accepted provenance derives
  monotone snapshots and retained confirmation coverage along the complete normal run. Coverage
  is no longer a final-state assumption of the composed result.
- `run_snapshot_below`: if the first World's snapshot is below its L1 clock, every later stored
  snapshot stays strictly below the current L1 clock. Normal recovery may execute in the same L1 block as a prior
  transaction; no strict confirmation-to-recovery block gap is imposed.
- `recovery_snapshot_source`: every successful normal recovery has a stored-snapshot source,
  including before the first landing, with its clock bound derived from the preceding run.
- `source_ordinary`, `source_retains_checkpoint`: both same-replay and actual-recovery sources
  give original ordinary causality and preserve the old complete checkpoint record.
- `confirmation_source_bound`: the current next-height selector covers the confirmation's
  snapshot. Same-generation inclusion uses replay; recovery uses its actual R, original clock
  ordering and the built context's generation/origin. No selected-cutoff inequality is an input;
  a trusted prefix whose snapshot source is `normalRecovery` carries that constructor's numeric
  bound (below).
- `confirmed_key_excluded`: lifetime historical exclusion survives withdrawals, slot reuse and
  later original ordinary operations, and applies to the actual request committee.
- `fresh_signing_connection`: the old checkpoint stays retained; a successful fresh call is
  bound to tip + 1, exact decoded message/signature/log, and a different lifetime key.
- `initialized_fresh_signing_connection`: genuine `Deployment.Genesis` supplies core and the
  initial clock bound. Initial lifetime keys, exit-history visibility and absence of
  confirmations remain explicit additional initial-state contracts.

The new `SnapshotSource.normalRecovery` constructor retains the actual successful recovery
and state/context bindings. The existing `SigningBridge.source_snapshot_bound` proves its
selector consequence, which reads only the clock, time order, kept snapshot, generation and
origin fields: `s.snapshot < ctx.originBlock` one generation above `before`. The recovery call
and kept checkpoint name the provenance, but no bound reads them, and `before` is not tied to a
trace, so the constructor is that numeric bound with recovery provenance attached.
`recovery_snapshot_source` derives it for an actual recovery at the end of a normal run. Existing source constructors, same-generation bridge and headline
statement types remain unchanged.

## Initialized non-vacuity witness

`EtnaWitnesses/Regressions/NormalSigning.lean` starts from the genuine initialized
`NonVacuity.world0`, rather than a fabricated final World:

1. Register standby key 8, request key 7's exit, and execute the existing valid twelve-block
   ordinary rotation/landing. Confirm key 7 at L1 29, checkpoint 12, snapshot 24.
2. Withdraw key 7's full remaining principal at L1 30 after the fixture's full one-block delay.
3. Execute a valid authenticated decoded two-block suffix and accepted landing at L1 35,
   advancing to checkpoint 14. Its source transports the actual older landing across an archive
   extension and registry withdrawal, with no assumed snapshot monotonicity.
4. Execute real normal recovery at R = L1 40 from checkpoint 14, creating generation 1.
5. Replay a valid local extension through height 22, including the S(2)=19 announcement and
   H+2 activation at height 21. The active cutoff advances from 40 to 43.
6. Reuse released slot 0 for lifetime key 9 at L1 48, after both selection cutoffs; the historical
   committees stay key 8. A separate nonce invalidation succeeds in that same L1 block.
7. Carry key 8's previous actual signer log into an authenticated generation switch/session,
   then actually sign height 23 in generation 1. All three phases and nil/non-nil messages are
   covered. The general initialized theorem excludes key 7, and a key-7 EngineRequest fails.

The old confirmation checkpoint 12 is strictly below origin 14 and cannot appear in this new
origin's replay. Its complete retained record and the actual recovery path supply the new
connection. A separate initialized witness recovers before **any** landing and derives a source
for unchanged snapshot 12 under recovery floor 20.

These are decoded fixtures: the one-member committees and short withdrawal delay are not
production launch/concentration acceptance; crypto, EL, L1/MPT and request adapters remain
explicit. The tests demonstrate inhabitation and binding, not production correctness.

## Limits and validation

No theorem lifts a headline `Run`, sound or not, to `NormalSigning.Run`. Under `Premises`, a
submitted landing supplies `built`, `valid` and `binding` (`submitted_landing_certified`), but
each landing's prior-snapshot source and reference bound, and the absence of rollback, are
separate contracts; the regression fixtures are the only runs built here. No fixture lands after
its recovery: `normalRecovery` is built but no run or trusted prefix consumes it.
Actual landing provenance, archive authentication, initial key/history conditions and per-call
producer/key/persistence behavior must be supplied by the implementation. The view must cover
the particular confirmation; global catch-up/freshness, exceptional rollback, upstream Comet
locking, continuous collateral and timely evidence/governance remain outside this extension.

The new Python kernel mutations delete actual recovery calls, time order, origin/generation
bindings, causal paths, prior landing sources, reference bounds and recovery snapshot/clock
bindings. Each must break a real theorem while retaining syntactically valid Lean; the unchanged
combined module must compile silently. Existing signer mutations continue checking message,
height, membership, checkpoint hashes and archive binding. Final measured build/audit/test
counts are recorded in the package README and PR description.
