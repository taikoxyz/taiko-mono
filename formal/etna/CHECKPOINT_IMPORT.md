# M10-A: authenticated checkpoint import and admission

[`EtnaCheckpointImport.tla`](EtnaCheckpointImport.tla) models an offline import
transaction, process-crash installation and subsequent session admission under
SPEC `d18357214fab30ea512ae9858a11699806d72ba1`, especially DATA-5.3-3/4/8,
DATA-5.4-1..7, RECOV-8.4-7..15 and SYNC-9-4..14. It adds forty configurations:
three exhaustive normal searches, twenty-seven permanent mutation controls and
ten existential reachability witnesses. Five additional input profiles exercise
individual bindings, contradictions, legal alternatives and origin exceptions.
The original forty configurations and raw inputs 0..15 are unchanged. Four
additional default connection profiles and two nested conditional temporal
profiles are described below.

This is specification-level finite evidence. It does not execute an importer,
CometBFT, EL, proof verifier or network; no concrete importer conformance is
claimed. Symbolic `Hash` and validator hashes are collision-free constructors,
not implementations of cryptography. `computedState` represents the result of
local state recomputation, independently supplied from the downloaded state root.

## Interfaces and finite profiles

| Profile         | Fixed origin | Import point | Session latest target |
| --------------- | -----------: | -----------: | --------------------: |
| `import-latest` |            2 |            4 |                     4 |
| `import-older`  |            2 |            4 |                     6 |
| `import-origin` |            2 |            2 |                     2 |

Generation 1 is initially current; an authenticated observation can learn
generation 2 during verification, staging or a running session. That observation
revokes trust and connection and blocks further old-generation admission. It is
knowledge obtained from L1, not an assertion that nodes instantly learn global
chain progress. No competing L1 forks or Ethereum finality algorithm is modeled.
The session's target is fixed for this bounded run. The importer authenticates
finality, and missing finality can become available on retry.

The module is deliberately not `EXTENDS EtnaL1Trust` or `EtnaAppCrash`:
M02 has only one non-origin checkpoint per generation; M03 starts with empty
stores and a tiny normal-execution sequence. Expanding those fixtures would
change their established semantics. The interfaces correspond to M02's finalized
latest-target certificate and generation fence, M03's process-durable writes and
session reset, and M04's authenticated committee results. This is neither formal
composition nor transitive refinement of those models. No committee-selection,
settlement, signer HRS or post-import ABCI engine is duplicated here.

`Continue` assumes successful normal validation/execution of every intervening
block, recording its exact EL/Comet/validator identity at the latest target.
It is an explicit trusted environment boundary, not a proof of that execution.
`Connect` exposes the trust-to-signer authorization boundary; actual signatures,
HRS arithmetic, all vote types and RPC serving remain covered only by their
separate models. Imported signer state is forbidden; the existing HRS tuple
remains unchanged even when import crashes or a generation change is learned.

## Raw inputs and classification

A raw input contains independent L1 commitments and candidate fields: EL hash,
state root and recomputed state; Comet header and envelope; validator-state
preimage with keys, powers, priorities and stored proposers; registry entries;
and the authenticated fixed window. The twenty-five fixture variants construct
those fields; no operational or observer predicate reads a variant number.

The variants cover exact input; unfinalized L1; corrupt publisher envelope;
authenticated envelope/EL contradiction; an unbound validator preimage; an
authenticated preimage/header-next-set contradiction; authenticated committee
mismatch; unavailable material; missing ancestors; recomputed-state mismatch;
missing committed-evidence markers; alternate valid landed priorities/proposer;
contradiction combined with a corrupt other component; contradiction combined
with missing ancestors/evidence; and a wrong peer header with unchanged L1 hash.
The alternate valid preimage is especially useful: copying a hardcoded canonical
committee's priorities would fail despite correct keys and powers.

Classification distinguishes:

- Missing material or an unfinalized record: wait, stay untrusted, obtain missing
  material/finality, and retry verification.
- Unauthenticated or corrupt publisher input: reject the candidate.
- Contradiction between authenticated commitments: safety halt. In particular,
  a proven contradiction is not hidden by unrelated missing or corrupt input.
- Authenticated consistent input: allow staging, without granting trust.

`seen.classification` captures the actual raw input and operational result.
`ObservedClass` computes a separate expected result from those fields and never
calls `Decision`, `Missing`, `Authentic` or `ProvenContradiction`. Observations do
not enable actions. This independence is still model-level: finite symbolic
fixtures and their intended meaning are modeling assumptions.

At `s=o`, the retained public Comet header belongs to generation 0. New generation
1 uses its fixed genesis: Info/Comet committed height zero, initial height three,
empty LastBlockID and LastValidators, genesis L1 timestamp 100, and the initial
committee for both future sets. Historic landed priorities and the old pending
set are not installed as this generation's genesis. The separately held public
Comet identity still participates in the latest-target both-hash check; only the
validator-state comparison has the origin exception. At `s>o`, all landed
priorities and stored proposers are installed exactly, without requiring `s+1`
or `s+2` blocks, and app/Info AppHash is EL(s), not header(s)'s EL(s-1).

## Discriminatory input obligations

The added fixtures change inputs only. `Authentic`, `Missing`,
`ProvenContradiction`, `Decision`, `ObservedClass` and the action engine remain
unchanged. Each source-fault probe replaces exactly one selected operational
condition in a temporary module; its normal baseline and restored module must
exhaust, and its mutated module must violate `ClassificationCorrect` at `Check`.
A parser/runtime error or a later store invariant does not meet this obligation.

| Input | Construction                                                                                                  | Normal classification above origin     | Isolated obligation                                                   |
| ----- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------- | --------------------------------------------------------------------- |
| 16    | Wrong peer EL hash; retained L1 and envelope unchanged                                                        | Reject                                 | Peer EL equals retained EL                                            |
| 17    | Wrong downloaded state root **and matching wrong recomputed root**                                            | Reject                                 | Downloaded root equals authenticated root                             |
| 18    | Reordered peer committee entries; retained registry commitment unchanged                                      | Reject                                 | Entries authenticate to the registry commitment                       |
| 19    | Changed peer window validator object; header window commitment unchanged                                      | Reject                                 | Window authenticates to the header commitment                         |
| 20    | Alternate second-set priorities and stored proposer; matching landed preimage hash                            | Verified                               | Install the authenticated second set without hardcoding its metadata  |
| 21    | Changed first-set powers plus matching preimage/entry commitments and entries; header next-set hash unchanged | Halt                                   | Authenticated preimage versus header next-set contradiction           |
| 22    | Input 3's envelope-conflict fields, but the L1 record is unfinalized                                          | Wait, then Halt after finality arrives | A contradiction requires finalized L1 authentication                  |
| 23    | Input 3's envelope-conflict fields, but the peer package is unavailable                                       | Wait, then Halt after arrival          | Latent absent fields cannot establish a contradiction                 |
| 24    | Matching corrupt envelope and header DataHash; retained L1 Comet commitment unchanged                         | Reject                                 | A peer header must authenticate before its envelope proves a conflict |

Input 17 is deliberately a coherent bad pair: changing only downloaded state
would also fail the recomputation comparison and mask omission of the L1 root
binding. Similarly, existing input 5 changes first-set powers without updating
derived entries; it contradicts both the header next-set hash and the derived
committee. Input 21 removes that masking by matching entries to the changed
preimage. It does not weaken the independent observer or manufacture an
incorrect chain/height commitment. Inputs 18, 19 and 24 leave their authenticating
L1 commitments untouched and therefore represent corrupt peer candidates.
Inputs 22 and 23 reuse the existing authenticated-envelope-conflict family with
only finality or availability absent. Their retained record fields are not a new
trusted premise: finality must arrive before the record authenticates anything,
and `present = FALSE` makes all latent package fields unavailable. The existing
retry supplies only that missing prerequisite; the now-proven contradiction
then halts. This is the DATA-5.3-4/8 and DATA-5.4-5 wait/retry boundary.

The following matrix records the bounded input-to-guard relation. Source-fault
probes use one listed input at a time, so another input cannot receive credit for
killing a different omission. “Remove” means replace only that conjunct/disjunct
with its neutral Boolean value, leaving the independent observer unchanged.

| Operational obligation                                 | Input                      | Fault and intended classification failure                              | Coverage limit                                                                                  |
| ------------------------------------------------------ | -------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `Authentic`: peer EL binding                           | 16                         | Remove equality: Verified instead of Reject                            | Symbolic EL identity                                                                            |
| `Authentic`: downloaded root binding                   | 17                         | Remove equality: Verified instead of Reject                            | Coherent bad pair isolates this comparison                                                      |
| `Authentic`: recomputed root binding                   | 9                          | Remove equality: Verified instead of Reject                            | Recomputed root is an independent symbolic result                                               |
| `Authentic`: Comet header binding                      | 15                         | Remove equality: Verified instead of Reject                            | Peer header time changes, retained hash does not                                                |
| `Authentic`: envelope binding                          | 2                          | Remove equality: Verified instead of Reject                            | Unauthenticated envelope cannot prove a contradiction                                           |
| `Authentic`: validator-preimage binding                | 4                          | Remove equality: Verified instead of Reject                            | Proposer changes without changing keys/powers                                                   |
| `Authentic`: registry-entry binding                    | 18                         | Remove equality: Verified instead of Reject                            | Mismatching entries are not authenticated                                                       |
| `Authentic`: window binding                            | 19                         | Remove equality: Verified instead of Reject                            | Fixed symbolic window; no window reconstruction algorithm                                       |
| `Missing`: peer presence                               | 7                          | Remove disjunct: Verified instead of Wait                              | Material arrives on existing retry action                                                       |
| `Missing`: finalized record                            | 1                          | Remove disjunct: Verified instead of Wait                              | Finality arrival is an environment assumption                                                   |
| `Missing`: ancestors                                   | 8                          | Remove disjunct: Verified instead of Wait                              | Non-origin bounded ancestor set                                                                 |
| `Missing`: evidence markers                            | 10                         | Remove disjunct: Verified instead of Wait                              | Non-origin bounded evidence set                                                                 |
| `ProvenContradiction`: envelope/EL conflict            | 3                          | Suppress conflict branch: Verified instead of Halt                     | Authenticated header and envelope                                                               |
| `ProvenContradiction`: next-set conflict               | 21                         | Suppress conflict branch: Verified instead of Halt                     | Matching entries avoid the second conflict branch                                               |
| `ProvenContradiction`: derived-committee conflict      | 6                          | Suppress conflict branch: Verified instead of Halt                     | Authenticated entries/window and preimage                                                       |
| Contradiction precedence over corrupt/missing material | 12, 13, 14                 | Existing `ContradictionRetry` controls require `ClassificationCorrect` | Existing controls test the combined outcome, not every prerequisite separately                  |
| `Authentic`: chain and height                          | None                       | **Unassessed** individual removals                                     | Coherent authenticated non-origin headers have the selected chain and height                    |
| `ProvenContradiction`: non-origin prerequisite         | 3 at origin                | Remove conjunct: Halt instead of Verified                              | Existing old-generation fixture under the fixed-genesis exception                               |
| `ProvenContradiction`: finality prerequisite           | 22                         | Remove conjunct: Halt instead of Wait                                  | Conflict is not authenticated until finality arrives                                            |
| `ProvenContradiction`: package-presence prerequisite   | 23                         | Remove conjunct: Halt instead of Wait                                  | Absent fields cannot prove a contradiction                                                      |
| `ProvenContradiction`: header-binding prerequisite     | 24                         | Remove conjunct: Halt instead of Reject                                | Coherent peer envelope/header do not authenticate their own L1 root                             |
| `Authentic` origin exception                           | 0, 3, 11, 16..21 at origin | Positive input profile; only EL/root/recomputation still bind          | Individual removal of `Authentic`'s origin exception is unassessed                              |
| Branch-specific conflict authentication prerequisites  | 2, 4, 18, 19               | Positive rejection checks                                              | Individual envelope/preimage/registry/window prerequisite-removal sensitivity is **unassessed** |

Chain and height checks remain required by DATA-5.4-1/2, but ordinary wrong peer
chain/height fields also break the header hash and cannot discriminate these
checks. Rebinding the finalized L1 Comet commitment to such a header would assert
a different trusted input domain. DATA-5.4-5 and SYNC-9-7 require distinguishing
that authenticated contradiction from invalid peer input; this model does not
claim that its generic Reject branch settles that extended classification.
These two guards are therefore unassessed, not proved redundant or complete.
No existing fixture is reclassified to make a mutation fail.

`import-input-bindings` checks rejection inputs 2, 4, 9, 15..19;
`import-input-contradictions` checks 3, 6, 12..14 and 21;
`import-input-valid-alternates` checks 0, 11 and 20;
`import-input-origin` checks 0, 3, 11 and 16..21 at the fixed recovery origin;
`import-input-conflict-prerequisites` checks 22..24 above the origin.
All five use the full existing safety-invariant set. Origin imports retain the
DATA-5.4-1/RECOV-8.4 genesis exception, including old-generation commitments and
fixed genesis validators; wrong EL/state inputs still reject. Existing input 3 at
the origin explicitly exercises the model's retained old-generation-header
exception: that envelope is not authenticated for the new generation's bootstrap
under DATA-5.4-1, so its would-be post-origin conflict cannot bypass genesis
installation. This is a check of the already-modeled origin boundary, not a
claim that a full valid old-generation execution produces contradictory landing
data. Alternate priority
fixtures preserve landed metadata for both sets. They are symbolic input
alternatives, not a proof of reachability under full Comet priority arithmetic.

## Installation, observation and crashes

`Stage` independently writes EL, app, Comet and evidence stores; `Flush` marks
each actual write durable. `Publish` exposes one completed boundary only after
all four stores are durable. A crash may occur at any staging/flush interleaving
or after publication. Non-durable writes disappear; durable content survives.
A pre-publication restart returns to verification and resumes incomplete staging;
a post-publication restart keeps the installed boundary but starts untrusted and
must authenticate its target again. At most one process crash is explored.
There is no power-loss, filesystem-corruption or concrete atomic-rename claim.

`seen.publication` records the actual published store contents and durability
set. `ObservedStores` independently constructs required content from captured
L1/candidate fields; it never calls `Planned` or `Written`. Assertions compare the
entire EL/app/Comet/evidence records, published boundary and retained store table,
not just ready flags. Fixed ancestor and evidence sets must survive installation.
The EL ancestor set represents its canonical/header indexes as a single abstract
store obligation; an app-side-only archive cannot satisfy it.

The window validator/commit structures and results hash are fixed symbolic
objects. This establishes preservation of those fixed objects, not the stock
store serialization, minimal evidence window, validator lookup arithmetic,
part-set calculation, evidence validation or full commitment-chain algorithms.
The ancestor domain is `2..s`; no claim about the >255-block EL case follows from
this tiny domain. Data availability, source selection, unbounded retry, multiple
imports, changing latest checkpoints within a session and historical origin
availability remain outside the run.

## Checks and permanent sensitivity controls

Normal configurations assert raw classification, full store alignment,
durability-before-publication, fixed genesis identity, latest-target trust,
absence of authority at publication, connection gating, HRS preservation and
sticky safety halts. Negative configurations name one exact expected invariant;
parse errors, timeouts or another invariant are failures, not successes.

Twenty-seven controls cover unfinalized or corrupt-input acceptance; five
contradiction classification cases; missing-material halt; premature publication;
wrong EL/priority/proposer/AppHash/FI/pending writes; lost EL ancestor/evidence
records; a corrupted publication boundary; changed InitialHeight; old landed
preimage or committed-height installation at the recovery origin; origin Comet
comparison bypass; latest-target/generation bypass; authority granted by import;
HRS reset; and automatic clearing of a safety halt. Store-write mutations leave
verification and publication guards enabled, and publication corruption is
independent of staged-store corruption.

The ten witnesses show latest admission, older-import continuation, origin
admission, missing-material retry, crash-before-publish resumption, a crash with
some but not all stores durable, completed older import still untrusted,
authenticated safety halt, generation supersession, and re-establishing trust
after a previously trusted process crashes. Witnesses prove existence, not
fairness or eventual progress.

## Reproduction and development evidence

Use the unchanged suite runner with supplied Java/TLC paths and an output path:

```sh
"$PYTHON" formal/etna/check.py --java "$JAVA" --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR" --case import-latest --case import-older \
  --case import-origin --case import-negative-wrong-el-store \
  --case import-negative-wrong-publication
```

Every default safety/reachability configuration is `configs/import-*.cfg`.
The two temporal profiles are nested under `sensitivity/configs/`. The runner uses one worker, seed
one, a 512 MiB heap and 45 seconds per configuration by default, recording exact
module/config hashes and requiring stable input files throughout the run.

The initial 33 expected outcomes were declared before the module body was
implemented. Additional checks were declared as source-informed refinements
were added. This is **not** a claim of a conventional production-code unit-test
RED/GREEN cycle: no production code changed. Parser/domain failures and a
sandbox-blocked Java RMI listener were setup/model defects, not semantic RED
results. Actual sensitivity evidence is the exact named TLC violations produced
by the permanent behavioral and pure-write mutations; ordinary configurations
must exhaust normally. Source review also corrected the origin branch before
independent review: a recovery origin uses genesis stores rather than the
post-s import bootstrap. These are model changes, not production defects.

## Conditional connection progress

The original disabled-`Connect` fault survived all forty original M10 safety and
reachability workloads. That remains valid historical evidence: those witnesses
stop at trust/admission and the safety invariant `ConnectedRequiresTrust` cannot
require a connection to occur. Existing actions, `Next`, `ImportSpec`, raw inputs
0..24 and all existing configurations retain their semantics.

[`EtnaImportProgress.tla`](EtnaImportProgress.tla) extends the unchanged base
actions with `ImportProgressSpec`, a separate conditional temporal workload. Its initial
state must contain the already correct, available and finalized `Raw(0)` package.
The generation and session target remain fixed: `LearnGeneration` is excluded.
The internal next-state relation uses the actual existing actions and includes
an optional process crash, bounded by `Crash` to at most one occurrence. A crash
may occur before publication or after connection; restart must re-establish
trust before reconnecting. No fairness condition requires a crash.

Weak fairness applies separately to `Check`, every `Stage(k)` and `Flush(k)`,
`Publish`, `Restart`, `ReadTarget`, `Continue`, `Admit` and `Connect`. Thus an
internal action that stays enabled must eventually make a non-stuttering step.
Fairness refers to the actual action operators, including their changed behavior
under a source mutation. It does not refer to preserved, unmutated action copies
or assume `connected = TRUE`. Per-store fairness avoids starving one store by
scheduling another. The finite crash allowance and fixed generation permit the
stronger `ConditionalStableConnection == <>[]n.connected`: eventually connection
holds forever, rather than merely occurring once before a crash.

These premises exclude missing/unavailable material and Byzantine candidates;
there is no `Retry` resource-arrival assumption. `Continue` retains the explicit
trusted premise that normal execution has validated every intervening block.
The profiles therefore prove neither real network/client liveness, data
availability, arbitrary crash recovery nor STF/consensus execution correctness.

Two nested temporal profiles exercise latest import 4→4 and older import 4→6.
Each declares exactly one `PROPERTY ConditionalStableConnection` and runs via
`sensitivity/run.py`, whose temporal classifier requires TLC exit 13 and the
sole matching property. They are deliberately outside the old default
invariant-only discovery path. The old `check.py` remains unchanged.

Four default profiles separately check `ConnectionEnabledWhenReady` and witness
`ConnectionNotReached` violations for latest and older imports under the original
`ImportSpec`. The enabledness antecedent observes published, trusted, running,
current-generation state with no connection; it does not reuse `Connect` as its
own prerequisite. These checks establish enabledness and existential reachability,
not fairness. The disabled-action fault must violate enabledness and the temporal
property. A no-effect `Connect` remains `ENABLED` and passes enabledness, but must
violate eventual stable connection. In particular, weak fairness of its eventual
stuttering self-loop cannot stand in for the desired result.

TLC's temporal evaluator compares candidate action successors. Existing store
slots change from the string `"Empty"` to records, and TLC cannot compare those
heterogeneous values for equality. The companion adds only a typed action tag,
`progressEvent`, whose primitive next-state assignment precedes the actual base
action. Different actions (including different store keys) therefore reject an
incompatible candidate tag before comparing store records; enabledness can
construct that tag and then generate the actual action's successor normally.

Fairness uses a typed `progressVars` projection containing this tag, phase,
staged/durable sets, publication/trust/connection flags, target readiness,
reached height and crash count. Each genuine internal action changes a projected
field. Erasing the tag from a companion transition gives exactly the existing
base action. No tagged wrapper assumes that action is enabled or changes its
result. A no-effect connection can change the tag once, then stutter forever;
weak fairness still cannot force its missing result. The actual `Connect` remains
the source-mutation target, and the stable-connection property observes only
`n.connected`. `progressAllVars` retains every base state variable plus the tag
for the next-state specification. The base `Init`, `vars` and `ImportSpec` do not
include the tag and their existing safety/configuration behavior is unchanged.
