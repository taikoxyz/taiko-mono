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
