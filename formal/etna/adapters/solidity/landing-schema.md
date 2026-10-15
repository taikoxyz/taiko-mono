# LAND adapter schema v1 (Task5, frozen shared interface)

Input: UTF-8 JSONL, one isolated fixture per row. The single case file staged for
Foundry is a JSON array made from those exact rows, without changing fields.
`schemaVersion: 1`, unique `id` string. Numeric fields are JSON integer numbers
(including uint64 boundaries); amounts are decimal strings to avoid JS loss.
No caller-provided blob commitment or replacement blob list enters actual land.

Required fields (all present, no implicit defaults):

- `parentHeight`, `lastHeight`, `headBefore`, `headAfter`, `tail`, `maxBatchBlocks`.
  Heights are uint64; heads/tail uint48. Parent checkpoint and queue heads may be
  fixture storage-seeded to test otherwise impractical boundaries. Tail is >=
  headBefore. The model's queue fee function reads `feesGwei[index-headBefore]`;
  missing/outside entries are zero. `feesGwei` is an array of uint64 decimal strings.
  The fixture must write these fees at those actual queue indices, retaining entries.
- `active`, `guardLocked` booleans (guardLocked tests may be model-only if transient
  storage seeding unavailable; flag any such case explicitly, never claim actual).
- `recipient`: 20-byte hex address. Normal rows use `0x000000000000000000000000000000000000bEEF`.
  Callback modes override this with the actual deployed callback address in observed
  context; the Lean runtime is rerun using that context recipient. Zero remains zero.
- `caller`: 20-byte hex address; normal `0x000000000000000000000000000000000000cAFE`.
  Copy cases differ only caller and must preserve recipient.
- `reference`, `currentBlock`, `referenceHash` (32-byte hex), `historySuccess`
  boolean, `historyLength` integer. Both BLOCKHASH and history return referenceHash;
  history mock must return exactly historyLength bytes, padding/truncating that word.
  `historySuccess=false` reverts. Boundaries 256/257/8191/8192 and current/future.
- `blobs`: array of bytes32 hex transaction BLOBHASH values. Contains a zero suffix
  optionally: model takes prefix before first zero, matching actual opcode iteration.
- `lastBlockHash`, `lastStateRoot`: bytes32 hex.
- `signalAuthorized`, `verifierAccepts`, `paymentAccepts`: booleans. Concrete
  SignalService checks unauthorized, zero root, zero hash in that order. Verifier
  interface is void STATICCALL; false means reversion, not return false. Payment
  failure means recipient rejects. Zero value skips CALL regardless paymentAccepts.
- `reentryMode`: `none`, `land-caught`, `save-caught`, `land-uncaught`, `save-uncaught`,
  `verifier-land`, `verifier-save`. Same proxy only. Caught recipient attempts leave
  outer success, uncaught -> payment error. Verifier modes are static callbacks;
  expected rejection/propagation must reflect static context and actual guard.
- `inboxBalanceWei`: decimal string. Usually sufficiently funded.

Output: one JSON object per row, `schemaVersion`, `id`, with:

`status`: `ok` or `revert`;
`error`: `none`, `reentrant`, `inactive`, `no-progress`, `batch-too-large`,
`height-overflow`, `zero-recipient`, `invalid-head`, `anchor-unavailable`,
`blobs-required`, `signal-unauthorized`, `signal-invalid`, `verifier`, `payment`.
When reference and blobs are both invalid, use `environment-error` in comparison
and record raw compiler selector separately: source sibling evaluation order is
not fixed. Other errors preserve exact precedence.

Committed business observations: `head`, `tail`, `checkpointHeight`,
`checkpointHash`, `signalPresent`, `signalHeight`, `signalHash`, `signalRoot`,
`paidTo`, `paidWei` (decimal string), `batchEvent`, `consumedEvent`.
Payment describes executed successful transfer instruction(s) that commit, not
recipient net balance. On revert all business fields restore prestate, paidWei=0,
paidTo=zero, and committed event flags false. Signal fixture begins without target
checkpoint. Pre-existing genesis state is retained; signalPresent refers to newly
requested checkpoint, not genesis. `paidTo=zero` if amount=0 even when consumption
log exists. Tail never changes.

Trace observations, separately optional: `tentativeHead`, `tentativeCheckpointHeight`,
`tentativeSignalPresent`, `tentativeBatchEvent`, `failureStage`, `rawSelector`,
`nestedError`, `rawLogCount`. Raw recorded logs are not committed logs on revert.
Do not claim a tentative value that was only inferred from final rollback state;
use debugger/storage-access trace or label source-derived separately.

Encoder context (actual fixture values, required whenever actual SHA3 reached):
`statementWords`: array of EXACTLY 18 hex32 canonical words in source order;
`actualPreimage`: hex of unique SHA3 memoryInput of length576 in the actual Inbox
PROXY frame recorded during land, not a copied helper;
`actualDigest`: its Keccak. Statement words must independently assemble source
values (domain, chain IDs, actual proxy/registry, generation, prior checkpoint,
config, row inputs, reference result, packed ordered blob commitment, queue heads,
recipient). A companion `context` object uses the exact keys chainid/l2chainid/proxy/registry/
generation/parentHash/config/recipient, to let Lean independently normalize fields.
Comparing words is structural Lean encoding + actual trace conformance. Inner blob
commitment Keccak remains explicit crypto boundary, not injectively proved.

# Invocation and ownership

Canonical corpus: `formal/etna/corpus/landing.jsonl`.
Tester owns `formal/etna/adapters/solidity/EtnaInboxLeanConformance.t.sol`.
Python adapter (Landing owner) stages harness to dependency
`packages/protocol/test/layer1/etna/EtnaInboxLeanConformance.t.sol` and JSON array
`packages/protocol/test/layer1/etna/landing-corpus.json`; it sets `ETNA_LANDING_CORPUS`,
then invokes the tester-authorized CLI.
Suggested harness single entry `test_land_LeanCorpus`; fs reads/writes may need
existing fs_permissions or explicit FOUNDRY_FS_PERMISSIONS environment setting,
without mutating production foundry configuration/compiler flags.
Tester emits `console2` lines prefixed `LAND_OBSERVATION `; the runner captures and
parses these into JSONL. Debug recording requires `-vvv` or higher.
Runner must save original staged files (or absence), finally restore byte-for-byte,
and compare production git diff/digests before/after. Dependency HEAD remains pinned
27777e9d7147e7b1d3543711f4d7370a0377fa53. Never concurrently compile same out directory.
Required test execution stays with controller-dispatched solidity-tester.

Accepted implementation details: every row emits the complete precall fixture context,
including early reverts. Recipient callbacks are etched at the requested address, so no
recipient override is needed. Verifier-land/save statically attempt the guarded function,
assert its REENTRANT_CALL error, and then return normally iff verifierAccepts=true.
guardLocked is actual transient storage seeding via temporary proxy runtime restored
before real land. Canonical corpus remains56 rows; head-past-tail lastHeight14 isolates
the tail check from the block-consumption check (initial13 was insufficient).
