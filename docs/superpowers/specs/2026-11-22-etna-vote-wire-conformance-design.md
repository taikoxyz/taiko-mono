# Etna vote wire conformance design

Direct user authorization: continue the formal-verification project after the
completed quorum stage. Scope is unmerged design178d7a7a, with unchanged main360.
This round compares exact unsigned vote serialization with pinned stock
CometBFTv0.40.0/0880b4d3, using independently frozen inputs and existing tools.
It does not operate a consensus engine or sign anything.

## Evidence contract

The independent29-vector corpus predates implementation. Its empty hash is
zero-length bytes, distinct from32 zero bytes. Numeric fields and hash fields
follow their own omission rules; timestamp is always emitted, even at epoch
zero. Height is int64, round int32 widened to sfixed64, and signed timestamp
seconds/nanos use64-bit two's-complement protobuf varints. Part-set total is
uint32. The outer framing is a varint of the entire canonical protobuf length.
The corpus includes exact body lengths127 and128.

The raw format encoder accepts exact non-bool signed integers in their declared
widths, immutable hashes of length0 or32, and a preauthenticated Etna-shaped
48-byte ASCII chain string. It encodes raw int64 seconds/int32 nanos without
calendar validation or time.Unix normalization. Serializer-only type/height/
round probes do not imply evidence admission. It authenticates no chain domain.

The stock producer receives only schema, chainId and ordered id/input rows;
expected bytes, result flags and source annotations are absent from its mount.
It constructs unsigned native proto Votes directly, preserving byte lengths,
and calls actual BlockIDFromProto/IsZero/IsComplete and gogoproto
TimestampFromProto on the original timestamp pair. For23 rows it calls
VoteSignBytes and emits actual bytes. For two invalid-second controls only,
it checks time.Unix preserves the original fields, calls VoteSignBytes and
records the expected marshal panic. Four other invalid raw timestamp rows
stop after native timestamp rejection. Panic recovery surrounds only the
VoteSignBytes call. Native shape annotations in the corpus remain source-only;
no signature, Vote.ValidateBasic, commit or slashing verification is performed.

A separate frozen29-row expectation map defines booleans and references literal
wire hex by index/id. An external collector compares exact raw Go JSON events,
the complete unique ordered receipt set, field types and actual bytes. A package
PASS or a self-reported digest alone is insufficient. Raw-only byte coverage
for six invalid timestamps is not attributed to the stock serializer.

## Runtime and custody

Reuse the existing validated source manifest, six Go SDK hashes, module profile,
read-only namespace bindings, physical cache lease and descendant supervisor.
Do not invoke historical product admission, old public signed fixtures or their
zero-hash normalization. Source1659 files are freshly verified before and after.
The existing Go module files are a pinned dependency profile only. The787
gogoproto files and cached download .mod are freshly checked before/after
against a manifest whose complete archive h1 matches the pinned go.sum. A new private
module line and upstream replacement are checked exactly; go.sum stays exact.
No dependencies are downloaded. The shared existing lock must be a single-link
regular physical file and remain held through execution, output/receipt checks
and descendant cleanup. Preserve source/tool/cache/lock identities and effective
modfiles in each receipt. Normal compilation and its control copies cannot run
concurrently against that shared cache.

Run one fresh smoke before the full29-case lane. Full execution requires and
revalidates the actual smoke capture from identical code, input, source, tools,
module profile and physical cache/lease. Native runtime bounds remain Go90s,
isolation100s, supervisor110s. Network, inherited credentials and host home/Git
are unavailable to Go. Only the shared build cache and fresh trial work are
writable. Preserve failed/inconclusive attempts; none grants a normal PASS.

## Boundaries

HistoricalN01/Registry fixtures, manifests, native producers, source bundles,
classifiers, claims, TLA/configs, and model606/quorum eef2 retain their identities.
Do not correct old fixture semantics by changing that historical adapter. New
unsigned library evidence does not admit design178 to the runtime classifier,
close its14 source360 runtime WAITING rows, or promote19 archived INCONCLUSIVE
searches. Actual staking/EL/guest/crypto, complete vote admission, deployed code,
proof cost and liveness remain separate. No production/SPEC/Notion/comments,
reviews, signing/keys, dependency install, deployment, merge or mark-ready.
Stop for discussion on an independently supported normal-path protocol defect.
