# Free proving arrival and capacity product

`EtnaProvingAsyncProduct.tla` imports the unchanged `EtnaProvingProgress`
operational model. It executes actual Init and exactly Setup stages0–3: two
Produce calls at time0, then short `(slot0,parent0,terminal1)` and long
`(slot1,parent0,terminal2)` captures. Separate literal records check the complete
initial state, every setup effect, both captured statements, payloads and cuts.
The free graph begins with no history, availability, proofs or publications.

After capture, all real History/Availability Boolean choices, all eight
Complete(target,backend,source) tuples, full publication of either job, valid
suffix publication, Tick, either Land, Finalize, PublishAnchor and candidate
Produce interleave freely. Cross-source completions and overwriting good proofs
with wrong statements remain legal. Only the suffix indexing domain is limited
to `parent<=included<terminal`; expected readiness never selects a transition.
No extra captures, recovery or authority rewrites are offered.

Every profile fixes head3/produces3/time2/U2/reference-window1/ancestry1, variable
resources and capacity1 or2. All normative guards are TRUE; included/proof credit
and authority rewrite switches are FALSE. No original operational module or any
of the493 default configurations changes. New root modules do join the runner's
input hash inventory; opt-in product configs live outside `configs/`.

## Independent assertions

The literal Complete comparator uses actual offered target/source/backend,
source ancestry, current private history and **selected** backend availability.
It checks equality with actual ENABLED Complete for all eight tuples, even if
completion would overwrite an identical package. The Land comparator uses
literal original data/statements/cuts, actual frontier records, strict past
reference and original full-range length. It checks actual enabledness in both
directions. Neither calls inherited Ready or OracleReady to compute an expected
answer. Separate fixed-job equality prevents a changed job from hiding an error
by making readiness false. Frontier-dependent indexing uses an explicit IF.

Every real action executes first and evaluates an independent action-local
effect/frame audit. Complete changes exactly its selected proof and proofInputs
cell. Resource loss preserves all cached packages, including incorrect ones.
Publish changes exactly one publication. Land checks full original publication,
both exact statements, actual pre-frontier parent, preserved records, exact raw
landing event and one application per new height. Finality derives the latest
checkpoint from actual land events; anchor publication and height3 production
check their actual arguments and effects. Existing raw event invariants remain
additional assertions.

Audits are sticky Booleans with a failure-only raw argument/prestate record.
They add no ordinary-state history factor. Normal profiles keep witness fields
constant. A selected named witness activates only its own small phase counter
and last milestone argument tuple. There is no observer powerset or appended
journal. Complete refusal is model eligibility, **not** a failed external
backend call; retry means an actual later Complete of the same tuple. There are
no in-flight request IDs, attempts, cancellation or backend queues here.

## Explicit profiles and evidence classes

Run this product through the existing checker, supplying local tools:

```sh
python formal/etna/check.py --tlc-jar "$TLC_JAR" --java "$JAVA" \
  --config-dir formal/etna/products/proving-async \
  --case cap1-normal --output-dir "$OUTPUT_DIR" --timeout 300
```

Explicit config paths resolve against the caller's cwd before the checker
changes subprocess cwd. Modules still resolve only under `formal/etna/`. A bad
explicit directory never falls back to defaults. The default remains the
script-relative493-profile directory. Exact expectation parsing, module
validation, source/config/jar drift checks and raw result format are retained.

- `cap1-normal` and `cap2-normal`: exhaustive safety; PASS requires exit0,
  completion text and zero queued states.
- Both capacities' `witness-retry`: disabled `(0,A,0)` with history present and A
  unavailable, actual A arrival, then actual successful same-tuple completion.
- Both `witness-cached`: both correct short proofs cached, all three resources
  later absent, then actual short landing while resources remain absent.
- Both `witness-short`: actual frontier1; both `witness-suffix`: frontier1/time1,
  both correct long proofs and publication containing only payload2, with actual
  long Land refused.
- `cap1-witness-budget`: frontier1/time1, both correct long proofs and FULL
  original long data length2; all other guards pass, budget alone refuses.
- `cap2-witness-resume`: suffix refusal, actual full re-publication, actual
  overlapping second landing from1 to2 preserving checkpoint1/application1,
  block-end finality2 at time2/source block1, actual anchor publication, then
  actual height3 Produce selecting checkpoint2/reference1 and retaining parent2.
- `cap1-complete-audit` and `cap1-budget-audit`: focused positive source controls
  with only the exact independent enabledness invariant selected.

Named witness profiles expect their single exact `*NotReached` invariant to be
violated. Their counterexamples establish reachability; they are not exhaustive
safety PASS results. A timeout, parser/setup error, wrong invariant, absent
statistics or source drift earns zero credit. Raw failed attempts are retained.
No engine is authorized by these instructions without the separate reviewed
static packet, root smoke release/readback and full-profile release.

## Actual-source controls and limits

The author control deletes only Complete's actual `r.available[b]` conjunct on
a private same-copy operational source. It must violate AsyncCompleteEnabled
with history present and the selected backend unavailable, leaving ancestry,
domains and effects intact. The independent control replaces only the original
Land budget `Len(r.published[j])<=BlobCapacity` with remaining-length budget
`x.terminal-r.included<=BlobCapacity`. It must violate AsyncLandEnabled at the
FULL-data cap1 frontier1 prestate above, with both correct long proofs. Suffix
publication is a separate data-equality refusal and cannot discriminate this
budget mutation. Each control requires exact original/fault/restored inputs,
raw intended failure and genuinely exhaustive original/restored positives.

Measured outcomes, hashes, failures and restoration evidence are recorded in
the task report and raw artifacts after execution; static Python profile tests
establish interface contracts only. This bounded graph does not establish
fairness, eventual settlement, proving latency, service throughput or blob
packing. Tick may expire the finite landing window, outages may persist, and
cross-source completion may replace a good artifact. P01, separate ancestry/age
obligations and implementation-level proving/backoff remain OPEN.
