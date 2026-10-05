# D98 follow-through and the scheduled learning-site synchronization

**Owner:** B. **Reviewers:** A and J. **[assumed: work order]** A's [schedule](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5987852227) assigns B the D98 Low follow-ups and a course synchronization after the A-owned full-tree repairs merge. This record is a documentation follow-through, not a red-team round or readiness verdict.

## Accepted inputs and review boundary

- **[assumed: accepted input]** D98 is `0dde5dd41c4901dfdacbbce391048c3476382671`, merging B's #22259 at `1451232eb28d9ee28d1fdfea84642bae8f0e1c49`. [A's approval and three Low follow-ups](https://github.com/taikoxyz/taiko-mono/pull/22259#issuecomment-5987881694) govern the S2 changes below.
- **[open: dependent input]** A's full-tree repair PR and its accepted merge are not yet available at the start of this pass. No future V5, escrow or C2 finality text is treated as accepted merely because the schedule names it. This row will record the actual reviewed and merged commits before that part of the synchronization is complete.
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
