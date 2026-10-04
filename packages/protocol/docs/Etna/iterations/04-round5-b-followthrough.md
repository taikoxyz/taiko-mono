# Round-five B consumers and accepted-rule synchronization

**[assumed: review record; open: A/J acceptance]** Base: D93/D94 at `0214b4c8cd5d9b209890f058cb53da66c933c2e2`. [A’s round-five report](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5984732764) assigns B the S2 stale-adoption text and C4 restart consumer. [A’s owner candidate](https://github.com/taikoxyz/taiko-mono/pull/22254) at `72a236800a3dbd1b10c57ab710d130ef07e8ec58` additionally requests S2-V47(c)’s announcement-spent control. This is a consumer/teaching follow-through, not a new red-team round.

## Accepted rules and remaining boundaries

**[assumed: D93/D94 acceptance]** S2’s recovery classifier, non-deferring record semantics, clock definitions and partial C2/C3/C8/S4 reader projections no longer await the adoption those decisions supplied. D94 also accepts the correlated rotation hold, permanent own-record-loss hold, explicit replay premise/full-root shortcut, pruned-history refusal and C4’s eager/lazy refund consumer. The course and indexes now teach those accepted rules as accepted.

**[open: completion, unchanged by acceptance]** Opening-subrun/cursor writers, sentinel reconstruction, restart-opening identity, lazy-refund ABI/layout, complete authenticated reader/persistence fixtures, retention/replay/gas measurements and S2-V43 remain open. Rule G, its pre-TC/signed-domain changes and RPT remain unadopted. D93’s OwnerSuspended gate and tenure exemption remain unsigned by the user, as do the previously recorded D88/D91 risks. A partly closed item is not declared closed or out of scope by this update.

## Pending owner consumers

| Finding | Consumer and logical schedule | Remaining dependency |
|---|---|---|
| RST-01, Low | C4-R12 cites C2-R14’s live first/conflictK/r selection and startDigest check. T22a has a finalization pass advance first after payload preparation; T22b lowers conflictK with an unchanged first; both reject stale pins. T22c prepares once first=conflictK; the stated ordinary calls cannot invalidate it. T22d alters the preimage or fails a later check; all new payload effects roll back. | #22254 acceptance; C2/C8’s pin/preimage encoding and exact stale-input error/priority. No bounded DAO delay or new C4 ABI. |
| L1-R5-01, Low | S2-V47(c) adds a record accepted after an announcement has already spent the flag: it leaves spent state and the established rf unchanged. Existing non-deferring record and historical A1 reads remain distinct. | #22254 acceptance; encoded evidence/history fixtures. |
| XS-R4-STALE-S2-QUOTE, Low | S2 clears current pending-adoption statements only for the D93/D94 subset. Source pins point to accepted owner text; still-open reconstruction/fixture obligations remain explicit. | A’s matching C2 text is in #22254; B claims no semantic closure beyond the decisions. |

**[proven: conditional restart stability]** Under C2-R13/R14 and with no intervening authorized upgrade/restart, a pass stops before conflictK and a lowering conflict needs a PROVISIONAL record with first ≤ k < conflictK. At first=conflictK that set is empty; neither permitted operation changes the pair. Before equality, an ordinary permissionless pass or valid earlier counterproof can invalidate a pinned payload; its cost is the corresponding public call/proof and gas, its effect a failed stale upgrade, not permission to restore stale custody. The proposed consumer preserves prior committed checkpoints and rolls back only the failing payload’s new writes. This argument neither requires an attacker nor establishes a wall-clock completion time.

## Review coverage and validation

**[assumed: J/A status]** [J confirms](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5984961450) rounds 3, 4 and 5 as consecutive rounds without a new verified Critical/High. Round five has nine verified Lows and no verified Medium. Item 5 is met, not the whole readiness checklist. J records that rounds 3–5 were delta reviews and recommends a full-tree pass; [A accepts that next step](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5984970938) after the Low fixes merge, before the audit. No full-tree round is claimed here.

**[proven: scoped review and static validation; open: execution and measurements]** Independent scoped reviews approve the S2 accepted/pending distinction and spent-flag consumer, C4’s live-input/atomicity schedules, and the course/index status projections. Static checks pass across 14 HTML pages, 20 SVGs, 311 local targets and 308 immutable source anchors; all 56 expected S2 vector rows occur once, the full D1 quotation is unchanged and DECISIONS is append-only. All 16 changed/new files are under Etna, with WORK and arbiter rows unchanged; `git diff --check` passes. Logical schedules are not executed conformance tests. Browser rendering, gas/replay costs and complete fixture encodings remain unverified; no production change is included.
