# Etna lander design

Date: 2026-10-11
Status: written spec approved by the user on 2026-10-11
Target PR: https://github.com/taikoxyz/taiko-mono/pull/22280

## Intent and accepted scope

Add a separately runnable lander to the Rust client. Any account can submit a
consecutive batch of CometBFT-decided Etna execution blocks to the L1 Inbox.
The lander constructs the batch, publishes its data in the landing transaction's
blobs, binds the V3 statement, obtains a proof through a trait, submits the
transaction, and resumes safely after interruption or competition from another
lander.

The first implementation exposes an asynchronous ProofProvider trait and ships
only DummyProofProvider. Its proof is exactly one zero byte, represented as
0x00 in Ethereum bytes JSON. The user's shorthand 0x0 denotes this value, not an
empty byte string or an ABI-encoded integer. No HTTP prover adapter or real Etna
guest is included in this version.

This work updates the existing PR. Existing ABCI block production, generation
rules, persistent state, and replay behavior remain compatible. The lander has
its own data directory and never writes abci-state.json.

## Source contracts

The design is grounded in these inspected revisions:

- Rust ABCI PR #22280: 86875b5ed60223df506c8ac345b877a1c2920644.
- Genesis-only contracts PR #22286: 639bae72ba2e69fc44387306d56f9fef7cb6703d.
- Reference specification PR #22262: 3458ce9562465be54fb24dfaba38a699116ffcc9.

The implemented ABI and V3 public statement follow #22286. Its current
land(LandInput, bytes) requires blobs in the same transaction. Separate
publication records, forced inclusions, rewards, slashing, stall recovery, and
the reference specification's broader withdrawal mechanisms are outside this
change.

References:

- [Landing ABI and guest obligations](https://github.com/taikoxyz/taiko-mono/blob/639bae72ba2e69fc44387306d56f9fef7cb6703d/packages/protocol/contracts/layer1/etna/iface/IEtnaInbox.sol).
- [V3 statement and remaining contract work](https://github.com/taikoxyz/taiko-mono/blob/639bae72ba2e69fc44387306d56f9fef7cb6703d/packages/protocol/contracts/layer1/etna/README.md).
- [Existing CometBFT envelope](https://github.com/taikoxyz/taiko-mono/blob/86875b5ed60223df506c8ac345b877a1c2920644/packages/taiko-client-rs/crates/abci/src/envelope.rs).

## Components and dependencies

Add crates/lander as a workspace library, with focused modules:

- comet: bounded HTTP RPC reads of status, block, commit, and ABCI committee
  queries, using the existing tendermint types.
- batch: I/O-free validation and assembly of a consecutive batch.
- codec: versioned, deterministic batch blob-payload encoding and decoding.
- blob: reuse protocol::shasta::BlobCoder for field-element encoding; build
  KZG commitments, proofs, sidecars, and ordered versioned hashes with Alloy.
- statement: generated contract ABI types and pure V3 hashing.
- proof: ProofRequest, ProofProvider, ProofError, and DummyProofProvider.
- l1: coherent Inbox reads, statement cross-checks, signing, broadcasting, and
  receipt queries.
- store: an atomic job/transaction journal and exclusive data-directory lock.
- runner: the polling loop, deadlines, retry classification, and reconciliation.

Add a thin taiko-client lander subcommand. Reuse shared RPC, logging, and
metrics helpers where their contracts fit. The command requires public L1,
public L2, and CometBFT HTTP endpoints; it does not require Engine API access or
a JWT secret. The L2 RPC supplies the chain id and the parent EL header,
including genesis block 0. Blocks and commits come from CometBFT.

The crate may depend on abci for its public envelope, schedule, committee, and
L1-proof helpers. Keep those existing modules free of new I/O. Preserve the
protocol modules and Anchor binding consumed by raiko2. Generate any added ABI
artifacts from the pinned #22286 interface; do not hand-edit generated bindings.

## Batch assembly and authentication

1. Read one L1 block and pin all Inbox reads to its hash. Read the current
   checkpoint, generation, genesis/epoch configuration, genesis cutoff, and
   starting committee hash. Do not combine unpinned reads from different L1
   states.
2. Validate endpoint identities and chain configuration. CometBFT chain_id must
   be taiko-etna-<l2ChainId>-g<generation>. Verify the public L2 parent header
   against the checkpoint hash and height. A different hash at that checkpoint
   is a safety error.
3. Read consecutive CometBFT blocks and commits above the checkpoint. Require
   one valid Etna envelope per block, matching BFT/EL heights, a continuous EL
   parent-hash chain, and coherent CometBFT header/data/commit hashes.
4. Obtain full committee records and members through the existing ABCI queries.
   Treat them as hints: reconstruct the member root, stake and power totals,
   record hash, and Tendermint validator set. Authenticate the starting record
   against the on-chain starting committee hash. Verify commit signatures,
   distinct signers, and strictly more than two thirds of voting power.
5. Reuse the pure committee derivation helpers at epoch-start heights. Derive
   each output for epoch e + 1 from the witness at h_first(e), using the
   parent's anchor. Require every output in the contract's exact order with no
   missing or extra records. Apply the existing H+2 committee-switch timing
   and authenticate previously landed committees when the batch begins later
   than their derivation heights.
6. Stop at the configured block or blob-capacity limit. If one complete block
   cannot fit, report its height and required capacity; never truncate a block,
   envelope, or commit.
7. Select an available finalized L1 reference at or after every anchor consumed
   by the batch, including its parent context. Verify the raw parent-header
   chain back through those anchors. Preserve each block's own anchor number
   and state root; choosing a later reference never changes an L2 header.
8. Build the blob sidecar, ordered versioned hashes, LandInput, and V3 statement.
   Cross-check the local statement with hashLandStatement through the Inbox
   proxy at the pinned L1 state before requesting a proof.

RPC committee hints must remain recoverable from the node's intact ABCI state
and CometBFT history. Missing/pruned blocks, commits, or required committee
context produce a clear unavailable-history error rather than a partial batch.

The host performs structural, signature, context, and committee checks. It does
not re-execute the EVM as a substitute for a validity proof. A future real
ProofProvider is responsible for the complete guest proof, including obtaining
the execution witnesses required by its proving backend.

## Blob payload V1

The payload is:

    0x01 || rlp([[comet_block_proto, commit_proto], ...])

Each list element carries the complete CometBFT block and its own commit as
canonical protobuf byte strings using tendermint-proto 0.40.4's v0_38 types
Block and Commit, with the pinned tendermint domain adapters and prost 0.13.
Use ordinary protobuf encoding, without an extra length-delimited wrapper.
The block already contains the exact Etna envelope in its single transaction;
do not duplicate or rewrite that envelope. The blocks are
in increasing, consecutive height order. The first byte is the batch codec
version, independent of the envelope's version.

There is no compression in V1. Encode the entire payload once, then split it
with the existing BlobCoder. Decoding concatenates the decoded blob payloads
in transaction order before checking the version and canonical RLP. Reject
unknown versions, an empty batch, malformed/truncated protobuf, noncanonical
encodings, inconsistent block/commit pairs, and trailing data. Put payload,
single-message, block-count, and blob-count bounds in front of allocations.

Support explicitly configured EIP-4844 and EIP-7594 sidecar modes using Alloy's
existing builders. The operator selects the mode matching the L1 fork. The
payload and ordered versioned hashes are identical for the same blobs in both
modes; their network wrappers and proof structures differ.

This defines the wire format the future guest must decode. V1 integration tests
establish round-trip and transaction binding, not real ZK verification.

## Proof and public statement

ProofProvider has the following asynchronous contract:

    prove(&self, request: &ProofRequest) -> Result<Bytes, ProofError>

ProofRequest contains the immutable prepared batch, authenticated L1 reference
headers and relevant context, full committee inputs, LandInput, ordered blob
hashes, and the V3 statement hash. Its identity is the statement hash. Provider
implementations may obtain backend-specific execution witnesses through their
own configured adapters; they cannot alter the prepared batch's public inputs.

DummyProofProvider ignores the computation and always returns Bytes([0x00]).
It is named and logged as dummy. Success on L1 depends on the configured
verifier accepting that value. This version must not report proof generation
as real cryptographic verification.

The V3 preimage is exactly sixteen ABI words, in this order:

1. bytes32("TAIKO_ETNA_LAND_V3")
2. L1 chain id
3. L2 chain id
4. executing Inbox proxy address
5. configured staking-registry address
6. recovery generation
7. parent height
8. parent block hash
9. on-chain starting committee record hash
10. last height
11. last block hash
12. last state root
13. L1 reference block number
14. L1 reference block hash
15. keccak256(abi.encode(records))
16. keccak256(abi.encodePacked(blobHashes))

The records encoding includes the dynamic-array ABI offset and length. Neither
contract identity is supplied by a prover response or derived from the caller.
A cross-check mismatch is a fatal configuration/schema error and must precede
broadcast.

## Runtime, persistence, and competition

The runner uses one job and at most one outstanding nonce at a time:

    Idle -> Prepared -> Signed -> Pending -> Confirming -> Idle

Prepared persists the immutable job and returned proof. Signed persists the
complete signed network transaction, sidecar, transaction hash, sender, nonce,
chain ids, contract identities, reference hash, and job identity before any
broadcast. Pending tracks that same transaction. Confirming waits for the
configured number of canonical L1 confirmations.

Use write/fsync/rename/directory-fsync for journal updates and an exclusive
data-directory lock. Persist neither the private key nor an endpoint credential
inside the journal. On startup, check the journal against the configured chain,
Inbox, registry, and sender before resuming it.

Before signing, broadcasting, or resuming a prepared job, reread the current
Inbox checkpoint and generation coherently and confirm that the reference is
still canonical and available. When another lander advances the checkpoint,
discard stale unbroadcast work and build on the new checkpoint. Keep tracking
an already broadcast transaction until its nonce/receipt is resolved; do not
blindly spend a new nonce on the obsolete job.

On restart or an ambiguous broadcast failure, reconcile receipts and nonce
state first. Rebroadcast identical signed bytes when appropriate. A receipt is
successful only if its block is canonical and the resulting checkpoint is
compatible with the local decided chain. L1 reorgs roll progress back to the
current on-chain checkpoint and trigger reconciliation; local journal progress
never overrides L1.

Initial retry behavior does not automatically replace fees or cancel a nonce.
An underpriced pending transaction may require operator intervention; log its
hash, nonce, and waiting reason. Separate signing accounts permit independent
landers to compete without sharing a nonce stream.

Classify failures:

- Temporary RPC errors, missing newer blocks, and insufficient finalized L1
  progress: retry with bounded exponential backoff and deadlines.
- Competing checkpoint progress or an expired unbroadcast reference: refresh
  the snapshot and rebuild; obtain a proof for the new statement.
- A mined revert with no competing progress: report the transaction and stop
  rather than repeatedly paying for the same rejected proof or schema.
- Invalid source certificates, checkpoint/hash contradictions, corrupt
  journals, or configuration/statement mismatches: stop with an actionable
  error before further signing.

Graceful shutdown leaves durable signed/pending work resumable. Process-crash
tests cover interruption around persistence and broadcast boundaries.

## Configuration and operator surface

Require the L1, L2, and CometBFT HTTP URLs, a signing-key file, a dedicated data
directory, and nonzero block/blob limits and fee caps. Fee caps are expressed
in wei; validate priority fee <= execution fee cap. Provide configurable RPC,
proof, broadcast/receipt deadlines, polling interval, confirmation count,
sidecar mode, and the existing chain-config override.

The configured block limit must respect the deployed Inbox's maxBatchBlocks;
the blob limit must respect the L1 fork's transaction limits. This ABI exposes
neither limit as a getter, so operator configuration supplies them. No implicit
fork inference or guessed fee budget is required.

Reuse the client shutdown handling and logging conventions. Expose landed
height, decided height, unsettled depth, batch size, blob count, pending nonce,
transaction status, and classified retries through logs/metrics. Do not expose
private-key material.

## Acceptance and tests

- Pin and reproduce #22286's fixed V3 hash vector:
  0x90607f5e39a9f1a365d93fbf59a9397c3243e004182898c0c8db284ae190a56b.
  Mutate identities, reference, parent, committee records, and blob order to
  verify binding and refusal on a contract-helper mismatch.
- Exercise blob payload round-trips across blob boundaries, rejected malformed
  inputs, exact capacity boundaries, oversized single blocks, and both sidecar
  formats' commitment/hash consistency.
- Verify real Ed25519 commits, wrong chain ids, insufficient or duplicate
  signers, mismatched data/header hashes, and epoch-switch boundaries.
- Check DummyProofProvider's exact one-byte result and error/timeout plumbing
  with injectable provider implementations.
- Test runner restart before/after broadcast, lost responses, receipt reorgs,
  another lander advancing all or part of a batch, and deterministic reverts.
- Run a Docker integration against anvil with the actual pinned #22286 Inbox
  and SignalService/proxy deployment, plus a verifier accepting the dummy
  proof. Verify that a real blob transaction advances the checkpoint and lands
  expected committee outputs. Use explicit, documented contract artifacts
  with revision and regeneration provenance.
- Contract integration may inject prepared CometBFT fixtures, while a separate
  live-CometBFT scenario exercises the real RPC collector. Do not count the
  existing storage-planting fake lander as verification of the new land path.
- Keep the existing nine ABCI Docker scenarios passing, including generation,
  restart, and lost-state replay. Run the mandated final sequence: just fmt,
  both just clippy passes, just unit, just test, and git diff --check.
- Update package/operator documentation and the PR description to distinguish
  the implemented dummy-proof lander from the still-unimplemented real guest.
  Push the verified follow-up to the existing PR branch.
