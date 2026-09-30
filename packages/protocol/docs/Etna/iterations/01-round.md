# Round 01 — initial candidate

Reviewed design: `f0a548458`, with migration-encoding clarification `585d2a183`. Independent reviewers: financial safety **gpt-6.1-sol** ([A](01-a.md)), liveness **gpt-6-astra** ([B](01-b.md)), censorship/concentration **gpt-6-sol** ([C](01-c.md)). A separately delegated judge reconciled all reports in [01-judge.md](01-judge.md). The first A invocation was rejected by the model's content filter; the same model completed a rephrased authorized defensive specification review. No executable attack or production change was requested.

**Result: no Critical; one High; one Medium specification failure; one Low; one Medium economic gate. No clean round credited.**

| ID | Judgment | Required disposition |
|---|---|---|
| J-01 | High: active publisher can serve X, privately land unsigned Y and escape every duty | Revise admission with nonexclusive public DA staging, explicit publication-by covenants and authenticated canonical-owner conflict evidence. Full data plus proof must still accompany the one canonical action. Re-review residual private-computation, Sybil and honest-race limits. |
| J-02 | Medium: early sealing requires an unavailable newer L1 origin | Permit origin reuse with nondecreasing authenticated origins; retain a finite freshness bound and re-prove FIFO progress. |
| J-03 | Medium economic gate: 60.48 million TAIKO per sustained signer; recycled force fees | Reduce/reason explicitly about short service liabilities; model capital and net irreversible queue cost. Do not promise identity diversity or deterrence of unbounded external MEV. |
| J-04 | Low: raw-balance equality fails under unsolicited donations | Use liabilities ≤ assets; donations are uncredited surplus and cannot block exits. |

At review completion these findings remain open. Revision dispositions will be appended before the next independent round. Missing circuit implementations, live deployment evidence and benchmarks are separate launch gates; hypothetical failures of specified safeguards were not counted as actual Critical exploits. No universal impossibility of literal R1–R7 was established.

## Revision disposition before round 02

- **J-01 changed, pending fresh review:** mandatory actual-data staging with360-second minimum public age; complete context and identical republication plus proof; no head reservation. Signed exact-context publication deadlines survive late revelation. Mandatory canonical producer authorization supports bounded same-owner conflict evidence without framing a named beneficiary. Mature public forks, private computation, cross-owner attribution and exact-context limits remain explicit; no global historical-gossip oracle is claimed.
- **J-02 mitigated on paper:** authenticated origins may repeat;900-second freshness suffices for eventual frozen-FIFO progress.900-block unsafe resource horizon and stage-aware job deadlines accommodate the new maturity wait. The origin/cadence proof is re-opened for review.
- **J-03 concretely revised, not declared economically proven:** position10TAIKO,600-TAIKO buckets,1200-second retention/3600-second evidence; explicit efficient-registration peaks37200/147000TAIKO at1/4 claims per second. Force fees split50%processor/50%irreversible sink;1000 accumulated requests from empty queue cost10.5ETH and sink5.25ETH plus external costs. Interleaved strategies and unknown MEV/token valuation remain stated limits. These are finite deterrents and exposure limits, not insurance or identity diversity.
- **J-04 corrected:** raw held-assets equality replaced by liabilities≤assets and uncredited surplus; donations cannot block exits.
- **Additional consistency repair:** canonical Head commits execution contextHash, while the receipt commits full statement/payment/producer/job details. Identical execution with another payment or job assignment cannot mutate precomputed child heads. No future L1-assigned stage ID enters execution: stage IDs are deterministic salted context hashes.

All changes are specification-only. No clean round is credited for making them; round02 reviews the resulting complete HTML without the prior mitigation list.
