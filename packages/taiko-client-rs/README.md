# taiko-client-rs

The Rust consensus-side node of the Taiko Etna PoS chain. Stock CometBFT orders and finalizes
blocks; the `taiko-client abci` ABCI++ application builds and validates them and drives
alethia-reth through the Engine API. Networks before the Etna activation keep using the previous
release of this client.

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
  canonical and final; `FinalizeBlock`, replay and block sync never call L1. At epoch boundaries
  the app derives the next committee from the registry snapshot and hands CometBFT the validator
  updates. Its state is persisted atomically at every `Commit`.
- **alethia-reth** executes blocks; the app drives it with `engine_forkchoiceUpdatedV3`,
  `engine_getPayloadV5` and `engine_newPayloadV4`. CometBFT height equals the EL block number.

## Project structure

| Path                   | Description                                                                      |
| ---------------------- | -------------------------------------------------------------------------------- |
| `bin/client/`          | The `taiko-client` binary (`abci`, `abci-genesis`)                               |
| `crates/abci/`         | The ABCI++ application of the Etna PoS chain                                     |
| `crates/protocol/`     | Shared protocol helpers; its `shasta` modules are kept for raiko2                |
| `crates/rpc/`          | Engine API wrappers, capability check and JWT provider helpers                   |
| `crates/bindings/`     | Generated Anchor contract bindings, kept for protocol's anchor builder (raiko2)  |
| `crates/test-harness/` | Docker devnet (anvil, alethia-reth, CometBFT) for the abci integration scenarios |
| `script/`              | Maintenance scripts (binding generation)                                         |
| `tests/`               | The integration test entrypoint and the test JWT secret                          |

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

| Flag                                    | Env                    | Description                                                                 |
| --------------------------------------- | ---------------------- | --------------------------------------------------------------------------- |
| `--abci.addr`                           | `ABCI_ADDR`            | Socket CometBFT's `proxy_app` connects to (default `tcp://127.0.0.1:26658`) |
| `--data-dir`                            | `ABCI_DATA_DIR`        | Directory of the persisted app state (`abci-state.json`), required          |
| `--chain-config`                        | `ABCI_CHAIN_CONFIG`    | Optional TOML overriding the built-in chain parameters (devnet only)        |
| `--l1.http`                             | `L1_HTTP`              | The operator's own L1 node, HTTP(S) only (no WebSocket), required           |
| `--l2.http`                             | `L2_HTTP`              | alethia-reth's JSON-RPC endpoint, required                                  |
| `--l2.auth`                             | `L2_AUTH`              | alethia-reth's Engine API endpoint, required                                |
| `--jwt.secret`                          | `JWT_SECRET`           | Engine API JWT secret file, required                                        |
| `--l1.timeout`                          | `ABCI_L1_TIMEOUT`      | Deadline of one L1 read, in seconds (default 3)                             |
| `--engine.timeout`                      | `ABCI_ENGINE_TIMEOUT`  | Deadline of one Engine API or EL RPC call, in seconds (default 5)           |
| `--elsync.timeout`                      | `ABCI_ELSYNC_TIMEOUT`  | Deadline of an EL sync to a trusted head, in seconds (default 600)          |
| `--prepare.timeout`                     | `ABCI_PREPARE_TIMEOUT` | `PrepareProposal` deadline in seconds (default 2), below `timeout_propose`  |
| `--metrics.enabled` / `.addr` / `.port` | `METRICS_*`            | Prometheus metrics server (default off, `0.0.0.0:9090`)                     |
| `-v`, `--verbosity`                     | `VERBOSITY`            | Log level, 0 = error … 4 = trace (default 2); `RUST_LOG` overrides it       |

The L2 chain id is read from `--l2.http` and selects the built-in chain parameters. Only the
internal devnet (chain id `167001`) has Etna PoS parameters so far; on other chains `abci`
refuses to start. The `--chain-config` TOML uses the snake_case names of `abci::ChainParams`
(for example `d_max = 12`); absent keys keep their built-in values.

A safety halt (a committed block or the execution engine contradicting the app state) exits the
process with status 2; investigate before restarting. Liveness halts (anchor not final,
back-pressure, committee record not landed, superseded generation) keep the process running and
CometBFT rounding; the ABCI query `/status` reports the head, epoch, generation and halt reason.

### `abci-genesis`

Reads the Ethereum-final activation record from L1 and writes the CometBFT `genesis.json`
(chain id `taiko-etna-<l2 chain id>-g<generation>`, initial height, validator set and the genesis
witness in `app_state`). It never invents values; `InitChain` re-verifies everything.

| Flag             | Description                                                                       |
| ---------------- | --------------------------------------------------------------------------------- |
| `--l1.http`      | L1 node serving state from the activation block back to its cutoff (then archive) |
| `--l2.chain-id`  | L2 chain id selecting the built-in chain parameters (no L2 node is contacted)     |
| `--chain-config` | Optional TOML overriding the built-in chain parameters (devnet only)              |
| `--out`          | Path of the `genesis.json` to write (default: standard output)                    |

## Run a validator

The walkthrough assumes the Etna Inbox on L1 is activated and the validator's Ed25519 consensus
key is registered in the staking registry snapshot the genesis committee is derived from.

1. **Build the genesis** from L1 (every node must use the same file):

   ```sh
   taiko-client abci-genesis --l1.http http://l1-node:8545 --l2.chain-id 167001 \
     --out ./genesis.json
   ```

2. **Initialize the CometBFT home** and install the genesis. `cometbft init` creates
   `config/priv_validator_key.json`; its public key is the one the staking registry must hold.

   ```sh
   cometbft init --home ./cmt
   cp ./genesis.json ./cmt/config/genesis.json
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

- **Every node** reads L1 headers and the `finalized` block from its own L1 node to check that
  anchored L1 headers are canonical and final. Full nodes need nothing more.
- **Validators** also build proposals, so their L1 node must serve `eth_getProof` (EIP-1186) for
  historical blocks. A proposal proves Inbox storage at its anchor, which is at least
  `l1_finality_extra_depth` blocks behind L1 `finalized`. At an epoch boundary the proposer also
  reads the next committee's registry entries at a block up to `cutoff_lag + cutoff_grid` blocks
  before the parent block's anchor. The proof window must therefore reach at least
  `(head − finalized) + l1_finality_extra_depth + cutoff_lag + cutoff_grid` blocks behind the L1
  head, plus a margin for an anchor that has not moved for a while. These names are the
  `abci::ChainParams` fields.
- reth limits historical proofs with `--rpc.eth-proof-window`. Its default `0` serves proofs at
  the head only, so set it to at least that depth. With other clients, check how far back they
  keep the state needed for proofs.
- `abci-genesis` reads the activation block and the blocks back to its cutoff. Once those leave
  the node's proof window it needs an archive node.

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
- `just test` runs the docker integration scenarios in `crates/abci/tests` (single validator,
  anchor finality, restart, epoch switch with and without landing, back-pressure, generation
  bump, smoke). Each scenario boots its own devnet through the docker CLI (anvil as L1,
  alethia-reth, CometBFT), so they run one at a time; the suite takes a few minutes. Extra
  arguments go to `cargo nextest run`, e.g. `just test restart` runs one scenario.
  `tests/entrypoint.sh` pulls the images first; override them with `ANVIL_IMAGE`,
  `ALETHIA_RETH_IMAGE` and `COMETBFT_IMAGE`, or set `PULL_POLICY=missing` to reuse local images.

## License

See the [LICENSE](../../LICENSE) file for details.
