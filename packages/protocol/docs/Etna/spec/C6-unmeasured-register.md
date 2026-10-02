# C6. Unmeasured-numbers and source-register index

**[assumed: ownership]** B maintains this index under D12/W6/W16. Each section owns its values, formulas, claim tags and closure criteria. A's C6 owns limitations. This index adds no protocol parameter, measurement, approval or implementation requirement.

**[assumed: status convention]** A link inherits its owner's claim and measurement labels, including mixed premises. Arithmetic on assumed gas, price or latency is not measurement. D44 amends D2: every number unmeasured at completion needs an owner-specified conservative default and measurement procedure. Existing assumed examples are not thereby proven conservative. Missing encodings, contradictory rules and undefined transitions require semantic resolution.

## Register maintenance

1. **[assumed: documentation process]** Every entry uses an existing row label, owning section and immutable source. Each entry carries no parameter value: values stay at the source. Where an owning table merges identifier and value in one cell, this index keeps only the identifier.
2. **[assumed: documentation process]** On an owning merge, re-pin and check the linked rule/row. Proposed newer sources are identified as proposals; a source pin alone is not acceptance.
3. **[assumed: documentation process]** Cover every numeric row and each owner's open/unmeasured list. Under D44, index the owning default, its conservative rationale, measurement procedure and consequence of an out-of-range result; invent none in this index. Semantic corrections go to the owner.
4. **[assumed: experiment boundary]** Any optional experiments run only in the session scratchpad and are deleted afterwards. Documents may preserve inputs, methodology and results; do not commit experimental code.

**[assumed: dated inventory]** This inventory preserves its W15/W16 immutable pins except C2, revalidated against its accepted D36 register at fb6180a, and C8, revalidated against its accepted D49 register at f87836f. Other draft pins are historical, not assertions that they remain current. The [dashboard overlay](C6-assurance-dashboard.md#current-decision-and-review-overlay) records subsequent decisions/reviews, through D49, including the D48 holder-path scope and A-only acceptance of #22215. Unmerged numeric registers are re-pinned after owner acceptance, without promoting their estimates in the meantime.

**[open: D44 completion]** The [closure index](C6-readiness-closure-index.md) identifies semantic owner work and required default/procedure evidence. A listed procedure is a task, not its result. No estimate becomes conservative merely by being inventoried.

## Source-register inventory

### C1: [owning register](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L235)

**[assumed: index; tags/status as source]** Pin `42c76c9b`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [P-HASH](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L241)
- [P-NUMBER](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L242)
- [P-PIN-SENTINEL](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L243)
- [P-RING](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L244)
- [P-SYSTEM-GAS](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L245)
- [P-READ-GAS](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L246)
- [P-HEADER-BYTES](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L247)
- [P-HEADER-FIELDS](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L248)
- [P-EXTRA](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L249)
- [P-FEE-SHARE](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L250)
- [P-TERM / P-VIEW / P-KIND](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L251)
- [P-FI-EXAMPLE-GAS](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L252)
- [System caller](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L258)
- [EIP-4788 address](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L259)
- [EIP-4788 runtime code hash](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L260)
- [EIP-2935 runtime code hash](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L261)
- [EIP-2935 address](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L262)
- [EIP-4788 system calldata](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L263)
- [EIP-2935 system calldata](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L264)
- [System-call ETH value](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L265)

### C2: [owning register](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L367)

**[assumed: accepted source; D36]** Pin `fb6180a5`. All 34 numeric rows were rechecked by label and line in this follow-up. D39 supersedes FI-dependent premises such as the run/clock/drift inputs; those rows remain owner-pending revisions, not adopted hatch parameters.

- [MAX_BLOCKS / MAX_VIEWS / MAX_BLOBS](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L373)
- [MAX_FI](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L374)
- [Blob usable bytes](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L375)
- [V9 record bound](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L376)
- [V10 = TERM_BYTES_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L377)
- [LANDING_BYTES](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L378)
- [LANDING_UNIT](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L379)
- [MAX_L1_HEADERS_PER_LANDING](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L380)
- [DRIFT_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L381)
- [LAND_WINDOW / LAND_WINDOW_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L382)
- [LAND_CHAIN_GRACE / REPLACE_GRACE](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L383)
- [ANNOUNCE_BOND](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L384)
- [DEGRADE_AFTER / DEGRADED_FINALITY](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L385)
- [PROVISIONAL_RING](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L386)
- [ROTATION_OVERLAP](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L387)
- [ZK_K / ZK_N](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L388)
- [R_BLK_MIN / R_BLK_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L389)
- [R_LAND_MAX; break-even fee](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L390)
- [R_BLOB, cap](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L391)
- [PIN_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L392)
- [ATT_REWARD_PER_BLOCK; LAND_RESERVE](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L393)
- [Per-term exposure](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L394)
- [RETAIN_SECONDS](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L395)
- [T2 blob retention](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L396)
- [FORCED_RING](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L397)
- [ANCHOR_MIN_AGE / ANCHOR_MAX_AGE; ROLE_HORIZON](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L398)
- [EIP-2935 / blockhash windows; landing horizon](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L399)
- [TERM_RING; SETTLE_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L400)
- [LANDED_CONFIRM_DEPTH; EXPIRY_TTL / REORG_MARGIN; LANDING_GAS_BUDGET](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L401)
- [LAND_CALLDATA_MAX](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L402)
- [Gas per landing](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L403)
- [Gas: committee walk when a landing pins; race loser](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L404)
- [Happy-path landed latency](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L405)
- [Checkpoint delay in degraded mode](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L406)

### C3: [owning register](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L248)

**[assumed: index; tags/status as source]** Pin `4aa0299c`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [FI_BOND](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L254)
- [SKIP_ESCALATION](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L255)
- [ESCALATION_DECAY](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L256)
- [FI_SKIP](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L257)
- [FI_DELAY](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L258)
- [FI_EXPIRY](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L259)
- [MAX_FI_RUN](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L260)
- [MAX_FI_PER_LANDING](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L261)
- [FI_BASE_FEE / FI_FEE_THRESHOLD](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L262)
- [FI_DUE_MAX](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L263)
- [FI_CALLDATA_MAX](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L264)
- [FI_GAS_LIMIT](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L265)
- [FI_ZK_GAS_LIMIT](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L266)
- [FORCED](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L267)
- [FORCED_RING](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L268)
- [FI_ANCHOR_LAG](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L269)
- [FORCED_LANDING_GAS](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L270)
- [Exponent cap](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L271)
- [Stall-in-progress threshold](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L272)
- [Inclusion bound](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L273)
- [Honest latency](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L274)
- [Absent pipeline](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L275)
- [FI blocks per term; drain](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L276)
- [Forced anchor window](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L277)
- [Origin age of a forced block; of an FI block](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L278)
- [FI record size](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L279)
- [Stuffing cost](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L280)
- [Stall seed cost](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L281)
- [Honest deposit after a run](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L282)
- [Per-requester ledger avoided](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L283)
- [Proof window of a blob entry](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L284)
- [Reveal and pin fit](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L285)
- [Manifest wrapper](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L286)
- [Quoted constants](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L287)

### C7: [owning register](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L201)

**[assumed: index; tags/status as source]** Pin `515f3be4`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [ANCHOR_MIN_AGE](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L207)
- [ANCHOR_MAX_AGE](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L208)
- [RECORD_MAX (V9)](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L209)
- [TERM_BYTES_MAX (V10)](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L210)
- [Framing per block](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L211)
- [extraData, P-EXTRA](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L212)
- [BASEFEE_SHARING_PCTG](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L213)
- [Kind values](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L214)
- [Sentinel views](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L215)
- [V_MAX; CERT_LAG_MAX](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L216)
- [PENDING_TTL; ANCHOR_WAIT](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L217)
- [MAX_FI_RUN; MAX_FI per landing](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L218)
- [Drift of an inherited anchor past ANCHOR_MAX_AGE](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L219)
- [FI_GAS_LIMIT; FI_ZK_GAS_LIMIT](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L220)
- [Per-block zk-gas limit](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L221)
- [FI record size](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L222)
- [LOOKBACK](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L223)
- [EIP-2935 window at L1](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L224)
- [Predicate evaluation cost per block](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L225)

### S1: [owning register](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L165)

**[assumed: index; tags/status as source]** Pin `e72e55e8`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [TERM; CYCLE_TERMS; T0](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L171)
- [LOOKBACK](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L172)
- [DELAY_S](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L173)
- [DELAY_REG; its inequality](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L174)
- [freshFrom offset; freshness window](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L175)
- [MIN_TENURE; STALE_EXIT](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L176)
- [EVIDENCE_WINDOW](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L177)
- [ROLE_HORIZON](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L178)
- [SUSPEND(3)](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L179)
- [B_SEAT; buffer; hard floor; LAND_RESERVE](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L180)
- [Entry capital per seat](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L181)
- [CAP; MAX_SEATS](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L182)
- [MAX_TRIES; MAX_DISTINCT](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L183)
- [WALK_MAX; walk failure probability](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L184)
- [K; K_MIN_CERT; V_MAX](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L185)
- [Full-committee minimum; launch condition](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L186)
- [Open-empty probability](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L187)
- [DEAD_TERMS; dead-mode opening](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L188)
- [TH9 price of share](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L189)
- [L1-proposer seed bias](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L190)
- [Domain write gas](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L191)
- [Committee walk gas (a pin)](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L192)
- [`isHolder` gas](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L193)
- [`poke()` gas](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L194)
- [Pin gas at the launch registry](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L195)
- [MISS_PENALTY; STRIKE_THRESHOLD within STRIKE_DECAY](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L196)
- [PIN_MAX](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L197)
- [Domain tags and walk prefixes](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L198)

### S2: [owning register](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L230)

**[assumed: index; tags/status as source]** Pin `ab391fe4`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [K; K_MIN_CERT](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L236)
- [Q(m)](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L237)
- [No-quorum and below-minimum-committee probabilities](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L238)
- [V_MAX; CERT_LAG_MAX; REDRAW_MAX](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L239)
- [TIMEOUT; TO_REBROADCAST; END_GRACE](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L240)
- [END_GRACE slot bound; handoff margin](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L241)
- [VC round trip](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L242)
- [VC_FALLBACK; gate times](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L243)
- [Certificate record moment; late record](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L244)
- [STALE_MAX / CLOCK_SKEW](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L245)
- [PENDING_TTL / ANCHOR_WAIT; RANGE_MAX / RANGE_RATE](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L246)
- [RETAIN_SECONDS](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L247)
- [MAX_ENVELOPE; gossip height window](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L248)
- [Certificate size](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L249)
- [View change size; `vcHash` preimage](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L250)
- [Aggregate verification gas; committee walk gas](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L251)
- [View-change verification gas (D16)](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L252)
- [L1 recording cost per term (S2-R13)](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L253)
- [Level timings](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L254)
- [Collusion probabilities](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L255)
- [Sentinel views; domain tags](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L256)

### S3: [owning register](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L260)

**[assumed: index; tags/status as source]** Pin `a0f3232a`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [V_term; P (A-REV)](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L266)
- [H(X)](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L267)
- [B_SEAT](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L268)
- [Collectible collateral per key](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L269)
- [Credit bounds](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L270)
- [BUFFER_BPS / HARD_FLOOR_BPS](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L271)
- [Entry capital](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L272)
- [Per-term exposure](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L273)
- [LAND_RESERVE](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L274)
- [Lapse line; ReserveLow line; top-up](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L275)
- [Honest drain; outage probabilities](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L276)
- [MISS_PENALTY](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L277)
- [SLASH_CLASS_A; SLASH_SEAT; STRIKE_THRESHOLD / STRIKE_DECAY](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L278)
- [SUSPEND(n); DELAY_S; DELAY_REG; STALE_EXIT; COMMITTEE_RING; ROLE_HORIZON](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L279)
- [CHALLENGER_BPS / CHALLENGER_CAP](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L280)
- [EVIDENCE_WINDOW = EXIT_LOCK](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L281)
- [SETTLE_MAX](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L282)
- [MAX_EVIDENCE_GAS](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L283)
- [Evidence gas](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L284)
- [R_BLK_MIN / R_BLK_MAX](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L285)
- [R_LAND_MAX; break-even fee](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L286)
- [LANDING_UNIT; LANDING_BYTES; paid landings](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L287)
- [R_BLOB; cap](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L288)
- [ATT_REWARD_PER_BLOCK](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L289)
- [PIN_MAX](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L290)
- [ANNOUNCE_BOND split](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L291)
- [Price of primary share](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L292)
- [MAX_SEATS fill cost](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L293)
- [Cartel table; seconds-weighted shares; entrant](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L294)
- [BLS convention](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L295)

### C5: [owning register](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L182)

**[assumed: index; tags/status as source]** Pin `66e37373`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [L1-SLOT](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L188)
- [L1-2935 window](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L189)
- [L1-BLOCKHASH](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L190)
- [L1-4788 ring](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L191)
- [L2-4788 / L2-2935](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L192)
- [L1-GAS-CAP](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L193)
- [L1-BLOCK-GAS](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L194)
- [L1-BLOBS-BLOCK](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L195)
- [L1-BLOB-RATE](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L196)
- [L1-FINALITY](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L197)
- [L1-EPBS](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L198)
- [L1-ANCHOR-MARGIN](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L199)
- [L1-RETENTION](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L200)
- [L1-STATE-GAS](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L201)
- [L1-CALLDATA-FLOOR](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L202)
- [L1-BLOB-RESERVE](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L203)
- [L1-FOCIL-CAP](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L204)
- [TX-ENVELOPE](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L205)
- [FOCIL-LEG-BYTES](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L206)
- [G-PREFIX](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L207)
- [LAND_CALLDATA_MAX](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L208)
- [G-VERIFY-GAS](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L209)
- [G-FLOOR(L)](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L210)
- [G-BURN-MIN](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L211)
- [S2-FLOOR(L)](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L212)
- [D-FLOOR(L)](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L213)
- [G-STALE-EXEC](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L214)
- [MIN_TIP](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L215)
- [T-GATE-DATES](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L216)
- [Quoted constants](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L217)

### C8: [owning register](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L471)

**[assumed: accepted source; D49]** Pin `f87836f4`. All 18 numeric rows are linked by identifier and verified against the merged source. The register separates derived byte/layout arithmetic from quoted inputs and unmeasured costs; none is measurement. The `Operator` row awaits reviewed D45 projection, FI-dependent rows await D41, and the `headerCore` width proposal remains conditional on C2 adoption. Section acceptance does not close these owner-marked conditions or unplaced fields.

- [DOMAIN tags](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L477)
- [phHash preimage](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L478)
- [Other preimages](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L479)
- [L2 timestamp bound; wire L1 number bound](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L480)
- [uint32 L1 time end](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L481)
- [TermRecord; Seat](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L482)
- [New-entry word of the FI queue](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L483)
- [LastLanded storage](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L484)
- [ProvisionalRecord storage](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L485)
- [Operator scalars](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L486)
- [Inbox appended slots; remaining gap](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L487)
- [SignalService gap](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L488)
- [Floor list element](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L489)
- [Anchor gap; Bridge gap; ERC20Vault gap](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L490)
- [FI queue walk, cold loads per entry](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L491)
- [Manifest-wrapped reveal](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L492)
- [headerCore widths (proposal for C2's E02)](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L493)
- [Reinitializer versions](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L494)

### S4: [owning register](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L192)

**[assumed: index; tags/status as source]** Pin `103b7c88`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [Roles](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L198)
- [Rung 1, takeover gap](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L199)
- [Rung 2, idle bound](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L200)
- [Rung 3, FALLBACK gates](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L201)
- [Rung 4, replacement window](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L202)
- [Rung 4, ramp](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L203)
- [Rung 5, degraded mode](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L204)
- [Rung 6, dead mode](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L205)
- [Landing horizon](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L206)
- [Retention gap](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L207)
- [Forced inclusion](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L208)
- [Locked bound](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L209)
- [Quorum failure](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L210)
- [Collusion](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L211)
- [Evidence windows](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L212)
- [Honest draw at the weak premise](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L213)
- [Level timings, cadence](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L214)
- [Landed latency, proving](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L215)
- [Other unmeasured inputs](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L216)

### C6A: [owning register](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L281)

**[assumed: index; tags/status as source]** Pin `22948df9`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [Threats](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L287)
- [Premises](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L288)
- [Round Mediums](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L289)
- [Register rows](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L290)
- [Quorum, stall and intersection counts](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L291)
- [Locked credit bound](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L292)
- [Horizons](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L293)
- [Retention gaps (L25)](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L294)
- [Stall costs (L23)](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L295)
- [L20 thresholds](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L296)
- [L17 leak](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L297)
- [L39 drift](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L298)
- [L37 window](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L299)
- [L27 loser cost](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L300)
- [Evidence windows (L32)](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L301)
- [Unmeasured in this half](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L302)

### C4: [owning register](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L327)

**[assumed: index; tags/status as source]** Pin `93d9038b`. Every register row is linked by identifier below; no parameter value is copied, defined or re-derived here.

- [MIGRATION_LEAD](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L331)
- [FREEZE](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L332)
- [DRAIN_DEADLINE](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L333)
- [MIGRATION_CHUNK_MAX](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L334)
- [Legacy ring and per-proposal forced-source bounds](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L335)
- [Historical floor FI fee](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L336)
- [TERM, ANCHOR_MIN_AGE, FI_SKIP, Etna FI prices/budgets](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L337)
- [Bootstrap/migration integer widths](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L338)
- [Layout, gas, state-witness and code-hash verification cost](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L339)

## Accepted C8 evidence and remaining measurement work

**[assumed: reference-only projection; open: owner evidence]** D49 accepts C8's section while carrying its exact-definition obligations and four synchronization follow-ups. The [source's unmeasured list](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L639) owns the missing cost evidence; no value or conservative default is supplied by this index.

| Source label or obligation | Evidence boundary and next owner artifact |
|---|---|
| Floor list element; C1-R10 state growth; J-3 | [C8-R15](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L381) reserves the L1 array root for the contract lifetime; elements grow with DAO recovery count, not checkpoint count. [C8's C6 obligation](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L601) calls for this lifetime record beside storage growth. The element layout is derived; lookup gas versus recovery count remains unmeasured and requires its owning default, procedure and selected-fork cost record. |
| LastLanded / ProvisionalRecord storage; Inbox appended slots | [C8-R15](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L337) fixes the placed layout and packing. C8's unplaced fields and migration namespace remain semantic work; deployed compatibility and first-write/state costs remain separate C4/C8 evidence. |
| Manifest-wrapped reveal; FOCIL-LEG-BYTES; TX-ENVELOPE | [C8-R18](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L469) derives the wrapper and padded request bound and places reconciliation on C5. Derivation is not an executed wrapper or zk-gas measurement; forced-inclusion use still awaits D41. |
| FI queue walk; headerCore widths | [C8's register](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L491) preserves conditional derivations. The hatch decides whether the walk exists, and C2 owns codec adoption. Do not promote either proposal into a hatch parameter. |
| QuotaManager after ownership renunciation; L-OP | [C4-R10](C4-migration.md#c4-r10-complete-retained-surface-change-table) freezes configuration and preserves consumption state at transition; authorized consumption and refill continue. D49 carries correction of C8-R14's overbroad frozen-state wording. Quota-zero/uncovered-path and total-loss qualifications remain source-owned; this record invents no protection or limitation acceptance. |

## Historical measurement and evidence closure ledger

**[assumed: dated source procedures]** These rows retain their linked W15/W16 tests and proposals. D29/D34/D39 supersede affected confirmation, economics and FI premises; the dashboard overlay gives current dispositions. Owners must carry applicable procedures into current registers with D44's conservative defaults and rationales. Preserve client/prover versions, selected fork, workload, hardware where relevant, cold/warm state, inputs and results. No result is supplied here.

| Owner / existing source labels | Closure evidence and scope |
|---|---|
| C1: P-READ-GAS, P-HEADER-BYTES, P-HEADER-FIELDS, P-FI-EXAMPLE-GAS; C1-R10 state growth | Owning [register](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L235): cold/warm oracle and reveal/pin paths, canonical/malformed header profiles, complete forced-call wrapper, byte/gas/zk-gas budgets; state/witness/disk growth per distinct origin. Measurement alone does not authorize pruning or rent. |
| C2: Gas per landing, Happy-path landed latency, C2-R12–R14 restart paths | [Register](https://github.com/taikoxyz/taiko-mono/blob/6e2b73215ea7031a4d67571049980d9742be13dc/packages/protocol/docs/Etna/spec/C2-landing.md#L321): each leaf, aggregate/header/KZG/queue work, maximal calldata, normal/forced/provisional/conflict calls; proving distributions and replay cost under selected repricing. Keep reward/fee/burn liabilities separate from new replay expenditure. |
| S1: Committee walk gas (a pin), Pin gas at the launch registry | [Register](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L165): separately index the page's small-registry estimate, intermediate simulation and maximum simulation. Reproduce each workload's path/node accesses, then measure full pin/root/key/version/storage overhead. D19 changes the walk; old measurements/simulations do not measure the new algorithm. |
| S1: Domain write gas; isHolder gas | Same register: registration/exit/history lookup, execution versus fresh-state charges, key PoP and standalone assignment costs. |
| S1: `poke()` gas | [Exact source row](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L194): unmeasured, no page estimate. Measure hash, seedAcc write and event with once-per-L1-block behavior under the selected fork. This does not establish an incentive; LS1-1/L35 owns that limitation. |
| S2: Aggregate verification gas; committee walk gas | [Register](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L230): complete aggregate verification and witness/committee access with the final S2/C8 encoding. Walk cost points back to S1. |
| S2: L1 recording cost per term (S2-R13) | [Exact source row](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L253): recordCertificate and recordViewChange separately, full calldata, window tests, first pin versus already pinned, fresh/warm/overwritten storage, record multiplicity, ordinary no-record path and races; derive per-term/day cost from explicit workloads and fee distributions. Aggregate gas is not full recording cost. |
| S2: View-change verification gas (D16); distinct-message verification (D21) | [Published owning row](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L252) now distinguishes signer-specific preimages and multi-message verification from certificate aggregate work; the adjacent [view-change size/preimage row](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L250) specifies the logical/witness split. Estimates remain explicitly unmeasured and conditional on C8 encoding. [B's open S2/S3 review](https://github.com/taikoxyz/taiko-mono/pull/22197#issuecomment-5945463611) raises the S6 witness-binding issue; its owner disposition is semantic review work, separate from a gas benchmark. |
| S2/C7/S4: A-T9, Level timings, Predicate evaluation cost, takeover and handoff | Owning [S2](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L230)/[C7](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L201) registers: gossip, execution, quorum/signature collection, fixed-reference validation, missing context, full/partial/no committee and recovery. Report distributions and workload, not only one successful timing. S4 is a projection. |
| C3: FI_DELAY, FI_ZK_GAS_LIMIT, FORCED_LANDING_GAS, FI record size, Manifest wrapper | [Register](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L248): sparse blob retrieval, selected client zk-gas, exact records/signed wrappers, queue-word reads and dual-proof landing. Compare C1 reveal/pin and legacy-profile envelopes; a void/revert is not successful execution. |
| S3: V_term | [Owning C6 obligation](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L362): **“a week of mainnet coinbase and MEV data.”** Record measured value and date; preserve the window and component attribution. |
| S3: fee input of V_term | [Same owning obligation](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L362): **“the same week's coinbase data.”** Base fee plus tips retained by coinbase, measured value and date; do not merge this closure into an undifferentiated revenue row. |
| S3: MEV input of V_term | [Same owning obligation](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L362): **“the same week's MEV data.”** Ordering value, measured value and date; disclose observable versus private/missing MEV. |
| S3: P (A-REV) | [Source register](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L266): unmeasured A-REV exchange-rate input under L15; see also S3's [C6 obligation](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L362). A's review points to the weekly-data closure; B requested its explicit application to P on #22202 because the published obligation enumerates three weekly tests and names P separately. This index retains the owner references and supplies no additional closure method. |
| S3: H(X); B_SEAT; Credit bounds | [H(X)](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L267), [B_SEAT](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L268), [Collectible collateral per key](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L269), [Credit bounds](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L270), [S3-R10](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L98) and [D20](https://github.com/taikoxyz/taiko-mono/blob/ad85e9fa2cda762d52e117750414fd4cf3c295b4/packages/protocol/docs/Etna/DECISIONS.md#L30): H(X)'s estimation method remains owner-open. Status and adopted threshold-based bound remain as those sources, with the owner's stated drain residual. **Open B review, pending D29/the D20 amendment:** B-C6A-01 disputes continuous funding and the recovery review disputes the quorum-sum interpretation. **B's suggested evidence, not an S3 closure test:** compare exposure with collectible balances after challenger recovery, earlier liabilities, delayed lapses and feasible conflicting intersections. S3 and the arbiter own any changed formula. |
| S3: Evidence gas, reward costs, Cartel table | [Register](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L260): each evidence path, reward/pin break-even workload, model inputs/seed and results under D19/D20. Any optional simulation code remains scratch-only. |
| C4: Layout, gas, state-witness and code-hash verification cost | [Register](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L327): exact deployment/layout/selector/immutable manifest and proof compatibility, bounded chunks, conservation/replay, client parity. Legacy resource/outcome and restart identity schemas are semantic integration obligations, not gas measurements. |
| C4: C4-R04–R06 intake/requeue/funding | [Rules](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L47): distinguish intake wait, repair work, unrecovered paid fees, escrow and fresh replay cost. No second payment, synthetic requester/bond or unspecified subsidy. Include these in the future migration lesson/runbook. |
| C5: L1-RETENTION, L1-STATE-GAS, T-GATE-DATES and shorter-slot assumptions | [Register](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L182): dated selected-fork/client/retention/price evidence; downstream C2/C3 horizons and owning operation costs must follow the verified profile. The equilibrium-reserve interpretation is a semantic assumption, not a benchmark. |
| C5/C8/C2/C3: FOCIL-LEG-BYTES, LAND_CALLDATA_MAX, TX-ENVELOPE | C8 fixes full fields/serialization; C5 checks actual transaction lengths. Preserve ordinary/blob-free distinctions and the user's permitted DA choices. |
| C5: G-VERIFY-GAS, G-STALE-EXEC, G-FLOOR(L), D-FLOOR(L), MIN_TIP | [Register](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L182): B-C5-01's complete four-frame approval shape is repaired; measure winner/loser, malformed short-call and runtime costs under the selected fork. MIN_TIP/frame limits remain owner decisions; typical genuine-call cost is not minimum griefing cost. Private-builder acceptance and unpaid simulation require actual policy evidence. |
| C8: FI queue walk, Manifest-wrapped reveal, LastLanded/ProvisionalRecord storage, appended slots | [Register](https://github.com/taikoxyz/taiko-mono/blob/f03f12a77879d625a7a2e8e34c55c516c47c5efd/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L359): resolve exact word loads/packing with C2/C3/S1 and deployed compatibility with C4; then measure selected-fork state/write and wrapper execution costs. Canonical SSZ/ABI/BLS and D26 authority choices are specification work. |
| S4: Rung 1, Level timings, Landed latency, Collusion, Other unmeasured inputs | [Register](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L192): references S1/S2/S3/C2/C3/C5 above; resolve probability units and theorem premises before copying a figure into the composition. No second parameter set. |
| C6-A: Unmeasured in this half, L17/L24/L32/L37 | [Register](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L281): source owners above supply economic/latency/gas/custody evidence; A owns residual disposition, S3 evidence-window interpretation, C4 migration and the user any D1 relaxation. IG1 is separate. |

**[assumed: economics disposition update]** The historical H(X)/credit-bound row records the earlier dispute. D34 defines separate inventory, live deterrent and conditional illustrations. [B's review 5946996920](https://github.com/taikoxyz/taiko-mono/pull/22202#issuecomment-5946996920) closes the earlier inventory/collectible-floor High at S3 d97f1fb for its original trace; no illustration becomes a guaranteed floor. Current evidence findings remain separate in the dashboard.

## Semantic-open coverage

**[open: index only]** Every source's open/integration list is retained as a linked owner inventory: [C1 §10](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md#L363), [C2 §16](https://github.com/taikoxyz/taiko-mono/blob/fb6180a54d929cf70f742359f1c69e7aa45e972f/packages/protocol/docs/Etna/spec/C2-landing.md#L471), [C3 §13](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md#L331), [C4 §10](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L341) / [§12](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L378), [C5 §14](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L322), [C8 §15](https://github.com/taikoxyz/taiko-mono/blob/f87836f4e8188201a882242c6e051d3991541c29/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md#L561), [C7 §11](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md#L307), [S1 §13](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L243) / [§16](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md#L316), [S2 §10](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L360), [S3 §15](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md#L331), [S4 §10](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L279), [C6-A §11](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L399). W13 identifies cross-owner inconsistencies; owners must disposition each remaining semantic item. A blanket “unmeasured” label cannot close missing encodings, evidence or transitions.

The [D44 closure index](C6-readiness-closure-index.md) expands B's C1/C4/C6 obligations into owner artifacts and checks. It supersedes the blanket D2 treatment; it neither disposes of source-owned open items nor grants user acceptance to a limitation.

## External implementation evidence (IG1)

**[assumed: dated classification]** [C5-R17(d)](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md#L158) classifies [client PR #22207](https://github.com/taikoxyz/taiko-mono/pull/22207) at `1170344842dec57b1a4dcbc5a2d68a9f920a0895` as an implementation gap. C6 records it as IG1. Classification is supplied, not pending: neither the guard nor “Catalyst changes” establishes an Ethereum ePBS dependency. C5 owns reclassification if the eventual confirmation implementation proves to require an L1 consensus change.

**[proven: inspected source behavior, not execution]** The [shared guard](https://github.com/taikoxyz/taiko-mono/blob/1170344842dec57b1a4dcbc5a2d68a9f920a0895/packages/taiko-client/pkg/preconf/etna.go#L16) rejects an Etna-timestamp preconfirmation. Its calls include [BuildPreconfBlock](https://github.com/taikoxyz/taiko-mono/blob/1170344842dec57b1a4dcbc5a2d68a9f920a0895/packages/taiko-client/driver/preconf_blocks/api.go#L110), [payload validation](https://github.com/taikoxyz/taiko-mono/blob/1170344842dec57b1a4dcbc5a2d68a9f920a0895/packages/taiko-client/driver/preconf_blocks/server.go#L959), and [envelope insertion](https://github.com/taikoxyz/taiko-mono/blob/1170344842dec57b1a4dcbc5a2d68a9f920a0895/packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go#L733). This revision does not supply a running Etna confirmation path; it does not prove no other implementation exists.

**[open: implementation evidence]** C5's closure requires a client implementing the accepted S2 layer with Catalyst or a replacement. A future implementation claim needs source revisions and a trace through construction, gossip/import, confirmation/handoff and objective evidence/current backing, including the fork/recovery cases. Removing the guard alone does not establish D1. No client work is requested by this index; timings/costs remain unmeasured until that workload is reported.

**[assumed: D44 scope]** The inspected client gap remains dated implementation evidence. D44 requires a complete implementation-ready specification, reference vectors and defaults with measurement procedures. The task remains design-only under D2; running-client/performance claims need execution evidence.

## Revision notices

**[assumed: decisions and reviews]** C2's numeric inventory is pinned to its D36 accepted revision and C8's to D49; other entries retain explicitly dated sources. The dashboard records D29/D42 confirmation/evidence, D34 economics, D39's pending hatch, D40/D45 registry repairs, D48's adopted holder-path scope awaiting projection, D43/D46 and #22215's A-only course/index acceptance, D44 readiness, D47's accepted delay and D49's accepted C8 with nonblocking follow-ups. Prior clearances approve only their cited heads.

**[open: follow-up review]** This update changes no parameter, formula, WORK status or limitation disposition. Defaults still need conservative rationales/procedures where absent, draft inventories need owner-merge updates, and completion requires WORK's full evidence checklist.
