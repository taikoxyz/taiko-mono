# Unsigned vote wire conformance

This round fixes the design to unmerged PR22425 at
`178d7a7a66b14305c2f6467ae77163f93dd677cf`, based on main360262975.
It follows the completed [quorum projection](L2_QUORUM_REVIEW.md), without
reopening that stage or admitting the draft into the runtime classifier.
The purpose is an actual stock-library encoding comparison, not more symbolic
quorum states or an actual signed consensus history.

## Fixed sources and independent inputs

The [source/build map](draft_rules/vote_wire_sources.json) pins the existing
five-document178 source manifest and the unchanged stock source/tooling
profiles. Native source is CometBFTv0.40.0, commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`, official tree
`083ecc3cf413b6333ffe47c2b0ce1d91ce84a259`. The existing source manifest
covers1659 files; native execution must verify them afresh before and after.
Relevant production paths are types/vote.go, types/canonical.go,
types/block.go, types/part_set.go, types/validation.go,
proto/tendermint/types/canonical.pb.go and libs/protoio/writer.go.

An independent source investigator checked those paths and cached official
tree identities. The timestamp implementation is cosmos/gogoproto1.7.2.
The complete fixed archive's Go h1 matches the pinned go.sum. All787 expanded
files, including19,052,308 bytes, matched that archive, with exact inventories
and no symlinks. The cached download .mod matches the expanded/archive go.mod
and its own pinned h1. The new
[dependency manifest](draft_rules/vote_wire_gogoproto_manifest.json)
supports fresh source checks before/after native execution; go.sum alone is
not a checksum of the already expanded files that a compiler reads.

Existing SDK build identity is pinned through the same six tool hashes as the
earlier stock consumers. Existing go.mod/go.sum are a dependency profile only;
no old product admission, signed public fixture or current-Etna runtime claim
is inherited. Variable SDK/source/cache/lock/output locations are CLI inputs.
No dependency is installed or downloaded by this lane.

The [29 raw vectors](draft_rules/vote_wire_vectors.json) were independently
hand-assembled before implementation, frozen at SHA256
`8081a5acbdbcc0f98bad5f3b26155ba202379a20705764e7e1a735032c9ab58f`.
Their historical generation-zero48-byte chain string is a wire input, not
evidence of a current deployed chain or authenticated configuration. A
[separate29-row map](draft_rules/vote_wire_native_expectations.json), SHA256
`b8f378ab566022f87ed5ad9ed79c12891fd05565161da47bbdb21ed4cc213c8f`,
was frozen before implementation as well. Its source-note filenames describe
the original evidence artifacts; runtime input paths come only from the
explicit source/build map, not those provenance filenames.

## What must agree

| Boundary | Source-derived expected behavior |
| --- | --- |
| Empty versus zero32 hashes | Nil requires both lengths zero and total0. Present32 zero bytes survive; hash contents never stand in for absence. |
| Present canonical BlockID | Even an empty part-set submessage is emitted. Serializer construction does not require IsComplete. |
| Timestamp at epoch zero | Timestamp is still emitted as2a00, even when both inner numeric fields are omitted. |
| Negative fields | Height and sign-extended int32 round use sfixed64; signed seconds/nanos use64-bit two's-complement protobuf varints, not zigzag. |
| Framing | Canonical body lengths127 and128 require different outer-varint widths. |
| Native Timestamp | Original pair must pass TimestampFromProto. Constructor normalization cannot claim a match for a different raw pair. |

The new raw encoder must match all29 literal wires. Exactly23 are also within
the native Timestamp domain and must match actual VoteSignBytes output. Two
invalid-second inputs, with valid nanos, separately exercise its marshal panic
after a checked time.Unix round trip. Four other invalid raw timestamp pairs
stop after actual native Timestamp rejection. Their raw encoder coverage is
not attributed to stock VoteSignBytes. Separate normalized control rows have
their own literal inputs/bytes. The independently checked raw corpus also
includes serializer-only invalid vote type, height and round probes.

The corpus's stockVoteShape strings are source inference only. The new native
producer checks BlockIDFromProto/IsZero/IsComplete, TimestampFromProto and the
bounded VoteSignBytes calls. It neither supplies signatures nor calls
Vote.ValidateBasic, signature/commit/slashing validation or a running engine.

## Preserve the old sentinel convention

The historical N01 public format used a zero-filled bytes32 sentinel for an
absent hash. Its signed_test.go presentHash adapter intentionally maps that
value to nil, as does the historical boundary adapter. That remains valid
historical evidence for those fixed89 inputs. Reusing it unchanged on a new
present-zero32 vector would erase this revision's distinction. The new lane
uses direct length-preserving proto input; the old fixture, adapter, module
profile and all their receipts retain their original identity and meaning.

No reachable protocol contradiction was found in the independently reviewed
source slice. The wider raw timestamp format is explicit in ENC-A-45 and does
not imply stock can represent or admit every such value.

## Custody and status

The stock producer receives schema, chainId and id/input rows only. It cannot
read expected bytes, native result flags or shape annotations in its mount.
The collector must require the exact selected test/event/receipt identities,
types and actual full wires; package success alone is not evidence. Smoke and
full captures bind all actual staged/effective module inputs, tools, source,
code, dependency, physical cache/lease identities and raw output. The shared
lease stays held through verification and supervised descendant cleanup.

Root observed one real assertion RED on the inert encoder: empty output
versus the full64-byte nil-epoch literal, with zero import or fixture errors.
The implemented encoder/collector now pass13 focused checks in both ordinary
and optimized Python. An independent bridge matches all29 frozen full wires
and29 public input projections, refusing73 invalid inputs in each mode.

Six actual semantic faults were introduced only in private copies: treating
zero32 as empty, omitting the epoch timestamp, using short negative varints,
zero-extending round, truncating the128-byte framing prefix, and normalizing
the original outbound timestamp. Each failed its specific literal-byte or
input-projection assertion; each exact restoration passed again. These are
verification-effectiveness controls, not newly discovered protocol defects.

The actual unsigned stock smoke and full CLI returned0, supervised completion
returned200, and source/tool/module/staged identities matched before/after.
The smoke preserved a present32-zero hash with IsZero=false/IsComplete=false.
The full29 selected rows match the frozen23 byte results and six native
Timestamp rejections. Two of the six proceed to the expected marshal panic;
four stop after rejection. The rejected rows pass as observation cases;
there are no Go skipped tests. All29 BlockID predicates were also observed.
No normal-path protocol contradiction was found in this selected comparison.

| Retained native evidence | SHA256 |
| --- | --- |
| Smoke raw Go JSON events | ec902aacbfb73ebc2f1b758a850744e2c1df70cab14440b34f631f8ae992c32d |
| Smoke execution metadata | 5c27026dfd6dbad73a7afc54c5ac6b29138b217b675b4b30d9eca18ff959547b |
| Full raw Go JSON events | 3483998b6b7d809d2ef07b6c49bf5d2383fac7a083c6029255dd4da5120a3839 |
| Full execution metadata | 6d332414cf8395e827eab7b76017f2914ff63daef207b2bba55f49b778a5de86 |

The isolated producer reads only four staged inputs; its alternate module pair
is checked separately. The original source1659 files, timestamp dependency787
files plus cached.mod and six tool hashes were verified afresh on both sides
of each actual execution. Full execution re-read the actual smoke artifacts.
The root independently witnessed both CLI completions and recorded external
raw/staging digests before granting full GO, then compared them afterward.
These are local trusted-runner custody checks, not signed origin attestation:
an operator who rewrites every capture and receipt can fabricate that history.

The caller must supply the established single physical lock associated with
the shared build cache. The runner checks and holds that file description,
and binds full execution to the smoke's same physical pair; it does not discover
a global cache-to-lock mapping or exclude an unrelated caller using a different
lock. For these actual runs the root independently checked the established
cache/lock device and inode before and after, with no concurrent native writer.
The leased supervisor held the inherited descriptor through descendant cleanup.
This operating premise is required when repeating the lane.

From the repository root, configure existing source/SDK/cache/lock locations
and use the managed Python interpreter; no download/install step is needed:

```sh
"$managed_python" -I -S -B formal/etna/conformance/run_vote_wire.py \
  --source "$comet_source" --go-root "$go_sdk" \
  --module-cache "$module_cache" --build-cache "$build_cache" \
  --build-lock "$shared_lock" --output "$smoke_output" --smoke
"$managed_python" -I -S -B formal/etna/conformance/run_vote_wire.py \
  --source "$comet_source" --go-root "$go_sdk" \
  --module-cache "$module_cache" --build-cache "$build_cache" \
  --build-lock "$shared_lock" --output "$full_output" \
  --smoke-output "$smoke_output"
```

Both output paths must be fresh and disjoint from the read-only inputs and
shared build cache. A successful capture retains combined.log, execution.json,
summary.json, inputs/ and modfiles/; failed/inconclusive attempts are retained.
Raw event parsing rejects missing/duplicate/out-of-order rows, wrong types,
changed bytes, extra events, skipped/failed terminals and summary-only input.
Synthetic unit receipts exercise parsing and custody checks only; they do not
count as native execution.

Fresh complete ordinary suites pass817 checks in each supported360/f556
context (624 main,173 conformance,20 sensitivity), zero failures/errors/skips.
The original923 tracked formal files remain identical except three intentional
document appends/insertions. All52 TLA/603 CFG files, old fixtures and source
classifiers are unchanged. Local TLC was not rerun for this Python/library
extension; exact new-head hosted493 outcomes and publication receipts belong
to the monitor ledger after immutable commit, not a prediction in this report.
An independent verifier read all29 actual native rows against the original
frozen maps in ordinary and optimized modes, then rejected331 row/event
mutations in each mode and re-admitted the restored captures. It separately
rehashed the actual staged files, observed raw logs, supervised command and
physical cache/lock custody. Independent whole-stage review passed all15
changed/new files, source and retained evidence. The non-blocking timestamp
summary was clarified: six total API rejections, two subsequent panics and
four rejection-only cases. External publication/CI receipts belong to the
monitor ledger after immutable commit.

This scope closes no current staking/EL/guest or actual vote-admission path.
The generic runtime classifier, all prior source bundles/claims, model606,
quorum eef2, old signed/native evidence and TLA/configs are preserved. The14
source360 runtime rows remain WAITING and19 archived searches INCONCLUSIVE.
