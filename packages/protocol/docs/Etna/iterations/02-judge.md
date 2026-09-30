# Round 02 — consolidated judgment of revision 1

**Verdict: no confirmed Critical or High finding in this round. The reviewed snapshot is not yet a complete passing specification.** Its contradictory publication-signature and producer-key encodings must be corrected. The pipeline consistency limit is a real Medium risk accepted only within the explicitly provisional, publicly staged scope below. Pending forced-fee accounting also needs correction. This can be the **first Critical/High-free round**, not convergence and not an implementation-readiness declaration.

## Scope, provenance and independence limit

- Reviewed commit: `78da76eb6bca51860ec7291e8897355ae277af20`, confirmed unchanged while judging. Inputs were the README R1–R7 ledger, the six HTML design pages, and the complete independent [A](02-a.md), [B](02-b.md), and [C](02-c.md) reports. Round 01's judge record supplies prior finding status; the revised predicates were examined directly.
- Reviewer A: `gpt-6.1-sol`, financial safety. Reviewer B: `gpt-6-astra`, liveness. Reviewer C: `gpt-6-sol`, censorship and concentration. Those three reviews were independently briefed against the same snapshot.
- **Judge independence limitation:** the environment refused another agent with `agent thread limit reached`. The coordinator reassigned the existing roles-page author to this separate judging task. This judge therefore has prior design context and authorship of `roles.html`; it is **not** represented as a fresh blank-context reviewer. The additional producer-key ABI finding below identifies a defect in that judge-authored page. The judge uses the inherited model; no unverified model override is asserted.
- Only this judgment file was written during judging. No design, production, circuit or client file was edited; no git mutation, deployment, benchmark or live-state verification was performed.

Severity measures the concrete consequence, not simply whether a finding touches a MUST requirement. A Medium inconsistency can still prevent a hard gate from passing. Conversely, an expressly required safeguard is not presumed absent in a hypothetical future implementation. Soft rollback is permitted; a global absence of capable provers is an acknowledged liveness-assumption failure; literal R7 does not ban an earlier generic copy of the data.

## Deduplication and disposition

| Source | Consolidated judgment | Status at reviewed snapshot |
|---|---|---|
| A02-01, B-02-01, C1 | **J02-01a, Medium: incompatible publication EIP-712 type strings.** C's High rating is not adopted; the independent canonical staging/DA predicate is not bypassed. | Confirmed, unresolved; R3/R6 exact evidence specification blocked. |
| Judge's cross-page comparison | **J02-01b, Medium: incompatible producer-key return/event ABI.** Grouped with the exact-encoding repair, but separately explained because it affects contract-owner admission. | Confirmed, unresolved; R1/R3 interoperability needs correction. |
| A02-02 | **No separate confirmed Medium requirement failure.** The signed duty ensures public availability and explicitly permits another responder. It does not require personal service by the signer. | Retain the refusal trace and clarify role wording; do not advertise independently maintained copies or personal responses. |
| C2; B's same-owner pipeline trace | **J02-02, Medium: bounded canonical-conflict coverage leaves pipelined same-owner reversals unslashed.** | Accepted limited-service risk with the rationale and prohibited claims below; not universal consistency insurance. |
| C's capital/cartel and staging-dominance stress traces; economic observations in A/B | **J02-03, Medium residual economic/resource risk.** Actual revised net costs and working-capital bounds exist; equal market shares and unlimited MEV deterrence do not. | Accepted at design-review level within the stated scope; calibration remains a launch/economic gate. |
| A02-03 | **J02-04, Low: pending forced-request ETH escrow omitted from displayed accounting.** | Confirmed; correct the equation and transitions before closing the round. |
| B-02-O1 | **Informational: some viable speculative children cannot use the optional on-chain job market.** | Disclose explicitly; no canonical liveness failure or requirement for an exclusive job market follows. |

Result: **zero Critical, zero High; two unresolved Medium encoding defects grouped into one repair family; two accepted Medium residual risks; one unresolved Low accounting omission.** The optional-job observation and custody wording clarification also need a written disposition. No degree of severity reduction makes the present contradictory schemas implementation-ready.

## J02-01 — Medium: one protocol needs one signed schema and one producer-key ABI

### J02-01a: publication signatures

**References:** `design/staging.html:200–209`; `design/accountability.html:10,103`; `design/roles.html:85`.

Staging prescribes the literal EIP-712 type `PublicationClaim(uint256 bucketId,uint256 position,uint256 revision,bytes32 baseHeadHash,uint256 issuedAt,bytes32 contextHash)`. Accountability and roles prescribe `EtnaPublication` with the same fields. Equal fields and domain do not make these equal digests. The documents' division of authority—staging for commitments, accountability for evidence—does not remove the contradiction.

**Concrete trace.** A publisher deposits the ordinary 600-TAIKO bucket collateral and signs an otherwise eligible sealed covenant under staging's type. A client authenticates that signature and displays the deadline. The owner misses the deadline. A verifier implementing accountability's type cannot recover the expected signer from the same claim/signature, so reporting fails. The position can eventually be released without its intended 10-TAIKO penalty. Reversing the two component choices has the symmetric failure. Reporter gas can be wasted; no forged victim signature, custody root or unpaid reward is established.

**Severity adjudication.** This is a genuine normative defect, not a launch benchmark and not an invented deployed bug. Its demonstrated effect is failure of a particular optional covenant's interoperability. Every canonical candidate still needs matching actual staged data aged 360 seconds, full republication and a valid proof. Other offense families and open recovery are not disabled by the trace. A/B's Medium rating therefore fits the demonstrated consequence better than C's High. This judgment does **not** accept the inconsistency or mark R6 passed because the amount is bounded: the required exact evidence format is presently incomplete.

**Required correction.** Choose one exact type name/string, field order/width and domain; update every page and comment. Default, publication-equivocation and mixed-kind evidence must share that schema. Publish one common domain separator, structure hash, signed digest and signature/recovery vector as documentation. Do not silently accept both schemas within the same revision without specifying their identities and cross-schema equivocation semantics.

### J02-01b: producer keys

**References:** `design/roles.html:132,139–140`; `design/staging.html:140–156`.

The roles page declares `getProducerKey(uint256) returns (address owner,address signingKey,bool active)`, while staging returns `ProducerKey {address owner,address signingKey,uint48 registeredAt,uint48 revokedAt}`. The corresponding `ProducerKeyRegistered` and `ProducerKeyRevoked` event signatures also disagree. These are not equivalent ABI renderings.

**Concrete trace.** A contract owner registers a legitimate immutable key. A registry follows staging and returns four words. A consumer following roles decodes word three as a canonical ABI `bool`; an ordinary nonzero Unix registration timestamp greater than 1 fails that decode. In the reverse configuration, a consumer expecting the four-word struct receives insufficient data. The honest owner meets the stated objective registration conditions but its key-dependent acceptance path fails between the two conforming-to-different-pages components. Event consumers also cannot reliably track the advertised registration/revocation records.

**Impact and cost.** No attacker is necessary; registration gas and prepared transaction/proof work can be wasted. Direct EOA authorization remains an alternative for an EOA's own identity, but it does not fulfill R1's promise that an arbitrary contract owner can use its objectively registered identity. This is Medium interoperability/admission failure, not an arbitrary signature forgery or canonical chain-wide halt.

**Required correction.** Make staging's declared key record and event ABI, or another single selected shape, identical everywhere. Define existence, active-at-acceptance and historical revocation behavior consistently. Preserve immutable owner/key history and already-checked accepted identity. A new key ABI must not turn current revocation state into a way to erase old slash evidence. A simple documented return/event encoding vector belongs alongside the signature vector.

## A02-02 — global publication is fulfillable by a third party

**References:** `design/accountability.html:17–18,34,159`; `design/roles.html:54,117–118`; `design/staging.html:214–224`.

A's trace is valid: custodian A can refuse personally while B publishes the exact bytes, earns the publication fee, and satisfies the pending availability duty. A is not slashed, and the globally revealed digest cannot be challenged again for another paid reveal. The false-negative rate for inferring **A's personal refusal** is 100% in that trace. This result must remain visible.

It is not, however, a breach of the actual signed on-chain duty. That duty expressly allows any responder and is discharged by globally retrievable exact bytes. The beneficiary of the assurance obtains the specified public data; A's silence no longer keeps those bytes unavailable. The response fee goes to the party doing the work. The contract makes no protocol-funded recurring personal-service payment to A. Requiring a signature proving that A personally participated would add a different service—online signer participation—even though the promised availability was already rescued.

The brief requires a useful objective surrogate for withholding, not proof of the internal storage operation or personal labor of every signer. The complete canonical candidate also independently needs mature public data. A's trace does not show a private first-reveal acceptance, invalid proof, hidden canonical dependency or unpaid subsidy. A signer remains punishable when its promised global publication actually defaults. Therefore this is **not a new Medium R6 failure and does not require a relaxation of an individual-response SLA the protocol never promised**.

**Required wording disposition:** describe custody as an assurance that the exact bytes will be publicly recoverable by the specified deadline, potentially fulfilled by another holder. Retaining a local copy is the recommended way to honor that assurance, not a separately proved physical-storage property. Do not advertise a count of custodian signatures as independent stored copies, personal endpoint uptime, or an honest-owner threshold. An application wanting personal authenticated responses needs a distinct priced duty; it is not silently supplied here. Before a successful reveal, selective gossip remains unprovable except through the stated response/publication predicates and their explicit false-positive/false-negative limits.

## J02-02 — Medium accepted limit: canonical conflict evidence is narrower than pipelined ancestry

**References:** `design/staging.html:180–181`; `design/accountability.html:20`; `design/roles.html:81,84`; `design/arguments.html`, “Authenticated same-owner conflict”.

**Concrete trace, confirmed.** Owner P signs provisional X at height k using a bucket based on accepted H. H's child H′ later becomes accepted. P authorizes a conflicting Y containing k, with immediate old head H′. Even with P's authentic accepted authorization and an exact block membership proof, the specified lookup/predicate requires `Y.oldHeadHash == X.baseHeadHash`; H′ does not equal H. The canonical-conflict slash therefore does not apply. No Sybil is needed; a distinct owner address gives an additional attribution escape. Cost is refundable reserve plus staging, proof and landing expense; gain can be soft-history reversal, fees/MEV or wasted competing computation. No universal profit is established.

**Why this is not the prior High trace unchanged.** Y cannot first disclose its complete execution inputs at canonical acceptance. It must be actually staged for 360 seconds and remain retrievable under the named DA assumptions. During that interval peers can inspect Y and a funded selected entrant can prepare the same branch's proof under the explicit retrieval/proving premises. P may still win, and X may still roll back. That is the permitted mature-public-branch race, not a bypass of the universal withholding-prevention predicate. A claim that public age alone prevents every profitable reversal would be false, but the specification does not make it.

**Acceptance rationale.** Retain this Medium risk for a bounded, optional exact-context consistency service. The existing prose explicitly limits that offense; global data eligibility, execution safety and forced FIFO do not depend on expanding it. An unbounded ancestry walk or automatic punishment of every loser is not required and could introduce a different grief path. A separately specified bounded ancestry witness could improve protection, but is not necessary to prove the current public-data lead.

**Conditions on acceptance:** user-facing client/certificate descriptions must state the exact immediate-parent scope and omit a general promise that the publisher can never authorize another future soft history. Refreshing promises against a new accepted base may restore the particular coverage; it does not retroactively broaden old promises. Report the pipeline and cross-owner false negatives. This acceptance cannot be used to mark R6 passed if actual staging/context binding were bypassed, or if a broader canonical-consistency guarantee were advertised elsewhere.

## J02-03 — Medium accepted risk: economic concentration and paid candidate overload

**References:** `design/roles.html:209–216`; `design/accountability.html`, “Conservation, exit and attack economics”; `design/staging.html:89–95,193–194`; `design/arguments.html`, “Known limitations”.

The revised design has concrete resource rules and arithmetic, unlike a bare claim that open registration ensures decentralization:

- A position reserves 10 TAIKO; opening one 60-position bucket costs 600 TAIKO. No more than that position's reserve can be allocated to all its offenses. Same-actor self-slashing loses 9 TAIKO per position, or 900 TAIKO for a defaulted 1,000-TAIKO job, before gas. This is a bounded penalty, not unlimited MEV insurance.
- With the published just-in-time full-bucket schedule, continuous one-claim/second service peaks at 37,200 TAIKO, and four claims/second at 147,000, including issuance overlap and the exact release boundary. Additional covenants, other service holders and delayed release add cost. New entrants are not required to sustain that throughput.
- There are zero seconds of exclusive canonical lease and no finite ticket pool to capture. Buying optional roles or accepting every posted job grants no permission to veto another funded address's valid staged proof. Job abandonment can incur its independently reserved default penalty; timely competing consumption is already canonical progress.
- Starting empty, 1,000 enqueues without intermediate consumption cost 10.5 ETH in fees, with 5.25 ETH irrecoverable even if the same actor earns every processing credit. Interleaving below 50 pending reduces those figures to 1 ETH and 0.5 ETH, while consuming FIFO work. Later arrivals cannot add predecessors to a fixed victim. Gas, execution, proving, staging and repeated DA are additional costs.
- Staging many candidates consumes actual L1 data/gas/storage but can impose inspection load. Nodes are not required to prove every candidate; the 60+180-second opportunity concerns a selected funded candidate. No honest-majority-of-stages assumption is justified.

**Residual trace.** A wealthy fast prover or builder-connected cartel can operate many owners, stage multiple alternatives, outcompete transaction-rich branches and earn most fees/MEV while respecting all of those rules. Refundable collateral costs opportunity and transaction expenses, not its entire face value. External revenues can exceed sinks and slashes. Zero leases is not a market-share cap; independent addresses are not independent economic owners.

**Acceptance rationale and requirement boundary.** R6 calls for concrete deterrence and objective punishment, not a theorem of equal market shares or an economic-identity oracle. The revised rules deter role squatting as a veto, impose capital-proportional simultaneous liabilities and irreversible queue abuse cost, and protect fixed FIFO predecessors. Those are meaningful specified mechanisms, with numbers and net-cost models, even though they cannot guarantee arbitrary attacks are unprofitable. No free admission monopoly, refund loop or permanent fixed-item bypass was established by A/B/C. Accept this Medium economic/resource risk at design-review level; retain token-liquidity, workload, proof-cost, DA-cost and subsidy measurements as launch calibration. Do not relabel the outcome as guaranteed competition or small-participant profitability.

The prior round's severe capital barrier and fully recyclable force-fee model have substantive revisions: 100→10 TAIKO, seven days→one hour evidence, explicit peak exposure, and a 50% force-fee sink. The old finding is not closed merely by a disclaimer. The revised costs support the narrower deterrence claim; actual market equilibrium remains unproved. R6 still cannot pass the **reviewed snapshot** until J02-01's evidence grammar is made consistent.

## J02-04 — Low: reserve pending force fees explicitly

**References:** `design/roles.html:109–115`; `design/index.html:135`; `design/roles.html:211–214`.

A's arithmetic observation is correct. Before processing, an enqueued 0.001 ETH belongs to neither displayed unpaid credit nor force sink, although the queue has recorded it. Processing then appears to create 0.001 ETH of accounted value without a new receipt, contradicting internal conservation. No sweep or unauthorized withdrawal follows because those actions are prohibited; this is not demonstrated insolvency.

Add `pendingForcedFeeEscrow` to the Inbox's ETH equation. Enqueue credits that reserve by the exact accepted fee; processing debits it once and creates the exact 50% beneficiary credit/50% sink entries. Surplus remains distinct. Enforce solvency separately in the Inbox and challenge registry; do not net an obligation against another contract's balance. Correcting the prior raw-balance equality was valid and remains necessary, but does not replace complete component accounting.

## Informational funding limit and rejected stronger interpretations

**B-02-O1 is confirmed as an optional-market coverage limit.** Acceptance requires a canonical parent and at least 300 seconds remaining before the worker deadline, plus a further 120-second origin margin. Thus `acceptedAt <= origin+480`. In B's example, parent P lands at t=660; speculative child C has origin 60, stage 240 and a ready proof. C can land while origin-fresh until 960, but a job first accepted at 660 would require freshness through 1080 and is refused. The guard correctly avoids an impossible job. Independent or off-chain funded proving still works, so no new chain halt is established. Explicitly disclose that the job market does not subsidize every viable speculative pipeline segment; adding conditional-parent offers would require a separate state machine, not deleting the guard.

The following attempted attacks did not establish new findings:

| Attempt | Judgment |
|---|---|
| First actual disclosure occurs in the winning canonical transaction | Matching actual staging, full-context binding and 360-second maturity reject it. A bare hash or changed blob fails the specified DA relation. |
| Repeated salt/stage publication resets a missed covenant or grants priority | Particular receipts are immutable; first context publication is permanent across salts; no stage reserves a head or fee. An expired origin is not refreshed merely by choosing another salt. |
| New force entries invalidate every in-flight proof | The mandatory prefix derives from the accepted parent's frozen origin snapshot; later indices cannot alter it. Origin freshness advances snapshots during progress. |
| Earlier forced work can be perpetually overtaken by later entries | FIFO predecessor count does not grow after the victim enqueues. Large paid backlog and failure of accepted-successor progress are separately stated limits. |
| Every incumbent stops, so a whitelist or DAO replacement is needed | A newly funded capable entrant can stage, self-authorize and prove. No optional publisher/worker/custodian supplies a mandatory approval. No progress is promised with zero capable provers globally. |
| Bounty recipient naming can frame an innocent publisher | Producer assent is mandatory and exact; an unconsented beneficiary identity is insufficient. Historical accepted identity survives key revocation. The cross-page key ABI must nevertheless be repaired. |
| Missing circuit binaries, a live manifest or measured throughput is itself a Critical exploit | Those are explicit future launch/implementation validation obligations. No reviewer demonstrated that an enforced proof/checkpoint rule is absent in the specified transition. Normative contradictions found above are different and must be resolved now. |
| Generic earlier data publication violates R7 | The single canonical action still contains full matching data and proof. Staging creates neither accepted unproved state nor canonical reservation. The extra transaction and duplicate DA cost are explicitly charged. A first-ever-publication-only rule would be an additional requirement. |
| One-second issuance requires irreversible soft finality | Local execution validity, optional provisional branch selection, L1 acceptance and Ethereum finality are separate. No such finality guarantee is required or supplied. |

## Prior finding status

| Round-01 item | Revision-1 judgment |
|---|---|
| J-01 High active-holder first-reveal disruption | **Mechanism changed and original trace blocked**, conditionally on actual complete-context DA binding. Mandatory public age changes the evidence and acceptance predicate; signed deadlines and authenticated producer conflicts add narrower punishments. The remaining pipeline/common-owner/earlier-gossip limits are handled above, not hidden. |
| J-02 Medium early-seal/new-origin cadence failure | **Specified repair survives this round:** nondecreasing identical-origin reuse lets early-sealed segments proceed without a newly produced L1 header. The 900-second freshness ceiling preserves eventual snapshot progress. One-second maximum-workload performance remains an unrun launch test. |
| J-03 Medium economic gate | **Substantively mitigated and scoped residual accepted as J02-03.** Working-capital reduction, exact model and irreversible force fee are real changes. No guaranteed diversity, fair race or unlimited-MEV coverage follows. |
| J-04 Low raw-assets equality | **Corrected:** liabilities/accounted obligations are at most held assets; donation surplus cannot freeze withdrawal or create a claim. New J02-04 adds the missing pending queue component. |

## Consolidated R1–R7 matrix

These are design-mechanism dispositions under the stated assumptions, not claims of deployment or benchmark completion. An unresolved exact schema prevents an unconditional pass even where no High exploit was established.

| Gate | Round-02 mechanism judgment | Remaining closure |
|---|---|---|
| **R1 — permissionless, DAO upgrades only** | Open canonical staging/proving/force/recovery has no incumbent or DAO operating gate. Self-authorized producer keys are permissible objective entry. **Exact contract-owner key ABI remains inconsistent (J02-01b).** | Repair common key ABI/events. Later authenticate selector, owner, wrapper and migration state; no operation requires a routine DAO action in the specified active flow. |
| **R2 — retain existing shared addresses and interfaces** | **Conditional specification pass.** The unchanged checkpoint ABI, preserved storage/history, proof-authenticated root paths and finite migration do not give stages/services custody authority. | Authenticated live manifest, compiled layout/selector review, historic message/fee/bond replay, legacy circuit/DA compatibility and migration rehearsal are launch gates, not completed evidence. |
| **R3 — full role terms and failure behavior** | Role separation, reserved liability, historical settlement and all-incumbent recovery survive. **Exact role/evidence interoperability blocked by J02-01.** | Repair schemas; clarify global-publication custody semantics and optional pipeline-job funding limit. Correct pending fee accounting. |
| **R4 — one-second locally checked soft cadence** | **Conditional specification pass for target and decoupling.** Origin reuse and precomputable execution heads allow staging/proving to overlap soft production. Missing dependencies stay UNKNOWN; the horizon is finite. | Measure admission/scheduling, maximum-resource execution and sustained proving; no unconditional partition or arbitrary-failure SLA is inferred. |
| **R5 — no CL lookahead or slot coupling** | **Pass at specified mechanism level.** Role/deadline rules use seconds and authenticated past L1 block numbers; no future proposer schedule appears. | Fork-header/parser conformance and timely pinning. At regular 12/6/4/2-second intervals the 256-block opportunity is approximately 3072/1536/1024/512 seconds, a scenario check rather than a normative slots-to-seconds rule. |
| **R6 — objective penalties and concrete deterrence** | Universal mature actual-DA eligibility blocks first reveal at landing; defined serving, publication, equivocation, authorized-conflict and job duties have bounded objective liability. Concrete economic mechanisms survive the reviewed traces. **Not yet passed at this snapshot: J02-01a contradicts its evidence format.** | Correct the signature schema/vector. Retain the accepted pipeline consistency and economic risks with exact scope, FP/FN and net costs. Do not claim individual-personal-service proofs, global owner identity, unlimited MEV coverage or guaranteed market diversity. |
| **R7 — atomic proposal/data/proof** | **Conditional specification pass.** Final acceptance carries and proves complete matching DA in one action; parent-frozen FIFO, independent backup proving, finality and ordinary transport fallback remain. Prior nonexclusive publication is allowed by the literal criterion. | Verify the complete executable relation and launch resource fit; disclose two DA publications, roughly seven-to-eleven-minute illustrative startup, lost stages/proofs and expiry/rebuild costs. |

## Convergence decision and next action

1. Resolve J02-01a/b with one shared schema/ABI and documented vectors; correct J02-04. Record the custody wording and optional-job funding dispositions.
2. Preserve this report's accepted Medium scopes and their rationale in the iteration log. Neither constitutes permission to advertise a stronger service than the evidence enforces.
3. Run the next independent multi-model round against the corrected, immutable specification. The independent attackers, unlike this reused judge, must remain fresh with respect to previous mitigation lists.

**Count: one Critical/High-free round eligible, zero convergence declarations.** This count follows the impact adjudication above, not a claim that the current document already passes every hard gate. The reviewed snapshot retains unresolved Medium exact-format defects. Correcting them and obtaining a second consecutive review with no new Critical/High, all Medium dispositions and all R1–R7 passing is still necessary. No impossibility verdict and no permission to skip that process are established here.
