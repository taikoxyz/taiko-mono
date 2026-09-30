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

## Disposition before round03

The publication EIP-712 type is now exactly `EtnaPublication` everywhere, with a deterministic [digest fixture](../design/encoding-vectors.md). Producer-key return tuple and event signatures now match the authoritative staging schema. The pending forced-fee escrow and its one-time split are explicit. Personal-server SLA wording and the older-pipeline job-funding limitation are clarified; the judge's bounded Medium acceptances remain visible.

Further interface closure for fresh review: the initial verifier is an immutable-key RISC0_RETH+SP1_RETH conjunction over one exact digest, including an Inbox-derived hash of required forced records. An explicit bounded outcome array supplies event fields and must hash to the proved outcome root. Both programs prove the full new Etna relation; legacy program compatibility is not presumed. Initial extra reward-authorization bytes are empty, with no undefined payment scheme. Canonical submission is nonpayable. These are specification choices subject to round03, not claims of implementation or measurement.

Soft response latency is now stated as0…1 second scheduling plus propagation/execution, illustratively1–2 seconds; the issuance interval remains1 second. The prior wording risked confusing cadence with end-to-end latency.

Validation: parsed all six reference HTML pages, checked unique IDs/local links (course still pending), normalized the conflicting schema declarations, checked whitespace, and computed the public fixture in the scratchpad against known Keccak empty/abc values. No production code or signing key was used. Independent language implementations must reproduce the fixture during implementation.
