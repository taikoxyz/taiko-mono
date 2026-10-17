# taiko-client-rs

The Rust consensus-side node of the Taiko Etna PoS chain, starting from L2 genesis block 0. Stock CometBFT orders and finalizes
blocks; the `taiko-client abci` ABCI++ application builds and validates them and drives
alethia-reth through the Engine API. The independent `taiko-client lander` publishes decided batches to L1.

Mainnet and Hoodi must keep their existing pinned 2.3.x client images: the Etna 3.x client removes
`driver`, `proposer`, and `whitelist-preconfirmation-driver`. The `codex/taiko-client-rs-2.3.x`
maintenance branch preserves those commands for legacy fixes. Cherry-pick compatible fixes there,
verify them using that branch's checks, and release patches with manual
`taiko-alethia-client-rs-v2.3.x` tags; its inherited tag-triggered Docker workflow publishes the
existing `taiko-client-rs` image repository. Release Please targets `main` only, and maintenance
branch pushes do not automatically create release PRs or Docker images. Branch CI and automated
maintenance releases require a separate workflow change.

## Architecture

Every validator and every full node runs three processes:

```
             CometBFT v0.40.x (stock, own process)
                  │  ABCI socket (proxy_app, default tcp://127.0.0.1:26658)
                  ▼
      taiko-client abci  ── Engine API (JWT) + eth RPC ──▶  alethia-reth
          │     │
          │     └── own L1 execution node: headers, eth_getProof, eth_getLogs, `finalized`
          └── --data-dir: abci-state.json
```

- **CometBFT** runs consensus among the current committee (Ed25519 keys, voting power derived
  from stake) and keeps the block store. Its mempool is disabled (`mempool.type = "nop"`): user
  transactions travel over the execution layer's devp2p, and the proposer's alethia-reth picks
  them from its own txpool.
- **`taiko-client abci`** wraps each execution block, together with the L1 facts it consumes (an
  L1 header plus EIP-1186 storage proofs of the Inbox and the staking registry; while an entry the
  chain has not consumed is queued at the anchor, that entry's proof and exact calldata bytes),
  into the CometBFT block. Validators check with their own L1 node that the anchored header is
  canonical and final. `FinalizeBlock`, replay and block sync read no L1 state or admission logs;
  for a block the node never judged, they confirm its anchor header (see Restarts). Canonical
  forced transactions omitted at position zero require Engine checks against the authenticated
  parent; valid inclusion and invalid-byte skips need no singleton build. At each switch height the
  app derives the target committee from the committed parent anchor and hands CometBFT the
  validator updates, effective two heights later. Its state is persisted atomically at every
  `Commit`. The genesis record includes the authenticated committee config hash, and the epoch
  schedule is derived from it. Only canonical `genesis` and `status` fields are accepted; legacy
  aliases, redundant persisted schedules, and missing config hash or Inbox binding are rejected.
- **alethia-reth** executes blocks; the app drives it with `engine_forkchoiceUpdatedV3`,
  `engine_getPayloadV5` and `engine_newPayloadV4`. CometBFT height equals the EL block number; Etna starts at L2 block 0, and consensus starts at height 1.

## Project structure

| Path                   | Description                                                                                           |
| ---------------------- | ----------------------------------------------------------------------------------------------------- |
| `bin/client/`          | The `taiko-client` binary (`abci`, `abci-genesis`, `abci-committee-record`, `lander`, `lander-claim`) |
| `crates/lander/`       | Permissionless batch/blob construction, proof trait and durable L1 submission                         |
| `crates/abci/`         | The ABCI++ application of the Etna PoS chain                                                          |
| `crates/protocol/`     | Shared helpers; `shasta` and `FixedKSigner` serve raiko2                                              |
| `crates/rpc/`          | Engine API and JWT helpers                                                                            |
| `crates/bindings/`     | Generated Anchor contract bindings, kept for protocol's anchor builder (raiko2)                       |
| `crates/test-harness/` | Docker devnet (anvil, alethia-reth, CometBFT) and calldata admission fixtures                         |
| `script/`              | Maintenance scripts (binding generation)                                                              |
| `tests/`               | The integration test entrypoint and the test JWT secret                                               |

## Committees from the committed parent anchor

Epoch `t` starts at `H(t) = 1 + t * epochLenL2`. Committee 0 uses `genesisCutoff`.
Every later committee uses the committed parent of its switch block:

```text
switch(t) = H(t) - 2
derivationParent(t) = H(t) - 3
snapshot(t) = anchor.number in committed EL block derivationParent(t)
```

At the switch, nodes prove the latest registry checkpoint at or before that snapshot under
the committed parent's exact L1 state root. Eligibility is evaluated at the snapshot number,
even when the last registry mutation is older. Snapshot entries are fully verified before eligibility, heartbeat,
pubkey deduplication, size cap and voting power are derived. Committees 0, 1 and 2 retain their
launch heartbeat exemption; later committees use the existing target-epoch window predicate.

At `H(t) - 2`, the envelope carries committee `t`'s witness and `FinalizeBlock` returns the
validator updates. CometBFT activates them at `H(t)`. Epoch-first blocks no longer publish a
future committee. The Inbox stores only the genesis committee hash and the authenticated
`committeeConfigHash`; no separate `set()` transaction or landed epoch mapping authorizes a
switch. The proof guest must independently derive every required signing/pending committee
from the same authenticated historical snapshot and configuration, including arbitrary batch cuts.

For example, with ten blocks per epoch, committee 1 is derived at height 9 from height 8's
committed anchor and activates at height 11. If height 8 anchored L1 block 1010, a new anchor
1030 proposed at height 9 cannot change that selection. A different decided history whose
height 8 anchored 1020 may select a different committee; all nodes replaying one history agree.

The config hash binds eleven ABI words under `ETNA_PARENT_ANCHOR_V3`: L2 chain id,
registry, `vp_unit`, `s_min`, `n_max`, `heartbeat_window`, heartbeat lookahead 2,
recipient-bound committee encoding version 2, `d_max` and `margin_v`. The opening is exactly 352 bytes.
The coordinated format is envelope v6, payload v5, V8 statement (20 words / 640 bytes),
journal schema 10, committee encoding version 2 and `APP_VERSION = 3`. State files must
carry that exact app version and all authenticated genesis, anchor and FI fields. Old formats
are explicitly rejected; no migration or signed-journal rewrite is provided. Never delete an
outstanding signed nonce or CometBFT history to force startup.

Settlement back-pressure remains `height - anchoredCheckpointHeight <= d_max - margin_v`;
generation behavior is unchanged. Thus committee authorization does not wait for `land`, while
a long settlement outage can still stop overall block production. An empty committed-parent roster
and an outgoing committee without quorum still require explicit protocol recovery; this change
does not supply an implicit replacement set.

The incoming set becomes certain only after its derivation parent commits. Valid preceding
anchor choices can affect membership, so guaranteed advance notice is shorter. Once an empty
parent snapshot is committed, later L1 registry changes cannot repair that switch. Stake
retention, withdrawal timing and restart trust assumptions remain; this change does not add
a recovery-generation bootstrap or an implicit replacement set.

## New-genesis deployment order

Deploy the registry and register nonzero immutable L2 recipients first. Predict the Inbox proxy
CREATE address, export a constructor-resolved `L2FeeVault` runtime bound to that Inbox/L1 chain,
and install it at the canonical treasury with zero balance, alongside the explicit EIP-4788 roots
and EIP-2935 history runtimes. Set `BasefeeSharingPctg = 0`. Preserve canonical devnet genesis fields except alloc and the derived top-level
`stateRoot`, which must be omitted after changing alloc. Start the custom-genesis EL and verify its actual block-0 hash/state root
before initializing Inbox with those commitments. Keep the deployment wallet's nonce unchanged
between address prediction and deployment. Only after L1 initialization finality should
`abci-genesis` construct the CometBFT genesis. See the complete
[protocol deployment instructions](https://github.com/taikoxyz/taiko-mono/blob/2a4bfa747edcafae96c15b58159e31eea0ebe78a/packages/protocol/contracts/layer1/etna/README.md#genesis-initialization).

The required [EL dependency](https://github.com/taikoxyz/alethia-reth/pull/251) is revision
`5d4d21ac472c024703082ba46c6eacfa3b8ec1bf`, image `us-docker.pkg.dev/evmchain/images/alethia-reth:sha-5d4d21a`,
verified manifest digest `sha256:85d23ce00bfe9e917bd3c327256d2c11cc05085a83c7afa33af8f11f50c8d495`.
It rebuilds the chainspec for an alloc-only canonical devnet override before computing block 0.
The genesis input/source hashes are indexed in `crates/test-harness/contracts/genesis.manifest.json`;
real runtime acceptance verifies immutable vault configuration, roots/history and fee movement.
The protocol dependency is [PR #22286](https://github.com/taikoxyz/taiko-mono/pull/22286); its exact
immutable revision appears in the artifact index below. This is new-genesis-only deployment.

## Genesis schedule bounds and pacing

Inbox initialization fixes `L1_0` (the initialization block), `L = epochLenL2` and
`E = epochLenL1`, and the configuration hash fixes the unsettled cap `U = d_max - margin_v`, so
only a new deployment corrects a bad value. `abci`, `abci-genesis` and the lander reject:

- `d_max <= margin_v` (`U = 0`): block 1 would already exceed the cap against the genesis
  checkpoint at height 0, so the chain could never produce it;
- `L < 3`, `L < U + 3` or `E = 0`;
- `h_first(1) = L + 1` above `type(uint48).max`, the last height `land` accepts;
- `L1_first(1) = L1_0 + E` above `type(uint48).max`, the last anchor number the `extraData`
  encodes.

Only the first transition is range-checked. At practical values the `uint48` limits lie millions
of years ahead, and an epoch whose `L1_first` exceeds them never opens (`epoch_not_open_on_l1`)
rather than crashing a node. The contract checks `3 <= L < type(uint48).max` and `E > 0`. `U = 0` is
already rejected by `abci-committee-record` before deployment, but the schedule bounds are first
checked by `abci-genesis` after initialization, so check `L + 1` and the expected `L1_0 + E` before
deploying.

Pacing is the deployer's obligation, not a validity rule. A block of epoch `e` needs an
L1-finalized anchor at or after `L1_first(e) = L1_0 + e * E`, so L2 pauses at an epoch boundary
(`epoch_not_open_on_l1`) whenever it produces `L` blocks faster than L1 produces `E` blocks, and
resumes once L1 finality catches up. To avoid these pauses, keep `E` L1 slots (12 s each on
Ethereum) no longer than `L` L2 blocks at the fastest intended block rate; every L2 block
advances the timestamp by at least one second. Back-pressure paces settlement the same way: L2
pauses (`back_pressure`) while `U` blocks are unlanded, so choose `U` above the number of blocks
produced during one landing round trip (proving, `land` inclusion and the landing's L1 finality)
unless such pauses are intended.

## Forced inclusion

A user can submit one exact transaction byte string to the Etna Inbox with `saveForcedInclusion(bytes)`.
The maximum is 8192 bytes; empty and undecodable bytes are admissible input but cannot count as
valid inclusion. The admission event records the raw bytes. Queue entries commit their Keccak-256
hash and pack the L1 timestamp, L1 submission block and fee in gwei. The fee grows with unsettled
entries. The app tracks `forced_cursor`, and each landing advances the Inbox's queue head to its
checkpoint cursor. Consumed queue entries remain stored.

Each block uses its own authenticated anchor `A` and the parent cursor `c`. A pending entry is
due when `A.timestamp >= entry.timestamp + forcedInclusionDelay`. The delay must be positive;
there is no expiry or expiry-derived upper bound.

- If `c >= tail(A)`, the block carries no forced witness and consumes no entry.
- Otherwise every block carries entry `c`'s two-slot proof. Proposers leave the witness's `tx`
  byte string empty for ordinary and included blocks, avoiding repeated admission data while an
  entry waits. Only skips carry the original preimage; an actually empty admission also uses an
  empty byte string and is distinguished by the proven hash and due time.
- A canonical transaction at position zero whose hash matches the proven entry consumes it,
  even early, without duplicating its bytes in the witness. It must fit the 8192-byte admission
  cap. Ordinary transactions may follow; matching a later transaction is insufficient.
- Nonempty witness bytes always match the proven hash and byte limit, including historical
  envelopes that redundantly carry them. RLP decoding bounds the bytes before copying them.
  A due entry absent from position zero must authenticate its preimage before any skip decision;
  omitted bytes cannot authorize skipping a nonempty admission.
- An entry absent from position zero cannot be consumed early. Once due, empty, malformed or
  noncanonical transaction bytes consume the entry directly as an invalid-byte skip.
- Due canonical bytes absent from position zero require the shared Engine skip checker. It
  builds the singleton on the supplied authenticated parent and requires the result to preserve
  the consensus-derived header and retain no transaction. ABCI supplies its committed-parent
  context; the lander additionally checks that parent's numeric canonical hash before probing.
  Filtering or zk-gas overflow can yield the empty result and authorize the skip. RPC errors,
  missing history, malformed results and a signature-recovery failure in a transaction the block
  claims to include never authorize consumption.

At or after due, a block that neither includes the entry nor completes an authenticated valid
skip is invalid; it cannot retain the cursor.

At most one queue entry is consumed per block. Included and invalid-byte cases require no
singleton build. `ProcessProposal`, cold `FinalizeBlock` and the lander share the classifier and
skip checker. Prepare reclassifies its final candidate after an ordinary fallback, reusing a
successful singleton confirmation only when the decision and its build context are unchanged.
Host Engine checks establish current dummy-proof behavior; an independent validity proof guest
remains future work. `land` pays consumed fees, with the landing reward, to the statement-bound
`feeRecipient`, the lander's sending address.

Proposers retrieve admission bytes with `eth_getLogs` for the exact proven submission block,
Inbox address and event identity, then recheck the transaction hash. Before due, this lookup is
optional and gets at most one quarter of the remaining Prepare budget: errors or a slow lookup
fall back to an ordinary block with the mandatory entry proof and empty witness bytes. Owned
reads may complete for later rounds. At due, missing bytes cannot authorize a skip. Retain historical admission
logs as long as queued entries may remain pending. No beacon endpoint, blob timeout or KZG warmup
is used for FI. The removed `--l1.beacon` and `--l1.blob-timeout` flags are rejected. Lander batch
publication still uses blobs and EIP-4844/EIP-7594 sidecars.

Completed proposal anchor/entry proofs and authenticated transaction bytes are cached under their
exact header/root/entry identity. One bounded entry/event read can survive a cancelled round;
changing its context aborts unfinished work. A commit retains bytes and an in-flight event read
only for the still-pending cursor. These reads use `--l1.timeout`; the overall preparation budget
must remain below CometBFT's proposal timeout. Missing or mismatching admission data prevents a
proposal rather than authorizing a skip. Committee witness prefetch and retry backoff are unchanged.

### Anchor freshness

Every block must satisfy `block.timestamp - anchor.timestamp <= maxAnchorAge`, checked in
`PrepareProposal`, `ProcessProposal` and `FinalizeBlock` replay. `maxAnchorAge` is a genesis
parameter the genesis record reads from Inbox slot 282, next to the delay. The pinned Inbox
initializer requires `maxAnchorAge >= 1152` seconds and a positive `forcedInclusionDelay`. There is no expiry bound. ABCI uses that authenticated value
for its block rule. The block timestamp is the derived `max(parent + 1, floor(BFT time), anchor.timestamp)`.

What freshness guarantees: a block's anchor never trails that derived timestamp by more than
`maxAnchorAge`, so the pending entry is due at any block whose timestamp has reached
`entry.timestamp + D + maxAnchorAge`. A proposer whose newest usable anchor (L1 `finalized`
less `l1_finality_extra_depth`) is too old proposes nothing and records the halt reason
`anchor_too_old`, so an L1 finality stall longer than `maxAnchorAge` pauses L2 until finality
resumes; nothing is lost.

What it does not guarantee: that block timestamps keep up with real time. Etna enables no
proposer-based timestamps (PBTS), so BFT time is the voting-power-weighted median of the
precommit timestamps a proposer includes in its block's last commit. A coalition with more
than 1/2 of the voting power sets that median outright. A coalition with more than 1/3 can too:
it withholds its votes from honest proposals, so only its own proposals are decided, and
includes in them only enough honest precommits to clear 2/3, which gives its own timestamps the
majority of the median weight (the exact threshold lies between 1/3 and 1/2, depending on how
finely stake is divided). Either coalition can hold block timestamps back and, while satisfying
the freshness rule, keep anchors stale and delay forced inclusions; each block still advances
the timestamp by at least one second. A delayed entry never expires. Bounding this delay in wall-clock time would need a validator-local
clock check (PBTS-style timeliness); that remains an open, launch-blocking design decision.

## Prerequisites

- Rust toolchain (1.95 or later)
- [Just](https://github.com/casey/just) and [cargo-nextest](https://nexte.st) 0.9.145 or later
- Docker (for the integration tests)

Nextest 0.9.145 fixes a macOS capture-pipe inheritance race that can falsely report a passing
test as `LEAK` ([upstream fix](https://github.com/nextest-rs/nextest/pull/3553)). The configuration
retains the previous runner's 100 ms leak-detection budget for both default and integration profiles.

## Build the source

```sh
cargo build --release
./target/release/taiko-client --help
```

## Subcommands

### `abci`

Serves the ABCI++ application to a CometBFT node.

| Flag                                    | Env                    | Description                                                                   |
| --------------------------------------- | ---------------------- | ----------------------------------------------------------------------------- |
| `--abci.addr`                           | `ABCI_ADDR`            | Socket CometBFT's `proxy_app` connects to (default `tcp://127.0.0.1:26658`)   |
| `--data-dir`                            | `ABCI_DATA_DIR`        | Directory of the persisted app state (`abci-state.json`), required            |
| `--chain-config`                        | `ABCI_CHAIN_CONFIG`    | Optional TOML overriding the built-in chain parameters (devnet only)          |
| `--l1.http`                             | `L1_HTTP`              | The operator's own L1 node, HTTP(S) only, required (see L1 node requirements) |
| `--l1.archive`                          | `ABCI_L1_ARCHIVE`      | Optional archive RPC for fixed committee registry snapshots only              |
| `--l2.http`                             | `L2_HTTP`              | alethia-reth's JSON-RPC endpoint, required                                    |
| `--l2.auth`                             | `L2_AUTH`              | alethia-reth's Engine API endpoint, plain `http` only, required               |
| `--jwt.secret`                          | `JWT_SECRET`           | Engine API JWT secret file, required                                          |
| `--l1.timeout`                          | `ABCI_L1_TIMEOUT`      | Deadline of one L1 read, in seconds (default 3)                               |
| `--engine.timeout`                      | `ABCI_ENGINE_TIMEOUT`  | Deadline of one Engine API or EL RPC call, in seconds (default 5)             |
| `--elsync.timeout`                      | `ABCI_ELSYNC_TIMEOUT`  | Deadline of an EL sync to a trusted head, in seconds (default 600)            |
| `--prepare.timeout`                     | `ABCI_PREPARE_TIMEOUT` | `PrepareProposal` deadline in seconds (default 2), below `timeout_propose`    |
| `--metrics.enabled` / `.addr` / `.port` | `METRICS_*`            | Prometheus metrics server (default off, `0.0.0.0:9090`)                       |
| `-v`, `--verbosity`                     | `VERBOSITY`            | Log level, 0 = error … 4 = trace (default 2); `RUST_LOG` overrides it         |

The four timeouts accept 1 to 3600 seconds. The L2 chain id is read from `--l2.http` and
selects the built-in chain parameters. Only the internal devnet (chain id `167001`) has Etna PoS
parameters so far; on other chains `abci` refuses to start. The `--chain-config` TOML uses the
snake_case names of `abci::ChainParams` (for example `d_max = 1024`); absent keys keep their
built-in values. `fee_vault` and `block_gas_limit` may only repeat the built-in values, because
the eleven-word contract configuration does not commit these fields; changing them requires a
coordinated protocol/built-in update. `d_max` and `margin_v` are committed, so a chain may set
its own; every node and lander of that chain must use the values its Inbox configuration hash
opens with. The authenticated Inbox address
is also required in persisted state and checked again on restart. `InitChain` requires the exact
L1_0 genesis time, canonical representable CometBFT consensus parameters, and an EL genesis
header whose hash and state root match H* and S*.

A safety halt (a committed block or the execution engine contradicting the app state) exits the
process with status 2; investigate before restarting. Liveness halts (anchor not final, anchor
older than `maxAnchorAge`, back-pressure, committee discovery unavailable, a due forced
inclusion event unavailable, superseded generation) keep the process running and CometBFT
rounding; the ABCI query `/status` reports the head, epoch, generation and halt reason.

`PrepareProposal` and `ProcessProposal` also refuse a block that could not land on its own: one
whose envelope, zlib-compressed as payload V5 compresses it, plus a 1,024-byte header allowance
exceeds 776,168 bytes (six landing blobs less 4 KiB of payload framing). This landing capacity
guard keeps every decided block landable; it is a liveness guard, not a validity rule, so
`FinalizeBlock` does not re-check it. The allowance covers the published header prefix (at most
768 bytes) and the framing of the lander's single-block fallback, which compresses the envelope
exactly as the guard does (see payload V5 below).

### `lander`

Runs an independent permissionless landing service. It reads decided blocks,
certificates from CometBFT, independently authenticates the required committees from historical
derivation-parent L1 registry witnesses, and submits complete batches in blob
transactions. No validator identity or stake is required to call `land`.

The first version implements `ProofProvider` with `DummyProofProvider`, which
always returns the single byte `0x00`. The deployed verifier must accept this
value for landing to succeed. A real Etna validity-proof guest/provider remains
separate work; the current contract tests establish the submission and binding
path, receipt proofs and L2 payouts; they do not establish EVM validity-proof soundness.

Required inputs are `--l1.http`, `--l2.http`, `--l2.auth`, `--jwt.secret`, `--comet.http`, a
`--signing-key` file containing a hex key, an exclusive `--data-dir`,
`--max-blocks`, `--max-blobs`, all three fee caps, `--sidecar`, and a nonzero
`--l2.reward-recipient`. Mixed-case hex addresses require a valid EIP-55 checksum;
all-lowercase and all-uppercase hex remain accepted. Batch recipients cannot be zero, the
configured canonical L2 fee vault, EIP-4788 beacon roots, or EIP-2935 history contract: these
canonical runtimes reject the vault's empty-calldata ETH transfer. Other EOAs and payable contracts
remain allowed. Proposer registration is a separate policy because EL tips use balance credits.

A restored unsigned `Prepared` batch must match the configured recipient. To change it, stop the
lander, confirm the journal is exactly `Prepared` with no signature or broadcast, then archive that
unsigned directory and rebuild in a fresh dedicated lander directory. Signed, Pending and Confirming
jobs retain their original recipient and transaction bytes; startup reports that retained intent
and applies the new configured recipient only to future batches. Reconcile any outstanding signed
nonce before archiving its journal; deleting a signed directory is not a recipient-change procedure.

The authenticated Engine API is required for historical singleton skip checks. Startup exchanges
Engine capabilities before opening the journal or running the lander, so JWT/endpoint failures are
reported before any skip is encountered. Transport failures (including HTTP authentication errors)
retry with bounded backoff and can be stopped by a signal; missing methods and malformed replies
stop startup. Diagnostics identify `--l2.auth` and `--jwt.secret` without copying upstream messages.
Fee caps are positive wei per gas:
`--max-fee-per-gas`, `--max-priority-fee-per-gas`, and
`--max-fee-per-blob-gas`; the priority cap cannot exceed the execution cap.
Signed transactions add a checked 20% gas-limit margin to the RPC estimate,
covering a pending reference that moves from BLOCKHASH into the EIP-2935 lookup
branch before inclusion, and never exceed EIP-7825's 16,777,216 limit. No reward settlement
margin or per-member settlement calldata exists. An estimate above the cap stops signing;
an Osaka node may instead reject estimation, which remains a retryable error. `n_max` may be
up to the registry/configuration cap of 4096. A bounded regression authenticates 301 distinct
members through a real registry proof and committee witness, reconstructs the lander validator
set and verifies real Comet signatures, including payout-tampering and insufficient-quorum
rejection. Larger sizes still require resource validation; this is not a 301-node network or
4096-member production-capacity test. Set the
limits to match the deployed Inbox and L1 fork. Choose the budgets
explicitly before running this example:

```sh
taiko-client lander --l1.http http://l1-node:8545 \
  --l2.http http://localhost:8545 --l2.auth http://localhost:8551 --jwt.secret ./jwt.hex \
  --comet.http http://localhost:26657 \
  --signing-key ./lander.key --data-dir ./lander-data \
  --l2.reward-recipient "$L2_REWARD_RECIPIENT" \
  --max-blocks 10 --max-blobs 6 --sidecar eip7594 \
  --max-fee-per-gas "$LANDER_MAX_FEE_PER_GAS" \
  --max-priority-fee-per-gas "$LANDER_MAX_PRIORITY_FEE_PER_GAS" \
  --max-fee-per-blob-gas "$LANDER_MAX_FEE_PER_BLOB_GAS"
```

Optional `--chain-config` uses the same parameters as ABCI; only the internal
devnet has built-in Etna parameters. `--rpc.timeout`, `--proof.timeout`,
`--broadcast.timeout` and `--receipt.timeout` accept 1–3600 seconds.
`--poll.interval` is milliseconds (default 1000); `--confirmations` counts
the receipt's own canonical block (default 1). Logging and metrics flags match
the other subcommands. Metrics use bounded phase/retry labels; transaction
hashes and waiting reasons appear in logs.

Batch submission starts when the complete publishable prefix reaches
`--min-blocks` (default 1) **or** the oldest locally observed backlog has waited
`--max-batch-wait` seconds (default 30; accepts 1–3600). The minimum must be
between 1 and `--max-blocks`. Blob/message limits can make a prefix smaller
than the minimum; its deadline still permits submission. The defaults retain
immediate submission whenever a complete block is available.

Batches may cross epoch boundaries; rewards impose no freezing cutoff. Two conditions bypass
both thresholds: only one producible height remains before the unsettled cap
`U = d_max - margin_v`, or an unlanded committee switch witness is available. Pressure uses the
checkpoint authenticated by the decided tip's L1 anchor, so a newer L1 checkpoint cannot hide
pressure before adoption. Switch urgency flushes unlanded history without authorizing committee
activation. Every prefix retains full committee, certificate, execution and FI validation.

The waiting timer is keyed by checkpoint height, hash and generation and is
persisted in the journal. More blocks arriving, temporary RPC failures, and
process restarts preserve its age. A different coherent checkpoint or an empty
backlog resets it. Waiting never requests a proof or signs a transaction.

The batch's L1 reference is separate from each L2 block's anchor. The reference
authenticates an ancestor header chain covering those anchors; it never changes
the anchor number or state root committed in an L2 header. V8 binds the Inbox, registry, both
chain ids, generation, checkpoint, committee configuration, terminal block/root, blobs, FI cursor
before/after, L1 fee recipient, L2 reward recipient and exact batch basefee amount. Committees are
independently derived from authenticated historical snapshots; starting-set hints are not authority.

Every block is held to the shared ABCI calldata classifier and asynchronous skip checker. Its
witness authenticates the cursor's entry under that block's anchor. Inclusion must match the exact
canonical bytes at position zero; a due invalid-byte skip consumes directly, while a due canonical
skip requires Engine evidence. Unavailable evidence retries without cursor advancement. The cursor
starts at the snapshot's Inbox head and advances by at most one per block. `forcedInclusionHead`
in `LandInput` is the cursor after the batch's last block.
`LandInput.feeRecipient` is the lander's sending address: `land` pays consumed fees to it and emits
`ForcedInclusionsConsumed`. The statement binding prevents copied landing transactions from
redirecting fees. The Inbox rejects a zero recipient (`ZeroFeeRecipient`); the lander treats that
revert as a configuration error. Envelope v6 carries at most 8192 FI transaction bytes, which the
lander republishes in payload V5 alongside the exact signed consensus data.

Priority fees go to the block proposer's immutable registered L2 reward address. Both proposal
preparation and validation bind the beneficiary to the original proposer in the certified
CometBFT block header, under that height's committee, including valid blocks retained across rounds;
registration ownership and L1 fee collection are separate identities. Registration requires a
nonzero recipient, which cannot be changed during that registration.

Base fees go to the immutable L2 treasury. A landing records a ten-field receipt commitment for
`sum(baseFeePerGas * gasUsed)` over exactly `(parentHeight, lastHeight]`, with explicit
`--l2.reward-recipient`. Anyone can pay gas to claim it once using a real account/storage proof
under a finalized L1 root relayed into the executed L2 EIP-4788 contract. Vault balances cannot
define fee earnings: payouts and forced ETH credits are independent of header fee sums.

`feeRecipient` continues to receive consumed queue fees on L1, while `l2RewardRecipient` receives
base fees on L2. There are no participation arrays, settlement calldata, L1 reward pool, DAO
subsidies, pre-funding or sweep. The lander needs its own L1 gas/blob working capital; earned
base fees do not guarantee coverage of proving or landing costs. No proving-performance
reduction has been measured. Use the explicit `lander-claim` command below; there is no automatic
bridge withdrawal. A canonical out-of-gas landing may still be rebuilt once with ordinary
estimation, preserving nonce recovery and the EIP-7825 cap.

Proof requests retain the Inbox schedule/config/checkpoint proof under the batch parent's anchor,
along with each committee's registry witness and proving header in the reference ancestry.
For an arbitrary batch start, minimal descending EL headers authenticate the current and next
committees' derivation parents from the contract's checkpoint hash. With checkpoint 15 and an
epoch length of 10, headers 15 through 8 identify committee 1's snapshot from header 8.
At checkpoint 9, committee 1 is already pending: the next block, height 10, still signs with
committee 0 but advertises committee 1 in `next_validators_hash`. Its proof also needs header 8.
The preceding header also authenticates the timestamp used for the parent's base fee.
Historical registry checkpoints can be proved under a later authenticated L1 root covering
the snapshot number; selection still uses the authenticated historical number. The earliest
required derivation parent is at most `epochLenL2 + 2` links behind the checkpoint.
The latest Inbox snapshot used to collect a coherent checkpoint is a separate operational
input; it cannot replace a proof under an older reference chain.

Blob payload V5 is `0x05 || zlib(rlp([[comet_header_proto, envelope], ...]))`: an RLP list of
the canonical `tendermint-proto` v0_38 header and the exact envelope bytes of each block's single
transaction, compressed as one zlib stream with the same codec as the ABCI landing capacity
guard. Each header hashes to the block id its committee signed, its `data_hash` commits
to the envelope and its `last_block_id` links it to the preceding header; decoding rejects any
item that breaks these links. Decoding also rejects bytes after the zlib stream and a list that
inflates beyond `--max-blocks` times CometBFT's `block.max_bytes` (22,020,096). Batch sizing
counts compressed bytes, so `--max-blobs` must equal 6: the guard admits a block needing all six,
and Fusaka permits at most six blobs in one transaction. Compression statically links the
locked stock zlib (libz-sys 1.1.28, zlib 1.3.2), so host library versions cannot change sizing.
If a single-block payload exceeds the byte bound at the default level, the lander retries it
at the best level, then with a zlib full flush between the published prefix and the envelope:
the flush closes the deflate block and resets the match state, so the envelope deflates exactly
as the guard measured it and the payload is at most the guard's figure plus the prefix and 16
bytes. Joint compression has no such bound, since the prefix shifts the envelope's deflate block
boundaries; crafted calldata can turn that into kilobytes and a block the guard admitted could
otherwise never land. The flushed stream is an ordinary zlib stream to every decoder. Larger
prefixes keep the default level and bounded sizing work. Prefix selection also caps a batch at 64 MiB of
uncompressed list, so its journal stays within 256 MiB, and deflates at most 32 MiB per selection
to size candidate prefixes (a prefix whose worst-case compressed size fits is not deflated; the
first block is always sized). A prefix past either budget waits for a later batch. Commits, last
commits, evidence and signatures are not published: the proof provider receives the complete
blocks and commits in `PreparedBatch.blocks`, and a guest must verify their signatures against the
published header hashes using CometBFT's ZIP215 Ed25519 rules, including valid torsion components.
Existing `BlobCoder` handles multi-blob field encoding of the compressed
payload.
`eip4844` and `eip7594` select different sidecar wrappers/proofs for the same payload and
commitments. Choose the mode supported by the L1 fork.
`CertifiedBlock.raw_block` retains the original canonical block protobuf from `/block`, including
Go's present empty height-1 commit and block id, nil evidence vote ids and evidence voting powers,
and duplicate-vote evidence whose precommit carries a vote extension (vote signatures do not
cover extensions, so anyone can attach one to a double-signed vote; Go's JSON carries the bytes
as base64, which the lander decodes so the evidence hash covers them exactly), and any vote,
commit signature or header time at the Unix epoch: Go always encodes these times, while
tendermint-proto's JSON adapter reads the epoch as absent, so the lander restores them (one
validator signing its precommit at the epoch is valid to CometBFT and would otherwise make the
block and its certificate unreadable). A seeded differential test reads stock-Go-encoded random
blocks and certificates back into exactly Go's protobufs.
The journal/proof wire encodes these unchanged bytes, and the commit's protobuf, as canonical
base64 and reconstructs the checked domain projection on restore. Body verification and every future guest must use that raw
protobuf for the signed 64 KiB part-set root and the concrete evidence subtype protobufs (without
the `Evidence` oneof wrapper) for `evidence_hash`; the raw witness is never rebuilt from the
domain projection, which omits evidence altogether: nothing reads it, and the domain conversion
rejects evidence CometBFT commits (extension signatures that are not 64 bytes, nil signatures of
other lengths or secp256k1 validators inside a light-client attack). A light-client attack whose
lunatic validator set uses a key type v0_38 protobufs cannot represent (secp256k1eth, BLS12-381,
ML-DSA-65) still cannot be read; it needs at least a third of the voting power. The
published header keeps the canonical Rust domain form,
which normalizes the height-1 empty last block id to `None`.

The journal is `lander-state.json`, separate from `abci-state.json`, and the
process holds `lander.lock`. It writes/fsyncs signed transaction bytes and the
sidecar before broadcasting. Restart reconciles receipts and account nonces
before resubmission; lost responses can only cause identical-byte rebroadcast.
Another lander advancing the checkpoint causes unbroadcast work to be rebuilt.
An already attempted transaction retains its nonce until reconciled, even if
its job becomes stale. This version does not replace fees or cancel nonces:
an underpriced transaction or a dropped stale job can require operator
reconciliation. A transaction that reverts canonically at the confirmation depth with the
checkpoint unchanged stops the lander once, with the journal already reset to idle: its nonce
is spent, so the next run builds a fresh job (a deterministic revert then stops at gas
estimation, before signing) rather than re-reading the receipt. A revert that used at least 15/16
of its gas limit ran out of gas, which depends on state at inclusion rather than on the job, so the
lander resets to idle and keeps running, rebuilding and re-estimating the next job. A second
out-of-gas landing in a row on the same checkpoint stops it with the journal idle, so a landing
that cannot fit its limit does not keep spending fees. The count is kept in memory only: a settled
landing, a checkpoint change or a restart starts it again. Use one active lander per signing
account and separate accounts for independent competitors.

The service needs unpruned CometBFT blocks/commits, the checkpoint parent and required EL ancestor headers, and
L1 headers/proofs and registry snapshot entries for every consumed historical snapshot. Starting EL ancestry is
bounded to 65,536 headers of at most 1,024 encoded bytes each, in addition to its epoch bound;
the count is checked before ancestor reads. A reference chain is bounded to 131,072 headers;
the durable journal is bounded to 256 MiB.
A complete single block exceeding the configured blob capacity stops with its
height and required capacity, rather than truncating consensus data.

### `abci-genesis`

Reads the Ethereum-final genesis record from L1 and writes the CometBFT `genesis.json`
(chain id `taiko-etna-<l2 chain id>-g<generation>`, initial height, validator set and the genesis
witness in `app_state`). It never invents values; `InitChain` re-verifies everything. The genesis
committee is the staking registry's snapshot at the Inbox's explicit `genesisCutoff`: the initializing DAO proposal names
that past L1 block explicitly, as it is written before the initialization block is known. Every
later epoch uses the committed switch-parent anchor; the new block's proposed anchor and a
lander's reference cannot replace it. Genesis verification also checks the stored committee config hash against
the local parameters. The genesis record carries the forced inclusion delay and `maxAnchorAge`
proven from Inbox slot 282; a zero delay or `maxAnchorAge < 1152` is refused.

| Flag             | Description                                                                           |
| ---------------- | ------------------------------------------------------------------------------------- |
| `--l1.http`      | L1 node serving state from the initialization block back to `genesisCutoff` (archive) |
| `--l2.chain-id`  | L2 chain id selecting the built-in chain parameters (no L2 node is contacted)         |
| `--chain-config` | Optional TOML overriding the built-in chain parameters (devnet only)                  |
| `--out`          | Path of the `genesis.json` to write (default: standard output)                        |

### `abci-committee-record`

Computes, before the initialization, the `committeeRecordHash` that `EtnaInbox::init` takes for a chosen
`genesisCutoff`: the hash of the genesis committee derived from the staking registry's snapshot
at that L1 block exactly as `InitChain` will derive it (every entry active at the cutoff with an
effective stake of at least `max(s_min, vp_unit)`, the lowest bond id per public key, at most
`n_max` members by stake, no heartbeat filter). The snapshot is read and proven at a later L1
block, the proving block, and the derived committee is verified against it before anything is
printed. Run it while writing the initializing DAO proposal; anyone can rerun it to check the
proposal's hash.

| Flag               | Description                                                                          |
| ------------------ | ------------------------------------------------------------------------------------ |
| `--l1.http`        | L1 node serving state from the proving block back to `--genesis-cutoff`, HTTP(S)     |
| `--l2.chain-id`    | L2 chain id selecting the built-in chain parameters (no L2 node is contacted)        |
| `--chain-config`   | Optional TOML overriding the built-in chain parameters (devnet only)                 |
| `--genesis-cutoff` | The initialization's `genesisCutoff`, an L1 block at or before `finalized`, required |
| `--at`             | The proving block, after the cutoff (default: the L1 node's `finalized` block)       |
| `--json`           | Print the report as JSON instead of plain text                                       |

The report gives the record hash, the cutoff, the snapshot's checkpoint index, the proving block,
every member's public key and voting power, the total voting power and stake, and the committee
config hash required by Inbox initialization.
Committee 0 uses this explicit genesis cutoff; later committees use the committed derivation parent anchor. A
cutoff after the L1 node's `finalized` block is refused, as the initialization fixes it irreversibly,
and so is a cutoff at which no entry is eligible: initializing with it would leave the chain
without validators. `--json` prints stakes as decimal strings, like the plain text. Logs go to
standard error.

```sh
taiko-client abci-committee-record --l1.http http://l1-node:8545 --l2.chain-id 167001 \
  --genesis-cutoff 400000
```

## Run a validator

The walkthrough assumes the Etna Inbox on L1 is initialized and the validator's Ed25519 consensus
key is registered in the staking registry snapshot the genesis committee is derived from. The
initialization's `committeeRecordHash` was computed with `abci-committee-record` at the initialization's
`genesisCutoff`, and its committee config hash matches the node's parameters; `abci-genesis` and
`InitChain` re-derive the same committee and refuse a genesis whose stored genesis committee hash
or config opening differs.

1. **Build the genesis** from L1 (every node must use the same file):

   ```sh
   taiko-client abci-genesis --l1.http http://l1-node:8545 --l2.chain-id 167001 \
     --out ./genesis.json
   ```

   Build `genesis.json` with the release that runs the chain: `InitChain` refuses an
   `app_state` it cannot decode.

2. **Initialize the CometBFT home** and install the genesis and the registered key.
   `cometbft init` writes a fresh `config/priv_validator_key.json` that the staking registry does
   not hold, so replace it with the consensus key whose public key the registry holds (the one
   the genesis committee of step 1 was derived from):

   ```sh
   cometbft init --home ./cmt
   cp ./genesis.json ./cmt/config/genesis.json
   cp /path/to/registered/priv_validator_key.json ./cmt/config/priv_validator_key.json
   ```

3. **Configure CometBFT** in `./cmt/config/config.toml`:

   ```toml
   proxy_app = "tcp://127.0.0.1:26658"   # taiko-client abci's --abci.addr

   [mempool]
   type = "nop"                          # user transactions travel over the EL's devp2p

   [consensus]
   timeout_commit = "1s"                 # block cadence; keep it at 1s or more

   [p2p]
   persistent_peers = "<node id>@<host>:26656,…"
   ```

   Leave `create_empty_blocks = true` (the default).

4. **Start alethia-reth** with Etna active (devnet example):

   ```sh
   alethia-reth node --chain devnet --devnet-etna-timestamp 0 \
     --http --http.api eth,net --authrpc.addr 127.0.0.1 --authrpc.jwtsecret ./jwt.hex
   ```

5. **Start the app**, then **CometBFT** in another terminal (the app runs in the foreground and
   must listen before CometBFT connects):

   ```sh
   taiko-client abci --l1.http http://l1-node:8545 \
     --l2.http http://localhost:8545 --l2.auth http://localhost:8551 --jwt.secret ./jwt.hex \
     --data-dir ./abci-data
   ```

   ```sh
   # in another terminal
   cometbft start --home ./cmt
   ```

   On restart, CometBFT's handshake replays any blocks the app has not committed yet.

## Operations

### L1 node requirements

- **HTTP only.** `--l1.http` takes an `http` or `https` JSON-RPC endpoint. WebSocket is not
  supported: alloy's WebSocket client stops reconnecting after a few attempts, so a longer L1
  outage would leave every later L1 read failing until a restart.
- **Every node** reads L1 headers and the `finalized` block from its own L1 node to check that
  anchored L1 headers are canonical and final. Full nodes also run the background prefetches
  validators use for committee switch witnesses, so give them the same L1 proof access.
  Proposers also need exact-block historical admission logs for pending forced entries.
- **Validators** also build proposals, so their L1 node must serve `eth_getProof` (EIP-1186) for
  historical blocks. A proposal proves Inbox storage at its anchor, which is at least
  `l1_finality_extra_depth` blocks behind L1 `finalized`. At a switch height the proposer also
  reconstructs the registry entries at the committed parent anchor. The selected registry
  checkpoint can be older than that anchor. The state window or cached history must cover
  those historical entry reads as well as the parent-anchor proofs. Landers starting mid-epoch
  also need the earlier derivation snapshot's entries and the bounded EL ancestor headers.
- At switch height `S(t)`, registry proofs must authenticate under the committed `D(t)` anchor's
  fixed state root. An L1 finality stall keeps that anchor for up to `maxAnchorAge` (planned
  2 h, about 600 L1 blocks), far beyond a geth full node's 128-block state window, so nodes
  discover the witness as soon as they commit the anchor (see the sidecar below). That needs the
  L1 proof window to cover the finality lag plus `l1_finality_extra_depth` plus one discovery
  and its retries; a deeper extra depth, or a node that was not live when the anchor was
  adopted, still needs historical state. Configure historical proof/state retention to cover the
  required history, or supply `--l1.archive` (`ABCI_L1_ARCHIVE`) as an HTTP(S) archive fallback
  for committee registry reads. Archive state reads use the exact requested block; their
  complete witness still verifies under the fixed committed parent root. Finality, canonical
  hashes, headers and Inbox proofs continue to use only `--l1.http`. With an archive configured,
  the primary gets a head start of at most 100 milliseconds before the archive state read also
  starts; the first successful response supplies discovery data. If one source fails, the other
  stays in flight under the unchanged read/prepare deadlines.
- Fully verified switch witnesses acquired locally or received in valid proposals are saved
  atomically as `abci-committee-witness.json` in the app data directory before reuse. Every node
  discovers the upcoming switch witness in the background under each committed anchor that can
  still be `D(t)`'s, starting with the live `Commit` of the block adopting it, saves it and
  keeps it while the anchor stays. Every `ProcessProposal`, empty proposals included, and every
  live `Commit` start a missing discovery and restart a failed one once its backoff has passed
  (2 s, doubling per failure under the same anchor up to 60 s, so an L1 that cannot serve the
  state or rate-limits it sees one attempt per pause). A discovery cut short by an RPC error or
  a deadline resumes from its finished reads; a finished discovery, a malformed answer or a
  registry or derivation error forgets them. An anchor can be `D(t)`'s only while `D(t)` passes
  back-pressure against the anchor's last checkpoint height and stays within `maxAnchorAge` of
  the anchor at one second per height at least, so this costs about one discovery per adopted
  anchor (one per L1 epoch) in the last `d_max - margin_v` heights before each `D(t)`. An L1
  finality stall that holds the anchor through `D(t)`, an anchor freshness stall, an outage or a
  restart therefore does not leave `S(t)` waiting on pruned state, provided the anchor's state
  was still served when it was adopted; a proposal shares a running discovery rather than
  repeating it. On restart, the app checks the complete chain/config/epoch/anchor identity and
  re-verifies the proof. Invalid or stale sidecars are ignored and reacquired; a sidecar write
  failure is a `committee_cache_error` liveness halt. Preserve this sidecar alongside
  `abci-state.json`. The cache protects already acquired witnesses; a validator that was down
  for the whole time the snapshot stayed within its L1's proof window still needs archive state,
  or a peer's valid `S(t)` proposal carrying the witness. reth's `--rpc.eth-proof-window` also
  limits historical proof access independently of retained state; configure it for the history
  needed by validators and landers.
- **Validators** (and `abci-genesis`) also read raw L1 headers with `debug_getRawHeader`, so
  enable the `debug` namespace on their L1 node (e.g. `--http.api eth,debug`). Without it the
  app re-encodes the header from `eth_getBlockByNumber`, which works only while it knows every
  header field: after the next L1 fork that adds one, proposals fail with an error naming the
  unknown fields until the namespace is enabled.
- **Proposers** fetch calldata admission events from `--l1.http` using exact-block `eth_getLogs`.
  Keep old logs available for still-pending queue entries; no FI expiry permits deleting them.
  Voters and cold replay use envelope-carried bytes and proofs instead of fetching admission logs.
- `abci-genesis` reads the initialization block and the registry entries back to the Inbox's
  `genesisCutoff`. That block is fixed when the initializing DAO proposal is written, well before
  the initialization block, so in practice `abci-genesis` needs an archive node.

### Restarts

- Stop CometBFT first while `taiko-client abci` can still answer in-flight requests, then stop
  the app. Start in the opposite order: the app must listen before CometBFT connects.
- Bound CometBFT's termination with the process supervisor. The pinned v0.40.0 socket client can
  accept a new ABCI request after EOF has drained its queues, leaving consensus blocked in
  `Flush` and shutdown blocked in `ConsensusState.Wait` (see the
  [pinned socket client](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/abci/client/socket_client.go#L443-L482)).
  A disconnected app therefore does not
  guarantee CometBFT exits. After an app crash, explicitly stop/reap CometBFT before restarting
  the pair; allow the supervisor to send SIGKILL when its graceful stop expires. Preserve the
  CometBFT home, validator signing state and ABCI store so the normal handshake can recover.
  This is a CometBFT process-lifecycle limitation, not a request to edit or discard chain state.
- The app checks alethia-reth against its committed head once per process, at CometBFT's first
  handshake `Info`, and syncs alethia-reth to that head if it lacks it. A CometBFT restart under a
  running app is not re-checked.
- If alethia-reth restarted or crashed while the app kept running, it may come back without its
  last blocks: restart the app and CometBFT so the next handshake re-checks it. Until then
  `FinalizeBlock` keeps retrying a block alethia-reth cannot execute, logging at ERROR after a
  minute.
- Replay and block sync need the own L1 node. For each block the node never judged whose
  envelope carries an anchor witness, `FinalizeBlock` requires the own L1 to have finalized that
  very header (plus the extra finality depth), as `ProcessProposal` does. So the L1 node must
  serve headers by number back to the activation block `L1_0` (no history expiry below it).
- While the own L1 is unreachable or has not finalized the anchor, `FinalizeBlock` waits, logged
  under `method="L1 anchor confirmation"` at WARN (ERROR after a minute); every other request,
  CometBFT's handshake included, queues behind it, so liveness probes on CometBFT's RPC can fire.
- Consecutive reads spanning at least five seconds showing the anchor cannot be on the own L1
  chain (a different block
  at its number, or a number beyond the own finalized block with a timestamp no block there can
  have) are a safety halt labeled `anchor_off_chain`: the node is being fed a forged history, or
  its L1 node is on another network. Point it at a correct L1 node and peers, or restore a
  trusted state.

### Execution layer state history

- Cold replay judges each decided block from its authenticated parent. Inclusion and invalid-byte
  skips need no singleton build. A due canonical entry absent from position zero requires a
  historical singleton and therefore the parent's execution state. Landers need the same history
  when authenticating canonical skips in decided batches.
- Keep the pinned alethia-reth behavior that processes payload attributes on historical canonical
  parents (`TaikoChainSpec::is_optimism() == true`). Leave
  `--engine.allow-unwind-canonical-header` disabled (the default): enabling it can rewind the shared
  canonical head. The lander checks the candidate parent's numeric canonical hash before probing;
  this guard is not an atomic lock against concurrent reorgs. ABCI supplies its committed-parent
  context without an equivalent numeric lookup. Neither path submits or forkchoices the singleton
  result. Engine builds are not universally read-only, especially on noncanonical parents.
- Retain execution state over the entire replay/landing distance, or use an archive node. A later
  snapshot may lack the required old state. Retryable unavailable-build RPC errors are
  non-consuming and logged with `method="forced_rebuild_unavailable"`; the `reason` diagnostic
  includes the parent number/hash and a qualified historical-state hint. A generic internal RPC
  error does not confirm pruning. Unknown payload IDs (`-38001`) restart the build to obtain a
  fresh ID. When state becomes available, retry resumes without advancing the cursor prematurely.
  Nonretryable Engine build failures stop through the safety-halt path, whose log uses
  `reason="forced_rebuild_unavailable"`. Restore the required state/history before restarting a
  halted app and CometBFT.

### Future validity proof boundary

The current proof provider returns dummy `0x00`; no real guest/prover is implemented. Current host
skip checks use Engine provided-list builds. A future prover can use the existing
`debug_executionWitnessForTxList` replay RPC as a witness collection primitive: recoverable
nonce/balance failures can contribute attempted state reads, and replay stops at the first zk-gas
overflow. Transactions after that cutoff are not replayed. Unrecoverable signatures are dropped
before execution, so their rejection needs authenticated raw bytes/signature validation rather
than an account witness. Malformed input and nonrecoverable errors still fail the RPC.

Candidate replay may need `options.skipZkGasDifficultyCheck = true` because the canonical header's
reused difficulty need not match the candidate list's finalized zk gas. This only bypasses that
post-execution mismatch; it does not remove other validation or guarantee witness availability.
The RPC supplies no FI rejection certificate, queue commitment or guest acceptance guarantee.
Future guest inputs must authenticate queue/raw transaction/context commitments, reproduce the
immediate execution prefix and budget, verify state witnesses, independently recheck the allowed
rejection or overflow, and bind cursor advancement/output. A candidate beyond an earlier cutoff
or under another parent context needs a suitable collection path.

A future guest must bind the V8 recipient and actual executed-header basefee sum, authenticate
the recipient-bound committee, and verify each beneficiary against the original proposer in
that block's certified CometBFT header under that height's committee, including retained blocks.
The lander-selected batch recipient is independent of these per-block proposer recipients.
It must preserve certificate threshold, execution ancestry, forced-inclusion and L1 reference checks. No real guest is implemented; the dummy verifier cannot establish those claims,
so this version is restricted to disposable development chains.

### `lander-claim`

`lander-claim` independently claims one landed batch reward on L2. The explicit key file pays
L2 gas; the authenticated receipt fixes the payout recipient and amount, and there is no redirect
or automatic bridge operation. Use a dedicated directory for each claim, separate from the L1
lander directory (including symlink aliases).

```sh
taiko-client lander-claim --l1.http http://l1-node:8545 --l2.http http://l2-node:8545 \
  --landing-tx 0x... --batch-id 0x... --key-file /secure/l2-gas-payer.key \
  --data-dir /data/claims/batch-id
```

A successful own landing logs `batch_id`, `landing_tx`, the covered `(parent_height, last_height]`
range, `l2_reward_recipient` and `base_fee_amount` before clearing its journal. A reverted competing
landing does not log a reward-ready identity. To recover the ID independently, inspect the successful
landing transaction receipt for `BatchRewardRecorded` emitted by the fixed configured Inbox proxy;
its indexed `batchId` is topic 1. Verify the log emitter, including when a forwarding contract sends
the landing: the outer transaction's `to` is not the Inbox identity.

The own L2 endpoint must expose the intended ABCI-produced canonical executed chain. Preparation
pins and independently hashes an executed header H, authenticates its L1 anchor through the own
L1 node's finalized ancestry, verifies the fixed Inbox account and receipt mapping proof, and
checks the actual EIP-4788 roots lookup at H using H's timestamp. The vault's immutable configuration
supplies the expected Inbox; a discovery event alone cannot authorize payment. Historical receipts
can use newer anchors and survive recovery-generation changes. Preparation does not require a
subsequent L1 landing already covering H.

The command estimates ordinary L2 EIP-1559 fees/gas, signs once, fsyncs the original bytes and
broadcast intent, then submits. Availability failures (including bootstrap, anchor lag, and ambiguous
sends) retry in the same process with cancellable backoff capped at eight seconds. Pending output
shows the original transaction hash and nonce; changed retry reasons are displayed without RPC
credentials or response bodies. SIGINT/SIGTERM interrupts RPCs and sleeps while retaining signed
bytes. Rerun the same command and key to reconcile that job; unconsumed nonces replay only the same
bytes. A consumed nonce without the matching canonical receipt requires operator review. No nonce,
fee, proof, or recipient is automatically changed after signing.

Reconciliation pins an own execution snapshot, reads its confirmed nonce before the receipt, then
checks claimed at the exact successful receipt block (or snapshot when the own receipt is absent or
reverted). It rechecks canonical hashes and refreshes a contradictory moving view once. Another
payer can consume the reward first: authoritative canonical claimed state returns AlreadyClaimed,
retains any original transaction, and stops broadcasting. This does not assert that our transaction
succeeded or finalized; a revert selector alone is never sufficient authority.

An Included result is provisional. Rerun to check Finalized: bounded chronological pages of the fixed
Inbox's BatchRewardRecorded logs discover a historical landing whose range covers the actual claim
block. Its exact receipt mapping commitment is proven under own finalized L1 state, then every EL
parent hash is authenticated back to our actual successful inclusion. The receipt records the same
endpoint atomically saved by Inbox land. Logs/cursors alone, a claimed-bit proof, and an entitlement
root cannot finalize our transaction. Discovery does not assume monotonic heights across recovery
or filter by the original entitlement generation; valid wrong-branch endpoints are skipped.

Validated Finalized journals are terminal: runner resume preserves their original inclusion and
signed bytes without fresh network reconciliation. Version-1 signed/finalized journals remain valid
without migration. Optional discovery metadata is untrusted and bound to the transaction, inclusion,
the independently hashed claim header's canonical L1 anchor and finalized context. The inclusive
anchor lower bound avoids scanning history before the claim could be landed. The original entitlement
landing identity and canonicality remain checked. Each operation discovers and schedules at most one
expensive candidate, saving the next event position **before** any candidate RPC can time out. This
optional within-page position binds the fixed page range and digest of the complete sorted log response;
changed or legacy context restarts it. The candidate receives the remaining configured finality budget,
with no smaller ancestry timeout. An operation timeout rotates to later candidates instead of replaying
the same slow prefix. One retained hint is freshly retried only after a complete discovery pass, with
the scan reset before that retry. Subsequent passes revisit every delayed, omitted or unavailable
candidate without an unbounded hint queue. No saved position or partially traversed ancestry authorizes
finality; every successful attempt requires a fresh full proof and all EL parent links.

`--rpc.timeout` defaults to 30 seconds for individual calls and ordinary reconciliation.
`--finality.timeout` separately defaults to 300 seconds for complete historical discovery and ancestry
(both accept 1–3600 seconds). One discovery operation makes at most 16 log requests of at most
1,024 L1 blocks. Responses exceeding 256 logs / 512 KiB event data and topics, the 2 MiB HTTP
allocation cap, or recognized provider log-query limits halve the inclusive page range. Recognized
limits include HTTP 413 and known -32005/-32602 result, response-size and block-range messages,
plus -32005 `query timeout exceeded`; ambiguous rate, authentication and parameter errors retain
their existing classification. The shortened end is saved before the next RPC so cancellation and finalized-head growth
cannot widen it. An oversized single block returns an actionable capacity error. Each operation
fetches at most 131,072 EL
ancestry headers in total. Claim HTTP responses are capped at 2 MiB before JSON decoding, including
chunked responses; redirects are disabled. Direct typed capacity or unsupported-capability errors can
stop the claim. The existing `RpcL1Source` adapter erases some `eth_getProof` errors, including response-cap
and unsupported-capability failures, into sanitized retryable unavailability. Those failures can keep
retrying until the operator cancels and fixes the endpoint; the response allocation bound still holds.
Required history includes fixed-Inbox logs, hash-pinned account/storage proofs, raw L1 headers and EL
headers by hash. Missing history cannot be bypassed by trusting events or claimed state.

Unsigned Prepared jobs can refresh their anchor proof before estimation. Roots validity depends on
whether the timestamp's modulo ring slot still stores that entry, not on a fixed wall-clock expiry.
An InvalidAnchorRoot estimate is retryable only while unsigned. After signing, retain the exact proof
and raw bytes. Before archiving an old signed job and opening a new dedicated claim directory, establish
its canonical outcome, check pending/confirmed nonce state, and settle or cancel any outstanding nonce
using the operator's external transaction procedure. Never clear an ambiguous pending job or change its
intent. A canonical reverted transaction consumes its nonce; replaying those bytes cannot repair it.

RewardTransferFailed can mean insufficient vault balance **or** recipient rejection; the selector does
not distinguish them. The vault cannot normally receive an ETH top-up through a plain transfer. Future
basefee accrual may restore insufficient balance, but cannot repair an immutable recipient that rejects
ETH. This receipt cannot be redirected to another recipient. Any independently approved new attempt
requires an unclaimed reward and a separately reconciled claim job.

## Development

```sh
just fmt        # pinned nightly rustfmt + cargo sort (never call cargo fmt directly)
just fmt-check
just clippy     # doc lints on library code, then every target with -D warnings
```

### Tests

- `just unit` runs all unit tests and the nine `lander_claim_cli` process tests, then protocol
  tests without default features and the abci doctests. No docker needed.
- `just test` runs the serial Docker integration scenarios in `crates/abci/tests`,
  `crates/lander/tests`, `crates/test-harness/tests` and `bin/client/tests`. ABCI scenarios cover single validator,
  anchor finality, restart and lost-state replay, epoch switch with and without landing, back-pressure, generation
  bump, calldata inclusion, invalid-byte skips, canonical skips, and unavailable-history
  retry/recovery, plus an L1 finality stall that pauses and resumes L2. The history test emulates
  the source-backed unavailable-build RPC shape through a delegating Engine adapter; it does not
  actually prune Reth state. Lander scenarios cover actual Inbox blob
  transactions, cross-epoch batching without reward cutoffs, real EL/Comet basefee claims with
  genuine L1 account/storage proofs and later-checkpoint finality, replay rejection, claim-spend
  independence in the next batch, and a forced inclusion landing that
  pays its fee, permissionless races,
  verifier rejection, receipt reorgs, durable nonce recovery, stock CometBFT collection,
  and actual-CLI SIGTERM/SIGKILL restarts, minimum/timeout batching, and pressure/epoch flushes. Each scenario boots its own devnet through the docker CLI (anvil as L1,
  alethia-reth, CometBFT), so they run one at a time; the suite takes about ten minutes. Extra
  arguments go to `cargo nextest run`, e.g. `just test restart` runs one scenario.
  `tests/entrypoint.sh` pulls the images first; override them with `ANVIL_IMAGE`,
  `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE` and `LANDER_ANVIL_IMAGE`, or set
  `PULL_POLICY=missing` to reuse local images. Existing ABCI tests retain Anvil v1.5.1;
  actual-contract lander tests use v1.8.5, which fixes canonical zero-storage proofs
  and supports EIP-7594 wrappers. `just unit` also verifies the pinned contract artifact hashes.
  Harness RPC ports bind to host loopback. SIGINT/SIGTERM remove resources owned by the interrupted
  test process; the entrypoint and CI use the shared `taiko-client-rs.test-run` Docker label to
  remove any leftovers from that run, including lander fixtures. Set `TAIKO_CLIENT_RS_TEST_RUN`
  to a unique identifier when supervising a direct cargo/nextest run and retaining an external
  cleanup fallback for SIGKILL.

- `just test-smoke` runs exactly four representative Docker scenarios: single-validator header
  rules, epoch switch, real L2 rewards claim/fee continuation, and lander CLI SIGTERM resume.
  This fixed recipe accepts no arguments. Use `just test` for targeted subsets or output options.
- `just verify` is the complete merge gate: formatting, strict clippy, fast tests, committed
  artifact reproduction, and all Docker scenarios. Smoke is an iteration aid and never replaces
  this gate. After each coherent code change batch, run `just fmt && just clippy-fix` and targeted
  tests; run the complete gate once on the final change batch.

Regenerate lander ABI/deployment fixtures only when their inputs change, with
`script/gen_lander_artifacts.sh /path/to/taiko-mono-at-pinned-protocol-revision`.
The script requires protocol HEAD `2a4bfa747edcafae96c15b58159e31eea0ebe78a` (also the
`PROTOCOL_REVISION` in `crates/lander/src/contracts.rs`),
installs pnpm dependencies before Foundry, builds the Inbox, registry, immutable `L2FeeVault` and
SignalService with their test fixtures, verifies compiler source hashes,
formats generated JSON, and records ABI/bytecode/compiler provenance. It also copies the Etna
vectors shared with the contracts (`testdata/etna_vectors`, which the `abci` and `lander` unit
tests read) from that revision and records their hashes. It leaves
the existing Anchor bindings unchanged. Run it twice and require identical generated output.
`just check-lander-artifacts` (the CI job "Lander artifacts") runs it on the pinned revision in a
temporary git worktree and fails unless every generated file equals the committed one.
Regenerate test-only `InboxSetter`, `ZkGasFixture` and `FeeRoutingFixture` artifacts with
`script/gen_test_harness_artifacts.sh /path/to/alethia-reth`; it verifies compiler settings and source hashes and records
bytecode provenance. Run that generator twice with identical output as well.

## License

See the [LICENSE](../../LICENSE) file for details.
