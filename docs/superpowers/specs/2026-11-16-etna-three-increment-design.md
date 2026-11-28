# Etna verification: three increments after review repair

The user authorized continued verification in batches of three, with confirmed
PR22387 feedback repaired first and hourly review checks. R0 is published at
`d1206bb0784346145449b22b00cbd791461c6713`; this is the subsequent three-item batch.
Keep the existing project, branch and draft PR, and stop after these three for
a retrospective. Review feedback retains priority throughout.

## Objective

Reduce shared assumption gaps: a successful witness must have explicit,
consistent input premises, and selected boundary behavior should be compared
with the actual implementation where feasible. Counts of green checks do not
establish completeness. This batch makes no protocol design change.

## T01 — distinguish BFT genesis time and EL time

Add a small bounded first-block timestamp companion under formal/etna using
RECOV-8.4-7/10/12 and CONS-3.2-3. Keep the original models/configs unchanged.
Represent BFT time and EL timestamp as distinct fields. At recovery origin12,
R.number103/time3, generation1, include these valid literal premises:

| Case             | Retained parent time | Anchor number/time | First BFT time | EL time |
| ---------------- | -------------------- | ------------------ | -------------- | ------- |
| equal-times      | 1                    | 103/3              | 3              | 3       |
| parent-dominates | 3                    | 103/3              | 3              | 4       |
| later-anchor     | 1                    | 104/4              | 3              | 4       |

The latter two must remain valid witnesses; equality of first EL time and genesis
time is not a universal rule. State retained-header/anchor authentication as
premises; these fixtures are not an executed STF history. Check exact parent,
origin, anchor, generation and both times against a separately captured literal
audit. Require actual reachable observations, plus meaningful source faults for
wrong BFT time, loss of parent+1, loss of later anchor and collapsing EL to BFT.
Do not invent an impossible first-block input merely to isolate a redundant
maximum term: an eligible anchor is no earlier than R.

Export actual TLC observations, with exact case IDs and provenance, to a separate
fixture for T02. Reuse existing extraction/validation patterns and the same TLC
jar. Do not change global conformance pins or old fixture payloads.

## T02 — execute the stock CometBFT first-block boundary

Use stock CometBFT v0.40.0 at commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`, verified from its official tag.
The existing Go toolchain satisfies its go.mod; reuse existing Go module/build
caches. Fetch missing public dependencies in a separate bounded preparation step,
then execute inspected code offline with read-only source/dependency binds and
disposable outputs. No new Go toolchain, wallet/signing material or live node.

Consume the T01 receipt fixture through a small Go conformance module. Exercise
the actual exported BlockExecutor.ValidateBlock path for initial height13,
genesis BFT time3, empty LastBlockID/LastCommit and seeded application/validator
state. Check valid baseline cases, including EL4/BFT3, and targeted wrong BFT
time, initial height, retained Comet hash used as LastBlockID, and nonempty first
LastCommit. Require the intended error, not merely any failure. A private source
fault removing the upstream genesis-time check must lose the expected rejection;
normal/restored tests must pass. Preserve the original upstream snapshot/cache.

Pin the new engine in separate comet-pins/manifest files, leaving existing
contract/Lean pins and fixtures unchanged. Reuse the isolation/source-recording
helpers where applicable; require exact nonempty Go test identities/outcomes.
This is selected single-block admission, not rounds/locks/weighted consensus,
network progress, committee derivation, cryptography or actual Etna EL execution.
An evidence-free pool/seeded committee must be disclosed as premises.

## T03 — discriminate import contradiction-authentication branches

Extend only raw M10 input cases and focused configurations for the missing
branch-specific envelope/preimage/registry/window authentication obligations.
Reuse Authentic, ProvenContradiction, Decision and the independent raw classifier;
do not duplicate an acceptance engine or modify those guards to make tests pass.
Preserve all existing raw0..24 inputs and config bytes.

Use corrupt unbound peer data to require Reject instead of a false authenticated
Halt. Existing raw2 and18 may distinguish envelope/registry guards; add coherent
negative fixtures for preimage and window masking as needed. A deliberately
contradictory authenticated tuple is a negative classifier input, not a positive
normal-operation or proof-validity claim. Individually remove the envelope guard,
each preimage branch guard, registry guard and window guard, requiring exact
ClassificationCorrect failures with successful normal/restored runs. Retain
trusted chain/height and broader crypto/implementation gaps honestly.

## Gates and scope

Each increment requires source correspondence, independent adversarial review,
independent behavioral challenges and scoped regression. Root records rulings,
evidence and publication. Maximum two material review/fix waves per increment.
Final accumulated model/Python/cohort checks use one stable snapshot. Actual
unchanged gates may retain earlier evidence with exact input identity; do not
call them fresh reruns. Publish reviewed commits to the existing draft PR.

No production or normative edits, merge, ready conversion, deployment, new SDK,
duplicate build caches or automatic fourth increment. Stop for discussion on an
independently supported actual protocol defect. The hourly monitor may continue
evaluating and fixing PR feedback after the three-item retrospective.
