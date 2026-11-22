# Etna vote wire conformance implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development, one
> implementation owner, independent source review and behavioral verification.
> Root owns execution GO, final readiness and existing-draft publication.

**Goal:** Compare current Etna raw vote encoding with actual pinned stock
unsigned serializer behavior, keeping historical signed evidence separate.

**Architecture:** Frozen29-vector corpus plus native expectations, a stdlib raw
encoder, a stock Go observation producer and a guarded offline runner/collector.

**Tech Stack:** Managed Python standard library, existing pinned Go SDK/cache,
stock CometBFTv0.40.0 and gogoproto1.7.2, isolated namespaces, Git/gh.

**Spec:** `docs/superpowers/specs/2026-11-22-etna-vote-wire-conformance-design.md`.

## Global Constraints

- Design178d7a7a is unmerged; source360 remains main. No runtime admission.
- Old N01/public signed fixtures/producers/claims/classifiers/models remain
  byte-identical. No current-Etna signature/commit/slashing or runtime credit.
- No consensus/EL engines, signatures/private keys, network during tests,
  dependency installs, production/SPEC/Notion/comments/reviews/merge/ready.
- Native GO authorizes unsigned stock library API calls only, not a node.
- Source1659 files, gogoproto787 files and cached .mod, tool6 hashes, effective modfiles and physical cache lease
  must be verified; preserve raw evidence and original cached inputs.
- One implementation writer; no execution before root inspects entrypoints and
  approves exact packet. Missing environment means INCONCLUSIVE, never PASS.
- No machine-specific paths in tracked files. CLI supplies variable locations.

## Review Focus

- Empty bytes and32 zero bytes differ; zero numeric fields and zero-filled
  bytes must not share an omission test.
- Nil omits the canonical BlockID pointer; a present ID always emits its
  part-set submessage, and every vote emits its timestamp.
- Negative rounds sign-extend to64 bits; negative protobuf integers use ten
  bytes and the127/128 body boundary changes framing length.
- Invalid raw nanos are never silently normalized into a claimed native
  match; native calendar rejection and raw-format coverage are separate.
- Incomplete, duplicate, skipped or fabricated receipts and stale smoke/code/
  module/lease identities must not pass the guarded native lane.

### Task 1: Source review and immutable corpus

**Owner:** Root, with independent source/feasibility investigators.
**Files:** Create this plan/design, `formal/etna/VOTE_WIRE_CONFORMANCE.md`,
`formal/etna/draft_rules/vote_wire_vectors.json`,
`formal/etna/draft_rules/vote_wire_native_expectations.json`, and
`formal/etna/draft_rules/vote_wire_sources.json` and
`formal/etna/draft_rules/vote_wire_gogoproto_manifest.json`.

- [x] Pin live main/draft/head and all current PR feedback; read exact stock
  canonical/protobuf/timestamp source, distinguish the historical sentinel.
- [x] Freeze29 independently hand-derived full wire hex/length vectors before
  implementation; freeze the29 native expectation rows,23 bytes/2panic/4skip.
- [x] Pin corpus/expectation/source/build profile hashes and verify prospective
  schema/interfaces. Record why wire, shape, signature and runtime differ.

### Task 2: Raw encoder and guarded unsigned native lane

**Owner files:** Create ONLY:
- `formal/etna/draft_rules/vote_wire.py`
- `formal/etna/tests/test_vote_wire.py`
- `formal/etna/draft_rules/comet_vote_wire_test.go.txt`
- `formal/etna/conformance/run_vote_wire.py`
- `formal/etna/conformance/tests/test_vote_wire_runner.py`

**Interfaces:** `VoteFields(vote_type,height,round,block_hash,parts_total,
parts_hash,seconds,nanos)` frozen dataclass; `vote_sign_bytes(fields,
chain_id)->bytes`. Type is signed int32 serializer enum (not an admission rule),
height/seconds int64, round/nanos int32, total uint32; chainId preauthenticated
Etna-shaped48 ASCII characters. Bytes retain all-zero content. Explicit
ValueError validation must survive -O. No filesystem/network in this module.

The runner's pure `project_inputs(corpus, ids=None)->dict` drops every expected
value and annotation. `validate_observations(corpus, expectations, rows,
ids=None)->dict` requires exact ordered keyed receipts with fields id,
timestampAccepted,marshalAttempted,panicked,wireHex (string or null),
blockIdIsZero,blockIdComplete; compare exact types and resolved literal bytes.
`collect_native(raw, returncode, corpus, expectations, ids=None)->dict` admits
only the exact Go1.27 JSON event/test set for `TestEtnaVoteWire` and its selected
subcases, with no skip/fail/missing/duplicate/unexpected receipt or trailing data.
These functions are directly unit-testable without Go or source custody.

CLI `--source --go-root --module-cache --build-cache --build-lock --output
--timeout 100`, plus `--smoke` or required `--smoke-output` for full. Reuse
low-level COMET.verify_snapshot/validate_layout, layout/identity/lease and
run_isolated primitives only; not historical product/fixture admission.
Staged module is exactly `example.org/etna-vote-wire` after one checked
module-line replacement, and receipts use `t.Logf("receipt=%s", jsonBytes)`.
Freshly verify all787 gogoproto files against the root-supplied h1-authenticated
manifest and the cached download .mod against its go.mod SHA before/after.
New Go test file exports `TestEtnaVoteWire`, reads only projected public input,
and emits one actual API receipt per selected id. It reads no expected bytes.
Source/build profile is the root-owned vote_wire_sources.json; watch all actual
Python dependencies, input/profile files, Go adapter and effective module files.

- [x] Write focused tests and inert API scaffold first; no implementation
  bodies or Go execution. Root observes semantic assertion RED in isolation.
- [x] Implement exact raw bytes, typed refusals and the Go observation producer.
  Test all29 raw literals, meaningful malformed inputs and byte-boundary cases.
- [x] Implement the collector and guarded smoke/full runner. Test real receipt
  corruption, missing/duplicate/skip/caller-claimed data and smoke-custody
  binding failures. Preserve physical cache/source/tool invariants and cleanup.
- [x] Root inspects all imports/hooks/entrypoints, runs focused normal/-O GREEN
  and independent source review, then approves exact fresh smoke packet.
- [x] Execute actual library smoke, review raw output and identities, then
  independently verified full29 native rows. Source and tools stay exact.
- [x] Independent frozen-oracle verification and real private-copy semantic
  faults/restorations: zero-as-empty, zero timestamp omission, wrong signed
  varint/round extension, framing boundary and native input normalization.
  A hash/setup refusal is not credited as a semantic fault detection.
- [x] Same-finder repairs/rechecks, maximum two material review/fix rounds,
  before selected implementation acceptance. No author commit or push.

### Task 3: Accumulated review and existing draft publication

**Owner files:** Root updates `formal/etna/WORKLIST.md`, `REPORT.md`,
`draft_rules/README.md`, the new report/plan and this stage's ignored ledger.

- [x] Preserve every prior tracked formal artifact except intentional document
  appends/insertion; retain14 WAITING/19 INCONCLUSIVE and unchanged classifier.
- [x] Complete ordinary suites in supported360/f556 contexts; no local TLC
  repeat if inputs/runner unchanged. Review new native rows separately from
  ordinary tests and exact hosted493 default outcomes.
- [x] Independent whole-stage source/behavior/receipt review, exact path hygiene
  and full intended-base diff. Resolve confirmed findings and recheck final bytes.

## Required post-commit publication receipts

Normal-push only the existing draft after readiness, sync only owned PR22387/
issue22355 status prefix and read back exact head/open/draft plus preserved
outside bytes. Observe exact new-head CI and audit official artifacts/raw
results. Record external receipts in the monitor ledger, complete only this
selected stage and return to feedback-only; no automatic next stage.
