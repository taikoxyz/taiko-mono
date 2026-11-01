# Public settled EL reconstruction

This model adds a public reconstruction program and conditional success proofs for
SPEC 5.2–5.3. It does not implement or verify compression, KZG, Keccak, an EVM, or a
production reconstruction client. The 405-clause inventory remains traceability,
not complete clause verification.

## Executable boundary

`EtnaModel/Reconstruction.lean` defines `PublicBlock` as complete encoded EL header
bytes and ordered complete EIP-2718 transaction bytes. `HeaderFields` exposes only
the fields read by the checks; all remaining header bytes still reach hashing and
`executeFullBlock`. `BlockValidity.Header` and `BlockValidity.Block` are not public
payload types. No Comet header/commit, private envelope, registry/anchor/FI witness,
or L2 RPC snapshot is an algorithm input.

`Primitives` is fixed for a reconstruction. It supplies public header/blob decoding,
versioned/header/state hashes, L1 record authentication, fixed configuration/rule
version, and deterministic **full-block** EL execution. That execution contract includes
fork-dependent EIP-4788 beacon-root and EIP-2935 parent-hash pre-execution writes,
ordered transactions, and remaining EL validation/processing. It is not a transaction-only
fold. Complete state/code and full public header context are retained as byte strings.

`reconstructPublic` always calls `initializeState`, which checks the authenticated starting record, configuration/rule version,
header height/hash/root and complete state commitment. `reconstructLanding` verifies available
original version-6 material, versioned hashes and the full `(p,h]` block count. It reads
actual `c` separately from proof origin `p`, checks every overlapping public hash/link,
then calls EL execution only for `(c,h]`. The returned checkpoint carries the Comet
hash and FI cursor from the authenticated L1 record; private consensus history is
neither supplied nor reconstructed.

`recover` retains state, archive and actual execution frontier while advancing generation
and setting the fixed recovery origin to `c`. Canonical order is a transaction ordinal;
multiple recoveries may occur in the same L1 block. This is ordinary recovery.
Exceptional verifier-failure rollback requires a separately authenticated restart and
is not silently interpreted as ordinary recovery.

## Proof and trust boundary

The core theorems live in `EtnaProofs/Reconstruction.lean`:

- `overlap_backwards` derives each overlapping hash by backward induction from the
  accepted frontier hash and the previously stored public parent links. It does not
  assume whole-prefix agreement. `HeaderSeparation` excludes collisions only among
  the finite saved/incoming headers being compared; it does not assert global
  injectivity of finite-width Keccak.
- `projected_execution` constructs a successful public execution from the actual
  valid guest chain and blockwise full-EL laws. `certified_success` combines this with
  the original `land` acceptance, `BatchValid`, certificate binding and the original
  `accepted_frontier_from_valid_chain` theorem. Original committed material availability
  is a premise. Reconstruction success is a conclusion, not a certificate field.
- `certified_result` authenticates the **returned** state root and the original Inbox's
  resulting checkpoint, including EL/Comet hashes and FI cursor, and preserves the
  linked saved public history. `landing_result_checked` independently establishes
  target checks for any successful algorithm return; it is not the completeness claim.
- `certified_trace_success` composes genuine projections and authenticated ordinary
  recovery records. `certified_exactly_once` gives a duplicate-free new-height interval;
  `certified_trace_interval` shows that the whole trace appends exactly the contiguous
  interval after its starting execution frontier. Exactly-once refers to EL state
  applications, not to overlap hash-verification reads. `trace_unique` follows from
  fixed deterministic interfaces and identical public inputs.
- `initialized_stored`, `actual_recovery_projection`, and the rejection/frame theorems
  establish initialization, original recovery correspondence, and fail-closed guards.

`ProjectionLaws` and `Certification` are **proof-only**. Private batch/certificate
witnesses never enter the executable functions. The laws bind actual public header and
transaction bytes to certified private blocks, parent header encoding, and deterministic
EL results. They apply to an explicit sound guest-rules domain: arbitrary legacy
`executionValid`/`batchPayloadValid` Booleans do not imply those laws. This domain is
instantiated nonvacuously by constrained original-generation and recovery-generation
rules in the finite regression fixture.

External obligations remain canonical/finalized L1 records and authentication, complete
authenticated starting material, available original blobs, truthful canonical codecs and
versioned/hash bindings, finite compared-header collision exclusion, and actual full EL
implementation correctness. The model makes no DA availability/liveness or launch-resource
acceptance claim and adds nothing to the original seven `Premises` fields or H1–H3.

## Regression and mutation evidence

The finite fixture uses genuine accepted original guest batches at `p=0,c=0,h=2`,
then `p=0,c=2,h=4`, an actual ordinary recovery, and a genuine recovery-generation
batch at `p=4,c=4,h=6`. It instantiates every fixed projection law and invokes the
general certified trace theorem. Explicit state images include header-dependent
beacon/history effects and an ordered transaction effect. These are finite semantic
fixtures, not an EVM or wire-codec implementation.

Positive tests include competing landing frontiers, exactly-once application of heights
1–6, and two actual accepted recoveries in the same L1 block with increasing generation
and nonce. Negative tests reject unavailable originals, unsupported versions, mismatched
blob commitments, incomplete block ranges, corrupted overlap, and wrong generation/origin.

`tests/test_reconstruction.py` contains 20 focused tests, including 17 model mutations.
Each mutant first compiles the modified Model alone with empty diagnostics, then appends
the unchanged Proofs layer and requires a substantive proof error. Mutations cover
availability, version/hash/count/authentication guards, parent/overlap links, reexecuting
the full prefix, omitting the public header context, discarded result/archive updates,
wrong generation/origin, recovery-origin/generation updates, and starting/terminal roots.
The focused run passed all 20 tests. The initial RED contract failed on the absent
reconstruction witness module before implementation; final focused Lean contracts pass.

All 1,132 pre-task complete theorem contracts and the original 954 exact declaration/type
pairs are preserved; 39 contracts are appended. Source evidence adds one narrow claim
and one explicit boundary, retaining 405 clauses, three independent authority pins,
and 600 rule IDs. Normative specifications, production code, dependencies, hooks,
audit policy, original Premises and headline theorem definitions are unchanged.

Final validation on the completed change: `scripts/audit_proofs.py` audited all **1,171**
exact theorem contracts and freshly replayed all **20** Lean regression modules; all
seven original premise fields remain used. `python3 -m unittest discover -s tests`
passed **347 tests** in 376.760 seconds. The 20 focused reconstruction tests include
17 type-correct semantic mutants. Source/rule/artifact consistency checks and
`git diff --check` also pass. No audit or shadowing allowlist was expanded.
