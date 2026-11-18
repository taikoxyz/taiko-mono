# Etna top-up rollback observations repair

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for this one scoped feedback repair. Steps use checkbox syntax.

**Goal:** Address PR22387 review4609790258 by independently observing the selected reverted Registry writes before the nested token call in N04.

**Architecture:** Extend the existing atomicity producer and its closed receipt oracle with actual ordered Vm AccountAccess/StorageAccess observations. Preserve the complete selected raw pre/post observer, nested token allowance write, refusal and identical retry. Keep completed N01–N05 and their evidence intact.

**Tech Stack:** Existing managed Python, offline Forge1.4.2/solc0.8.30 and pinned forge-std; no new dependency.

**Spec:** [Existing N04 design](../specs/2026-11-18-etna-public-consumer-conformance-design.md#n04-late-transfer-failures-and-exact-call-retry); canonical SPEC and scoped correspondence pins remain unchanged. Feedback is evidence, not new authority.

## Global Constraints

- Base e7bd3d91baf4b686d7d52a267392913ad9dcf659; existing codex/etna-tla-settlement draft branch only.
- This is one confirmed feedback repair, not a new increment/group or reopening completed batches. Leave the deferred qualified-unittest import P3 alone.
- No production/SPEC/Notion, deployment/live, signing/key generation, install, dependency fetch or security-specific tools.
- Keep contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c, all manifests/public projections/tools/dependencies and original pre-N baseline executable bytes intact.
- Use explicit bounded gh, GIT_NO_LAZY_FETCH=1 for local Git and the managed Python interpreter with -B. Environment paths are runtime configuration only.
- One implementation writer, independent source review and independent behavior. No source/model/config/docs writes during engine guards; native execution waits root static preflight GO.
- Retain all raw failures/restorations and the existing physical Forge lock and fresh private per-campaign caches. Never mutate canonical source for an experiment.
- Root owns shared REPORT/WORKLIST/README, publication and monitor state. Preserve all previous ledgers and keep completed_batch state unchanged.
- At most two material repair rounds for this scoped finding, then explicit root adjudication. Push normally only after relevant checks and independent gates; no merge/ready.

## Review Focus

- Same error, token allowance write and rollback digest can hide absent Registry attempts.
- The write storage account is the proxy, while DelegateCall names implementation code. Resume after the Inbox call can contain the writes.
- Order is relative to the unique actual nested token CALL; do not infer all writes from a parent frame or accept post-token/child-context writes.
- Bind all four distinct selected slots, actual old/new values, count/order and revert metadata, and check restored raw values. Reject omitted, duplicated, swapped or altered observations.
- Keep register, successful retry/activation, N02/N03 outputs and omitted-transfer source control intact. Old N04 receipts lack the new witness and remain historical, not a silent compatibility fallback.

---

### Task 1: bind actual pre-token Registry writes and prove discrimination

**Files:** Modify formal/etna/conformance/solidity/EtnaRegistryAtomicityCases.t.sol, formal/etna/conformance/run_registry_cases.py (atomicity only), formal/etna/conformance/registry_cases/pins.json (atomicity only), formal/etna/tests/test_registry_cases.py and formal/etna/conformance/REGISTRY_CASES.md. Minimal shared base edits require root evidence of necessity; no broad refactor.

**Interfaces:** Existing \_callRegistry records ordered Vm accesses only around the action. Extend the typed atomicity receipt with observed selected transitions and token-boundary relationship; the independent Python oracle accepts exact source-derived values. Other scenario ABI/result dictionaries remain unchanged. Source output is a bounded fixture witness, not an exhaustive storage trace.

- [ ] Inspect producer/consumer/runtime entrypoints and write meaningful RED tests. Demonstrate the old oracle cannot discriminate moving the same transfer before Registry writes while retaining the same refusal, allowance observation and final state. Native RED/controls may be performed by the independent verifier under separately reviewed isolation; no engine before GO.
- [ ] Implement actual trace observation and strict downstream receipt checks. For topup_refusal bind pending0→4→0, ready0→14→0, admission leaf4096 16384→32768→16384 and parent2048 16384→16385→16384. Derive/pin the four exact keys independently from TOP and R+3. Each selected write is exactly once in the proxy's delegated context, occurs before the unique nested token call and is reverted. Upper index nodes do not change because the empty sibling slot2 wins at parent1024. Preserve the actual observed fields; do not emit literal expected values as runtime observations. Preserve token allowance4→0 rollback and complete raw-state equality.
- [ ] Freeze the field/schema/oracle and staged inputs, get root static GO, run one narrowly selected native top-up observation calibration, then inspect actual segmentation, frame/depth/storage-account and reverted flags. Root GO for full existing two-leaf original/omitted-transfer/restored gate only after calibration agrees. Keep all source/tool/mode/physical-lock guards.
- [ ] Independent verifier exercises actual early transfer or a distinct partial reordering in a private source copy, retains old positive/new refusal, exact intended oracle diagnostic, native call outcomes and same-copy restoration. Include altered-receipt negatives for missing/duplicate/wrong slot/value/context/order/revert/restored fields, plus original/restored positives. Do not call an early-transfer coverage counterfactual a protocol defect.
- [ ] Run focused and ordinary suites, affected N02/N03 exact retained receipt replays and relevant runtime controls. Independently review the complete repair diff and behavior before publication. Write exact commands/results/hash/pin/restoration reports; commit owned changes only. Root updates shared records and GitHub bodies, reads back head/draft/CI and clears processed ticks. Return to feedback-only after this repair; no new group.
