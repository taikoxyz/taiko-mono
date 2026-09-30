# Round 03 — complete outer interfaces; inner codec gap

Reviewed snapshot: `29cc3b060`. Fresh reviewers: **gpt-6.1-sol** [A](03-a.md), **gpt-6-astra** [B](03-b.md), **gpt-6-sol** [C](03-c.md). The [fresh separate judge](03-judge.md) had no design authorship; its inherited model identity was not exposed. Reports disclose the coordinator's codec concern and counterarguments, rather than claiming wholly unprompted judging.

**Judgment: zero new Critical or High; one unresolved Medium. Not converged.** Rounds 02 and 03 meet the consecutive Critical/High-free count, but the complete R6/R7 specification does not yet pass.

- **J03-01, Medium, required fix:** the inner body/manifest serialization and `manifestRoot` construction are undefined. Outer hashes and a sound proof cannot choose an unspecified decoder. Specify canonical headers/transactions, all forced inputs including rejects, system anchors, fragment boundaries, hash domains and a reproducible fixture; then obtain fresh review.
- **C-01, proposed High, rejected by judge:** selectively serving X while mature public Y wins does not establish a new forbidden canonical outcome. Y has a public data lead; X's valid recipient already has complete bytes and can relay them; the same soft rollback can occur with X public from issuance. A new absolute X-publication service would not guarantee priority over an already-mature Y. The 600-second recovery promise, optional sealed covenant, attribution misses and timeout errors remain explicit limitations.
- Prior Medium pipeline-attribution and economic-concentration risks remain accepted with the exact bounded scope in the judge report. Earlier signature/key grammar and forced-fee accounting defects are fixed at specification level.

Next: define and commit the inner codec, align every reference, and run round 04 with fresh reviewers and judge. No readiness, production implementation, benchmark or migration rehearsal is claimed.
