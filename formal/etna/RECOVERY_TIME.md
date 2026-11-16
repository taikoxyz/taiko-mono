# Recovery first-header clocks (T01)

`EtnaRecoveryTime.tla` is a small deterministic first-header interface. It does
not add a consensus engine or execute an EL state transition history. Existing
R0 models, configurations, conformance payloads and global pins stay intact.

The authority is SPEC commit `d18357214fab30ea512ae9858a11699806d72ba1`,
SHA256 `4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`.
RECOV-8.4-2/3 fixes origin c/R for generation1. RECOV-8.4-7 fixes initial
height c+1 and genesis time R.timestamp; RECOV-8.4-10 fixes first BFT time to
that genesis time and empty LastBlockID/LastCommit. CONS-3.2-3 independently
fixes EL timestamp to max(parent EL timestamp+1, floor(BFT time), anchor time).
RECOV-8.4-12 allows a finalized first anchor no earlier than R. A later anchor
does not change BFT genesis time. Only integer seconds are exercised here.

| Literal case       | Parent height/time | Fixed origin c/R.number/R.time | Anchor number/time | Generation | BFT time | EL time |
| ------------------ | ------------------ | ------------------------------ | ------------------ | ---------- | -------- | ------- |
| `equal-times`      | 12/1               | 12/103/3                       | 103/3              | 1          | 3        | 3       |
| `parent-dominates` | 12/3               | 12/103/3                       | 103/3              | 1          | 3        | 4       |
| `later-anchor`     | 12/1               | 12/103/3                       | 104/4              | 1          | 3        | 4       |

Authenticated retained parent metadata, authenticated fixed origin and finalized
anchor eligibility are input premises. These literal fixtures are not a proven
STF history, an authentication implementation, or proof of committee/proof validity.
The parent is never retimestamped during recovery. No eligible anchor earlier
than R is invented to make the BFT maximum term independently dominant.

`Fixture` and `Header` are operational. The separately written literal `Audit`
never calls either constructor or `Max2`; `RawPremisesBound` checks the complete
raw input, and `ObservationExact` checks the complete observed input and header,
including both clocks, generation, parent, origin and anchor. `Construct` records
the actual output after an explicit preparation transition. `ConstructionEnabled` rejects suppressing
that action. `Prepare` only stages model inputs/observation readiness; it is not a protocol
action or a fairness assumption. Preparation makes disabled-action failures
reachable after initialization, so the
unchanged shared campaign classifier can identify its exact semantic target.
The three `*-witness` configs intentionally violate their exact
NotReached invariants after construction, so safety alone cannot establish success.
The two `*-collapsed-control` configs intentionally violate
`CollapsedClockIdentity` on the valid EL4/BFT3 cases. These are scoped negative
controls, not a claim that R0's parent1/anchor3 fixture is incorrect.

## Actual receipts

`conformance/export_recovery_time.py` runs a wrapper around the model and prints
actual `observed` records using TLC `PrintT`. It reuses the existing constrained
`ValueParser`; Python does not implement the timestamp acceptance or construction
rule. Schema `etna-recovery-time-replay-1` exports exactly the three case IDs,
`observation.raw` premises and separately named `header.bftTime` and
`header.elTimestamp`. Source/config/parser/exporter/wrapper/TLC and pinned SPEC
provenance are bound, with source/tool drift checks before accepting output.
The separate `recovery_time_cases.json` is T02's input; old exports are unchanged.

Use the configured Python and supplied existing Java17/TLC1.7.4, with inspected
source and tools mounted read-only through `conformance/run_isolated.py`, network
disabled and disposable outputs. The exporter downloads nothing:

```sh
"$PYTHON" formal/etna/conformance/export_recovery_time.py \
  --java "$JAVA" --jar "$TLC_JAR" --output "$RECEIPTS" --log "$TLC_LOG"
"$PYTHON" formal/etna/conformance/export_recovery_time.py \
  --java "$JAVA" --jar "$TLC_JAR" --output "$RECEIPTS" --check
"$PYTHON" -B -m unittest discover -s formal/etna/conformance/tests -p test_recovery_time.py
```

`--check` reruns TLC and compares the complete fixture after structural/provenance
validation. Regression tests reject missing/duplicate/unexpected cases, missing
raw/clock fields, altered raw inputs or clocks even after rehashing, substituted
provenance and source drift. A self-rehashed fixture is not an authenticated
attestation; comparison must use freshly generated actual observations.

## Source-fault controls

The authoritative shared `sensitivity/mutations.json` appends five IDs to the
existing compatible TLC cohort without changing old IDs/selectors:

| ID                                   | Source fault      | Exact mutant target                             |
| ------------------------------------ | ----------------- | ----------------------------------------------- |
| `recovery-time-bft-origin`           | R.time+1 BFT time | `ObservationExact`                              |
| `recovery-time-parent-step`          | Omit parent+1     | `ObservationExact` on parent case               |
| `recovery-time-later-anchor`         | Omit anchor time  | `ObservationExact` on later-anchor case         |
| `recovery-time-collapse-clocks`      | EL=BFT            | `ObservationExact` separately on both EL4 cases |
| `recovery-time-construction-enabled` | Disable Construct | `ConstructionEnabled`                           |

The campaign requires successful original/restored semantic outcomes and exact
mutant failures. Parser errors, timeouts or unrelated failures are inconclusive.
The finite construction checks and fault kills do not establish full refinement,
real CometBFT admission, fractional-time rounding, actual EL execution, proof
cryptography or unbounded liveness. T02 checks a selected actual engine boundary.
