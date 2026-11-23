# Anchor, immutable proof and recovery verification

Design PR #22425 at `178d7a7a66b14305c2f6467ae77163f93dd677cf`, main
`3602629758beb653423a23608fd1960810efcfac`, and formal baseline
`f5ca696e1f2fb966be76971075b5194de423aaa7`. TLC exhausted 607 distinct states
for the restricted Micro graph. All 15 public cases met their configured
expectations at model SHA-256
`411829ee1b8e277fa364ee338ae2e468f230c9ba2a17ffdd9e3491edd7e1fc52`. The
same-configuration normal pressure repair exhausted 144 distinct states on
the conditional Main input family. Local evidence includes independent
readbacks, 31 private witnesses, semantic controls with exact restorations, and
817 ordinary checks in each supported source cohort. Closing review and
publication receipts belong to the draft PR and monitor after the immutable
commit.

The [source profile](draft_rules/anchor_proof_source.json) binds the
[SPEC correspondence](draft_rules/quorum_source.json),
[model contract](ANCHOR_PROOF_RECOVERY_CONTRACT.md), three frozen independent
fixture files and [local evidence](anchor_proof/evidence.json). The fixtures
predate the model. Their literal expectations are read independently of the
model's action guards.

## Scope and outcomes

| Scope | Actual finite result |
| --- | --- |
| Micro, both inclusion slots | TLC completed with 607 distinct states and an empty queue. Independent actual-dispatch witnesses covered every ordered pair of `idle`, `s`, and `l` at slots 500 and 600, comparing the offered jobs, outcomes, records, FI, and SignalService. Independent node observations, replay, EL comparison and pending trust are part of the restricted graph. |
| Normal Main pressure RED/GREEN | The same Main/None CFG (SHA-256 `274bba1d3e1518416135a0174d061d6b861875ee84813d24798624c4e1f666cb`) produced `AnchorFenceSafe` at the reviewed pre-repair model `779a9add`, then an exhausted 144-state PASS at `411829ee`. The RED trace read 25 states, ending with actual c12 and an admitted H14 at B.c10. The corrected pressure witness refuses that candidate and admits its valid C-anchored neighbor. The permanent LatestC mutant is a separate public case. |
| Immutable proof and actual-c landing | Both short-first and direct-long histories consume the correct suffix, respectively H14 and H13/H14. The captured range, immutable blocks and both statement bindings remain fixed. The Twin fixture shares EL at H11 and differs in Comet identity, so the actual-c full cut refuses the beta proof. The ElOnlyCut control exposes an acceptance under the mismatch. |
| P-only committee authority | The POnly witness reads the authenticated p12 B-derived policy separately from ordinary reference-scoped data. The old anchor's distance is 140880, while V's is 100 against reference 141200. H13/H14 use Stake/F as current membership and consume the two due FI entries in transaction-0 order. |
| Pending trust, recovery and origin | Retained H11 keeps its historical anchor and timestamps. The app gate waits for independent EL and pinned record comparisons. The DirectLong public new-domain readback covers gates 12/14. The private actual ShortFirst trace covers 12/13/14, and independent readbacks see new-role commitments F/F/G at H15/H16/H17. |
| Default bank | 531 outcomes comprise the prior 516 plus one Micro PASS and 14 named checks, for 134 PASS and 397 named overall. The formal tree contains 55 TLA files. Private probes, faults and the normal pressure diagnostic stay outside this bank. |

Main, Twin and POnly exercise conditional finite input histories. They use
authenticated L1 and symbolic guest/STF/QC contracts. Main selects an immutable
external script at initialization. A branch-local snapshot identity binds the
parent history and actual storage/input/outcome so that divergent histories at the
same numeric L1 height retain their own records. Twin requires the source's
atypical greater-than-one-third double-sign premise and tests the consumer's
full-cut check under independently certified conflicting histories.

Recovery at H14 requires the specified outage, supported ancestry budget and
audited last-provable prefix. An unlanded H15 alone supplies no rollback premise.
Stale recovery at L1 1000 consumes an offer without changing contract storage,
and fresh recovery at L1 141000 consumes a distinct offer. Raw readbacks check
the fresh tag, actual prestate (generation 0, c14, nonce 0), receipt and effects.
The fresh authorization tuple is a pinned internal input recipe, so the
run covers one fixed recipe for the fresh call. Slot 285's
saved root and ledger are abstract ghost projections of authenticated EL state.
The model checks archive/state/origin/genesis/session contracts symbolically.
Application admission and status are in scope. A refused signer RPC followed
by resumed signatures requires a separate guarded restart and session contract.

## Review, refusals and controls

Independent preimplementation review identified two P1 and three P2 gaps in
the planned verification. The builder revised branch identity, Micro pair
coverage, same-config pressure calibration, storage and L1 frames, and the
qualification for old-job rejection. The same reviewer rechecked those changes.
Source review of the first model identified four P1 interface issues, two P2
model gaps and a parser blocker. One repair wave made EL and record 285
separate reads, retained the pending pin through an unchanged target, checked
every current and next committee word through the terminal and origin
boundaries, authenticated restored inputs symbolically, routed all ordinary
reads to the actual queried reference in this alphabet, and distinguished
the unavailable-recovery storage frame from L1 progression. The same reviewer
rechecked the source repairs and the subsequent single-hunk pressure fix.
These were specification correspondence and model findings. No protocol defect was confirmed
within the exercised scope.

Whole-stage review found that the two Main histories reuse the same printed
post-recovery header and root labels for different anchored content. At Z141100
the ShortFirst history retains record 13 and its record 14 has parent 13.
DirectLong has no record 13 and its record 14 has parent 12. Both print
E15new/K15new/S15new for H15, but its anchorID, the later reference ID and
the complete new proof statement differ. The evidence uses branch-local
interpretations for dependent symbols. Shared old inputs retain their names.
The finite lifting argument covers each run's comparisons. Cross-history
content binding and replay isolation remain open.
[Interpretation erratum and original dual-trace projection](anchor_proof/MAIN_IDENTITIES.md).

The 31 off-bank [probe profiles](anchor_proof/probes/profiles.json) use actual
dispatch. Independent typed readbacks check all nine Micro pairs, event order
through unavailable responses, remote replay before the local signer gate
opens, early EL mismatch and separate invalid EL and Comet record replies,
eight malformed capture inputs, six rebuild refusals, unavailable recovery,
the Twin full-cut refusal and the private ShortFirst history. Two Micro
observers add a deterministic observation field. The private reader restricts
that extra field to those cases, and the protocol actions and guards are shared
with the core. The 32-job private readback uses the ShortFirst raw trace twice
for separate role and stale-transaction checks. The root adapter also invokes
the same independent semantic API for all three ShortFirst gates.

Four isolated source faults accepted packets with trimmed proof data, a missing
ordinary root for an inherited anchor, a record role at the wrong root, or a
wrong terminal next committee. Each had the intended `ProofBindingSafe` violation. Independent
readbacks compare actual fault states with recorded normal `NoOverlap` or
`NoPOnlyWitness` baselines. All four restored source inventories exactly match
the private packet, and each reaches its intended rejection witness. The
missing-action control removes only the second stale-short offer. Its Micro
graph still exhausts 520 states, while the required `s,s` witness exhausts
without `NoProbe` and fails the coverage check. Exact source restoration
recovers the witness. Across these controls there are four named faults,
four capture restorations, two missing-action checks and one final witness
restoration.

After recovery and new-domain landing at c15/generation 1, the original
P/short/long offers are `alreadySettled`. Old generation, settled ranges and
expired references coincide. Isolated proof-generation sensitivity remains
**OPEN**.

The evidence also records two pre-RED parse/setup failures (TLC 150), one
old-reader failure caused by treating diagnostic captured authorization as
the fresh tuple, and one root adapter failure caused by comparing a tuple to
a list. The corrected public reader and ShortFirst adapter completed against
the actual raw histories. Those failures carry no RED or semantic credit.

## Replay and evidence

The [manifest](anchor_proof/evidence.json) is a portable projection of the local
run artifacts. It gives exact input inventories or baseline/delta inventories,
selected module and CFG digests, recorded TLC/JRE and launcher pins, actual
sandbox argv, and original result and raw log identities with byte sizes.
It also links the stdout of each [independent readback](anchor_proof/readback/output).
Outer commands, original receipts, logs, review notes and actual source
overlays are retained in the stage's ignored `retained-runtime/anchor-proof`
directory. Outer host commands appear publicly only by hash. The raw producer
logs and result JSON remain there at the recorded digests.

From the repository root, use caller-supplied pinned Java and TLC paths and
a fresh caller-owned output directory. The default bank contains the Micro
configuration.

```bash
"${PYTHON_BIN:?}" -I -S -B formal/etna/check.py \
  --java "${JAVA_BIN:?}" --tlc-jar "${TLC_JAR:?}" \
  --output-dir "${TLC_OUTPUT_DIR:?}" --timeout 45 --heap-mb 512 \
  --case apr-micro
```

The normal Main pressure replay uses the
[off-bank diagnostic configuration](anchor_proof/diagnostics/apr-normal-pressure-safety.cfg).

```bash
"${PYTHON_BIN:?}" -I -S -B formal/etna/check.py \
  --java "${JAVA_BIN:?}" --tlc-jar "${TLC_JAR:?}" \
  --output-dir "${TLC_OUTPUT_DIR:?}" --timeout 45 --heap-mb 512 \
  --config-dir formal/etna/anchor_proof/diagnostics \
  --case apr-normal-pressure-safety
```

The captured sandbox argv for `producerPackets.public` lists all 15 public
case names. The selected wrapper modules and configs for private replay are
under [probes](anchor_proof/probes). In a disposable copy of the formal source
tree, materialize the wrappers at its root by removing their final `.txt`
suffix and point `--config-dir` to the probe configs.

For each of the four capture faults, start with a separate fresh copy of the
private source packet. Apply just that control's `semanticDiff` at the formal
source root. Copy its exact [executed CFG](anchor_proof/controls/configs)
into the copy's `formal/etna/configs/` under its original filename.
Check the selected wrapper, CFG and full source inventory against the named
fault packet in the manifest. From that copy run the checker as above with
a fresh output directory and only `--case <faultCase>` (for example
`--case apr-fault-data`). Each CFG expects ProofBindingSafe. For restoration
start with the original private inventory, select only the corresponding
`restoredCase` and check its NoProbe result. The missing-offer control uses
its separate diff and existing Micro and probe CFGs. The recorded checks use one
TLC worker and seed 1. Historical pressure RED replay requires the retained
pre-repair source.

The [final readback helpers](anchor_proof/readback) operate on raw logs and
the frozen fixtures. In an isolated replay, stage the helpers and fixture files
at the same sandbox location shown in the manifest. Match the requested raw
log bytes against their recorded digest before invoking the versioned reader.
For the regular CLI, `independentReadbacks.<invocation>.jobs[].args` gives
the literal argument vector after the Python entry point, including the actual
baseline log and invariant for fault comparisons. The full-ShortFirst adapter
uses `full.log` at that sandbox location. Reader pins identify which
invocations used the current packaged helpers. Historical reader bytes and
exact job inputs remain in the retained originals.

The two ordinary cohorts each ran 624 unit, 173 conformance, and 20 sensitivity
checks with zero failures, errors or skips. Historical preservation was
checked against 1021 tracked baseline files, with scoped edits to the three
report/index documents and the count guard. The three independent literals
match their frozen digests.

## Review decisions and costs

| Decision | Cost or remaining obligation |
| --- | --- |
| Continue the existing authorized execution workflow directly and keep the work on the existing draft. | Any mistaken workflow assumption is scoped to reviewable rework in the stage. |
| Build a distinct product and reuse only pure prior helpers, because prior actions fix anchor lag and actual-c relationships differently. | Additional abstraction and reuse work remains subject to independent source and behavior review. |
| Preserve historical evidence and ignored workspaces. | Retention consumes disk space. |
| Exhaust one complete small Micro alphabet and use larger source-derived histories. | Broader interleavings and the previous Free objective remain open. |
| Derive immutable snapshot identities from each branch and select an immutable Main script. | More state, with independent field readback needed to check omitted or leaked histories. |
| Require all nine actual Micro paths and remove one stale offer as a coverage control. | Nine private probe executions complement the safety run. |
| Run pressure RED and GREEN on the same normal configuration and inputs. | An additional version-specific diagnostic remains separate from the permanent mutant. |
| Keep generation-only sensitivity open after the compound old-job rejection. | One consumer-boundary obligation remains open. |
| Frame contract storage and external L1 progression separately. | A refused transaction still consumes its slot, which adds environment and frame bookkeeping. |
| Model app gate and status with actual signer refusal, restart and session binding as external contracts. | End-to-end signing and RPC liveness need separate evidence. |
| Repair EL/record/pin, next checks, restore authentication, read roles and unavailable recovery frames in one source wave. | Additional finite state and reader work, with cryptography, runtime and archive availability external. |
| Route all ordinary proof read roles to the actual reference in this alphabet. | The checked routing scope is limited to that alphabet. |
| Keep malformed interfaces as private candidate inputs and preserve public profiles and fixture literals. | Extra unpinned histories remain outside the evidence. |
| Observe ordered Micro histories with a deterministic extra variable and preserve the core Next. | A fourth variable is allowed by the reader in exactly two modes. |
| Separate captured diagnostic authorization and the fresh internal call recipe. | Claims about raw authentication are scoped to the observable tag, prestate, receipt and effects. |
| Interpret dependent Main identity atoms per immutable script and lift the frozen finite checks by consistent renaming. | Requires the original two-trace comparison and explicit dependency scope. Cross-history replay and concrete commitment construction remain unverified. |

## Open boundaries

Full-protocol progress remains approximately 30 percent (25–35 percent
judgement). The previous Free height-14 search remains OPEN, with zero of its
12 classes exhausted. The 14 runtime WAITING and 19 archived INCONCLUSIVE
items remain open at their recorded scope. The public and private scripts
stop short of learning and comparing a generation-1 post-origin target after
new proof landing at c15. Arbitrary caller-supplied recovery authorization
parameters remain outside the fresh recipe. Unrestricted composition,
fair/temporal progress, actual proof construction and verification, deployed
or implementation behavior, archive restoration, and resource bounds require
separate evidence.
