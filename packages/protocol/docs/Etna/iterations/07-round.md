# Round07 — anchor removal reviewed; pre-activation intake corrected

Immutable reviewed candidate: `575d41a5ad2aa1a276c9a491cd04dcd4d1f8d8c2`. This is the first fresh review of the anchor-removal revision; earlier rounds05–06 covered the previous design only.

**Result:** no new Critical or High findings. The independent [judge](07-judge.md) retained one Medium normative issue and six scoped Medium residual risks. Its immutable-candidate verdict passes R1–R6 conditionally and leaves R7 narrowly open for new force intake during DRAINING. This round alone does not establish convergence. The correction below is a new candidate requiring fresh round08 review.

## Independent coverage and provenance

Completed fresh reviewers were **gpt-5.6-sol/high** for [custody A](07-a.md), **gpt-6-astra/high** for [liveness B](07-b.md), and **gpt-6-sol/high** for [censorship C](07-c.md), each with no inherited conversation. A prior gpt-6.1-sol custody invocation was filtered and produced no final report; it contributes no completed coverage. Requested model configurations are recorded, not backend attestations. The separate judge inherited its configuration and had no exposed runtime identifier.

Every completed reviewer read all eight reference HTML pages and both component vector files at the exact SHA, plus only the README requirement table. They did not read old reports or mitigation lists. That table included author verdicts and the required HTML contained historical status assertions; reports disclose this exposure and do not treat it as evidence. Fresh round08 instead receives the requirement table without its verdict column.

The judge wrote its independent assessment before report intake: SHA-256 `c68f17436feddbb38651cf79bf1a2c652d2cce685080a7f29b302935dacb8927`. It then read authorized C, B and A reports, changing its narrow R7 conclusion after A's trace. Final adjudication SHA-256: `4e2a19f2c5aa7830888268f9762cbda0e7a9d77896173461f061a65ba81cb858`. The review is predicate-based, not a vote.

## Required correction applied for round08

**J07-M01, Medium, mitigated in the new candidate:** `force` now requires ACTIVE before any record, escrow allocation or excess credit. PREPARED and DRAINING calls revert without accepting user value. The new queue starts empty; activation checks its empty internal state and zero request-fee liabilities without clearing anything or comparing unsolicited ETH to liabilities. A read-only fee quote creates no admission promise. All frozen legacy requests, fees, data and bond obligations retain their original drain rules.

This closes the concrete trace in which a new user's fee became locked behind unavailable legacy evidence before any Etna head existed. It introduces an explicit intake gap during draining, visible to clients. It does not make old unavailable data recoverable or authorize a DAO refund. H0 and its once-only empty cut are unchanged; successful same-block enqueues after activation appear in the ordinary end-of-block snapshot. The reference, proof sketch, numerical example and course now agree. No encoding domain, parameter, vector output, custody address or system-call behavior changed.

**J07-L03, Low, fixed editorially:** replace stale “public system transaction”/“anchor value” with standard-call/origin terminology and scope old acceptance assertions to their historical rounds. Current convergence remains pending.

## Explicit dispositions of every remaining finding

| Judge ID | Severity | Root disposition and reason |
|---|---|---|
| M02 | Medium | **Accept finite paid-backlog delay.** Mandatory FIFO defeats overtaking, not arbitrary earlier backlog. Keep conditional progress and disclose queue-dependent latency; calibrate capacity and costs before launch. |
| M03 | Medium | **Accept ordinary caller funding and archive dependence.** No rewarded/privileged checkpoint operator is required. Users can force a processing-time pin and timeless reveal, but must fund valid L2 transactions and retain authentic header/state witnesses. The UI distinguishes recorded, pinned and revealed state. |
| M04 | Medium | **Accept bounded forced-transaction scope.** The 1845-byte reveal construction fits 2048 bytes, subject to the measured 1M-gas limit. It does not make every large Bridge proof/target call forceable. Keep that limit explicit; a larger envelope needs separate resource evidence and review. |
| M05 | Medium | **Accept concentration beyond the bounded rent theorem.** High MEV or no funded early competitor can sustain capture. Mandatory rent/sinks are concrete identity-independent friction, not ownership diversity or a profitable operator market. Human economic calibration remains required. |
| M06 | Medium | **Accept service capital and actual-data costs as an unmeasured feasibility risk.** One-second issuance is a target, not demonstrated full-load bonded service. Measure proof/DA/gas, publication and participant budgets before launch; failed measurements require revision. |
| M07 | Medium | **Accept finite predicate-specific accountability and revocable soft state.** Cross-owner/context gaps, pre-deadline withholding, evidence expiry and losses above reserves remain possible. Preserve mandatory staging and exact fragment duties without inventing a global gossip/intent proof. |
| L01 | Low | **Accept potentially uneconomic or absent reporting.** Objective evidence does not guarantee a reporter. Calibrate payout/costs, display exposure expiry, and do not promise inevitable punishment. |
| L02 | Low | **Accept caller-paid permanent pin state growth.** One entry per distinct authenticated origin, no duplicate growth, and no arbitrary hash write. Include long-run growth in resource checks; an integrated coinbase may recapture ordinary L2 fees. |

Deployment-dependent custody/selector/layout and engine/prover parity failures are blocking launch obligations. Their potentially severe impact is not downgraded; the documentation supplies the relevant required guards but does not prove an implementation or live migration satisfies them.

## Verification and next step

Root spot-checked each report's central trace and the exact migration phase table, oracle/write guards and custody interfaces. Independent analysis reproduced the empty-bootstrap and forced-reveal byte bounds. Static/browser checks cover 21 HTML pages, 25 SVG diagrams and 32 hidden answers; no execution/proof vector, gas benchmark or deployed-layout evidence is claimed. Reviewer calculations stayed in scratch or memory; no production files changed.

Commit this correction and record its SHA as the immutable round08 candidate. Round08 is the last permitted round under the original eight-round cap. A new Critical/High or an unresolved gate at that point must be reported honestly; the earlier verdict cannot be inherited by this changed design.
