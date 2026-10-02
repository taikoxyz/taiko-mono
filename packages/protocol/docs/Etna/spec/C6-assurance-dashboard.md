# C6-B. Assurance dashboard

**Owner:** B. **Reviewer:** A. **Independent reviewer:** J.

**Status [open]:** W6 review snapshot, 2026-10-01. The converged specification is **not ready**. This index defines no protocol rule, parameter, new limitation acceptance or exception to R1–R7. A owns C6's threat model, invariant synthesis and accepted-limitations register. [WORK](../WORK.md) alone records task completion; A alone updates it. Source revisions below are immutable: a later PR head does not inherit a verdict from this snapshot.

## 1. How to read the evidence

**[assumed: documentation convention]** **Proven** means an argument under its named premises, not machine verification. **Assumed** identifies a proposed mechanism, a trust/economic premise or a source-reported result. **Open** identifies missing semantics, a decision, review or evidence. **Unmeasured** identifies a quantity for later implementation measurement; D2 permits it and does not by itself make a coherent specification unready. Missing signed fields, undefined state transitions and contradictory accounting are semantic opens, even if they affect performance.

**[assumed: index boundary]** Rule IDs resolve to the owning source, not to a paraphrase here. The [unmeasured register](C6-unmeasured-register.md) lists every supplied section's numeric-register rows by identifier or exact source label and gives measurement closure tests. C5, C8, S4 and A's C6 half are pending integration artifacts at this snapshot; no IDs or verdicts are fabricated for them.

**[open: external implementation status, 2026-10-02]** The register's [client/Catalyst evidence record](C6-unmeasured-register.md#external-implementation-evidence-outside-d2) tracks #22207 at `1170344842dec57b1a4dcbc5a2d68a9f920a0895`, which explicitly rejects Etna preconfirmation. Anchorless client support is not evidence that D1's confirmation layer executes. C5 owns the dependency classification and C8 the interface integration; this observation neither establishes an Ethereum ePBS requirement nor adds implementation to D2's specification-readiness gate.

| Source | Immutable revision / entry point | Review state evidenced here |
|---|---|---|
| C1, execution/checkpoints | [6f3834077, C1](https://github.com/taikoxyz/taiko-mono/blob/6f38340771752c76484adf55abebd9ff9f19a18a/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md), #22195 | **Open:** A's follow-up applied; new verdict pending. J closed J-1/J-2 at the preceding 75616d5, not a blanket approval of future edits. |
| C2, landing | [f67d4d4, C2](https://github.com/taikoxyz/taiko-mono/blob/f67d4d47e7c7b3ac960d4434ac28e5dedf5b64da/packages/protocol/docs/Etna/spec/C2-landing.md), #22196 | **Open:** four original B findings closed; [new Medium hash-domain ambiguity](https://github.com/taikoxyz/taiko-mono/pull/22196#issuecomment-5934018060) blocks B approval. |
| S2, certificates/handoff | [0403a54, S2](https://github.com/taikoxyz/taiko-mono/blob/0403a540a2186f404d7e5bff99496d29a7be3789/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md), #22197 | **Open:** B request-changes; D16 adopts repairs, revised text and new verdict still required. |
| C7, block validity | [0583a6f, C7](https://github.com/taikoxyz/taiko-mono/blob/0583a6fdd249c22862df93b257a0cf79c7b98136/packages/protocol/docs/Etna/spec/C7-block-validity.md), #22199 | **Open:** B request-changes; D14/D17 decide repairs. J's later D14-only closure does not close the other B findings. |
| C3, forced inclusion | [185ed1c, C3](https://github.com/taikoxyz/taiko-mono/blob/185ed1c4c8185d29f1228d597fc1a352bd8f8974/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md), #22200 | **Open:** B request-changes; D18 adopts repairs. J's later age-bound closure is distinct from the new accounting/clock findings. |
| S1, seats/sortition | [dbdcc3d, S1](https://github.com/taikoxyz/taiko-mono/blob/dbdcc3dc5bf9475429edcbe2ba025301805f515d/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md), #22201 | **Open:** B request-changes; D19 adopts walk/exit/recycling changes, not yet verified in a revised source by this index. |
| S3, slashing/economics | [1383e06, S3](https://github.com/taikoxyz/taiko-mono/blob/1383e06c9ac601aa7e0e25737111024422824dc5/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md), #22202 | **Open:** B request-changes; D20 adopts actual-backing and comparator repairs. The old nominal credit bound is superseded. |
| C4, migration | [744234398, C4](https://github.com/taikoxyz/taiko-mono/blob/744234398514746baefc99710fd267356a1d0bbf/packages/protocol/docs/Etna/spec/C4-migration.md), #22205 | **Open:** [J found no Critical/High and supported DL-3 conditionally](https://github.com/taikoxyz/taiko-mono/pull/22205#issuecomment-5934289378) at this pin; B's clarification revision and A's arbitration remain pending. |
| Decisions | [ef22fce25, D1–D20](https://github.com/taikoxyz/taiko-mono/blob/ef22fce253b348506193398e9697f1c52e4b8fe2/packages/protocol/docs/Etna/DECISIONS.md) | **Assumed: record:** adopted directions can supersede a source claim, but do not prove the replacement is internally consistent or merged. |

## 2. Assurance claims and their dependencies

| Claim | Owning argument | Evidence / boundary |
|---|---|---|
| No mandatory Anchor transaction | C1-R01/R02/R07/R09, §7 | **Proven conditionally:** standard operations precede ordinary execution; current-root guard closes old writers. Premises include A-EXEC, A-HISTORY and authenticated origins. **Open:** C4 installation manifest and client/guest conformance. |
| Checkpoint root/header integrity at the existing service | C1-R06/R08, §7; C2-R04/R19 | **Proven conditionally:** full-header authentication and single L1 ancestry bind number/hash/root; same-epoch conflict is not overwriteable. **Open:** C8 codec/profile vectors and C4 inherited-history audit. A pin does not establish finality or data availability. |
| Local block validation and landed acceptance | C7; C2-R04/R05; D17 | **Assumed:** D17 distinguishes VALID_GOSSIP from VALID_LANDED. **Open:** total mode table, carried-object hash branches and S3 evidence for a bad carried certificate. Do not teach these as identical predicates. |
| Slashable user-actionable confirmation | S2-R18; S3-R10; D16/D20 | **Open:** only the equivocation route has the promised slash evidence, under its committee/history assumptions and current collectible backing. The exceptions below remain visible. No positive numeric bound is copied from superseded S3 text. |
| Proof and data land together | C2-R01–R05; C5 | **Assumed:** one atomic landing action binds data/proof, recipient and parent. **Open:** final frame/mempool semantics and full codec integration. A copied proof retains its bound recipient; a different recipient needs a new proof. |
| Forced progress despite withheld or unprovable work | C3-R05–R11; C2-R08; S2 | **Open:** D18 repairs positive-due authentication, one-cut accounting and irreversible settlement. D12 accepts the genuine stall/void residual; it does not excuse a falsified clock or duplicate payout. |
| Existing custody survives migration | C4-R01/R05/R09–R13 | **Proven conditionally:** authenticated retained state and exact layout/authority preservation keep message/token identities and custody. **Open:** legacy FI adapter, bootstrap integration, actual deployment manifest and R1 authority interpretation. |
| DAO is not a normal liveness actor | S4; C2-R11–R14; C4 | **Open / fails in named exceptional cases:** C2 explicitly requires DAO recovery in CONFLICT and admits an uncertified regime with a prover-backend outage. This candidate is not an unconditional discharge of original R1. |

**[assumed: dependency projection]** The following is an index, not a second state machine:

```text
C1 execution + S1 assignment + S2 certificates -> C7 gossip validity
                       |                              |
                       +---- C3 forced rules --------+
                                                      v
                              C2 data/proof landing -> custody publication
                                                      |
C4 retained-state migration -> same SignalService / Bridge / Vault addresses

S3 owns accountable collateral; S4 owns the composed safety/liveness argument.
C5 owns L1/frame dependencies. C8 owns exact encodings and physical layouts.
```

## 3. What the confirmation labels permit a user to conclude

**[assumed: S2-R18 projection, not replacement text]** A displayed label identifies both the observed history and the assumptions it relies on. Missing context is not a known invalid block. Execution validity is not canonical inclusion. L1 inclusion is not Ethereum finality. A checkpoint is a custody authorization and must follow C2's publication rule, not merely the local label.

| Observation | What may be stated | What remains outside that statement |
|---|---|---|
| Locally valid / preconfirmed | C7's applicable gossip predicate passed for the node's authenticated context. | **Open/assumed:** propagation, canonical extension, data retention and later landed identity. |
| LOCKED | S2's locking condition and S3's currently collectible evidence-backed amount, with applicable committee/opening identity. | **Assumed limitation:** S2-R18 discharges D1 for equivocation only. Protocol-authorized replacement or forced recovery after the deadline machinery, an L1 reorg, redraw/FALLBACK exceptions and governing upgrades can remove work without the nominal equivocation slash. D20's backing update still needs source-level review. |
| Landed, provisional | C2 accepted the journal but withheld the custody checkpoint under its provisional rules. | **Assumed limitation L-PF:** later confirmation/finalization or CONFLICT recovery determines its fate; elapsed time is not proof-system soundness. |
| Checkpoint published / L1-final | C2's publication predicate passed; Ethereum finality is separately observed for its L1 history. | **Assumed:** accepting proof systems, any named quorum premise in degraded mode, implementation correctness and future upgrade policy. A finalized bad authorization cannot be repaired by hiding its checkpoint afterward. |

**[open: D1 integration]** The scoped confirmation is a candidate product with explicit exceptions, not an unconditional promise that every reorg compensates a user. D1 does not itself require victim compensation. D20 must nevertheless avoid advertising already-spent collateral as backing for another confirmation: historical assignment stability and current economic backing are different facts. S3/S2 own the exact formula and observation point; C6 copies neither an old nominal number nor a pending replacement formula as an approved value.

## 4. Limitations index for A's accepted-limitations register

**[assumed: ownership]** These rows link owning rules/decisions and preserve acceptance status. They do not accept a new risk on A's or the user's behalf. A's C6 register supplies the final limitation text, severity, acceptance rationale and links to J's verdict. A historical candidate limitation is input, not a completed convergence review.

| Record / owner | Status and consequence that must remain visible |
|---|---|
| L-PF / C2-R12–R15 | **Assumed proposed limitation:** provisional work can be rolled back after a proof conflict; CONFLICT stops all landing, including forced batches, until a DAO upgrade selects recovery. Already paid rewards and FI fees are not clawed back. Restart costs and custody cases are indexed below. R1 remains qualified. |
| C2-R14 custody residual / C4-R12/R13 | **Proven conditionally unreachable on the stated protocol path:** no reverted suffix checkpoint was published. **Open outside that premise:** cached signals, completed transfers and retry authorizations survive a checkpoint-map epoch change; C4 prohibits rollback below the newest published checkpoint. No cache-reset shortcut is approved. |
| D12 genuine stall / C3 | **Accepted Medium by D12:** due honest entries can be voided with poison and need resubmission; repeat stalls have the owning section's time/price bounds. D18 repairs are necessary before reusing that argument. Voiding a reveal is not successful checkpoint recovery. |
| L3/L5, S2-R13/R18–R20 | **Open or conditionally accepted in owning text:** private quorum, L1 recording race and fallback routes limit slashable finality. Do not turn a timeout into an objective proof of P2P withholding. Archive/inclusion/funding assumptions stay explicit. |
| L14, S2-R18 and C2-R10 | **Open semantic alignment:** reward/deadline clocks and the actual landing horizon are distinct; use the appropriate owning predicate when reporting replaceability or expiry. |
| L16/no-committee launch, S1-R13/R18 and S2-R18 | **Assumed disclosed limitation:** the owner/seat launch counts are a Sybil-able heuristic, not an enforced safety gate. Launch or later churn can produce no-committee terms, with no LOCKED label and certificate-free proving requirements. This row belongs beside the launch condition in A's register. |
| L19, C2-R11 | **Assumed disclosed limitation:** certificate-free operation cannot use the certified single-leaf fallback. A required backend outage can halt it and require an upgrade. Do not mark R1 universally passed. |
| L20, S3-R23/S1 | **Assumed disclosed limitation:** reserve routing and lapse timing can expose temporarily unfunded duties. D20 changes actual backing; the old nominal collateral claim is not preserved by accepting L20. |
| Retention / C2-R18/S2-R22 | **Assumed:** attesters retain bytes under the stated duty. Minimum duty and maximum landable horizon differ; archived retrieval is a distinct premise. A hash is not a byte archive. |
| C2-R02 witness reuse | **Assumed disclosed limitation:** multiple valid signature witnesses can make different data commitments and duplicate proving expense for one state range. Proof reuse fixes both recipient and exact blobs. C8 must also classify VC witness bytes under D16. |
| C4 migration / P-B-C4-01 | **Open proposal:** deadline abandonment loses ordinary unfinalized content and retains authenticated forced requests with already-paid fees zeroed. The original fee is unrecovered and is not paid again; requeue creates no new bond or refund entitlement and replay can require self-funding. J's DL-3 support requires this consequence to remain user-facing. Legacy execution compatibility remains C3's obligation. |
| Retained DAO powers / P-B-C4-02 | **Open product interpretation:** A directs retained DAO-only withdrawal/resolver/token powers; original R1 permits only upgradeability. Equal governance latency is not a proof that these selectors satisfy the original wording. |
| C1 permanent state / §7/§9 | **Proven conditional per-origin bound; open lifetime economics:** distinct origins add permanent pin/checkpoint state. No global storage-growth or anti-monopoly guarantee follows from a local bound or producer-recoverable gas. |

### L-PF restart cost, without an invented subsidy

**[assumed: source accounting, C2-R14 plus C3 D18 and C4-R06/R12]** For the actual restored suffix, report separately (a) paid landing/attestation/pin rewards, (b) paid FI fees/refunds and burned entry deposits, (c) new proving/DA/L1 costs of replay, and (d) value acted on against reverted L2 work. These have different beneficiaries and may use different denominations. Report TAIKO and ETH amounts separately; conversion uses S3's explicitly unmeasured price premise, never an assumed permanent exchange rate.

**[proven: accounting identity only]** The unrecovered protocol payouts are the sum of the actual irreversible debits/credits in that suffix, not a second entitlement created by rewinding an execution cursor. A time bound on the reverted suffix is not itself a monetary bound. C2/S3's per-term debit bounds can bound the reward component only after the applicable paid-term count and all self-landing/settlement paths are derived. FI fees and economic user losses require their own bounds. This index does not invent a constant total restart cost.

**[open: measurement and funding]** C2/S3/C4 must supply the replay workload and actual collectible payer balances; the unmeasured register covers both proving leaves, retransmission/data publication and L1 execution cost. D18's irreversible settlement prevents paying an old deposit twice; it does not automatically finance a replay prover. A governance resolution time is unbounded by this protocol, so no unconditional restart-time or DAO response-cost guarantee is stated.

**[assumed/proven conditional: custody distinction]** C2-R14 separates a publication bug from an extraordinary upgrade below published custody. For a configured capped asset, the actual QuotaManager's available balance and refill rules limit authorized outflow over a specified interval; quota zero is unlimited. A rate multiplied by the provisional interval alone omits the DAO-response interval, initial available capacity and outstanding retry semantics. For a deliberately deeper rollback, exposure begins when the oldest invalidated authorization became usable, which C2 does not bound. A quota is not a lifetime loss cap or a revocation mechanism. C4's permitted restart preserves valid cache/retry history and does not authorize this deeper rollback.

## 5. Requirement and readiness gates

| Gate | Snapshot verdict | Evidence needed to change it |
|---|---|---|
| R1 permissionless, DAO upgrades only | **Open; current stated exceptions fail its unconditional reading.** | C2/S4 reconcile CONFLICT/uncertified-outage recovery and C4's retained operational powers with the user's requirement or obtain an explicit product relaxation. This is not an impossibility proof for all possible designs. |
| R2 existing addresses and compatible shared upgrades | **Open, conditionally designed.** | C1/C4/C8 complete the retained deployment/layout/ABI manifest and legacy service adapter, with A/J review. |
| R3 all roles and all-offline/malicious cases | **Open.** | S4 role catalogue composes S1/S2/S3 and permissionless migration/caller paths without an unnamed trusted role. |
| R4 cadence and soft-confirmation latency | **Assumed target, unmeasured.** | Coherent S2/C7 timing/labels; index later propagation/execution/proving measurements. D2 permits absent measurements, not inconsistent timing semantics. |
| R5 no lookahead or slot-coupled timing | **Conditionally supported; open composition.** | C5/S4 verify every rule's units and header/history assumptions under changed L1 cadence; hypothetical slot examples are not protocol clocks. |
| R6 objective slashing and anti-monopoly | **Open.** | D16/D19/D20 integrated evidence, exits, immutable rank selection and collectible collateral; S3/S4 state cartel/Sybil limits without claiming per-address caps identify entities. |
| R7 atomic data-plus-proof landing | **Conditionally designed; open integration.** | C2/C3/C5/C8 jointly define the exact proof/data/frame/journal shapes, prover failure, DA/finality and fallback behavior. |
| D1 slashable actionable confirmation | **Open, equivocation-scoped candidate.** | S2/S3 reviewed identity/evidence/backing plus disclosed unslashable recovery exceptions and product-scope acceptance. |
| D2 spec-level readiness | **Not met yet.** | Close semantic/encoding/state-machine gaps; A/J approve immutable section revisions. Measurements may remain explicitly unmeasured. |
| Convergence | **Not met.** | Merged specification passes the charter's consecutive independent red-team rounds and J's readiness audit; candidate-tree rounds and these section reviews do not count as merged-spec rounds. |

## 6. Learning-site synchronization and handoff

**[assumed: publication record]** The integration base at this snapshot contains the charter/decomposition/work orders, not a published converged course. Candidate A/B learning sites remain historical candidates. They must not be relabeled as this specification or cited as evidence that a pending section was accepted. This W6 contribution therefore adds the index and measurement register; it does not silently import either candidate's lessons.

| Future lesson dependency | Authoritative material / changed claims to consume |
|---|---|
| Execution and roots | Accepted C1, then C4's activation prerequisites; optional reveal/pin, guarded legacy writes and no mandatory Anchor transaction. |
| Assignments and local validity | Accepted S1 then S2/C7; D19 fixed draw counter and finite exits; D17 gossip/landed predicates. |
| Actionable confirmation and attacks | Accepted S2/S3; D16 logical opening identity and objective evidence; D20 actual backing and all S2-R18 exceptions next to LOCKED. Link the register's client/Catalyst evidence record so proposed behavior is not presented as already executing in the anchorless client. |
| Landing and recovery | Accepted C2/C3/C5; fixed-recipient proof reuse, authenticated due clock, irreversible per-entry settlement and L-PF consequences. |
| Custody and migration | Accepted C4/C8; exact existing-address changes, legacy-request adapter, bootstrap, funding and prohibited deeper custody rollback. |
| Full argument | Accepted S4 and both C6 halves; original requirement verdicts, accepted Medium rationale and merged-round findings with their actual closure commits. |

**[open: course acceptance]** Each lesson remains a small prerequisite-ordered mechanism with a diagram, concrete source-derived example, defended/remaining attacks, hidden self-check answers and a challenge box, as the original brief requires. A final course revision must pin its source commit and update all dependent lessons and examples when a rule changes. The owner of the final site build is assigned through WORK; this index neither duplicates rules in a second course spec nor claims the unfinished course is synchronized.

## 7. Review provenance

**[assumed: evidence record]** B's original W8 verdicts and A's adopted directions are recorded in [the umbrella status comment](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5933729212), D16–D20, and the linked section PRs. C1's latest submission is [5933874097](https://github.com/taikoxyz/taiko-mono/pull/22195#issuecomment-5933874097); C4 is [#22205](https://github.com/taikoxyz/taiko-mono/pull/22205). [J's C6 review](https://github.com/taikoxyz/taiko-mono/pull/22206#issuecomment-5934276207) at `0440d277` found no Critical/High and requested the nonblocking maintenance clarifications now recorded in the register. A's verdict and review of this revision remain open. No model-generated internal support note is presented as J's independent verdict, an arbiter decision, a test run or a measurement.
