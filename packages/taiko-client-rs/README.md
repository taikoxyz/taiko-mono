# taiko-client-rs

The Rust consensus-side node of the Taiko Etna PoS chain, starting from L2 genesis block 0. Stock CometBFT orders and finalizes
blocks; the `taiko-client abci` ABCI++ application builds and validates them and drives
alethia-reth through the Engine API. The independent `taiko-client lander` publishes decided batches to L1. Other networks keep using the previous release of this client.

## Architecture

Every validator and every full node runs three processes:

```
             CometBFT v0.40.x (stock, own process)
                  │  ABCI socket (proxy_app, default tcp://127.0.0.1:26658)
                  ▼
      taiko-client abci  ── Engine API (JWT) + eth RPC ──▶  alethia-reth
          │        │
          │        └── own L1 node: headers, eth_getProof, `finalized`
          └── --data-dir: abci-state.json
```

- **CometBFT** runs consensus among the current committee (Ed25519 keys, voting power derived
  from stake) and keeps the block store. Its mempool is disabled (`mempool.type = "nop"`): user
  transactions travel over the execution layer's devp2p, and the proposer's alethia-reth picks
  them from its own txpool.
- **`taiko-client abci`** wraps each execution block, together with the L1 facts it consumes (an
  L1 header plus EIP-1186 storage proofs of the Inbox and the staking registry), into the
  CometBFT block. Validators only check with their own L1 node that the anchored L1 header is
  canonical and final; `FinalizeBlock`, replay and block sync never call L1. At each switch
  height the app derives the target committee from the committed parent anchor and hands CometBFT the
  validator updates, effective two heights later. Its state is persisted atomically at every
  `Commit`. The genesis record includes the authenticated committee config hash, and the epoch
  schedule is derived from it. Old `activation` and `migration_state` field names remain aliases
  within the new model; a state file lacking the required config hash is rejected.
- **alethia-reth** executes blocks; the app drives it with `engine_forkchoiceUpdatedV3`,
  `engine_getPayloadV5` and `engine_newPayloadV4`. CometBFT height equals the EL block number; Etna starts at L2 block 0, and consensus starts at height 1.

## Project structure

| Path                   | Description                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------- |
| `bin/client/`          | The `taiko-client` binary (`abci`, `abci-genesis`, `abci-committee-record`, `lander`) |
| `crates/lander/`       | Permissionless batch/blob construction, proof trait and durable L1 submission         |
| `crates/abci/`         | The ABCI++ application of the Etna PoS chain                                          |
| `crates/protocol/`     | Shared protocol helpers; its `shasta` modules are kept for raiko2                     |
| `crates/rpc/`          | Engine API wrappers, capability check and JWT provider helpers                        |
| `crates/bindings/`     | Generated Anchor contract bindings, kept for protocol's anchor builder (raiko2)       |
| `crates/test-harness/` | Docker devnet (anvil, alethia-reth, CometBFT) for the abci integration scenarios      |
| `script/`              | Maintenance scripts (binding generation)                                              |
| `tests/`               | The integration test entrypoint and the test JWT secret                               |

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

The config hash binds nine ABI words: `ETNA_PARENT_ANCHOR_V1`, L2 chain id, registry,
`vp_unit`, `s_min`, `n_max`, `heartbeat_window`, heartbeat lookahead 2 and membership algorithm 1.
The envelope is version 3 and the lander journal schema is 5. State files must contain
`genesis.committee_config_hash`, and local parameters must open it correctly. Old version-2
history, fixed-cutoff configuration/state openings, V4 journals/statements and schema-3 and
schema-4 journals (V1 and V2 blob payloads) are rejected; never discard an outstanding signed
nonce to force startup.
No migration is provided. The committee record encoding remains version 1.

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

## Prerequisites

- Rust toolchain (1.95 or later)
- [Just](https://github.com/casey/just) and [cargo-nextest](https://nexte.st)
- Docker (for the integration tests)

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
| `--l1.beacon`                           | `L1_BEACON`            | L1 beacon node serving forced inclusion blobs, HTTP(S), required              |
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
snake_case names of `abci::ChainParams` (for example `d_max = 12`); absent keys keep their
built-in values.

A safety halt (a committed block or the execution engine contradicting the app state) exits the
process with status 2; investigate before restarting. Liveness halts (anchor not final,
back-pressure, committee discovery unavailable, superseded generation) keep the process running and
CometBFT rounding; the ABCI query `/status` reports the head, epoch, generation and halt reason.

### `lander`

Runs an independent permissionless landing service. It reads decided blocks,
certificates from CometBFT, independently authenticates the required committees from historical
derivation-parent L1 registry witnesses, and submits complete batches in blob
transactions. No validator identity or stake is required to call `land`.

The first version implements `ProofProvider` with `DummyProofProvider`, which
always returns the single byte `0x00`. The deployed verifier must accept this
value for landing to succeed. A real Etna validity-proof guest/provider remains
separate work; the current contract tests establish the submission and binding
path rather than EVM validity-proof soundness.

Required inputs are public `--l1.http`, public `--l2.http`, `--comet.http`, a
`--signing-key` file containing a hex key, an exclusive `--data-dir`,
`--max-blocks`, `--max-blobs`, all three fee caps, and `--sidecar`.
The command needs no Engine API or JWT. Fee caps are positive wei per gas:
`--max-fee-per-gas`, `--max-priority-fee-per-gas`, and
`--max-fee-per-blob-gas`; the priority cap cannot exceed the execution cap.
Signed transactions add a checked 20% gas-limit margin to the RPC estimate,
covering a pending reference that moves from BLOCKHASH into the EIP-2935 lookup
branch before inclusion. Set the limits to match the deployed Inbox and L1 fork. Choose the budgets
explicitly before running this example:

```sh
taiko-client lander --l1.http http://l1-node:8545 \
  --l2.http http://localhost:8545 --comet.http http://localhost:26657 \
  --signing-key ./lander.key --data-dir ./lander-data \
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

Two conditions bypass both thresholds: only one producible height remains before
the unsettled cap `U = d_max - margin_v`, or an unlanded switch witness is available.
Pressure uses the
checkpoint authenticated by the decided tip's L1 anchor, so a more recent L1
checkpoint cannot hide pressure while the node has not adopted it. Switch urgency
covers the unlanded history, allowing several capacity-limited prefixes to publish
the witness. This flush is useful for settlement and does not authorize committee
activation. These overrides submit complete blocks and retain all batch validation.

The waiting timer is keyed by checkpoint height, hash and generation and is
persisted in the journal. More blocks arriving, temporary RPC failures, and
process restarts preserve its age. A different coherent checkpoint or an empty
backlog resets it. Waiting never requests a proof or signs a transaction.

The batch's L1 reference is separate from each L2 block's anchor. The reference
authenticates an ancestor header chain covering those anchors; it never changes
the anchor number or state root committed in an L2 header. V6 binds the Inbox
proxy, registry, both chain ids, generation, current checkpoint, authenticated committee config
hash, terminal block/root, blob hashes, and the forced inclusion queue head before (stored) and
after the batch. Each committee is independently derived from its
committed derivation parent's L1 snapshot; no per-epoch committee output or starting-set hint is authoritative.

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

Blob payload V3 is `0x03 || zlib(rlp([[comet_header_proto, envelope], ...]))`: an RLP list of
the canonical `tendermint-proto` v0_38 header and the exact envelope bytes of each block's single
transaction, compressed as one zlib stream with the same codec as the ABCI landing capacity
guard. Each header hashes to the block id its committee signed, its `data_hash` commits
to the envelope and its `last_block_id` links it to the preceding header; decoding rejects any
item that breaks these links. Decoding also rejects bytes after the zlib stream and a list that
inflates beyond `--max-blocks` times CometBFT's `block.max_bytes` (22,020,096). Batch sizing
counts compressed bytes, so `--max-blobs` must be at least 6: the guard admits any block whose
compressed item fits six blobs on its own. Prefix selection also caps a batch at 64 MiB of
uncompressed list, so its journal stays within 256 MiB, and deflates at most 32 MiB per selection
to size candidate prefixes (a prefix whose worst-case compressed size fits is not deflated; the
first block is always sized). A prefix past either budget waits for a later batch. Commits, last
commits, evidence and signatures are not published: the proof provider receives the complete
blocks and commits in `PreparedBatch.blocks`, and a guest must verify their signatures against the
published header hashes. Existing `BlobCoder` handles multi-blob field encoding of the compressed
payload.
`eip4844` and `eip7594` select different sidecar wrappers/proofs for the same payload and
commitments. Choose the mode supported by the L1 fork.
At height 1, the Rust domain form normalizes Go's present empty last commit and
last block id to `None`. Certificate part-set verification reconstructs those
Go protobuf defaults; a guest must apply that reconstruction when verifying
the signed 64 KiB part-set root. The published header keeps the canonical Rust
domain representation.

The journal is `lander-state.json`, separate from `abci-state.json`, and the
process holds `lander.lock`. It writes/fsyncs signed transaction bytes and the
sidecar before broadcasting. Restart reconciles receipts and account nonces
before resubmission; lost responses can only cause identical-byte rebroadcast.
Another lander advancing the checkpoint causes unbroadcast work to be rebuilt.
An already attempted transaction retains its nonce until reconciled, even if
its job becomes stale. This version does not replace fees or cancel nonces:
an underpriced transaction or a dropped stale job can require operator
reconciliation. Use one active lander per signing account and separate accounts
for independent competitors.

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
the local parameters.

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
   taiko-client abci --l1.http http://l1-node:8545 --l1.beacon http://l1-beacon:5052 \
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
  anchored L1 headers are canonical and final. Full nodes need nothing more.
- **Validators** also build proposals, so their L1 node must serve `eth_getProof` (EIP-1186) for
  historical blocks. A proposal proves Inbox storage at its anchor, which is at least
  `l1_finality_extra_depth` blocks behind L1 `finalized`. At a switch height the proposer also
  reconstructs the registry entries at the committed parent anchor. The selected registry
  checkpoint can be older than that anchor. The state window or cached history must cover
  those historical entry reads as well as the parent-anchor proofs. Landers starting mid-epoch
  also need the earlier derivation snapshot's entries and the bounded EL ancestor headers.
- reth limits historical proofs with `--rpc.eth-proof-window`. Its default `0` serves proofs at
  the head only, so configure it for the required historical proofs. geth with the default path-based state scheme
  keeps only about the 128 most recent states, so the required depth must stay below 128 there (or run
  a hash-scheme archive node). With other clients, check how far back they keep the state needed
  for proofs.
- **Validators** (and `abci-genesis`) also read raw L1 headers with `debug_getRawHeader`, so
  enable the `debug` namespace on their L1 node (e.g. `--http.api eth,debug`). Without it the
  app re-encodes the header from `eth_getBlockByNumber`, which works only while it knows every
  header field: after the next L1 fork that adds one, proposals fail with an error naming the
  unknown fields until the namespace is enabled.
- **Validators** fetch the blob of a due forced inclusion entry from `--l1.beacon`
  (`/eth/v1/beacon/blobs/{slot}`, which since Fulu needs a supernode or semi-supernode). Blobs
  are kept for about 18 days, longer than the 14 days after which an entry expires and needs no
  blob. The app reads the beacon's genesis and spec at startup and does not start without them.
- `abci-genesis` reads the initialization block and the registry entries back to the Inbox's
  `genesisCutoff`. That block is fixed when the initializing DAO proposal is written, well before
  the initialization block, so in practice `abci-genesis` needs an archive node.

### Restarts

- Restart `taiko-client abci` and CometBFT together, the app first: CometBFT stops when its
  connection to the app breaks, and the app must listen before CometBFT connects.
- The app checks alethia-reth against its committed head once per process, at CometBFT's first
  handshake `Info`, and syncs alethia-reth to that head if it lacks it. A CometBFT restart under a
  running app is not re-checked.
- If alethia-reth restarted or crashed while the app kept running, it may come back without its
  last blocks: restart the app and CometBFT so the next handshake re-checks it. Until then
  `FinalizeBlock` keeps retrying a block alethia-reth cannot execute, logging at ERROR after a
  minute.

## Development

```sh
just fmt        # pinned nightly rustfmt + cargo sort (never call cargo fmt directly)
just fmt-check
just clippy     # doc lints on library code, then every target with -D warnings
```

### Tests

- `just unit` runs the unit tests (everything outside `tests/` directories) and the abci
  doctests. No docker needed.
- `just test` runs the serial Docker integration scenarios in `crates/abci/tests`,
  `crates/lander/tests` and `bin/client/tests`. ABCI scenarios cover single validator,
  anchor finality, restart and lost-state replay, epoch switch with and without landing, back-pressure, generation
  bump and smoke. Lander scenarios cover actual Inbox blob transactions, permissionless races,
  verifier rejection, receipt reorgs, durable nonce recovery, stock CometBFT collection,
  and actual-CLI SIGTERM/SIGKILL restarts, minimum/timeout batching, and pressure/epoch flushes. Each scenario boots its own devnet through the docker CLI (anvil as L1,
  alethia-reth, CometBFT), so they run one at a time; the suite takes a few minutes. Extra
  arguments go to `cargo nextest run`, e.g. `just test restart` runs one scenario.
  `tests/entrypoint.sh` pulls the images first; override them with `ANVIL_IMAGE`,
  `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE` and `LANDER_ANVIL_IMAGE`, or set
  `PULL_POLICY=missing` to reuse local images. Existing ABCI tests retain Anvil v1.5.1;
  actual-contract lander tests use v1.8.5, which fixes canonical zero-storage proofs
  and supports EIP-7594 wrappers. `just unit` also verifies the pinned contract artifact hashes.

Regenerate lander ABI/deployment fixtures with
`script/gen_lander_artifacts.sh /path/to/taiko-mono-at-pinned-protocol-revision`.
The script requires protocol HEAD `639bae72ba2e69fc44387306d56f9fef7cb6703d`,
installs pnpm dependencies before Foundry, verifies compiler source hashes,
formats generated JSON, and records ABI/bytecode/compiler provenance. It leaves
the existing Anchor bindings unchanged.

## License

See the [LICENSE](../../LICENSE) file for details.
