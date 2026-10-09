# Phase B measurement report — template (one per spike)

**How to use this template.** Copy it to `artifacts/S<id>/report.md` and fill every field. Rules: (1) every measured number carries a unit, a method, a repetition count and a variance; (2) every derived number shows its formula and names the measured rows it consumes; (3) every number is tagged `sourced`, `derived`, `hypothesis` or `unmeasured`; (4) a field that does not apply is filled with `N/A` **and a reason**, never left blank; (5) thresholds are quoted from the spike specification and their pre-registration time is recorded; a threshold written after the run invalidates the report; (6) raw artifacts are committed and hashed, and are not edited after G2.

Spike: `S<id> — <title>` · Report version: `v<n>` · Date (with timezone): `<YYYY-MM-DD hh:mm TZ>`
Author: `<name>` · Reviewer: `<name>` · Harness commit: `<git sha>` · Repo commit: `<git sha>`

## 1. Identification

| Field | Value |
|---|---|
| Spike document | `./S<id>-<slug>.md` |
| Spec parameters this report closes | `<register rows>` |
| Run IDs covered by this report | `<ids>` |
| Pre-registered thresholds and constants | `<ε, σ, fleet budget, … each with the timestamp it was fixed>` |
| Supersedes | `<previous report version or N/A>` |

## 2. Run metadata (plan §2 — one block per distinct configuration; repeat as needed)

| Field | Value |
|---|---|
| Pinned versions | every tool, library, guest backend, verifier package, dependency resolved at run time (name = version/commit) |
| Hardware | CPU model and count, RAM, GPU model and count, VRAM, driver, OS; cloud instance type if any |
| Workload | exact identifier/hash of the frozen workload; payload length; block/tx mix; blob count; seed |
| Method | exact commands; cheatcodes/flag set; what was measured in-process vs derived; what was mocked or excluded |
| Date | start and end timestamps with timezone |
| Repetitions | count per configuration, and which quantity each repetition covers |
| Variance | min / median / max / stddev per repeated quantity; a zero variance is stated, not implied |
| Price or external inputs | each sampled value, with its source URL and retrieval date (never hard-coded) |

## 3. Measured quantities

One row per quantity. `Method` must be specific enough to reproduce (instrument, call, delta, snapshot name). `Raw` names the file in §6 that contains the evidence.

| # | Quantity | Symbol | Value | Unit | Method | Reps | Variance (min/med/max) | Tag | Raw |
|---|---|---|---|---|---|---|---|---|---|
| M1 | | | | | | | | | |
| M2 | | | | | | | | | |
| … | | | | | | | | | |

## 4. Derived parameter values

One row per parameter this spike fixes. The formula is written symbolically, then with the measured symbols of §3 substituted. No row may cite a number that is not in §3 (or a sourced constant, cited).

| Parameter (register spelling) | Formula | Measured inputs (row refs) | Value | Unit | Register action |
|---|---|---|---|---|---|
| D1 | | M… | | | replaces the unmeasured row in [09-parameters.html](../spec/09-parameters.html) |
| … | | | | | |

## 5. Pass/fail against the pre-registered thresholds

| Gate | Threshold (quoted from the spike spec) | Pre-registered at | Measured value | Verdict (mechanical) | Escalation, if fail |
|---|---|---|---|---|---|
| P1 | | | | pass / fail | the named owner and the decision menu from the spike spec |
| … | | | | | |

**Falsifiers observed.** For each falsifier listed in the spike's §2/§6, state `not observed`, `observed` (with the evidence), or `not tested` (with the reason).

| Falsifier | Status | Evidence / reason |
|---|---|---|
| | | |

## 6. What was NOT measured

Mandatory. List every quantity the spike intended to constrain but did not measure, every excluded module or environment, and every assumption that transferred in from another workload. State the effect of each omission on the conclusions (`none` requires a reason).

| # | Not measured / excluded | Why | Effect on the conclusions |
|---|---|---|---|
| N1 | | | |
| … | | | |

## 7. Raw artifacts

| Path (under `artifacts/S<id>/`) | SHA-256 | Content | Write-once |
|---|---|---|---|
| `raw/…` | | | yes |
| `summary.csv` | | | yes after G2 |
| `summary.json` | | | yes after G2 |
| `fixtures/…` | | | yes |
| `harness/` | (tree hash) | the exact harness revision that produced the data | yes |

## 8. Machine-readable summary (`summary.json`)

One object per spike; keys are fixed by this template, values filled from §3–§7. Additional keys are allowed but must be namespaced.

    {
      "spike": "S<id>",
      "report_version": "<n>",
      "date": "<ISO-8601 with offset>",
      "repo_commit": "<sha>",
      "harness_commit": "<sha>",
      "versions": { "<name>": "<version-or-commit>" },
      "hardware": { "cpu": "<model>", "cores": 0, "ram_gib": 0, "gpu": "<model>", "gpu_count": 0, "vram_gib": 0, "os": "<name>" },
      "workload": { "id": "<hash>", "payload_bytes": 0, "blob_count": 0, "seed": "<value>" },
      "method": "<one line: how the quantities were obtained>",
      "repetitions": 0,
      "measured": [ { "id": "M1", "quantity": "<name>", "symbol": "<sym>", "value": 0, "unit": "<unit>", "variance": { "min": 0, "median": 0, "max": 0, "stddev": 0 }, "tag": "measured", "raw": "raw/<file>" } ],
      "derived": [ { "parameter": "<register spelling>", "formula": "<symbolic>", "inputs": ["M1"], "value": 0, "unit": "<unit>" } ],
      "gates": [ { "id": "P1", "threshold": "<quoted>", "preregistered_at": "<ISO-8601>", "measured": 0, "verdict": "pass|fail", "escalation": "<owner/decision>" } ],
      "falsifiers": [ { "id": "F1", "status": "not_observed|observed|not_tested", "evidence": "<ref>" } ],
      "not_measured": [ { "id": "N1", "item": "<name>", "why": "<reason>", "effect": "<effect>" } ],
      "artifacts": [ { "path": "<path>", "sha256": "<hash>" } ]
    }

## 9. Sign-off

| Role | Name | Date | Statement |
|---|---|---|---|
| Author | | | the report is a faithful record of the runs described; no number is invented |
| Reviewer | | | independently checked the arithmetic of §4, the raw files of §7, and the verdicts of §5 |

## 10. Completion checklist (all boxes required before G2)

- [ ] Every §3 row has a unit, a method, repetitions and a variance.
- [ ] Every §4 row shows its formula and cites measured rows.
- [ ] Every §5 threshold is quoted from the spike spec and timestamped before the run.
- [ ] Every falsifier of the spike is classified.
- [ ] §6 lists every omission, including environment and transfer assumptions.
- [ ] Every artifact in §7 is committed with a hash; raw files are unedited.
- [ ] `summary.json` parses and matches §3–§7.
- [ ] No number is described as a benchmark when it is arithmetic, and none is a placeholder.
