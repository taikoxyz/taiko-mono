# L2 committee Free operational view: safety remains open

The selected height-14 Free objective remains **OPEN**. The stronger monolithic
view timed out, and all twelve exact input-class safety searches also timed out.
No completed safety graph or normal-path protocol defect was established.

This stage is pinned to unmerged design PR22425 at `178d7a7a`, main `360262975`
and verification baseline `03cdafc9`. The original committee/recovery kernel is
byte-identical. The [source profile](draft_rules/l2_free_view_source.json),
[projection and cover argument](L2_FREE_OPERATIONAL_VIEW.md), and
[raw evidence manifest](free_view/evidence/runtime-v2.identity.json) bind the
precise instance and outcomes. Post-commit publication and exact-head hosted
artifact receipts are recorded separately in the monitor ledger.

## What changed

`EtnaL2CommitteeFreeView` instantiates the existing five-variable kernel. Its
view retains the operational fields and all six actual invariant truth values.
It hides positive exit dates, stale snapshots and F/G-only voter identities
under the reviewed good-prefix lifting argument. Actual stake votes remain.
It does not copy transitions or introduce protocol state.

The exact cover uses loss cardinalities 0, 1 and 2, crossed with four possible
generation-zero threshold programs: (2,3), (2,Disabled), (Disabled,2), and
(Disabled,3). Missing events and unused suffixes remain allowed, generation-one
threshold choices remain unrestricted, and `Lose({})` is a real event. Every
original finite history belongs to at least one class; every class uses only
original steps. An independent completed-receipt membership check is retained
in the class view. It never enables or restricts an action.

## Actual evidence and its limits

| Check | Actual result | Meaning |
| --- | --- | --- |
| Coarse VIEW `1a76d934` with hidden fault | QuorumSafe failure missed; 3 generated / 1 distinct | Genuine RED demonstrates a check could be hidden. |
| v1 VIEW `1a5e6220` with six real truth bits | Exact QuorumSafe, 2 / 2 | Failure remains observable. |
| Class scaffold `e7d4eb4e` before filtering | Exact InputClassSafe at Init → SetM Disabled; 63 / 7 | Wrong-class input detection exercised before filtering. |
| Twelve class witnesses | All exact NoPartitionWitness; actual two SetM operands and Lose cardinality read back | All classes are nonempty; queues remained nonzero and give no exhaustion credit. |
| Full-mode candidate | Exact NoCandidate at generation 0 / height 13 | Candidate activation exists in unfiltered original Free steps. |
| Eleven final-wrapper projection paths | Independent literal/raw readback passed | Current/saved snapshot and positive-date merges, F-vote merges, and stake-vote separation exercised. |
| Six same-key faults | Six named original-property failures, six normal and six byte-restored completed baselines | Tests error visibility and restoration on finite private prefixes. |
| Final safety cover | Twelve timeouts, zero completed classes | Original six-property Free objective remains OPEN. |
| Ordinary regressions | 817 each on source360 and sourcef556; no failures or skips | Existing tools, source classifiers and compatibility contracts still pass. |

The manifest binds each of those three diagnostics to its own producer receipt,
wrapper, selected module and config, raw log and result. For the final wrapper
`13caebfb`, the pair, normal, fault and restored producer inventories identify
the actual harness and config for each run. Their per-case raw log hashes match
the independent readers' inputs. The restored inventory and the original normal
packet have identical bytes across all 15 entries.

The six actual controls change only the origin parent certificate, current
snapshot, positive exit date, fallback certificate votes, saved snapshot, or
stored generation. They preserve the actual receipt and all unrelated fields.
The independent reader checks the intended single predicate failure and equal
operational keys. Private finite-prefix completion does not substitute for
Free exhaustion or protocol liveness.

Each class had its own 45-second limit, 512 MiB, one worker and seed 1. The
twelve safety limits total 540 seconds. The measured case durations sum to
540.753 seconds and include per-case subprocess termination, wait and timing
overhead. The searches have overlapping prefixes. The twelve class witness
runs took 47.732 seconds in total and the full-mode candidate took 1.631
seconds, for a combined witness time of 49.363 seconds. Timeout logs provide
periodic counts only. The archived monolithic v1 result retains its original wrapper,
configuration, log and result bytes.

## Default regression admission

Default CI has **516 cases = old 503 + 13 named witnesses** (133 expected normal
completions and 383 named outcomes). All twelve new safety configurations are
in `free_view/configs`, outside the default bank, with their original EXPECT
PASS expectations. The off-bank monolithic configuration remains available.
Green default CI does not discharge any of these safety searches.

From this directory, an explicitly configured runtime can reproduce a witness:

```sh
python check.py --java "$JAVA_BIN" --tlc-jar "$TLC_JAR" \
  --output-dir "$OUTPUT_DIR" --case l2fv-reach-candidate \
  --timeout 45 --heap-mb 512
```

To select an exploratory class, use `--config-dir free_view/configs` with
`--case l2fv-safe-l0-m2-3` and a fresh output directory. A timeout is an
inconclusive result, not a passing check. The jar digest is recorded in the
evidence manifest; no dependency installation is part of this stage.

## Remaining protocol work

The current full-protocol judgement remains about **30% (25–35%)**. This is
architectural judgement, not a ratio of cases. This stage strengthens evidence
at a four-bond, unit-power, height-14, at-most-one-recovery instance with trusted
completed proof, authenticated latest L1 adoption and code-present Effects/Revert
contracts. It does not close arbitrary stake amounts, monetary rounding,
admission lifecycle, 128-member scaling, consensus rounds/locks, temporal fairness,
proxy absence/restoration, anchor lag, guest proving, or implementation behavior.

The next substantial missing product connects node-adopted anchors, actual L1
landing/proof frontiers, proof origins and saved-state recovery. Existing
historical products provide contracts to reuse, but their revision-specific
results do not certify that latest-source composition. The 14 runtime WAITING
and 19 historical INCONCLUSIVE rows remain unchanged.
