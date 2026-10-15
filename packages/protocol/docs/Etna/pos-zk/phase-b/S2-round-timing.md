# S2 — Round timing at the target validator count

**Phase B spike specification. This is an experiment design, not a result: it contains no measurement of its own.**
Every number below is tagged *sourced* (source named), *derived* (arithmetic shown), or *hypothesis to be tested*.

Status: ready to execute · Date: 2026-10-05 · Owner: protocol lead
Reads: `05-phase-b-plan.md` §1 (S2); `spec/02-consensus.html` CONS-07 and the worked timing trace (§"Worked timing trace at the 2 s cadence"); `spec/09-parameters.html` (`TIMEOUT_MIN`/`TIMEOUT_MAX`, PARAM-03); `02-consensus-survey.md` §4 (Family A anchors, rules, cost model)
Fills register rows: `TIMEOUT_MIN`, `TIMEOUT_MAX`, the PARAM-03 row "Round completion time at 2 s with a permissionless global set", and the two unmeasured inputs of CONS-07(2): `Delta_max` (advisory one-way delay between correct validators) and `X_max` (local execution time for one block).

## 1. Purpose, and the parameters this spike fills

**Purpose.** Measure round completion, block-interval and view-change behaviour of a stock CometBFT-class engine at n = 50 / 100 / 200 validators spread across cloud regions, with and without injected faults, to decide whether one round fits inside D1's 2 s cadence and to derive the timeout ladder `TIMEOUT_MIN`/`TIMEOUT_MAX`.

| Parameter / quantity | Unit | Value before S2 | What S2 supplies |
|---|---|---|---|
| `TIMEOUT_MIN` | seconds | unset; PARAM-03 unmeasured | measured base round budget `T_min` |
| `TIMEOUT_MAX` | seconds | unset; PARAM-03 unmeasured | measured/recommended ceiling `T_max` (CONS-07(2) proposes 30 s) |
| `Delta_max` (one-way delay) | ms | **unmeasured** (CONS-07(2)) | measured p99 one-way delay matrix between regions |
| `X_max` (local execution per block) | ms | **unmeasured** (CONS-07(2)) | measured p99 block-processing time at the fixed payload |
| Round completion time at 2 s | distribution | unmeasured (PARAM-03) | p50/p95/p99 of round completion and block interval |
| Cadence feasibility at n | yes/no per n | unmeasured (open item F3) | the largest n at which the 2 s target holds, per topology |
| Vote size on the wire | bytes | derived ~180–300 B (02-consensus-survey.md §4.5) | measured p50, plus the declared intended-format bound |

**The committed target this spike tests (not a measurement).** The spec's timing trace assumes `Delta_max = 250 ms` one-way and `X_max = 500 ms` local execution, from which

    round_trip = 4*Delta_max + X_max = 4*250 + 500 = 1,500 ms = 1.5 s     [derived, spec/02-consensus.html]
    T_min      = 2*round_trip = 3 s                                      [derived, CONS-07(2)]
    happy path = 1.5 s inside the 2 s cadence interval; slack 0.5 s       [derived]

S2 either confirms these two inputs with p99 telemetry or falsifies them. It does not get to redefine the cadence: 2 s is D1, a user decision.

## 2. The question, and the decision it unblocks

**Questions.** (a) At n = 50 / 100 / 200, spread over 1 / 3 / 5 regions, does one round plus the commit wait complete inside 2 s at the 99th percentile? (b) What ladder base `T_min` is required, and what do the ladder's backoff and ceiling look like? (c) What is the view-change rate under no fault and under slow validators, partitions and leader failure? (d) What bandwidth and message counts per validator per round does this imply? (e) What is the largest n at which the 2 s target holds, with the assumed delay bound?

**The decision.** `spec/09-parameters.html` requires `TIMEOUT_MIN`/`TIMEOUT_MAX` to exceed the observed round-trip plus dissemination time among correct validators. CONS-07(2) fixes the form `T_min >= 2*round_trip` with `round_trip = 4*Delta_max + X_max`, and the ladder `T(H,R) = min(T_max, T_min * 2^min(R - R_progress, R_cap))` with `R_cap = ceil(log2(T_max / T_min))`.

- **Confirm** (`round_trip` measured, 2 s cadence holds at n with an admissible ladder): register `TIMEOUT_MIN = T_min`, `TIMEOUT_MAX = T_max`, `Delta_max`, `X_max`; the D1 cadence claim at n moves from *unmeasured* to *measured* for the tested geography.
- **Falsify** (no admissible ladder holds 2 s at n): the cadence at n is a **user decision (D1)**. The report MUST escalate with the measured numbers and MUST NOT propose a different cadence as a default. The escalation menu, in order: tighten the ladder (bounded below by `T_min >= 2*round_trip`, so this only works if `round_trip` is small), reduce n (a membership decision, `MEM`/`ECON`), or change the cadence (D1, the user's call).

**What this spike does not decide.** It does not decide the vote format. The S5 repair adds `configHash` (bytes32) and `recoveryGeneration` (uint64) to the signed vote and header bytes — **a size change of about 40 bytes per vote, not a timing-shape change**: it alters no message flow, no quorum, no lock rule and no number of round trips. The spike MUST NOT build it (§3.3). It also does not decide safety (the engine's rules and proofs are taken as published, 02-consensus-survey.md §4.2/§4.7) or proving throughput (S1).

## 3. Harness

### 3.1 What to build

| Component | Specification |
|---|---|
| Consensus engine | Stock **CometBFT**, one exact release pinned and recorded: v0.40.0 (published 2026-07-27) or the v0.38.x LTS line (v0.38.26, 2026-08-13); source 02-consensus-survey.md §4.0. Record tag, commit, and the built binary's SHA-256. CometBFT maintains four release lines at once, so the pin must name one and no spec quote is reused across lines (02-consensus-survey.md §4.0 provenance warning) |
| Application | The engine's stock in-process app (kvstore-class) driven by a deterministic tx generator; block payload fixed at **131,072 bytes** (the PARAM-02 per-2 s-block data budget, derived: 65,536 B/s x 2 s), with an empty-block control. Record tx size/count. The app measures block-accept/validate time (the testbed's `X`); it does **not** execute EVM |
| Topology | One process per validator node, one VM per validator, spread over >= 3 cloud regions; a controller node; all nodes time-synchronised (chrony/NTP) with skew recorded before and after each run. Record instance type, region, vCPU/RAM, image digest |
| Ladder | The CONS-07 ladder, mapped to the engine's per-phase timeouts. The base is derived from the **measured** delay matrix at testbed stand-up, not chosen: `Delta_hat` = p99 one-way delay for the worst region pair in use, `X_hat` = p99 block processing, `round_trip_hat = 4*Delta_hat + X_hat`, `T_min = k * round_trip_hat` for k in {1, 2, 4}, `T_max = 30 s`, `R_cap = ceil(log2(T_max / T_min))`. The per-phase split MUST be recorded as a mapping table |
| Ladder conformance test | Stall round 0 for one height (proposer killed or firewalled) and measure the observed round duration at R=0 and R=1. It must match `T(H,0)` and `T(H,1)` within 10%; a larger residual invalidates the ladder mapping for that cell |
| Fault injection | `tc netem` delay/jitter/loss on the consensus port; a partition split by region; a leader kill. Every injection has a timestamped schedule and a controller log. Injections MUST be scoped to the consensus traffic so that the controller and metrics collection survive |
| Load | Blocks produced continuously for >= 300 heights per run after a 60-heights warm-up, at the target cadence |

**Cost-reduction shortcut (allowed, gated).** Running 200 VMs is expensive; packing several validators per host with `netem`-emulated inter-region delays is permitted **only** if a calibration run at one (n = 100, 3 regions, chosen k) point shows the container-based round-time p50/p95/p99 matching the one-VM-per-validator distribution within 5%. Record the calibration. Without it, the shortcut is invalid.

### 3.2 Reuse, pinned

| Component | Pin / source |
|---|---|
| CometBFT engine | one exact release per §3.1; 02-consensus-survey.md §4.0 (v0.40.0 2026-07-27; v0.38.26 2026-08-13; v0.39.4 2026-07-28) |
| CometBFT rules text | re-verify every quoted rule (lock, PoLC, commit, timeout) against the **pinned release tag**, not branch `main` (02-consensus-survey.md §4.0 warning) |
| Engine metrics | the engine's own Prometheus metrics for heights, rounds, votes and P2P bytes, plus `/proc/net/dev` and `tc -s` counters for the cross-check |
| Fault tooling | `tc netem`, `nftables`/`iptables`, process signals; no custom consensus code |
| Fixture | a fixed-seed tx generator producing 131,072-byte blocks; the seed and the first block hash recorded |

### 3.3 What NOT to build, and why that is legitimate

1. **The vote-format change.** The S5 repair's `configHash`/`recoveryGeneration` fields in the signed vote and header bytes are **irrelevant to timing and MUST NOT be built**. The engine's round structure, message count, quorum and lock rule are unchanged by adding two fixed-width fields; only the signed byte length moves (about 40 B per vote: bytes32 + uint64, `spec/05-proof-statement.html` line 106 and `spec/09-parameters.html` recoveryGeneration row). The harness therefore declares an intended-format upper bound = measured stock vote size + 40 B and reports both. If the engineer cannot bound the size without implementing the format, the correct action is a size-sensitivity run with a padded message (e.g. via an ABCI++ vote extension used purely as padding), never building the format. What the format change *does* affect — in-guest verification cost — is S1's business, not this spike's.
2. **A new consensus protocol.** The design (D-1) is CometBFT-class with the published lock/PoLC/commit rules; the engine is reused as-is.
3. **L1 epoch membership.** The validator set is static for the duration of each run. The L1-authenticated epoch handover (M2) is a correctness surface, not a timing surface within a run; its boundary cost is left unmeasured and disclosed.
4. **Staking, slashing, recovery, the prover, the EVM.** None affects round timing; none is built.
5. **The real client's P2P stack.** The engine's gossip is the measured transport; a different production transport is a disclosed transfer gap.

### 3.4 Why the shortcut is legitimate, and what it does not cover

Round timing is determined by the message flow (proposer -> all, all -> all), the number of round trips (four one-way delays in the happy path per the committed trace), the byte size of proposals/votes/blocks, the quorum size and the timeout policy. A stock engine at the pinned release implements exactly that flow with the published rule set (02-consensus-survey.md §4.2 quotes the lock, PoLC and commit rules that CONS-04/CONS-05 adopt). The vote-format change moves one term — signed bytes — by tens of bytes out of hundreds, which the declared upper bound covers. Everything else in the production design that this harness omits (stake-weight skew, epoch handover, EVM execution, real geography, operator churn) is disclosed below, and none of it can make a round *faster* than a measured failing round.

| Omission | Direction | Handling |
|---|---|---|
| Stake-weight skew (few large validators) | can change proposer distribution and gossip fan-out | not covered; the run uses equal-power validators and says so |
| Epoch handover and the H+2-equivalent set activation | adds a boundary cost once per epoch | not covered; disclosed as unmeasured |
| Real EVM execution (`X_max`) | the testbed's X is app validation only | a separate **block-import cell**: run the repo's pinned execution client (`packages/taiko-client` or `packages/taiko-client-rs`, commit recorded) importing the fixed 131,072-byte blocks, and report its p99 processing time as the design-relevant `X_max`. If the client cannot be built in-harness, report the testbed's X only and mark `X_max` **partially measured** |
| Production P2P transport / DoS protections | can add latency under load | disclosed; the engine default is measured |
| Vote-extension verification surface | not used as a protocol mechanism | padding only, clearly labelled |

## 4. Experiment matrix

### 4.1 Independent variables

| Variable | Levels | Notes |
|---|---|---|
| n (validators) | 50; 100; 200 | plan §1 S2 |
| Topology | 1 region (control); 3 regions; 5 regions | record the measured delay matrix for each |
| Ladder base factor k | 1; 2; 4, with `T_min = k * round_trip_hat` | k < 2 violates CONS-07(2) and is a control only |
| Ladder ceiling | `T_max = 30 s` (proposed by CONS-07(2)) | one level; report the ladder it produces |
| Fault | none; slow f = floor((n-1)/3) validators; partition (1/3 vs 2/3) for 30 s; leader failure at one height; optional 1% loss | fault cells only at the k that passes no-fault |
| Block payload | 131,072 B; empty (control) | PARAM-02 target data budget |
| Validators per host | 1 (primary); packed (only with the §3.1 calibration gate) | — |

### 4.2 Staged design

| Stage | Cells | Repetitions |
|---|---|---|
| 0 stand-up | delay matrix per region set; ladder mapping + conformance test per k; clock-skew check | 1 each |
| 1 no-fault | full grid n x topology x k x payload = 3x3x3x2 = 54, trimmed to 24: k=2 at every (n, topology) with both payloads (3x3x2 = 18), plus k ∈ {1,4} at 3 regions with the full 131,072 B payload (3x2 = 6) | >= 3 runs per cell |
| 2 faults | at the smallest passing k, n ∈ {100, 200}, 3 regions: 4 fault types | >= 3 runs per cell |
| 3 block import | the pinned execution client on the fixed blocks, all n | >= 3 |
| 4 packed-host calibration | one (n=100, 3 regions, passing k) point | >= 3 |

Each run: >= 300 heights after a 60-height warm-up, >= 900 samples per cell for percentiles (a p99 from fewer than 300 samples is not reported; a p99.9 is not reported at all).

### 4.3 Fixed workload

Block payload exactly 131,072 bytes of transactions from a fixed seed; the same block sequence replayed in every cell; the empty-block control is the same run with the generator disabled. Record: seed, tx count and size, first/last block hash, total bytes.

## 5. Metrics

| # | Quantity | Unit | How measured |
|---|---|---|---|
| M1 | One-way delay matrix | ms | timestamped probes between all node pairs (p50/p95/p99); recorded before, during and after each run. `Delta_hat` = the worst region-pair p99 |
| M2 | Round completion time | ms | per height and round, from round start to the 2/3 precommit observed at each validator; report p50/p95/p99 and the count |
| M3 | Block interval (cadence) | s | commit-to-commit per height at the median-clock node; p50/p95/p99/max and the fraction above 2 s |
| M4 | `X` (block processing) | ms | app-side accept/validate timing; p50/p99. Design-relevant `X_max` from stage 3 |
| M5 | View-change rate | rounds/height, fraction | rounds > 0 per height; fraction of heights with R > 0; spurious rate in no-fault runs |
| M6 | Bandwidth per validator | bytes/round, Mbit/s | ingress and egress per round; peak rate; block propagation separated from consensus messages |
| M7 | Messages per validator per round | count | by type (proposal, prevote, precommit, block part) from the engine metrics |
| M8 | Vote size on the wire | bytes | measured p50/p99; plus the intended-format upper bound (stock + 40 B) |
| M9 | Fault response | s and blocks | time/ heights to return to a <= 2 s interval after the fault is removed; longest gap; heights affected |
| M10 | Node health | % CPU, GiB RSS, disk | per-node samples; a cell with p99 CPU > 80% is invalid (resource-bound, not network-bound) |
| M11 | Clock skew | ms | max pairwise skew before/after; > 100 ms invalidates the run's timing |
| M12 | Largest n | count | largest tested n satisfying the cadence gate; extrapolation (fit of p99 round time vs n, with CI) reported separately and valid only up to 1.5x the largest tested n |

**Run metadata (every run).** Engine release + commit + binary hash; config file hash; OS image digest; node count, regions, instance types; ladder mapping and k; fault schedule; clock skew; fixture seed; start/end time and timezone; per-node resource samples; the controller log. Records with any missing field are discarded.

## 6. Pass/fail

`T_cadence = 2.000 s` (D1, sourced).

| Gate | Condition | Threshold |
|---|---|---|
| **G-CADENCE(n, topology, k)**, no fault | p99 block interval <= `T_cadence` **and** p99(round completion + commit wait) <= `T_cadence` | yes/no |
| **G-CHURN** | spurious view changes in no-fault runs | <= 1% of heights |
| **G-TRACE** | measured `round_trip = 4*Delta_hat + X_hat` | <= 1.500 s, the value the committed trace assumes |
| **G-LADDER** | admissible base | `T_min >= 2*round_trip` (CONS-07(2)) |
| **G-CONFORM** | ladder conformance residual | <= 10% at R=0 and R=1 |
| **G-FAULT** | after fault removal, cadence restored | leader failure: <= 5 blocks; partition: <= 10 blocks; and no height gap > 10 s in any fault cell |
| **G-VALID** | clock skew <= 100 ms; p99 CPU <= 80%; >= 300 heights; config matches manifest | yes/no |

Threshold rationale, fixed before the run: the 2 s gate is D1 itself, not a derived tolerance. The 1% churn gate is the boundary at which view changes stop being exceptional: at 2 s and a base ladder of >= 3 s, a spurious view change costs at least one cadence interval, so more than 1% churn means the ladder is shorter than the network's real tail and the cadence cannot be sustained. The 1.5 s trace gate is the spec's own committed value; failing it does not by itself fail the cadence, but it **falsifies `T_min = 3 s` as derived** and forces the base to be re-derived from the measured `round_trip`. The 10 s fault gap is five cadence intervals — beyond that the engine has exhausted the round budget more than once and is not producing at a cadence at all.

**Verdict rules.**
1. **CONFIRM at n** iff for at least one admissible (topology, k) with G-VALID, G-CONFORM, G-CADENCE, G-CHURN and G-FAULT all hold. Register `TIMEOUT_MIN = T_min`, `TIMEOUT_MAX = T_max`, `Delta_max = Delta_hat`, `X_max` (design-relevant, from stage 3), and the largest passing n.
2. **FAIL at n** iff no admissible ladder passes G-CADENCE at n while G-VALID holds. Then the 2 s cadence at n is not demonstrated, and the cadence is a **user decision (D1)**: escalate with the measured numbers and the largest n that does pass. Present the options in the order of §2 — tighten the ladder, reduce n, change the cadence — and recommend none of them as a default.
3. **INVALID** iff G-VALID fails or the ladder mapping cannot be made conformant: fix the testbed and re-run; do not report partial numbers.

**Escalation path if the testbed cannot reach the intended n:** run the largest n the cloud quota allows, report it as the tested bound, and state explicitly that n beyond it is unmeasured. This is a coverage limit, not a result.

## 7. Worked example of the arithmetic (symbolic)

Measured for one cell: `Delta_hat` (worst region-pair p99 one-way delay), `X_hat` (p99 block processing), `T_obs(R)` (observed round duration at round R), the per-height intervals, the round counts.

Step 1 — the round-trip budget and the base:

    round_trip_hat = 4 * Delta_hat + X_hat                       [s]
    G-TRACE holds  iff round_trip_hat <= 1.5 s
    T_min          = k * round_trip_hat     [k in {2, 3, 4} admissible by CONS-07(2); k=1 is the churn control only]
    T_max          = 30 s                                         [CONS-07(2) proposed]
    R_cap          = ceil(log2(T_max / T_min))
    T(H,R)         = min(T_max, T_min * 2^min(R - R_progress, R_cap))

Step 2 — the cadence check:

    happy_path = round_trip_hat + commit_wait
    slack      = 2.000 - happy_path
    G-CADENCE  holds iff p99(block interval) <= 2.000 s
                    and p99(round completion + commit_wait) <= 2.000 s

Step 3 — the ladder's cost when a round fails:

    recovery_after_leader_failure ~= T(H,0) + round_trip_hat       [s]
    G-FAULT (leader) holds iff recovery_after_leader_failure <= 5 blocks * 2 s = 10 s

Step 4 — the n answer:

    fit p99_round(n) = a + b*n  (or a + c*log n), report the CI
    n_star = the n at which the fit equals 1.5 s; report only if n_star <= 1.5 * n_max_tested, else "beyond the tested range"

Step 5 — registration inputs:

    TIMEOUT_MIN = T_min ; TIMEOUT_MAX = T_max ; Delta_max = Delta_hat ; X_max = X_hat
    churn = heights_with_R_gt_0 / total_heights   [must be <= 1% in no-fault cells]
    conformance residual = abs(T_obs(R) - T(H,R)) / T(H,R)  [<= 10%]

## 8. Risks, confounders, and what makes the measurement invalid

| Risk | Why it bites | Control |
|---|---|---|
| Clock skew | per-height timestamps and one-way delays become noise | chrony on every node; pairwise skew check before/after; > 100 ms voids the run |
| Resource saturation (CPU, disk, provider bandwidth cap) | turns a network measurement into a host measurement; a packed-host shortcut makes this worse | per-node samples; p99 CPU > 80% invalidates the cell; the packed-host calibration gate |
| Region sample is not operator geography | cloud region RTTs are a proxy for a permissionless global set | record the measured delay matrix; state that results hold for that matrix only; the delay bound is an assumption (A-CONS-3), not a guarantee |
| Engine version / config drift mid-run | mixed versions produce meaningless percentiles | freeze image digest and config hash per run; record both |
| Static validator set | misses the epoch handover boundary cost (M2) | disclosed as an omission; no epoch transition occurs inside a run |
| Vote size vs vote format confusion | the added fields are a size effect | measure wire bytes; declare the +40 B upper bound; do not build the format |
| Fault injection leaking into the controller path | metrics/SSH break mid-run, corrupting the schedule | scope `tc`/firewall rules to the consensus port; verify the controller's own probes after each injection |
| Fake cadence from small blocks | empty blocks would flatter the result | primary payload is 131,072 B; empty blocks are a labelled control only |
| Percentiles from too few samples | p99 from < 300 samples is unstable | >= 300 heights per run, >= 3 runs per cell; report the count with every percentile |
| Recovery time measured against a moving baseline | the engine may not return to the same round-0 behaviour | compare against the same cell's no-fault p99, and report the comparison |

**Invalidity conditions (any one voids the run):** clock skew > 100 ms; p99 CPU > 80% on any node; a fault injection without a matching controller log entry; a config or image differing from the manifest; fewer than 300 heights; ladder conformance residual > 10% without a documented, corrected mapping.

**What would falsify the design decision this spike informs.** (i) At the target n, no admissible ladder `T_min >= 2*round_trip` achieves a p99 block interval <= 2 s in any topology → D1's cadence is not demonstrated at n, and the cadence decision goes back to the user, not to the engineers. (ii) Measured `round_trip > 1.5 s` at the tested geography → the committed trace's inputs, and the derived `T_min = 3 s`, are falsified; the ladder must be re-derived before `D_MAX`, `T_STALL` and the round budget are re-frozen. (iii) Churn above 1% even at the loosest admissible ladder → the delay distribution has a tail the timeouts cannot cover, and the topology (or n) is the binding constraint.

## 9. Artifacts to commit and where

Under `packages/protocol/docs/Etna/pos-zk/phase-b/artifacts/S2/`:

| Artifact | Content |
|---|---|
| `runs.json` | one record per run with every field of §5 plus the ladder mapping, fault schedule and config/image hashes |
| `summary.csv` | one row per (n, topology, k, fault, payload, run): percentile columns, churn, bandwidth, message counts, health |
| `delay-matrix.csv` | pairwise p50/p95/p99 one-way delays per topology, per run |
| `testbed/` | provisioning (terraform/ansible or equivalent), the pinned engine configs per k, container/VM image digests |
| `faults/` | injection scripts and the timestamped schedules actually applied |
| `raw/<cell>/<run>` | per-height intervals, per-round records, engine metric dumps, `tc -s` counters, node health samples, controller log |
| `calibration/` | the packed-host equivalence run, if the shortcut is used |
| `report` | `phase-b/S2-round-timing-report.md` — the measurement report with the versions, hardware, topology, delay matrix, workload, method, date and variance |

## 10. Effort and skills (estimate, not a measurement)

| Item | Estimate | Basis |
|---|---|---|
| Testbed stand-up (provisioning, clock sync, metrics, ladder mapping + conformance) | 2–3 engineer-weeks | plan §3 puts the S2 testbed in weeks 1–2 |
| Runs (24 trimmed cells x >= 3 runs x >= 300 heights) | 1–2 engineer-weeks plus cloud spend | steady state per run = 300 heights x 2 s = 600 s plus a 60-height (120 s) warm-up, plus deployment/teardown |
| Analysis, artifacts, report | 1 engineer-week | — |
| **Total** | **3–5 engineer-weeks** for 1–2 engineers | consistent with plan §§3, 6 |

**Skill profile.** Distributed-systems operations (CometBFT/Tendermint configuration, genesis and validator keys, P2P ports, Prometheus); Linux traffic control and firewalling for fault injection; cloud provisioning across regions; measurement methodology (percentiles, confidence intervals, sample-size discipline, monotonic clocks); Go or Rust for the generator/controller glue. No consensus-protocol design work is required — that is the point of using the stock engine.

**Hardware envelope (minimum for a valid run).** Per validator node: >= 4 vCPU, >= 8 GiB RAM, >= 40 GiB disk, 1 Gbit/s, one VM per validator in the primary cells; >= 3 cloud regions; >= 1 controller node; all nodes time-synchronised. Inter-region RTTs and any provider bandwidth caps must be recorded as part of the result, because the whole measurement is conditioned on the delay matrix (A-CONS-3).
