# D98/D99 follow-through and learning-site synchronization

**Owner:** B. **Reviewers:** A and J. **[assumed: work order]** A's [schedule](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5987852227) assigns B the D98 Low follow-ups and a course synchronization after the A-owned full-tree repairs merge. This record is a documentation follow-through, not a red-team round or readiness verdict.

**[assumed: current source status; open: A/J review of B’s sync]** D99 is accepted at `0300904d6002768683e465cc13f102d337f9d1c6`. [B’s approval at `cceb3f7`](https://github.com/taikoxyz/taiko-mono/pull/22260#issuecomment-5988757559) closes the owner-review findings. The sections below preserve the earlier preparation and request-changes checkpoints as history; their pending-owner descriptions are superseded by the final D99 pass at the end. D44 item 5 remains 0 of 2.

## Accepted inputs and review boundary

- **[assumed: accepted input]** D98 is `0dde5dd41c4901dfdacbbce391048c3476382671`, merging B's #22259 at `1451232eb28d9ee28d1fdfea84642bae8f0e1c49`. [A's approval and three Low follow-ups](https://github.com/taikoxyz/taiko-mono/pull/22259#issuecomment-5987881694) govern the S2 changes below.
- **[assumed: accepted input, superseding the initial dependency]** A’s #22260 is accepted by D99 at `0300904d6002768683e465cc13f102d337f9d1c6`, after B’s `cceb3f7` approval and the nonblocking C3 wording fix. Earlier drafts did not treat the scheduled mechanisms as accepted before this merge.
- **[assumed: audit reading adopted in D98]** Only full-tree rounds under J's two-refuter protocol count toward D44 item 5. The count is **0 of 2**. The earlier clean delta rounds remain historical evidence; a repair review is not a counting round.

## D98 Low follow-ups

| A's requested clarification | B's disposition | Remaining limit |
|---|---|---|
| S2 §9 must track the C2-R20/§11 consumer of checkpoint-backed finality. | An explicit consumer row names the required projection and its acceptance evidence. | It stays open until the reviewed A-owned consumer is accepted; joint encoded and executed fixtures remain separate obligations. |
| R17/V53(d) must disclose different honest tips across the maturity boundary. | The rule and schedule distinguish local eligible-tip choice from a C7 validity verdict and the persistent signing guards. | Mature-view agreement and authenticated replay remain assumptions; missing inputs hold selection. |
| The landed row and lifecycle need the L1-reorg edge. | The label states its pre-finality reorg exposure. Reorgs from LANDED and LANDED_PROVISIONAL recompute the canonical landing/promotion state: a lost landing is void; a lost promotion may restore provisional status. | The existing non-reorg CONFLICT route for provisional records remains. Finality still needs the covering checkpoint publication, with its proof and upgrade assumptions. |

**[proven: scoped comparison]** The complete D1 quotation remains byte-identical to D98. C4's current status records the merged full-tree repairs while retaining the explicit C2-R04/C7 condition on its first-journal bootstrap argument. No bootstrap regime, layout, witness or fixture is closed by a status update.

**[assumed: independent scoped review]** A separate B reviewer approved the S2 Low follow-ups at S2 blob `e6430cc21fe2814db7019c41062c4cd131c0837b`: it found no new conflict between the shallow-reorg transitions, provisional CONFLICT rollback and the final checkpoint predicate. This review covers those edits only and does not stand in for A/J or a full-tree round.

## Course and index synchronization

**[assumed: prepared D98 synchronization; open: dependent A repairs]** Current teaching follows accepted D98, retaining open and unsigned markers and immutable owner citations. The scheduled D99-dependent V5 maturity hold, announcement escrow and C2 finality projection will be checked against their actual accepted text before the full scheduled pass is declared complete. D95/D96's stored `confirmingLeaf` and `forcedExit` behavior were checked against their accepted owner text and remain part of the coverage.

**[proven: source comparison]** The separate `lastLandedTerm = firstEtnaTerm - 1` assignment already appears in accepted C4-R07; D98's newly merged proposal is R08's ten-field `LastLanded` table, whose complete C2/C7 bootstrap integration remains open. The course must not relabel the pre-existing cursor as a newly proposed rule. Likewise, accepted C2-R20's unqualified `landed` includes checkpoint publication; an accepted provisional landing receipt is labeled separately. The course preserves those distinctions while S2-R18 owns the corrected final predicate.

**[open: A-owned entry point]** The root README still presents D86-era current status and the old round-2 fix PR as pending. Its owner is A; this pass does not silently rewrite it. A's final entry-point refresh should reflect D97/D98's 0-of-2 reset and full-tree protocol, without presenting the old nine-section readiness census as a fresh full-tree audit.

## Validation and exclusions

**[proven: D98 preparation checks]** The prepared changes cover 17 Etna files. Static validation passes for 14 HTML pages, 23 inline SVG diagrams and 323 local targets, including fragments. The 1,153 immutable GitHub references resolve to 789 unique targets across 137 Git blobs: 1,025 line anchors, 54 heading/id anchors and 74 whole-file references. All 20 D98 `#L108` citations resolve to the actual D98 row. S2 retains 58 unique vector IDs; its 1,905-byte complete D1 quotation and every course blockquote remain byte-identical to D98. `git diff --check` passes. WORK and DECISIONS remain byte-identical to the accepted base.

**[open: remaining validation]** These are checks of the D98 preparation, not the still-dependent D99 synchronization. Browser rendering was attempted but did not produce a usable screenshot in this environment, so no visual-rendering pass is claimed; the temporary profile was removed. No production contract/client changes, deployment, gas measurement or executed conformance suite are part of this task. The scheduled final pass must recheck any later changed source and teaching before publication.

## A's repair review and pending consumer draft

**[assumed: B's W8 verdict; open: A/J disposition]** A opened #22260 at `ee7664c`; its current reviewed head is `8234e18a883677c1a5d9fdbfd2c3108230972acf`, differing only by a README status refresh. B's [commit-pinned review](https://github.com/taikoxyz/taiko-mono/pull/22260#issuecomment-5988544305) requests changes for four Medium specification defects: successive image rotations, an unsupported blob-inclusion deadline, the omitted sentinel bond/exclusion conjunct, and the marker-setter/tip-writer distinction. It also lists the smaller projection and vector corrections. No new Critical/High or qualifying red-team round is claimed. The reviewed maturity and money mechanisms pass only their stated scopes.

**[open: pending source acceptance]** The README drift noted above is addressed by A's `8234e18` status overlay; that source is still a pending PR at this review. B's proposed owner consumers and teaching below are labeled separately from accepted D98. P-B-FT-02 records the review and economic illustration change append-only in DECISIONS; existing decision rows and WORK are unchanged. The D98-only validation above applies to the earlier preparation, not to these subsequent pending additions.

## Pending consumer checkpoint and second W8 verdict

**[assumed: review record; open: A/J disposition]** A’s `ce6d0ca8cc142893fc530d82dc3bd99ed63a29f0` repairs the original four traces. [B’s scoped re-review](https://github.com/taikoxyz/taiko-mono/pull/22260#issuecomment-5988695253) closes the sentinel and marker/updater findings, and the service finding under the explicitly assumed total waiting/proving/inclusion bound. The fixed-duration image-retention argument passes, but a new variant of that Medium remains: an ordinary upgrade can raise the live provisional-finality duration after the old image’s overlap expired, keeping the unfinalized record contestable in name while evicting its only matching image. The review also carries forward the finality diagram/vector and census/economic projection Lows. This is not a new full-tree round.

**[assumed: proposed artifacts; open: accepted-head synchronization]** The frozen draft includes S2’s all-reference maturity consumers and V55, C4’s class-A announcement-refund exception and authenticated legacy-liability audit, three C6-B candidate overlays, and fourteen course pages. New candidate mechanisms remain marked PROPOSED and pinned to `8234e18`; the final pass will re-read and repin the accepted correction. These pages must not be published as accepted current rules from this intermediate checkpoint. A has not accepted the owner PR or assigned D99 at this check.

**[proven: static checks on this draft; assumed: tool output]** Against D98, all 21 changed paths are under Etna, WORK is byte-identical, and DECISIONS preserves the accepted bytes as a prefix. Fourteen HTML pages parse, all 33 inline SVGs parse, and 638 local link targets resolve (340 HTML, 298 Markdown). All 1,405 immutable links resolve against local Git objects (939 distinct targets, 155 blobs; 1,270 line links, 61 fragments, 74 whole blobs); all twenty D98 line-108 links identify D98. The complete raw D1 quotation is unchanged at 1,905 bytes, and the decoded lesson quotation matches it. S2 has 59 unique vector rows. `git diff --check` passes. These counts describe the candidate draft before the appended review-record links; later validation must recompute them.

**[open: visual and implementation evidence]** A headless local Chromium attempt timed out without producing a screenshot; its owned scratch profile and log were deleted. No visual-render pass, compiled layout, executable fixture, gas measurement, production test or deployed-state audit is claimed.

## Final D99 synchronization

**[assumed: accepted owner sources; open: A/J review of this B pass]** D99 at `0300904d6002768683e465cc13f102d337f9d1c6` accepts A’s repair after B’s approval of `cceb3f7812a0126da283ccd43f6023a30eda5d89`. A also applied the remaining C3 prose clarification before the accepted head. The B branch incorporates D99 with a merge commit, preserving its published history. B’s P-B-FT-02/03 review statuses remain historical; P-B-FT-04 records the accepted disposition without editing an arbiter row.

| Mechanism | Teaching and consumer change | Remaining boundary |
|---|---|---|
| Fixed-reference maturity | S2 cites C7’s gate for every fixed L1 reference; the lesson’s existing held-input rules, diagram and answers now require mature evaluable references. The honest-reference selection policy is 60 s under the stated 12-s head-spread premise, distinct from the 48-s validity/reset floor. | Head lag and delivery are unmeasured; L51 unsigned. No PH.timestamp delay is added. |
| Announcement escrow | C4/S2 and operative landing, FI and migration text distinguish ordinary refunds from a class-A-voided announcement; paid-pin and forfeiture recipients use bound rewardTo. | Record placement, exact lazy-refund ABI and encoded fixtures remain open. |
| Rotation and service | Course/indexes consume both non-emergency upgrade guards and P-SPI’s explicit assumed total waiting/proving/inclusion bound, with cumulative refresh work and a bounded served prefix. | Emergency upgrades and guard costs remain disclosed; P-SPI has no inferred user signature or measured value. |
| Role/economic accounting | The course updates zero-seat reserve release, exact-next-term pin payment, live-key registration, strike-gap storage, both reserve-drain recipient cases, rounding and legacy ETH liabilities. | Economic illustrations are conditional, not measured floors; unsigned residuals remain unsigned. |
| Finality and provenance | Covering-checkpoint publication finality governs the final label; stored confirmingLeaf remains the event provenance; forcedExit and exact live restart inputs remain taught. The 86-name error census and 49-byte Operator scalar count match D99. | Publication finality is not proof soundness. Counts are not implemented fixtures or audited layouts. |

**[assumed: review method]** Independent narrow B reviewers rechecked the changed S2/C4 consumers, the rotation and timing fixes, and the operative course sentences against immutable owner sources. These reviews improved this documentation pass and do not stand in for A/J, the full-tree protocol, or implementation evidence. The complete D1 quotation remains unchanged; no production code or deployment work is included.

**[proven: final static validation; assumed: tool output]** Against the accepted D99 base, the final pass changes 21 Etna-only files. WORK is byte-identical and DECISIONS preserves every accepted byte before B’s append-only proposals. Fourteen HTML pages and all 37 inline SVGs parse with no duplicate ids; 627 local targets resolve (329 HTML, 298 Markdown). All 1,451 immutable links resolve (950 distinct targets across 156 blobs; 1,316 line anchors, 61 fragments, 74 whole blobs); all 21 D99 line-109 and 25 D98 line-108 citations identify the correct decision rows. D1 remains exactly 1,905 raw Markdown bytes and matches the decoded lesson quotation. S2 has 59 unique vector rows, including V55. No external runtime assets were added. `git diff --check` passes. The earlier browser-render limitation remains: this is static validation, not a visual, production, fixture-execution or measurement result.
