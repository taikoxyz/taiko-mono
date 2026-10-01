c60b2042af3d422fff96e79c59f283b40cab41a5

# Round 08 — independent judgment

**Current-round verdict: R1–R7 pass at specification level. No new Critical/High normative defect is validated. All Medium residual risks below are retained and explicitly accepted within the bounded research specification, with rationale. This is not implementation or launch approval.** The anchor-removal follow-up is specified without an anchor transaction, custom pre-execution callback, privileged transaction position, or automatic SignalService write.

This verdict follows the predicates and counterexamples below, not a vote among reviewers or author status assertions. A missing rule would remain a specification blocker even if a future implementation could add it. Actual execution, proving, deployments, historic state, gas, economics and operating assumptions remain unverified.

## Provenance and isolation

The immutable input SHA is the first line above. The judge used inherited configuration; its exact runtime SKU is unavailable and unverified. Requested reviewer configurations were A=`gpt-6-sol/high`, B=`gpt-6-astra/high`, C=`gpt-6.1-sol/high`, each `fork_turns=none`. The requests and report labels do not attest to actual runtime identities. Root reported that A resumed in the original isolated agent after a coordinator progress interruption; no reviewer conclusion was supplied to this judge before its initial assessment.

Before any reviewer intake, I independently read the complete following input files through `git show` at that SHA, plus the clean R1–R7 requirements and current-round scope. Citations in this report use original source line numbers relative to `packages/protocol/docs/Etna/design/`.

| Complete input | Source lines |
|---|---:|
| `index.html` | 1–221 |
| `staging.html` | 1–234 |
| `codec.html` | 1–219 |
| `roles.html` | 1–313 |
| `accountability.html` | 1–217 |
| `checkpoints.html` | 1–150 |
| `migration.html` | 1–572 |
| `arguments.html` | 1–215 |
| `encoding-vectors.md` | 1–43 |
| `codec-vectors.md` | 1–102 |

I did not read README status, iterations, notes, git history, prior reports or linked author analyses during the independent pass. Mandatory pages themselves exposed prior-status assertions, particularly `index.html:4`, `roles.html:282,307`, `accountability.html:214`, and `arguments.html:7,162,165,208`; those assertions were disregarded as evidence. This is report-independent review, with disclosed embedded-status exposure.

The complete independent initial assessment was written to `/tmp/etna-anchor-scratch/judge08-initial.md`, SHA-256 **`8afe67de82e0c650ae463afe29052d56fb63f677fcd266159521a39f113722c0`**, before opening any reports. Root independently verified that hash and then authorized B/C intake, followed later by A. The initial remains unchanged; it already recorded all seven provisional passes, ten concrete traces, no validated Critical/High, and feasible Medium residuals. Current-round adjudication did not change that result.

| Authorized current-round report | SHA-256 of report read |
|---|---|
| `08-a.md` | `3dd81b63a36ad3f29719a75d75fa002024a704f853ddd490467bbe8c54e0d955` |
| `08-b.md` | `24d460505e00752708b2a2548a41e6e9cb72b23d807c94ce30db5822a463e391` |
| `08-c.md` | `c6f83e5770573b3b3f347d0ae42148cbe2e3c5da61eed70626c543bd78e05af9` |

All three full reports were read; truncated tool output was reread. No prior-round artifact had been read when the current-round adjudication in this file was first made durable. The current-round result therefore does not derive from previous convergence claims.

## Independent falsification traces

The following compact record preserves the substantive independently attempted paths. “Attempted Critical/High” describes the intended impact if a path worked, not a validated finding of that severity.

### J1 — first-block legacy root forgery

**Prerequisites/cost:** attacker can fund an ordinary transaction from the former public legacy sender and may match the old ancestors digest. **Actions:** (1) place `anchorV4` before any optional pin/reveal in the first Etna block; (2) supply a forged checkpoint; (3) try the retained SignalService syncer or router fallback; (4) use the root to release custody. **Intended gain/requirements:** false bridge authorization, R1/R2/R7; attempted Critical.

**Blocked.** Standard EIP-4788 writes the exact authenticated nonzero origin before every ordinary transaction (`codec.html:109–114`). Both old writers require a successful *current* timestamp oracle read equal to zero; missing/wrong code, failed reads and malformed returns cannot select legacy mode (`checkpoints.html:53–74`; `migration.html:461–483`). The migration proof must certify both guards and canonical runtimes before activation, and every inherited/fallback route is included in the retirement obligation (`migration.html:184,210,242,321`). A future implementation is not being asked to invent the guard. Its actual installation and client/prover parity still need validation.

### J2 — invented, stale or cross-layer checkpoint reveal

**Prerequisites/cost:** any ordinary caller, chosen header bytes and gas. **Actions:** (1) construct a header with a fabricated state root; (2) select a stale/future timestamp or nonexistent permanent pin; (3) try the extension in L1 mode; (4) replace an existing height with a different header. **Gain/requirements:** unauthorized custody root, R1/R2/R7; attempted Critical.

**Blocked.** Explicit immutable L2 mode, current nonzero-root guard, exact code hash/raw oracle interface and bounded exact-size return checks precede mutations (`checkpoints.html:23,53–73`). Pins accept only the processing block's current authenticated hash (`checkpoints.html:76–88`). A fresh reveal hashes the complete canonical header, checks parser bounds/minimality/nonzero root, and requires exact live timestamp or permanent-pin provenance (`checkpoints.html:90–97`). Existing records must match both nonzero fields; conflicting or half-empty records fail. Returning an identical existing authenticated record without a live ring read is idempotence, not new authority. A-LEGACY remains necessary for inherited records. Provisional pins roll back with their branch (`arguments.html:56–59`).

### J3 — ring expiry as a permanent checkpoint veto

**Prerequisites/cost:** producer excludes ordinary reveal calls, or a paid backlog/outage delays them. **Actions:** (1) let timestamp t's slot collide at t+8191 or later; (2) process `revealCheckpoint(t,header)` after expiry; (3) repeat until users cannot obtain a bridge checkpoint. **Gain/requirements:** delayed exits/checkpoints, R1/R2/R5/R7.

**The stale positive reveal fails as specified; the permanent-veto continuation is blocked under the stated progress premises.** The ring is not promised to last 8191 arbitrary blocks (`checkpoints.html:19,108`). A funded valid forced `pinCurrentOrigin()` transaction contains no expiring timestamp; it saves the origin selected when processed. A subsequent `revealCheckpoint(0,header)` has no ring deadline (`checkpoints.html:109,121–125`; `arguments.html:126–128`). Mandatory snapshot processing and nondecreasing origins place that pin at/after enqueue, preserving an earlier append-only source signal. The maximum-header type-2 reveal is bounded at 1845 bytes within the 2048-byte queue cap. Actual gas, valid nonce/balance/fees, archives and progress remain premises, and arbitrary Bridge claim sizes have separate limits. **Medium residual:** financed multi-step recovery can be slow or unavailable when those premises fail; no forged root follows.

### J4 — fake activation, reset H0 or preserve an old L1 writer

**Prerequisites/cost:** public activation/drain caller, calldata and gas; no upgrade authority. **Actions:** (1) omit frozen legacy work; (2) substitute a root or installation digest; (3) replay activation to reset queue/head/rent; (4) publish from the old L1 syncer after ACTIVE. **Gain/requirements:** state substitution or erased obligations, R1/R2/R7; attempted Critical.

**Blocked.** Stored-state tails and exact deterministic transitions fix finite prior work (`migration.html:421–429`). Activation independently compares READY, verifies the pinned installation relation, seals the adapter and installs the unique H0 atomically (`migration.html:283–341,426`). H0's origin sentinel is an exact-head-only exception, not a caller flag or checkpoint. L1 SignalService's writer switches through irreversible public phase (`migration.html:255`). Before ACTIVE, new force calls collect no fees or liabilities. The first real origin is at/after activation; the first empty cut defers requests once and installs the exact later snapshot. Unavailable old data or compatible proving blocks activation safely; it does not authorize skipping obligations or a DAO assertion of correctness.

### J5 — invalidate proofs with queue appends or starve a fixed request with old origins

**Prerequisites/cost:** attacker pays enqueue fees or can fund valid minimal proofs, DA and rent. **Actions:** (1) append just before each proof lands; alternatively (2) repeatedly accept empty-discretionary successors with reused old origins; (3) keep a victim outside the required prefix. **Gain/requirements:** wasted proofs or indefinite censorship, R1/R5/R7; attempted High.

**Blocked for a fixed admitted supported request during continuing canonical progress.** Inbox derives immutable required records from the parent-frozen cut/time, not a prover's replacement array (`index.html:138–158,184–190`). Later enqueues cannot change that proof's work. The 900-second origin-age cap eventually forces fresh snapshots; every next applicable child removes the first up to four due records. Codec rules put valid forced execution before discretionary work and publish rejected raw bytes too (`codec.html:117–121`). H0's one empty interval preserves rather than clears requests (`migration.html:337–344`). **Medium residual:** paid earlier backlog creates potentially long finite delay; later arrivals cannot add predecessors to the fixed victim. Total prover outage is a different premise failure.

### J6 — private first disclosure, copied payout or manufactured producer assent

**Prerequisites/cost:** private valid candidate/proof or copied public data, gas/DA/rent and chosen metadata. **Actions:** (1) register a detached digest/private manifest; (2) name another beneficiary or innocent publisher as producer; (3) reveal full data only at acceptance; (4) collect payment or slash the framed owner. **Gain/requirements:** undisclosed canonical replacement, payout diversion or false attribution, R2/R6/R7; attempted High.

**Blocked.** Staging requires actual publication and complete execution context; final acceptance requires the exact 360–900-second receipt, complete matching data again and the proof-bound body/blob relation (`staging.html:57–61,89–95,118–120`; `index.html:173–175`). Complete statement fields bind payment/job/producer identity. Exact typed producer authorization uses the direct or immutable registered key, and the accepted receipt retains its checked identity (`staging.html:123–157`). A competitor may generate its own proof/self-authorization for the same public context; this is open competition, not proof theft or an incumbent approval gate.

### J7 — cure late service defaults, multiply rewards or erase a worker miss

**Prerequisites/cost:** reserved signer/job collateral, authentic signatures, optional Q deposits and ordinary gas. **Actions:** (1) publish after +240 and claim cure; (2) re-sign later issuedAt, rotate key or change staging salt; (3) collect Q once per matching signer; (4) consume a job parent only after the deadline and claim cancellation. **Gain/requirements:** avoided liability or unbacked payment, R3/R6; attempted High for insolvency.

**Blocked.** Exact fragment/FR calldata creates immutable first-publication history; late/missing/mismatching publication directly proves default (`accountability.html:17–28`). Challenges cannot extend publishBy, only the first selected timely response earns Q, and every position slashes once (`accountability.html:31–38`). Changed issuedAt or claim kind is incompatible signed content; historical key and reserve terms survive rotation (`roles.html:78–91`). Job settlement uses immutable timely consumption/retirement, not today's head (`accountability.html:56–59`). Asset-specific coverage, state-first pull credits and permanent sinks prevent self-report minting (`roles.html:114–127`). **Medium residual:** undisclosed evidence can expire, and reporters can rationally decline; known admitted challenges still settle before release.

### J8 — profitable, Sybil or zero-rent canonical concentration

**Prerequisites/cost:** sustained proving/DA capability and sufficient external value, or no independent entrant willing to fund early competition. **Actions:** (1) give users soft X; (2) stage valid alternative Y early; (3) choose another owner/immediate-base context; (4) repeatedly win with profitable rent or wait ≥900 seconds using a fresh origin/stage; (5) roll back incompatible soft state. **Gain/requirements:** fees/MEV/censorship and unpaid soft rollback, R4/R6.

**Feasible Medium residual.** Exact-owner/immediate-base/height conflict evidence does not identify economic Sybils or traverse arbitrary ancestry (`staging.html:180–181`; `accountability.html:39–47`). Mature alternatives may win under L1 ordering; the soft result is expressly revocable (`index.html:80–83`). Rent is mandatory and identity independent, but its positive capture-cost bound requires A-COMPETITION(D<900); gain can exceed rent, and absent a willing competitor an incumbent can wait for zero (`roles.html:276–289`). This meets the literal demand for concrete auction/decay/cost mechanics and rationale, not a guarantee of diverse ownership or arbitrary-MEV deterrence. A disclosure of the risk does not make the trace blocked.

### J9 — expired evidence, uneconomic reporting or honest timeout default

**Prerequisites/cost:** authentic hidden claims/no funded reporter, or censorship/partition against an honest signer. **Actions:** (1) retain evidence beyond evidenceClose and release; or (2) keep honest publication out past its signed deadline; (3) enforce the objectively missed service promise. **Impact/requirements:** a true breach escapes punishment or an honest service defaults, R3/R6.

**Feasible Medium residual.** New evidence expires while admitted challenges remain settleable (`roles.html:82–87`; `accountability.html:199–211`). The 1-TAIKO reporting share need not cover gas; signatures cannot prove earlier gossip or malicious intent. Objective completion, finite liability and permissionless evidence still satisfy the specified penalty requirement. Universal detection, zero attribution error about intent, and unlimited customer insurance are not supplied.

### J10 — shorter L1 intervals or maximum workload degrade soft service

**Prerequisites/resources:** 12/6/4/2-second L1 production, expensive bounded blocks, missing dependencies or a long proof outage. **Actions:** (1) let direct BLOCKHASH expire; (2) demand maximum work at the advertised cadence; (3) continue soft issuance without accepted progress. **Impact/requirements:** UNKNOWN/late service or unsafe-horizon suspension, R4/R5/R7.

**No normative High established; performance remains unverified.** HeaderStore pins authenticated history while available; uniform 256-block windows illustrate 3072/1536/1024/512 seconds respectively, without converting the protocol window into a consensus wall-clock promise (`codec.html:75–78`; `index.html:220`). Timers use seconds, origins may repeat, and no future proposer schedule is consumed. One-second issuance, transport/execution latency and the 900-block unsafe horizon are explicit (`index.html:70–82,195–216`). Actual 10M-gas execution, dual-proof throughput, acquisition and inclusion budgets must be measured. Missing measurements cannot be called a passed SLA, but they do not imply an unstated authorization or checkpoint rule.

## A/B/C adjudication and deduplication

Every reviewer trace has the following disposition. Supporting predicates are those cited above and in the named reports; agreement alone is not a blocking argument.

| Report trace(s) | Adjudicated result |
|---|---|
| A1 false L2 withdrawal root | Blocked by complete proof/actual DA/current-parent/atomic checkpoint, J6 and `index.html:122–159`. Proof soundness failure would have Critical impact, but is not an identified missing relation in this candidate. |
| A2 old Anchor writer | Blocked by both certified current-zero guards before ordinary execution, J1. |
| A3 invented reveal | Blocked by exact provenance, complete header hashing and nonoverwrite, J2. A-LEGACY remains necessary for prior records. |
| A4 skipped fresh force escrow | Blocked beyond the intentional first-child deferral by exact H0/ACTIVE/snapshot rules, J4/J5. |
| A5 double legacy fee/bond loss | Blocked by one pending ID/hash, once-only queue advancement/credit and separate original bond ledger (`migration.html:257,421–456`). Actual escrow sufficiency and compatible legacy proofs remain launch gates. |
| A6 duplicate reserve/Q payout | Blocked by separate funded ledgers, first response and once-only slash, J7. |
| A7 late worker cancellation | Blocked by historical receipt time, J7. Voluntary acceptance of an impossible task remains worker-diligence risk. |
| A8 checkpoint expiry | Fixed-timestamp failure feasible; permanent veto blocked by current-origin pin. Medium recovery risk, J3/M4 below. |
| A9 cross-owner soft fork | Feasible Medium bounded-attribution/rollback/concentration risk, J8/M1/M2. |
| B1 first reveal/timely silence | First-disclosure acceptance blocked, J6. Mature Y and withholding until timely deadline remain Medium, M2. |
| B2 all incumbents/jobs disappear | No incumbent lease, open self-authorized replacement. Optional service/replacement delay remains Medium. Loss of *all* required proof capability has High availability impact under a failed A-PROVE premise, not a newly omitted safe escape. |
| B3 expiry/zero-rent trap | Stage at origin+541 cannot mature by origin+900; specified ineligibility. Rebuild fresh while unchanged-parent rent remains zero, J8. Medium cost/delay, no permanent lock. |
| B4 queue append/churn | Moving target and indefinite fixed-victim starvation blocked, J5. Paid backlog retained as Medium. |
| B5 ring expiry | Same J3/A8; current pin is the specified non-expiring recovery step. |
| B6 pin before source signal | Blocked by processing snapshot at/after enqueue, nondecreasing origins and preserved append-only signal (`arguments.html:127`). Correct-view/archive premises remain. |
| B7 shorter slots | Timely historical pin survives direct lookup expiry, J10. No hidden CL schedule; late pin failure and future parser incompatibility are explicit limits. |
| B8 migration commit/erased history | Abandoned deterministic commit has no exclusive worker and can be proved by another entrant. Missing historical witness/compatible proving can cause a High-impact safe halt; explicit preactivation blocker, not new unfilled predicate. No new force fee liability is admitted while blocked. |
| B9 repeated cheap wins | Feasible Medium ordinary-ordering concentration, J8/M1; cannot evade due FIFO or reset rent without progress. |
| B10 late default erasure | Blocked by historical consumption/retirement times, J7. Timely legitimate race loss remains unpaid work, M5. |
| C1 profitable positive-rent capture | Feasible Medium, M1. The 0.02-ETH/head symbolic external gain exceeds q(660), leaving about 0.6666666666666666 ETH after minimum rent over 100 captures. No gain cap is specified. |
| C2 zero-rent capture/entrant retreat | Feasible Medium, M1/M5. Fresh stage around head age600 can mature around960 at zero rent. Willing early competition is a stronger premise than available hardware/funds. |
| C3 Sybil/pipelined conflict/timely silence | Feasible Medium, M2. Exact owner or immediate-base predicate is absent; timely duties still prohibit no such soft rollback. |
| C4 capital/rational default | Feasible Medium, M3. 37,200/147,000-TAIKO efficient-cadence peaks and additional publication costs are real stated barriers. Default can be rational when 9 TAIKO plus report gas is cheaper than publication; no price or guaranteed recipient publication is assumed. |
| C5 paid backlog | Feasible Medium, M4. 10.5 ETH gross/5.25 sunk for 1000 enqueues from empty without consumption; victim quote0.021 ETH. 167,340 seconds is a conservative conditional upper bound, not exact achievable delay or measured throughput. |
| C6 uneconomic work/canceled job | Feasible Medium incentive risk, M5; complete willing-prover loss can have High availability impact. Four minimum force fees yield0.002 ETH to processors, not guaranteed dual-proof/DA/gas recovery. Early competing success can cancel bounty without insuring wasted work. |
| C7 uneconomic reporting | Feasible Medium, M6. Permissionless evidence and fixed payout exist, but 1 TAIKO need not cover report cost; effective enforcement may be zero. |
| C8 checkpoint omission | Same J3/A8/B5. Expiry-based permanent veto blocked; multi-step cost/delay remains Medium. Final Bridge claim has independent explicit resource limits. |
| C9 Sybil fee/refund/reset escape | Blocked: half of processed force fees and all actual rent remain sunk; only excess returns to caller; self-slash loses90%; stages/quotes/jobs/failures cannot reset rent (`roles.html:114–127,267–279,288`). |
| C10 private stage/priority/job squatting | Blocked by actual old publication, exact deterministic ID/context association and no canonical lease. Paid inspection/lifetime-state growth remains a resource residual, not a reserved head (`staging.html:89–95,118–121,230–232`). |

No report established a new Critical/High normative finding. **High availability impact from total archive/proving premise failure is not relabeled as harmless:** launch must verify those inputs and cannot proceed without them. Conversely, inventing a no-proof checkpoint/timeout waiver would break safety rather than repair that impact.

## Written Medium dispositions

These are all feasible residuals, **accepted for this bounded design review**, not user approval to operate or deploy and not claims of mitigation. No Medium is left without disposition.

| ID and coverage | Decision and rationale | Consequence that remains |
|---|---|---|
| M1 — concentration and repeated capture; J8, A9, B9, C1–C2 | **Accepted bounded risk.** Literal R6 requires concrete anti-monopoly mechanics/rationale. Uniform irreversible rent, decay, same-block reset cost and an explicit external-gain inequality supply those. A false promise of fair shares would fail; none is normative. | High MEV can pay rent; absent a willing early competitor all wins may be rent-free. Calibrate demand, external gain, peak price and entrant budgets before launch. |
| M2 — soft rollback, selective timely disclosure and attribution gaps; J8, A9, B1, C3 | **Accepted bounded risk.** R4 defines cadence/latency and does not require pre-L1 finality. R6's exact signed duties can be objectively enforced without pretending to identify common owners or global first receipt. | Mature alternatives, distinct owners and different immediate bases can escape conflict slashing. Clients must preserve revocable/UNKNOWN semantics; custody cannot consume soft roots. |
| M3 — bonded-service capital, publication costs and rational defaults; C4 | **Accepted optional-service risk.** Objective entry/exit and finite reserved penalties exist; raw canonical entry does not require continuous bonded-service capital. Ten TAIKO is not an insurance valuation or ETH gas budget. | Voluntary service may exit or pay defaults rationally; mandatory fragment publication needs actual financing/customer demand. Threshold examples are symbolic, not market measurements. |
| M4 — paid FIFO delay and checkpoint recovery expense; J3/J5, A8, B4–B5, C5/C8 | **Accepted finite-delay risk.** R7 supplies eventual proved processing under progress, not a uniform short SLA for arbitrary earlier paid backlog. Current-origin pin removes the specific expiring-request veto. | Two queue passes, gas, data witnesses and valid sender funding can materially delay checkpoint usability. Oversized/failing operations are not promised successful execution. |
| M5 — proof profitability, race losses, expiry/rebuilding and service outage; B2–B3/B10, C2/C6 | **Accepted operating premise/risk.** Open entry removes an authority gate; it cannot ensure profitable dual proving or reimburse losing work. No job reserves the canonical parent, and stale work is never accepted to restore liveness. | Willing funded entrants, both proof capabilities, sustainable throughput and fresh rebuilding remain necessary. A total absence causes safe halt, with potentially High availability impact. |
| M6 — finite evidence, reporter economics and honest timeout default; J9, B1, C7 | **Accepted bounded accountability risk.** Objective deadlines, permissionless evidence, payout splits and false-evidence rejection satisfy the scoped requirement; they do not establish actual observation, infinite retention or intent. | Enforcement can be zero after hidden/uneconomic evidence expires; censorship can default an honest signer. Admitted challenges must still settle before release. |

## All-seven requirement judgment

| Gate | Falsification result and decisive evidence | Final current-round disposition |
|---|---|---|
| R1 — permissionless; DAO upgrades only | No surviving normative incumbent/admin gate: open roles and replacement; contract provenance separated from human admission; every owner/pauser/resolver/quota/initializer/fallback path must retire (`roles.html:48–63`; `migration.html:197–213,249–258,461–483`). | **PASS design.** Actual selector/ownership deployment audit remains open. Funding, data and malicious-upgrade assumptions are explicit. |
| R2 — retain shared custody addresses/state | Exact retained checkpoint ABI, mode-specific provenance, unchanged VERSION1 maps/cache/signal/message formats and complete shared/wrapper change inventory (`checkpoints.html:23–49,76–97,127–135`; `migration.html:24–26,58–82,137–188,217–223`). | **PASS specification.** No replacement frozen address is required. Live manifest, layouts, legacy history and migration-state proof remain launch blockers. |
| R3 — complete role lifecycle/failure analysis | Role table covers entry/exit/duties/rewards/slashes/all-offline/malicious behavior; independent finite reserves and historical settlement block overbooking/escape (`roles.html:48–109,114–127`; `accountability.html:31–61`). Pin/reveal has no invented operator duty. | **PASS design**, with M3/M5/M6. Optional-market success is unproved; no implementation may add unstated withdrawal or admission discretion. |
| R4 — ≤1-second preconfirmation cadence | One-second issuance,0…1-second scheduling plus transport/execution, provisional validity and900-block unsafe horizon are explicit. Origin reuse decouples early sealing from a new L1 block (`index.html:70–83,194–205`; `codec.html:59–61`; `arguments.html:80–82`). | **PASS timing specification**, with M2/M5. Neither unconditional≤1-second end-to-end latency nor measured 10M-gas/dual-proof throughput is established. |
| R5 — no CL lookahead/L1-slot coupling | Historical authenticated headers, L1 block numbers and second-based timers; no future validator schedule. Timely HeaderStore pins support12/6/4/2-second interval reasoning (`index.html:68–70,218–220`; `codec.html:75–78`; `migration.html:432,517`). | **PASS design.** Acquisition/inclusion/parser/runtime conformance must hold; no fixed implementation promises compatibility with every future fork. |
| R6 — objective penalties and concrete anti-monopoly economics | Every specified offense has L1-verifiable evidence, open submitter, once-only payout/sink and invalid-evidence treatment. Concrete rotation/cap rejection, auction, decay, costs and rationale are tabulated (`accountability.html:17–61`; `staging.html:123–181`; `roles.html:200–290`). | **PASS bounded mechanism**, with M1–M6 where applicable. No fair-share, universal enforcement, profitable-service or unlimited-MEV result follows. |
| R7 — propose with proof | Single canonical action carries full matching DA plus complete dual proof, exact parent/FIFO/producer/rent and atomic checkpoint. Prior staging has no canonical ordering right; minute-level proving/maturity/failure/finality and blob/calldata paths are defined. H0 and first snapshot are exact (`index.html:122–190`; `staging.html:118–120`; `migration.html:283–344`; `codec.html:109–121`). | **PASS design under literal earlier-copy-permitted R7.** Dual-backend size/gas, complete KZG/body relation, archival recovery and launch performance remain unverified. No proofless canonical escape is authorized. |

## Validation, limitations and stopping record

I independently reproduced all **17 named digest outputs, two fragment-boundary digests and six rent values** in the supplied vectors with scratch-only Keccak/ABI arithmetic, after checking Keccak's known empty-input and `abc` answers. An initial optional `Crypto` import was unavailable; the subsequent self-contained calculation passed. No arithmetic code file was retained. This is component consistency, not a valid execution/proof fixture, Solidity/Go/Rust parity, real migration, gas measurement or deployed-state attestation.

Unverified launch evidence remains: exact complete proving relations and usable dual artifacts; full KZG/blob and canonical execution enforcement; EIP-4788/2935 canonical runtime plus builder/importer/guest parity; complete selector retirement, immutable modes and code hashes; live proxy/layout/owner/treasury/legacy-escrow manifest; preserved historical messages/data; maximum pin/reveal/forced/publication/report/verification gas; one-second execution and sustained proving; staged-blob retention; fresh-header acquisition; economic willingness/calibration. These do not excuse a missing safety rule. They prevent converting this design pass into implementation or launch approval.

The current-round judgment satisfies this round's conditions: no validated new Critical/High, all Mediums disposed of with rationale, and all R1–R7 pass at specification scope. **Two-consecutive-round convergence is not yet adjudicated in this first durable version.** No prior-round report has been used; the authorized prior-round comparison must be added only after separate intake permission. The cap is eight rounds; this judgment does not authorize an additional review round or production work.

## Authorized convergence comparison and final stopping verdict

The paragraph immediately above records the first durable, pre-history state of this report. Root verified its SHA-256 as **`552740ac0f04db1d280a22cb44e02ebe2eebb2d8dfc6575a6b7b829621887fe7`** and only then authorized intake of `07-judge.md` and `07-round.md`. I read both in full and no other history. Their hashes were respectively **`4e2a19f2c5aa7830888268f9762cbda0e7a9d77896173461f061a65ba81cb858`** and **`96aae5426a5ea29c63f2daba69540e0225df6c2c9e6fb61d019ebc3bb4482036`**. The independent initial hash and current-round reasoning above remain unchanged.

### J07-M01 checked against candidate 08

The previous judge reviewed `575d41a5ad2aa1a276c9a491cd04dcd4d1f8d8c2`, established zero Critical/High, and required one Medium correction: new Etna `force` intake could accept user fees while DRAINING had no executable Etna head and could remain blocked on old evidence. Its R7 verdict was narrowly Fail on that immutable candidate. The coordinator's claim that a later correction was applied is not the evidence for closure.

Candidate **`c60b2042af3d422fff96e79c59f283b40cab41a5`**, independently read before any prior report, contains the exact required predicates:

1. `index.html:185` requires ACTIVE before any force state or fee effect. PREPARED/DRAINING revert; legacy obligations still drain under their original rules.
2. `migration.html:249,253,330–337` rejects force before ACTIVE without appending records, allocating escrow, or creating excess credits. It initializes the new queue once as empty and requires zero internal request liabilities at activation; unsolicited ETH is surplus and is not a reason to clear or invent liabilities.
3. `migration.html:321,337` makes verification, sealing, H0 installation and phase transition atomic; activation never clears unexpected records or escrow. The read-only quote creates no admission promise.
4. `migration.html:339–344` preserves H0's once-only empty interval, includes successful post-activation same-block enqueues in the first real origin's exact end-of-block snapshot, and applies the ordinary FIFO afterward. The numerical example and conditional progress statement cover ACTIVE arrivals. `arguments.html:87–94` likewise excludes new pre-ACTIVE escrow.

**J07-M01 is mitigated at specification level.** The earlier trace now reverts at its second step, before accepting the new user's fee. No DAO refund, erased legacy work, invented proof, replaced address or custom system call was added. The visible intake gap during finite legacy draining is the explicit correction. Migration can still be blocked by missing old evidence, with the existing old obligations preserved; it cannot accumulate the new Etna liabilities identified by J07-M01.

### Complete carry-forward disposition

| Prior finding | Current evidence/disposition |
|---|---|
| J07-M01 — pre-ACTIVE new force escrow | **Mitigated**, by the precise candidate predicates above. This is a normative fix, independently covered by J4/J5 and A4/B8 in the current round. |
| J07-M02 — paid FIFO delay | **Accepted**, current M4. Finite paid backlog is real; later arrivals cannot overtake. Queue-dependent latency and measured capacity remain necessary. |
| J07-M03 — caller funding/archive dependence | **Accepted**, current M4/M5. A funded valid L2 sender and authentic state/header witnesses remain necessary for forced pin/reveal. No relayer subsidy or data-reconstruction oracle is inferred. |
| J07-M04 — not every Bridge operation fits force limits | **Accepted as a distinct Medium scope limitation within M4.** A valid ordinary Bridge proof/target operation larger than2048 bytes or1M gas can remain omitted indefinitely by an incumbent even while supported forced work progresses. Forceable pin/reveal alone does not make that later operation forceable. R2's retained-address/state/interface criterion and R7's expressly bounded supported force path do not supply that broader guarantee (`checkpoints.html:124,129`; `arguments.html:95,127`). M4's finite-delay claim applies to admitted supported requests, not this unsupported-operation case. A broader guarantee would require a separately specified resource/interface revision. |
| J07-M05 — profitable/zero-rent concentration | **Accepted**, current M1. Preserve only the explicit competitor/net-gain theorem; uniform costs do not establish ownership diversity or profitability for entrants. |
| J07-M06 — bonded service capital/data costs | **Accepted**, current M3/M5. Actual sustained throughput and market feasibility remain unmeasured. No gas-floor scenario establishes a total-cost benchmark or useful full-load one-second service. |
| J07-M07 — losses outside finite predicates | **Accepted**, current M2/M6. Exact-owner/context attribution, timely publication, finite reserves/evidence and revocable soft results remain explicit limits. |
| J07-L01 — uneconomic/late reporting | **Accepted and conservatively included in current Medium M6**, together with finite evidence and honest timeout default. The severity grouping changed; the absence of inevitable punishment was not dropped. |
| J07-L02 — permanent pin state growth | **Accepted Low residual.** Each distinct authenticated current origin may add one permanent bool; duplicates do not grow state (`checkpoints.html:76–88,119`). An integrated coinbase may recapture ordinary L2 fees, so those fees are not claimed to be an irreversible attacker cost. Long-run state/proving cost still needs measurement. |
| J07-L03 — stale anchor/review terminology | The central normative replacement is present: `staging.html:60` refers to standard pre-execution calls and `codec.html:109–114` expressly forbids an anchor/synthetic transaction. Prior-status assertions are scoped/disregarded, not evidence. **Retain a Low editorial residue:** `staging.html:113` still says “affected anchors” while describing fresh-context rebuilding. Read it under the explicit origin/system-call rules; it creates no valid alternate anchor path. A terminology cleanup does not change the reviewed relation. |

### Stopping test at the eight-round cap

| Required stopping condition | Evidence and result |
|---|---|
| Two consecutive rounds with no new Critical/High | Round07's independent judge records zero established Critical/High on its anchor-removal candidate. The independently sealed and adjudicated round08 likewise validates none. **Met.** Potentially severe consequences of failed proving/archive/deployment premises remain acknowledged. |
| Every Medium mitigated or explicitly accepted with rationale | J07-M01 is mitigated by current written rules; every other prior Medium and every current Medium has the scoped dispositions above. No feasible risk is converted to a blocked trace by disclaimer alone. **Met.** |
| Current R1–R7 pass | The current all-seven matrix passes after independently checking ACTIVE-only intake, exact H0/FIFO and anchor-removal provenance. **Met.** Round07's R7 remains Fail for its old immutable candidate; this is not a claim of two historical all-gate passes. |
| Maximum eight rounds | This is round08. No additional round is assumed or authorized. **Reached.** |

**Final verdict: the stated research stopping criterion is met at round08. Stop the review cycle with conditional specification convergence.** The criterion is two consecutive rounds without a new Critical/High, all Mediums mitigated/accepted in writing, and all *current* gates passing. If a different rule required every gate to have passed in both immutable snapshots, these records would not satisfy that stronger rule; no such substituted rule is used here.

This final disposition authorizes no production implementation, deployment, transaction or launch. The explicit unverified launch gates above remain, and future material changes require their own review. The final file hash is reported separately to avoid a self-referential embedded hash.
