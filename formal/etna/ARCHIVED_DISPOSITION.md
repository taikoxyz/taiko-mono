# X01 archived Etna search dispositions

The 19 configurations under [experiments](experiments/) remain **INCONCLUSIVE**.
The [disposition manifest](archived_disposition.json) records each config's
SHA-256, the associated historical source paths and byte pins, the observation
record, the unexhausted product, and selected current evidence. The timeout notes
contain periodic progress counts. Completion requires a terminal result, which
these runs did not record. An old `EXPECT: PASS` header names an expected
outcome only.

X01 covers acceptance of the dispositions. The larger
[WORKLIST obligations](WORKLIST.md#remaining-obligations) retain their own
acceptance criteria. C01, R01 and P01 remain OPEN. F01 and Q02 remain WAITING
on their implementation boundaries. This audit reads sources and existing
receipts and adds no execution or graph-exhaustion evidence.

## Reading and checking the archive

The inventory rule is every `.cfg` recursively below `experiments/`, the
archive boundary outside the default suite. Match the config's `MODULE` comment
to the module beside it or beside its `configs/` directory, then read the
associated observation. Follow the local `EXTENDS EtnaSettlement` for every FI
row and the rollback row. FI uses
[its shared archive dependency](experiments/fi-base/EtnaSettlement.tla);
rollback uses [its sibling dependency](experiments/m09-wide-runtime/EtnaSettlement.tla).
These paths and the [current root base](EtnaSettlement.tla) share the
SHA-256 `3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a`.
The audited wrapper and assertion changes distinguish the historical FI and
rollback semantics. The distinct dependency paths preserve each archive's
documented source layout.

The signer rows use the
[progress note](experiments/signer-wide-progress.txt). It attests the
predecessor SHA-256
`7c86c43e5d10a64cf101d3c61d6ed47d7ec0212c7c59ae11266bd8ff12b957cf`.
The available [parameterized model](EtnaSignerCrash.tla) is byte-verified as
`c948786960d3dd5af381c653f3c0c28795291b19d3b96e660efa8825f6d93c4a`.
The note says the predecessor held salts fixed to `0..1`. The two retained
configs explicitly declare that same domain. The predecessor digest is an
attestation for the observed runs and the parameterized digest identifies the
local reproduction source. The historical notes for the two signer configs
and rollback Replay lack config-digest claims. The checker pins their exact
retained paths and SHA-256 values from the audited checkout. Those are retained
file identities. The signer note attests only the predecessor module identity
for the incomplete runs.

Run the local checker from the repository root.

```sh
python3 -B formal/etna/check_archived_disposition.py
python3 -B -m unittest discover -s formal/etna/tests -p test_archived_disposition.py
```

The checker discovers the configs in a source export and checks exact layout,
family counts, one guide link per config, and source paths and hashes. It
byte-verifies the historical observation files, including the
[FI dependency note](experiments/fi-base/OBSERVATION.md), so their labels and
per-profile results retain their audited meaning. Historical config digests
recorded in those notes corroborate the remaining 16 config identities. The
checker validates current evidence links and named obligation statuses without
pinning the shared report or worklist bytes. Row interpretations require
source-semantic review.

## Signer · C01

Read `Request`, `Persist`, `Expose`, `Deliver`, `Crash` and `Restart` in
`EtnaSignerCrash`, then compare the invariant list in each config. Slots
abstract lexicographic HRS ranks. Distinct salts distinguish reuse of the
exact written bytes from fresh computation. `Expose` is the actual external
return/enqueue boundary and `Deliver` may legally deliver already enqueued old
bytes after recovery. Trust authentication, reconnect and a completed durable
generation-floor update are explicit model premises, along with one serialized
state owner and process-crash durability.

| Archived config                                              | Unexhausted dimension                                                                                                                                                                                                     | Selected counterpart                                                                                                                          |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| [Two payloads](experiments/signer-wide-two-payloads.cfg)     | The joint product of A/B across both domains and ranks 1/2, both salts, before/after-persist crash, live recovery, uncertainty and delivery. Monotone HRS, same-rank uniqueness and exact saved bytes must hold together. | M03 separates rank depth from salt breadth. G05 selects three recovery-composition cases. J04 uses A/B in fixed call positions alongside Nil. |
| [Three payloads](experiments/signer-wide-three-payloads.cfg) | The same product adds arbitrary Nil/value choices, same-rank Nil/value conflict and retained Nil bytes under delayed delivery.                                                                                            | J04 exercises eight literal histories with old rank-1 Nil, old rank-2 B and new rank-1 A, crossing first crash cut, salt and delivery timing. |

[M03](CRASH_RECOVERY.md#checked-signer-profiles-and-incomplete-wider-experiments)
uses A/B with salt 0 at two ranks and A/B/Nil with both salts at one rank.
[G05](REPORT.md#coverage-closure-batch--g05-actual-signer-composition) composes the
real symbolic signer with selected positive-stop and recovery schedules.
[J04](SIGNER_NIL_REPLAY.md) demands the actual record captured before a persisted
crash, including exact retry and independent request identity.
[N01](conformance/COMET_SIGNED.md#expected-native-behavior) verifies selected
stock signed-vote admission, conflict, Nil/non-Nil power, threshold and POL
behavior with public signatures and synthetic weighted profiles. The
[input-binding correction](REPORT.md#n01-feedback-repair-bind-actual-native-inputs)
ties the accepted receipts to native input bytes. C01 retains wider ordering,
durable floor, lost-HRS refusal and concrete WAL/supervisor/authenticated
restart and retry behavior.

## Registry · R01

The cfgs bind slots, issued IDs, clock, amounts and top-up call count. Compare
`Init` and `Next` or `SetupNext` in the archived modules. Then read `Tick`,
`SelectSnapshot`, `Register` and `Withdraw` beside the observer assertions.
The distinction between anticipated after-state and observed primed state is
material to checking a refusal or withdrawal.

| Archived config                                                             | Unexhausted dimension and source difference                                                                                                                                                                                                                                                                                        | Selected counterpart                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Raw one slot](experiments/registry-raw-init/registry-workflow.cfg)         | Empty Init, two issues, time 1..6, amounts 1/3 and one top-up per ID. Registration, initialization, selection, top-up/exit, punishment and withdrawal can interleave freely. `Tick` uses `CapturedSnapshot` for its observer and committee comparison reuses `Members`/`Powers`.                                                   | M05 uses fixed registration block positions and a prepared lifecycle; J03 begins at empty Init with a literal prefix.                                                                                                                                                |
| [Fixed registration](experiments/registry-fixed-init/registry-workflow.cfg) | Same one-slot bounds, with registration at `1+2*nextId`. Historical selection, activation, exit, forfeiture and retirement still vary. Raw snapshot/committee observations and ceil-half forfeiture are present; the withdrawal receipt records the computed slots.                                                                | Current M05 fixes the same registration blocks and additionally runs the active-bond/replacement prefix. Repeated top-up, split and public-zero cases have separate selected bounds.                                                                                 |
| [Raw two slot](experiments/registry-two-slot-raw/registry-two-slot.cfg)     | Empty Init, two slots and two issues, time 1..4, one top-up per ID, free registrations. Occupancy and independently timed holder histories can vary. The third issue required for displacement is unavailable. The archive predates independent admission receipts and actual withdrawal/reject frames.                            | Current M05 opens with two deposits and block-2 snapshot selection, then tests a third registrar through time 4. J03 permits a third issue and time 6 in six selected retirement schedules.                                                                          |
| [Rich receipt](experiments/registry-rich-receipt/registry-two-slot.cfg)     | Two slots/three issues, time 1..4 and one top-up per ID. After the prepared two-deposit/snapshot opening, admission minima, tie and rejection can vary. The rich last-registration receipt tracks decisions. Its withdrawal still exposes computed slots and there is no sticky whole-reject-frame or per-bond conservation check. | M05 preserves the prepared admission scope with `ExpectedAcceptance`, compact rejection flags and actual withdrawal slots. J03 checks a stake tie on effective plus pending, amount-2 refusal against minimum 3, displaced pending-funded retirement and withdrawal. |

[H01](conformance/REGISTRY_PUBLIC.md#literal-execution-ledgers) checks selected
Registry roots, state, events and cash using public PoPs.
[N02](REPORT.md#n02-actual-signed-evidence-and-input-binding) adds actual
double-sign calldata, slashing, split and retry/refusal effects.
[N03](REPORT.md#n03-actual-exit-withdrawal-and-slot-reuse) checks a 16-step
two-cycle exit/confirmation/withdrawal/reuse history with a surviving slot and
immutable historical checkpoints.
[N04](REPORT.md#n04-actual-late-token-failures-and-identical-retries) checks
selected late allowance and balance refusals with actual selected rollback,
identical-call success and later activation. These selected Solidity receipts
use the [mock Inbox and exact-transfer token](conformance/REGISTRY_CASES.md#internal-solidity-fixture).
R01 retains free lifecycle composition, actual finalized-R selection, wider
contract/token integration and full capacity.

## Forced inclusion · F01

All nine configs use two entries, L2 height 2, generation 0→1, nonce at most 2
and time 0..2. In Raw and Prefix the height bound applies per live history;
there is no global production counter. In Budget and Projected a total of two
productions spans generations. Compare `Enqueue`, `FITick`, `ObserveBuild`,
`RestoreParent`, `Produce`, `FILand` and `FIRecover`. The L2 local cursor
can advance ahead of the L1 landed head; the latter drives admission fees.

In Raw, the producer records its predicate-local cursor and uses the selected
anchor in the receipt. Prefix already captures closed queue snapshots from the
pre-state and reconstructs the predecessor cursor, but its receipt still uses
the predicate-local cursor. Both clear the prune halt in `FIRecover`. Budget
adds independent actual pre-cursor capture and a closed-anchor corruption
control and leaves `halted` unchanged across recovery. Projected adds explicit
halt-frame and pre-production observations, canonical blank bytes and a
projection that retains necessary singleton-build context. Its older
`WrongParent` string sentinel differs from the current typed control; the
archived normal configs select `Correct`.

| Archived config                                                           | Unexhausted choices                                                                                                                                               | Selected counterpart                                                                                                   |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [Raw Empty/B](experiments/fi-raw/configs/fi-empty-revert.cfg)             | Empty queue allows admission/clock races, pre-due deferral, build availability and restoration, due Empty skip, position-zero B and delayed landing/recovery.     | M06 EmptyReady fixes admission and one transient/complete Empty skip.                                                  |
| [Raw A/Bad](experiments/fi-raw/configs/fi-mixed.cfg)                      | Empty queue allows admission/clock races, ordinary blocks before due, earliest A/Bad handling and delayed settlement.                                             | M06 MixedReady fixes admission, clock closure and due A.                                                               |
| [Prefix Empty/B](experiments/fi-prefix/configs/fi-empty-revert.cfg)       | Two admissions and first closure are fixed. Remaining ordinary production, singleton build/retry and recovery remain variable without a total cap.                | EmptyReady spends the second tick and one production on the selected legal Empty path.                                 |
| [Prefix fee lag](experiments/fi-prefix/configs/fi-fee-lag.cfg)            | Admit A, close block 0, include A early, admit B at local cursor 1 and L1 head 0. The continuation can produce across generations without a total cap.            | M06 FeeLag preserves that prefix with a cap of two. H04 adds a selected third production and partial landing/recovery. |
| [Prefix A/Bad](experiments/fi-prefix/configs/fi-mixed.cfg)                | After two admissions and first closure, vary early A/deferral, due A and Bad handling with arbitrary remaining builds/landings within the time and height bounds. | MixedReady spends the second tick and one production on due A.                                                         |
| [Budget Empty/B](experiments/fi-budget/configs/fi-empty-revert.cfg)       | Same two-admission prefix with a total of two productions. Build availability, pre-due refusal/deferral and recovery before consumption remain variable.          | EmptyReady plus individual retry and included-revert witnesses.                                                        |
| [Budget A/Bad](experiments/fi-budget/configs/fi-mixed.cfg)                | Same cap. Whether advance uses the exact earliest due entry can vary across early A, ordinary deferral, Bad and variable settling.                                | MixedReady plus H04's distinct A/B suffix program.                                                                     |
| [Projected Empty/B](experiments/fi-projected/configs/fi-empty-revert.cfg) | Same Budget config bytes and different wrapper. The narrower observer still leaves pre-due and build refusal/restoration paths before Empty skip.                 | EmptyReady executes one specific retry/skip. H04 contains no Empty singleton step.                                     |
| [Projected A/Bad](experiments/fi-projected/configs/fi-mixed.cfg)          | Same Budget config bytes and projected wrapper. The choices before A consumption still vary.                                                                      | MixedReady fixes A consumption at time 2. H04 restores only selected A/B partial settlement and replacement.           |

[M06](FORCED_INCLUSION.md#finite-workloads-and-observation-projections) uses
executed prefixes through which all intermediate states are checked. EmptyReady
and MixedReady spend the clock and one production before the free continuation.
FeeLag retains one tick after setup.
[H04](FI_SUFFIX_RECOVERY.md#omitted-chronology-and-finite-program) uses an A/B
fixture, time four and three actual modeled productions. Its two literal
histories observe a retained or blanked suffix, cursor rewind, original fees
and actual replacement landing. Its old-proof refusal also has a parent below
the new start, while [G04](REPORT.md#coverage-closure-batch--g04-positive-stop-old-proof-handoff)
isolates generation under a different fixed proof premise. H04 includes B as
a symbolic body token. M06's included-revert witness and exact singleton skip
are separate evidence. Timeout, a pruned parent and wrong parent or budget are
distinct from a completed empty singleton. F01 retains the wider interleavings
or a justified reduction plus actual FIFO/STF, fee and settlement behavior.

## Proving · P01

The three archived profiles share height/production 3, clock 0..2, U=2, two
job IDs and reference/ancestry bounds 1. In the archived model `Ready` permits
a same-time reference, `Finalize` takes a height, `PublishAnchor` uses the
current time and `Recover` combines a recovery reference and its observation.
Compare current `Ready`, `Finalize`, `OrdinaryFinalizationsCorrect`,
`PublishAnchor` and the trusted completed recovery macro. These differences
affect which landings and resumption steps the old workload could reach.

| Archived config                                                                           | Unexhausted dimension                                                                                                                                                        | Selected counterpart                                                                                                                                                                |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [One job/ancestry](experiments/progress-initial/configs/progress-ancestry.cfg)            | Capacity two, one spare task ID and dynamic history/backend changes around recapture and a reference beyond old ancestry support.                                            | Current OneJob uses absent resources. H03 performs expiry and distinct recapture with supported ancestry. Separate recovery profiles cover selected authenticated topology changes. |
| [Two jobs/capacity two](experiments/progress-initial/configs/progress-pipeline.cfg)       | Partial arrivals and publication before readiness, immutable complete long statements/data after short landing, finality and resumption.                                     | ReadyTwoJobs precompletes both jobs. J05 exercises twelve partial-arrival histories with one B outage, immutable overlapping statements and block-end finality.                     |
| [Two jobs/capacity one](experiments/progress-initial/configs/progress-small-capacity.cfg) | Arrival competition when the short original fits and the long original cannot fit. The short landing leaves a one-unit suffix without changing the long original length two. | Current capacity-one scope begins with both jobs prepared. H03 and J05 exercise dynamic arrivals only at capacity two.                                                              |

[M07](PROVING_PROGRESS.md#exhaustive-workload-profiles),
[H03](PROOF_RECAPTURE.md#previously-omitted-chronology),
[J05](PROVING_ARRIVAL_OVERLAP.md#finite-product-and-frozen-literal-calls) and
[the recovery profiles](PROVING_RECOVERY.md) cover complementary finite slices.
H03 and J05 perform no recovery. The selected recovery macro has a trusted
finalized origin and preserves physical resource state; under M07's time-two
bound it can execute only from time 0. Production anchor age shares the
reference-window parameter and capacity units are symbolic. P01 retains
asynchronous resource and topology composition, capacity-one arrival
competition and progress under explicit premises. P02 retains actual
capacity and proving throughput.

## Corrective rollback · Q02

The [archived Replay config](experiments/m09-wide-runtime/configs/rollback-replay.cfg)
uses height at most 2, generation at most 2, nonce at most 4 and time at most 1.
After `SetupStep`, archived `Runtime` admits authorize/recover/invalidate,
confirmation and other legal actions around Upgrade. `Upgrade` writes the
base landings, but its receipt lacks the later actual base landing-record
before/after comparison, leaving the assertion gap even if SignalService
checkpoint projection looks correct. The current wrapper adds
`BaseLandingRollbackCorrect`, checkpoint reads and independent authority
provenance. Relevant outcomes include identity of retained records,
invalidation of all later authority, current-nonce fencing, cross-/same-block
confirmation reset and payment continuity.

[Current M09](VERIFIER_ROLLBACK.md#checked-behavior-and-independent-observations)
uses three prepared workloads and selects Upgrade first after setup.
[H05](ROLLBACK_PAYMENTS.md) checks three selected payment, nonce and height-reuse
histories through a modeled atomic correction. It actually exercises
pre-correction stake/value transfers, same-block cached/retry revocation,
fresh proof and zero duplicate fee/transfer. The separate immediate raw
`cash'`, completed and escrow audits matter because M09's inherited upgrade
observer records unprimed afterCash and omits completed. H05 treats the bad
verifier landing as injected. Q02 retains freer schedules, actual migration,
node reconciliation and failure atomicity across the concrete token, bridge
and SignalService boundaries.
