# Round 02 — independently reviewed staged-data candidate

Snapshot: `78da76eb6`. Fresh independent reviewers: **gpt-6.1-sol** [A](02-a.md), **gpt-6-astra** [B](02-b.md), **gpt-6-sol** [C](02-c.md). They read the complete revised HTML without prior findings or mitigation lists. [Separate judge](02-judge.md) discloses prior authorship of the roles page: the tool refused another root-level agent thread, so an existing agent performed the judge role. A fresh independent judge has been reserved through hierarchical delegation for the next round.

**Judgment: zero new Critical or High; first CH-free round. Not converged.** C recommended High for the publication type-name disagreement; the judge assigned Medium based on the specification-interoperability impact while keeping exact R3/R6 closure blocked. Severity was not treated as permission to ignore a hard gate.

- Correct the conflicting EIP-712 type literal and producer-key tuple/event ABIs; add a concrete digest vector.
- Make pending forced-fee escrow explicit (Low), including enqueue and processing ledger transitions.
- Accept the disclosed exact-base/same-owner conflict scope (Medium): mature actual DA independently prevents first-reveal-at-landing; no identity oracle or unbounded ancestry attribution is claimed.
- Accept finite economic deterrence and the shorter soft-service evidence horizon with their quantified capital/cost limits. No insurance against unlimited MEV or guaranteed market diversity is asserted.
- Clarify that anyone's correct public disclosure fulfills an availability duty; no holder-specific personal-response SLA was signed.
- Disclose that conservative freshness guards make some otherwise viable older pipelined candidates ineligible for optional funded jobs. Raw proving remains open.

No production implementation, benchmark or live migration rehearsal was performed or claimed. Normalization and interface-closure dispositions will be appended before the next fresh review.
