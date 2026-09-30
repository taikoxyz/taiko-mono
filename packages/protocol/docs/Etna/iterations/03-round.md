# Round 03 — complete outer interfaces; inner codec gap

Reviewed snapshot: `29cc3b060`. Fresh reviewers: **gpt-6.1-sol** [A](03-a.md), **gpt-6-astra** [B](03-b.md), **gpt-6-sol** [C](03-c.md). The [fresh separate judge](03-judge.md) had no design authorship; its inherited model identity was not exposed. Reports disclose the coordinator's codec concern and counterarguments, rather than claiming wholly unprompted judging.

**Judgment: zero new Critical or High; one unresolved Medium. Not converged.** Rounds 02 and 03 meet the consecutive Critical/High-free count, but the complete R6/R7 specification does not yet pass.

- **J03-01, Medium, required fix:** the inner body/manifest serialization and `manifestRoot` construction are undefined. Outer hashes and a sound proof cannot choose an unspecified decoder. Specify canonical headers/transactions, all forced inputs including rejects, system anchors, fragment boundaries, hash domains and a reproducible fixture; then obtain fresh review.
- **C-01, proposed High, rejected by judge:** selectively serving X while mature public Y wins does not establish a new forbidden canonical outcome. Y has a public data lead; X's valid recipient already has complete bytes and can relay them; the same soft rollback can occur with X public from issuance. A new absolute X-publication service would not guarantee priority over an already-mature Y. The 600-second recovery promise, optional sealed covenant, attribution misses and timeout errors remain explicit limitations.
- Prior Medium pipeline-attribution and economic-concentration risks remain accepted with the exact bounded scope in the judge report. Earlier signature/key grammar and forced-fee accounting defects are fixed at specification level.

Next: define and commit the inner codec, align every reference, and run round 04 with fresh reviewers and judge. No readiness, production implementation, benchmark or migration rehearsal is claimed.

## Disposition before round04

J03-01 now has a concrete proposed repair: [codec.html](../design/codec.html) fixes an uncompressed RLP body, complete 21-field L2 header and signed transaction families, all forced bytes/outcomes, ordered fragment and segment manifests, and exact system-anchor envelopes. [Component fixtures](../design/codec-vectors.md) give numeric commitment values, offsets, boundaries and required rejection cases; the intentionally tiny example is not falsely presented as a valid Ethereum block or proof.

The execution profile pins public Unzen/Osaka sources and enumerates Etna overrides: fixed total gas bounds, one-second basefee target, deterministic header metadata, a single origin per segment, and protection of the public system identity from ordinary transactions or EIP-7702 delegation. Existing anchor fee exemption, nonce/gas accounting and 75/25 fee rounding were checked against pinned public source. Every first-activation proof byte is carried publicly in the bounded anchor transaction. Local preconf authentication need not wait for an L1 header-pin transaction.

Cross-page references now distinguish the early block-fragment root from the sealed segment manifest root. Honest recipients re-gossip complete validated blocks; this clarifies the actual data-holder response in C-01, without claiming irreversible soft ordering or a new mandatory absolute-publication promise. The judge's accepted Medium scopes remain unchanged.

Validation before fresh review: seven HTML pages parsed, unique IDs/local links checked (course entry still pending), whitespace checked, formulas and pinned public fee/anchor sources spot-checked, and scratch-only Keccak/ABI fixtures calculated with known Keccak test answers. No production implementation or benchmark was run. Fresh round04 must test the complete updated specification, including these new profile choices.
