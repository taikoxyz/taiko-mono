# M10-A: authenticated checkpoint import and admission

[`EtnaCheckpointImport.tla`](EtnaCheckpointImport.tla) models an offline import
transaction, process-crash installation and subsequent session admission under
SPEC `d18357214fab30ea512ae9858a11699806d72ba1`, especially DATA-5.3-3/4/8,
DATA-5.4-1..7, RECOV-8.4-7..15 and SYNC-9-4..14. It adds forty configurations:
three exhaustive normal searches, twenty-seven permanent mutation controls and
ten existential reachability witnesses. No earlier module or configuration changes.

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
and the authenticated fixed window. The sixteen fixture variants construct
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

Every configuration is `configs/import-*.cfg`. The runner uses one worker, seed
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
