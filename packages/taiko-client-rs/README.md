# taiko-client-rs

The Rust Unzen derivation driver and consensus-side node of the Taiko Etna PoS chain, supporting fresh genesis and explicit
L1-authenticated governance recovery from a retained local EL origin. Stock CometBFT orders and finalizes
blocks; the `taiko-client abci` ABCI++ application builds and validates them and drives
alethia-reth through the Engine API. The independent `taiko-client lander` publishes decided batches to L1.

The protocol rules are specified in the
[Etna PoS + ZK design specification](../protocol/docs/etna/README.md);
"spec section N" below refers to it. This README covers building, running and operating the
client, and names the spec section where an operator needs a rule.

Mainnet and Hoodi must keep their existing pinned 2.3.x client images: the Etna 3.x client removes
the independent `proposer` and `whitelist-preconfirmation-driver` commands. The Unzen `driver`
and staged `etna-handoff` command are available in this revision; see
[Unzen to Etna handoff](docs/unzen-etna-handoff.md). The `codex/taiko-client-rs-2.3.x`
maintenance branch preserves those commands for legacy fixes. Cherry-pick compatible fixes there,
verify them using that branch's checks, and release patches with manual
`taiko-alethia-client-rs-v2.3.x` tags; its inherited tag-triggered Docker workflow publishes the
existing `taiko-client-rs` image repository. Release Please targets `main` only, and maintenance
branch pushes do not automatically create release PRs or Docker images. Branch CI and automated
maintenance releases require a separate workflow change.

## Architecture

Every validator and every full node runs the three processes below. A validator also runs
`etna-signer`, the guarded external FilePV signer: it dials CometBFT's `priv_validator_laddr` and
asks the app's private control socket before every signature (see
[Run a validator](#run-a-validator)).

```
             CometBFT v0.40.x (stock, own process)
                  │  ABCI socket (proxy_app, default tcp://127.0.0.1:26658)
                  ▼
      taiko-client abci  ── Engine API (JWT) + eth RPC ──▶  alethia-reth
          │     │
          │     └── own L1 execution node: headers, eth_getProof, eth_getLogs, `finalized`
          └── --data-dir: abci-state.json
```

- **CometBFT** runs consensus among the current committee (native secp256k1eth keys, voting power derived
  from stake) and keeps the block store. Its mempool is disabled (`mempool.type = "nop"`): user
  transactions travel over the execution layer's devp2p, and the proposer's alethia-reth picks
  them from its own txpool.
- **`taiko-client abci`** wraps each execution block, together with the L1 facts it consumes (an
  L1 header plus EIP-1186 storage proofs of the Inbox and the staking registry, and the pending
  forced inclusion entry's proof), into the CometBFT block. Validators check with their own L1
  node that the anchored header is canonical and final. `FinalizeBlock`, replay and block sync
  read no L1 state or admission logs; for a block the node never judged, they confirm its anchor
  header (see Restarts). At each switch height the app derives the next committee and hands
  CometBFT the validator updates (spec section 4, Staking and committees). Its state is persisted
  atomically at every `Commit`.
- **alethia-reth** executes blocks; the app drives it with `engine_forkchoiceUpdatedV3`,
  `engine_getPayloadV5` and `engine_newPayloadV4`. CometBFT height equals the EL block number. Fresh Etna starts at L2 block 0 with consensus
  height 1; recovered generations start consensus at retained height c+1.

## Project structure

| Path                   | Description                                                                                                          |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `bin/client/`          | The `taiko-client` binary (`abci`, `abci-genesis`, `abci-committee-record`, `abci-recover`, `abci-import`, `lander`) |
| `crates/lander/`       | Permissionless batch/blob construction, proof trait and durable L1 submission                                        |
| `crates/abci/`         | The ABCI++ application of the Etna PoS chain                                                                         |
| `crates/protocol/`     | Shared helpers: blob coder, mix hash, Etna `extraData`, EIP-4396 base fee                                            |
| `crates/rpc/`          | Engine API and JWT helpers                                                                                           |
| `crates/test-harness/` | Docker devnet (anvil, alethia-reth, CometBFT) and calldata admission fixtures                                        |
| `script/`              | Maintenance scripts (artifact generation, signer builds)                                                             |
| `tests/`               | The integration test entrypoint and the test JWT secret                                                              |

## Fresh deployment

Fresh deployment starts at generation zero; it migrates no earlier state format. Explicit
[governance recovery](docs/governance-recovery.md) authenticates a later generation and
creates fresh app/Comet stores while preserving registered signing authority and old history. It is aligned with the protocol revision `PINNED_REVISION` in
`script/gen_lander_artifacts.sh` (the Inbox, staking registry and the pinned contract artifacts)
and alethia-reth commit `ad584325c6b1e15f3c163fb25e71c04a78b194e0`. Start the EL and verify its block 0 before the Inbox
is initialized (spec section 10, Startup and deployment). The proof provider is a dummy `0x00`,
so run the client only on disposable development chains.

The client Dockerfile builds that exact EL source by default, and `just test` builds its
`execution-runtime` target as the local default test image. `ALETHIA_RETH_IMAGE` remains an
explicit override (a Docker build argument or test environment variable); use a binary built
from the same pinned revision. The client and isolated import helper require Rust 1.99.

Validators sign with stock CometBFT v0.40.0 `secp256k1eth` consensus keys; node P2P keys stay
separate Ed25519 identities. The CometBFT chain ID is the 48-byte `etna-` deployment domain that
`abci-genesis` writes.

Never reset signed state or Comet history to force a start. The app writes
`comet-hash-{height}.json`, the committed Comet block ID that checkpoint trust compares with a
landed checkpoint, before each commit. Trust never reads one below the committed anchor's last
checkpoint, so commits delete those; back-pressure keeps at most `unsettled_limit + 1` files.
Do not delete the others by hand. At every committed height the app also writes
`val-state-{height}.bin`, its record of the validator state CometBFT holds after that height;
`InitChain` records the generation's start state the same way, and a checkpoint import at s the
states after s − 1 and s. At every epoch switch height it writes `val-updates-{height}.bin`, the
validator updates that height returned, an empty list included. Each record starts with the
keccak256 checksum of the rest. The app keeps the state records from one height below the
checkpoint its committed anchor proves; below that it keeps only the newest valid one, as the base
to recompute from, and the update records above it. A missing record, or one that fails its
checksum or decoding (set aside as `val-state-{height}.bin.corrupt`), is recomputed with
CometBFT's per-height arithmetic from an earlier record and the update records since, and
written again (spec SYNC-9-5c). Do not delete these by hand either: without those inputs the
node cannot serve the state at that height to `abci-import export`, whose package at s carries
the state after s − 1. `fatal-evidence.txt` survives
restarts and records the first safety failure, such as an unknown-execution-state Engine error
(`-38100`); repair its cause before restarting. An L1 header shape the node cannot parse makes
`ProcessProposal` reject and `FinalizeBlock` wait, without a safety halt: upgrade the client.

The app fsyncs a checksummed RLP execution body before acknowledging each finalized block,
then publishes the committed AppState through the existing atomic barrier. After an EL restart,
startup and proposal retries can re-feed a lost suffix from these local bodies without peers.
Recovery authenticates the chain backward from the committed EL hash and replays forward with
bounded memory; it never makes an uncommitted proposal canonical. Keep `execution-block-*.bin`
alongside the app data. Bodies are retained for the full generation above its origin or imported
execution floor: a landing alone does not prove the EL has flushed that checkpoint to disk.
A fresh recovery or checkpoint import establishes a new boundary in a fresh app directory; keep
older directories under the existing recovery retention policy. Missing or corrupt auxiliary
bodies keep the request pending; missing state at the generation origin or import floor must be
restored separately.

The `app_hash` the app returns for each height x is appHash(x) =
keccak256(abi.encode(bytes32("ETNA_APP_HASH_V1"), ELHash(x), valStateHash(x))) (spec CONS-3.1-8,
ENC-A-29b). valStateHash covers the CometBFT validator state after x: the validator set that
signs the next height and the one after it, with their voting powers, proposer priorities and
stored proposers (spec appendix A). The app computes that state with stock CometBFT v0.40.0's
per-height arithmetic from the validator updates it returns. Landing records hold no validator
state, and checkpoint trust compares only the landed EL and Comet hashes (spec SYNC-9-5). Stock
CometBFT compares each header's app_hash with its own app's, so a block whose app_hash commits
another validator state stops this node's consensus without a process exit (spec SYNC-9-5c). The
ABCI query `/val_state/<height>`, with a decimal height, returns the raw state encoding at any
height from one below the checkpoint the committed anchor proves (never below the generation's
start height) through the head. Do not substitute CometBFT's `/validators` RPC: away from the
heights where CometBFT stores a set in full, it rebuilds the proposer priorities in one bulk
step, which can differ from the live state.

The client implements ruleset 0 and authenticates the rules schedule in Inbox slot 293 at
each block's carried or inherited anchor. It selects rules by the block timestamp, refuses
to propose or accept an unsupported ruleset, and waits for upgraded software during replay.
An authenticated planned stop refuses every block whose parent's timestamp is at or after the
stop time, at any height; governance recovery clears the stop. Recovery preparation also
refuses rules it cannot implement at R. Rules scheduled after R do not change that fixed
recovery origin.

The ABCI app supports new networks with Etna start S = 0 and authenticated nonzero starts
through [the restored Unzen driver handoff](docs/unzen-etna-handoff.md). The standalone lander
lands batches ending at any height above S, with committee 0 bootstrap and first-landing switch
checks. It retains the raw L2 SignalService implementation proof at S for the proof backend. The
supplied backend still emits dummy proofs; real proving and switch deployment remain separate
work.
[Checkpoint import](docs/checkpoint-import.md) supports nonzero starts using a separately obtained
offline EL dataset and the operator's original EL chainspec. Public EL snapshot tooling remains
separate work. App state uses schema 21; lander journals use schema 20.
Older stores and witnesses are refused without rewriting signed jobs or FilePV state.

## Forced inclusion

Users submit a forced transaction as calldata with the Inbox's `saveForcedInclusion(bytes)`; spec
section 7 (Forced inclusion) gives the rules for including or skipping it. For operators:

- Proposers read each pending entry's admission event with exact-block `eth_getLogs` on
  `--l1.http`, bounded by `--l1.timeout` and `--prepare.timeout`; keep old logs while entries stay
  pending (see L1 node requirements). Forced inclusion uses no beacon endpoint.
- Skipping a due eligible transaction needs a singleton Engine build on the parent's execution
  state, so validators and landers need that history (see Execution layer state history).
- Admission fees stay in the Inbox: neither `saveForcedInclusion` nor `land` pays the treasury.
  Anyone may call `sweepProtocolFees()` to send the Inbox's balance to the deployment's protocol
  treasury. L2 base fees and tips go to each block's proposer-selected beneficiary.

## Prerequisites

- Rust toolchain (1.99 or later)
- [Just](https://github.com/casey/just) and [cargo-nextest](https://nexte.st) 0.9.145 or later
- Docker (for the integration tests)

Earlier nextest versions have a macOS capture-pipe inheritance race that can falsely report a
passing test as `LEAK` ([upstream fix](https://github.com/nextest-rs/nextest/pull/3553)). Both the
default and integration profiles use a 100 ms leak-detection budget.

## Build the source

```sh
cargo build --release
./target/release/taiko-client --help
```

## Subcommands

### `abci`

Serves the ABCI++ application to a CometBFT node.

| Flag                                    | Env                    | Description                                                                    |
| --------------------------------------- | ---------------------- | ------------------------------------------------------------------------------ |
| `--abci.addr`                           | `ABCI_ADDR`            | Socket CometBFT's `proxy_app` connects to (default `tcp://127.0.0.1:26658`)    |
| `--fee-recipient`                       | `ABCI_FEE_RECIPIENT`   | Required explicit local execution beneficiary; receives all base fees and tips |
| `--data-dir`                            | `ABCI_DATA_DIR`        | Directory of the persisted app state (`abci-state.json`), required             |
| `--chain-config`                        | `ABCI_CHAIN_CONFIG`    | Optional TOML overriding the built-in chain parameters (devnet only)           |
| `--l1.http`                             | `L1_HTTP`              | The operator's own L1 node, HTTP(S) only, required (see L1 node requirements)  |
| `--l2.http`                             | `L2_HTTP`              | alethia-reth's JSON-RPC endpoint, required                                     |
| `--l2.auth`                             | `L2_AUTH`              | alethia-reth's Engine API endpoint, plain `http` only, required                |
| `--jwt.secret`                          | `JWT_SECRET`           | Engine API JWT secret file, required                                           |
| `--l1.timeout`                          | `ABCI_L1_TIMEOUT`      | Deadline of one L1 read, in seconds (default 3)                                |
| `--engine.timeout`                      | `ABCI_ENGINE_TIMEOUT`  | Deadline of one Engine API or EL RPC call, in seconds (default 5)              |
| `--elsync.timeout`                      | `ABCI_ELSYNC_TIMEOUT`  | Deadline of an EL sync to a trusted head, in seconds (default 600)             |
| `--prepare.timeout`                     | `ABCI_PREPARE_TIMEOUT` | `PrepareProposal` deadline in seconds (default 2), below `timeout_propose`     |
| `--anchor.hold`                         | `ABCI_ANCHOR_HOLD`     | Seconds the proposer keeps its parent's anchor after a newer finality (12)     |
| `--metrics.enabled` / `.addr` / `.port` | `METRICS_*`            | Prometheus metrics server (default off, `0.0.0.0:9090`)                        |
| `-v`, `--verbosity`                     | `VERBOSITY`            | Log level, 0 = error … 4 = trace (default 2); `RUST_LOG` overrides it          |

Proposal preparation first builds and checks the size of a mandatory-only envelope. The
execution block uses an explicit empty transaction list or a due, eligible forced transaction
alone. This also establishes any legal singleton skip. Early inclusion of an entry that is not
yet due and ordinary mempool work use the remaining preparation budget. If optional work times
out or exceeds the size limit, the proposer returns the checked minimum envelope with its
witnesses. Missing mandatory evidence or an over-budget mandatory build still prevents a
proposal. Configure preparation and Comet propose deadlines for the target hardware.

The four timeouts accept 1 to 3600 seconds. The L2 chain id is read from `--l2.http` and
selects the built-in chain parameters. Only the internal devnet (chain id `167001`) has Etna PoS
parameters so far; on other chains `abci` refuses to start. The `--chain-config` TOML uses the
snake_case names of `abci::ChainParams` (for example `unsettled_limit = 3600`); absent keys keep their
built-in values; unknown keys are rejected. `block_gas_limit` stays fixed by the built-in EL
parameters. The required
`--fee-recipient` overrides the local TOML beneficiary. Full uint256 L1 identity is read from
`--l1.http`; an explicit `l1_chain_id` TOML value must match, while an omitted value uses the RPC
identity. L2 IDs are checked without truncation and values above uint64 are explicitly refused.
All nodes must use the same chain parameters: genesis and every restart check them against the
Inbox's committee configuration hash. The Inbox address
is also required in persisted state and checked again on restart. Fresh `InitChain` requires
the exact L1_0 genesis time, canonical representable CometBFT consensus parameters, and an EL
header at the Etna start S whose hash and state root match the start hash and the start state
root. Recovered `InitChain` independently
verifies its authenticated c/R origin and generation genesis; see the
[recovery runbook](docs/governance-recovery.md).

On a network that switched from Unzen (a nonzero Etna start S and a `[switch]` table, see the
[handoff runbook](docs/unzen-etna-handoff.md)), run alethia-reth with exactly the
`fork_timestamp` the app uses: the app cannot read the EL's Etna time, so a different value
shows up as EL errors around the fork, not as a trust check failure. Before every trust grant
the app checks that `fork_timestamp` equals the switching EtnaInbox's immutable
`etnaForkTime()`, read by `eth_call` at its finalized L1 block's hash, so `--l1.http` must serve
hash-pinned `eth_call` (SYNC-9-5a). While the Inbox's latest checkpoint is S, trust also needs
an `eth_getProof` at S's hash from `--l2.http` (SYNC-9-5a, SYNC-9-16). reth's `--rpc.eth-proof-window` is 0 by default, so that proof fails once the head
passes S and trust stays closed. Until the first landing is final in own L1, keep S's state and
set a proof window of at least `unsettled_limit` blocks plus a margin, or point `--l2.http` at an
archive endpoint.

A safety halt (a committed block or the execution engine contradicting the app state) exits the
process with status 2; investigate before restarting. Liveness pauses (anchor not final, anchor
older than `maxAnchorAge`, back-pressure, committee discovery unavailable, a due forced
inclusion event unavailable; spec section 8, Halts and recovery) keep the process running and
CometBFT rounding; the ABCI query
`/status` reports the head, epoch, generation and, as `halt_reason`, the cause of the current
liveness pause. A superseded generation is
permanent. A proposal whose anchor shows a higher Inbox `recoveryGeneration` is refused and trust
is revoked while the process keeps running. A decided block carrying such an anchor, or a startup
or signer-session trust check finding a different generation, is a safety halt. Restart only
under the new generation.

### `lander`

The permissionless lander collects native Comet blocks/certificates, authenticates historical
committee witnesses and execution/FI rules, and submits `land(input, leaves, proof)` blob
transactions. `DummyProofProvider` returns exactly `0x00`; use an explicitly compatible dummy
verifier on a disposable devnet. This does not establish validity-proof soundness.

Required inputs are `--l1.http`, `--l2.http`, `--l2.auth`, `--jwt.secret`, `--comet.http`, a
`--signing-key` file containing a hex key, an exclusive `--data-dir`, `--max-blocks`, all three
positive fee caps and `--sidecar`. Landing pays the lander nothing: execution fees go to each
block's beneficiary, and forced inclusion fees stay in the Inbox until `sweepProtocolFees()`.

```sh
taiko-client lander --l1.http http://l1-node:8545 \
  --l2.http http://localhost:8545 --l2.auth http://localhost:8551 --jwt.secret ./jwt.hex \
  --comet.http http://localhost:26657 --chain-config ./chain.toml \
  --signing-key ./lander.key --data-dir ./lander-data \
  --min-blocks 60 --max-blocks 120 --max-batch-wait 300 --sidecar eip7594 \
  --max-fee-per-gas "$LANDER_MAX_FEE_PER_GAS" \
  --max-priority-fee-per-gas "$LANDER_MAX_PRIORITY_FEE_PER_GAS" \
  --max-fee-per-blob-gas "$LANDER_MAX_FEE_PER_BLOB_GAS"
```

A landing may end at any height, so a batch holds one or more complete blocks. At startup the
lander reads the Inbox's `maxBatchBlocks` and caps every batch at the lower of `--max-blocks`
and `maxBatchBlocks` (logging when the Inbox lowers it). Each landing carries at most six
blobs, a fixed constant (LAND-6.1 step 5).
`--min-blocks` defaults to 1 and `--max-batch-wait` to 30 seconds. The minimum is 1 through
that batch cap: the lander refuses to start with a higher one, which no batch could reach. Wait
expiry or consensus pressure can flush an available complete prefix below it. The wait is kept
in memory from the first backlog this process sees at the current checkpoint; a restart starts
it again. Batches can cross epoch transitions; batch timing and back-pressure follow spec
sections 6.3 (Batches) and 6.4 (Back-pressure).

`--land-to HEIGHT` runs the lander once: it lands exactly one batch from the latest checkpoint p
to HEIGHT, with the same selection, leaves and journal as any batch, and exits 0 once that
landing is confirmed. It waits while the decided tip is below HEIGHT and ignores `--min-blocks`
and `--max-batch-wait`. It exits nonzero when p is already at or above HEIGHT, when HEIGHT − p
exceeds the batch cap, when the blocks do not fit one batch, when another landing reaches or
passes HEIGHT first, or on a signal. It has no environment variable. A checkpoint import
producer uses it to land the height after its stock snapshot
([procedure](docs/checkpoint-import.md#stock-snapshot-for-the-producer-check)).

On a switching network, the first landing from S also carries an `eth_getProof` of the L2
SignalService proxy's implementation slot at S, read from `--l2.http` (PROOF-6.2-46a,
SYNC-9-16). Until the first landing is final in own L1, that endpoint needs S's state within its
proof window, at least `unsettled_limit` blocks plus a margin as for `abci` above, or an archive
endpoint; otherwise the lander waits and retries.

`--chain-config` uses the same authenticated parameters as ABCI. L1 identity is read as full
uint256 from the actual endpoint; an explicit `l1_chain_id` must match. L2 IDs above uint64 are
rejected, never truncated. `--engine.timeout`, `--rpc.timeout`, `--proof.timeout`,
`--broadcast.timeout` and `--receipt.timeout` accept 1–3600 seconds. Defaults are respectively
30, 30, 300, 30 and 30. `--poll.interval` is milliseconds (default 1000);
`--confirmations` counts the receipt's own canonical block (default 1).

Engine/JWT access is required for historical singleton skip checks. Startup checks Engine
capabilities before opening the journal or signing. Temporary endpoint failures retry with
bounded backoff and remain signal-cancellable; unsupported capabilities and malformed replies
stop. Logs identify failed endpoints without exposing credentials or upstream response bodies.
The priority fee cap cannot exceed the total execution cap. Gas estimation adds a checked 20%
margin within EIP-7825's 16,777,216 cap; no automatic fee or nonce replacement is supported.

The public blob payload carries execution blocks only (spec section 5.2, Blob payload);
`--sidecar eip4844` or `eip7594` selects the sidecar format for the same payload. The `land`
input and statement are spec section 6.1 (land). At startup and for each batch the lander reads
the Inbox's `VERSION`, initialization, L2 chain id, registry, committee config hash and
`maxBatchBlocks`. Before signing or first scheduling a broadcast it
rechecks the checkpoint frontier and the reference block.

`lander-state.json` uses schema 20 and is protected by `lander.lock`; other schemas are refused
and left intact. The journal is verified once at startup (statement hash, blob and KZG binding,
signed bytes); later writes are not re-verified. Signed bytes and blob sidecars are durably
written before broadcast. For an original range (p,h] and competing checkpoint p<=c<h, the
original input, leaves, proof, blobs, nonce and signed bytes remain unchanged. At c>=h,
never-broadcast work can finish; possibly-broadcast work remains pending until canonical
receipt/nonce reconciliation.
An ambiguous send or dropped transaction never authorizes recycling its nonce.
When the RPC no longer knows a pending transaction and both account nonce views still match
its nonce, the lander rebroadcasts the identical persisted bytes, including after competing
checkpoint progress or reference expiry and across restart. A canonical revert can then resolve
the outstanding nonce. It never signs a replacement or raises the original fee caps. A known
or underpriced transaction can still require operator reconciliation; investigate the account and
journal using
the [nonce reconciliation procedure](docs/governance-recovery.md#5-start-the-new-services)
before any operator action; never delete the journal or allocate a replacement nonce to bypass it.

A canonical revert where a competing landing moved the checkpoint settles and continues. With the
checkpoint unchanged, the lander also continues if the signed reference had expired in the receipt's
block and the L1 RPC's `debug_traceTransaction` with `callTracer` confirms `ReferenceBlockUnavailable`
as the top-level revert. It persists Idle, builds a fresh job and signs at the next nonce. Temporary
trace RPC errors leave the transaction in Confirming for retry. A missing tracing capability, an
inconclusive trace or another revert such as out-of-gas persists Idle and stops the lander. Restart
after fixing the cause. A deterministic revert then stops at gas estimation before signing.
An authenticated unsupported ruleset pauses preparation until the software is upgraded. The
log reports `software upgrade required`, and
`lander_retries_total{reason="unsupported_ruleset"}` records this separately from RPC or
finality waits.
Use one active lander per signing account and preserve journals across restarts. Keep unpruned
Comet blocks/commits, EL ancestry/execution state and historical L1 headers/proofs/registry
snapshots. Governance recovery and old-generation nonce reconciliation are covered in the
[recovery runbook](docs/governance-recovery.md#5-start-the-new-services). Real proving
and automatic operator nonce repair remain excluded.

### `abci-import`

Export a landed Etna checkpoint package, then import it into fresh app, stock Comet and execution
stores with one `import` command, published together as `ROOT/ready/{app,comet,el}`. Plain
`abci`, the EL and stock Comet then run those stores. See the
[checkpoint import runbook](docs/checkpoint-import.md) for the stopped EL source, original genesis,
validator-state preimage archive and startup. An import grants no signing readiness. A
registered validator resumes with its registered key and the same chain_id's HRS after matching
its own finalized target.
The EL helper derives the original block-zero hash from the operator's `--el-chain` using
`etna-el-import chain-identity --chain PATH --chain-id N`. Import pins the install and its receipt
to that identity, independently of the Inbox's Etna start hash H\* at S.
The [client rule inventory](docs/etna-conformance.md) and
[local resource measurements](docs/checkpoint-import-resources.md) describe the reproducible checks.

### `abci-recover`

Three one-shot commands: `prepare` authenticates a requested generation on own finalized L1 and
writes a plan file, `install` writes a fresh Comet home and an empty app directory from it, and
`status` summarizes a plan offline. The operator stops the old services and starts the new ones;
no command starts, stops or signals a process. Follow the
[governance recovery runbook](docs/governance-recovery.md) for the exact commands, the signer
environment of the new generation, the start order and full nodes. Recovery requires usable local
EL state at c, the block of the retained landing; a node whose EL holds another block there, or
none, takes the settled one first (runbook, "Take the settled EL state at c"). `abci-recover`
imports no snapshots and retains the dummy-proof development scope.

### `abci-genesis`

Reads the Ethereum-final genesis record from L1 and writes the CometBFT `genesis.json`
(48-byte `etna-` deployment-domain chain id, initial height 1, native validator set and the genesis
witness in `app_state`). It never invents values; `InitChain` re-verifies everything. The genesis
committee is the staking registry's snapshot at the Inbox's explicit `genesisCutoff`: the initializing DAO proposal names
that past L1 block explicitly, as it is written before the initialization block is known.
Genesis verification also checks the stored committee config hash against
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
at that L1 block exactly as `InitChain` will derive it (spec section 4.3, Committee derivation).
The snapshot is read and proven at a later L1
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
every member's compressed 33-byte public key and voting power, total voting power, selected effective
stake in TAIKO base units, and the committee
config hash required by Inbox initialization. A cutoff after the L1 node's `finalized` block
is refused, as the initialization fixes it irreversibly, and so is a cutoff at which no entry is eligible: initializing with it would leave the chain
without validators. `--json` prints each member's effective stake as a decimal string. Its top-level fields are
`record_hash`, `committee_config_hash`, `record`, `members`, `selected_eff_stake`, `proving_block`. The record has
`target_epoch`, `cutoff_l1_block`, `checkpoint_index`, `set_hash`, `total_power`; each member has
`pubkey`, `eff_stake`, `power`. Logs go to
standard error.

For launch acceptance (SPEC 4.1/4.4/11 and ACCEPTANCE 4), pin an independent `C_CAP_MIN`,
conservative per-TAIKO `P_REF` in the same currency, price source, haircut, expiry, review frequency
and responsible owner in the deployment manifest. With positive and current inputs, compute
`S_MIN_TOTAL = ceil(3 * C_CAP_MIN * 10^18 / P_REF)`. Check the report's selected effective stake
against that floor and require `ceil(totalPower / 3) * vp_unit * P_REF >= C_CAP_MIN * 10^18`.
Pending and unselected funds do not count; each entry and known common controller must be strictly
below one third of power. This report supports operator review, not a price oracle or consensus
threshold. Preserve the separate real-two-proof and resource acceptance requirements.

Owners may `topUp` active entries without free slots; funds become effective only through explicit
`activateTopUp` after the L1 delay, then affect selection snapshots that include that checkpoint.
They cannot activate after an exit is set. The DAO's `forfeit` deducts the deployment's explicit
`forfeitBps` fraction of effective plus pending principal, forces exit and records a lifetime key
flag, with no forfeiture nonce or registry revocation. The authorization has an inclusive L1
timestamp deadline and remains usable across landing and recovery. Withdrawal and double-sign
slashing cover both balances. Exercise the response budget before lawful withdrawal; seven days
is not automatically enough for governance execution.

Recovery binds `expectedRecoveryNonce` and `validUntil` in addition to generation and c;
the owner may invalidate the nonce explicitly. Recovery does not punish principal itself or
invalidate forfeiture authorization. Estimate recovery economics before authorization and reassess
finalized R, including activated top-ups. Economic shortfalls or expired valuation require alerts,
public disclosure and replenishment, without adding a signing, rotation or recovery veto.

```sh
taiko-client abci-committee-record --l1.http http://l1-node:8545 --l2.chain-id 167001 \
  --genesis-cutoff 400000
```

## Run a validator

The walkthrough assumes the Etna Inbox on L1 is initialized and the validator's native secp256k1eth consensus
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

2. **Initialize the CometBFT home** and install the genesis:

   ```sh
   cometbft init --home ./cmt
   cp ./genesis.json ./cmt/config/genesis.json
   ```

   For a brand-new identity, use the bootstrap-only `etna-signer keygen` and
   `etna-signer pop` commands before registration and genesis creation; see the
   [native signer instructions](tools/etna-signer/README.md). They emit public JSON
   for deployment tooling. Never use keygen to recover an existing validator.

   Keep the registered validator's existing `priv_validator_key.json`, its HRS state directory
   (one stock `<chain_id>.json` per chain) and its domains log in private directories outside
   the Comet home, every separate Comet container mount and the app store, with the log on
   another volume than the states (see the
   [signer bootstrap](tools/etna-signer/README.md#bootstrap-a-new-validator)). The key's
   directory must be writable by the signer, which creates its owner lock `<key>.lock` there.
   Preserve every state across every restart; never initialize, reset or replace one to recover
   consensus. The local key created by `cometbft init`
   is an unused random identity: do not replace it with the registered key. Stock
   `DefaultNewNode` also creates this dummy when absent, then replaces it with SocketPV
   for the mandatory listener; remote setup errors abort, with no local fallback. The
   dummy is unregistered and stays at HRS0. Its presence is not authoritative signing state. Only `etna-signer`
   may access the registered private key and signing state. Use separate users or container
   mounts so the Comet process cannot read that private signer directory. The combined image
   enforces a dedicated Comet UID as described below.

3. **Configure CometBFT** in `./cmt/config/config.toml`:

   ```toml
   proxy_app = "tcp://127.0.0.1:26658"   # taiko-client abci's --abci.addr
   priv_validator_laddr = "unix://run/signer.sock"   # validator marker; the supervisor assigns run/signer-<nonce>.sock
   # Or network signing over stock Noise (START-10-6), with the peer ID `etna-signer
   # transport-keygen` printed and ETNA_SIGNER_TRANSPORT_KEY naming that key:
   # priv_validator_laddr = "noise://<signer-peer-id>@127.0.0.1:26659"

   [mempool]
   type = "nop"                          # user transactions travel over the EL's devp2p

   [consensus]
   timeout_commit = "1s"                 # block cadence; keep it at 1s or more

   [p2p]
   persistent_peers = "<sentry id>@<host>:26656,…"   # the only nodes this validator dials
   pex = false                           # no peer exchange
   max_num_inbound_peers = 0             # no inbound slot for unlisted nodes
   unconditional_peer_ids = "<sentry id>,…"           # exactly ETNA_P2P_INBOUND_PEER_IDS
   ```

   Leave `create_empty_blocks = true` (the default). A `tcp://` `priv_validator_laddr` is refused:
   its stock listener generates a fresh identity at every start, so neither side could
   authenticate the other. In Noise mode the supervisor derives the peer ID the signer pins from
   Comet's persistent node key (`config/node_key.json`, created by `cometbft init`) and refuses
   to start without it.

   A validator exchanges P2P messages only with nodes its operator lists, such as its own sentry
   nodes (START-10-6): it has peer exchange off, dials only `persistent_peers` and accepts an
   inbound connection only from the listed IDs. Stock CometBFT v0.40.0 writes a peer's consensus
   message to the WAL before it verifies it and allows 40 inbound peers by default, so unlisted
   direct peers could push the WAL past its 1 GiB limit within seconds and cost the validator
   same-height resumption (LIMIT-12-2). The supervisor refuses to start a validator unless
   `p2p.pex = false`, `p2p.max_num_inbound_peers = 0`, `p2p.unconditional_peer_ids` holds
   exactly the comma-separated IDs in `ETNA_P2P_INBOUND_PEER_IDS` (none when unset), and nothing
   else dials: `p2p.seeds` empty, `p2p.seed_mode = false`, `rpc.unsafe = false` (its
   `dial_peers` would dial any node) and `p2p.libp2p.enabled = false`.

   Every validator also keeps three CometBFT v0.40.0 settings at their stock defaults (SPEC
   START-10-6). Leave them out or set them to exactly these values; the supervisor refuses to
   start, and `abci-recover install` refuses a validator template, when one differs:

   ```toml
   [blocksync]
   adaptive_sync = false

   [consensus]
   double_sign_check_height = 0
   block_time_tolerance = "1m0s"         # 60 s; "60s" and "1m" are accepted too
   ```

   Adaptive sync would run consensus while block sync catches up, and that can sign votes for
   heights already decided, which signer state does not prevent. A nonzero double-sign check
   height stops CometBFT on restart when the validator's key signed recent blocks, which would
   defeat the supervisor's automatic restart. Keep the node's clock synchronized with NTP well
   inside the 60 s tolerance (SPEC CONS-3.4-12): stock CometBFT judges a block invalid when its
   time is not earlier than the node's clock plus the tolerance, so a node whose clock lags that
   far prevotes nil, and once more than 2/3 of the voting power prevotes for or decides the block
   anyway, its consensus stops, and its block sync stalls, until it is restarted after its clock is
   corrected.

   These checks read the effective values: every spelling in `config.toml` (Viper folds key case
   and reads literal dotted keys), or the stock default when there is none, and every `CMT_*`
   override in the supervisor's environment, which Comet inherits, in both the `CMT_P2P_PEX` and
   the copied `CMTP2P_PEX` spelling. Each candidate must pass, an override that cannot be
   evaluated exactly is refused, and so are a `CMTHOME`/`TMHOME` that would move Comet off
   `ETNA_COMET_HOME` and an explicit Comet argv (`ETNA_COMET_COMMAND_JSON`) that sets any of these
   settings, `db_dir`, `db_backend`, `node_key_file` or `priv_validator_laddr` by flag. Keep the
   values in `config.toml`.

4. **Start alethia-reth** with Etna active and the agreed L2 genesis allocation (devnet example):

   ```sh
   alethia-reth node --chain ./etna-l2-genesis.json --devnet-etna-timestamp 0 \
     --http --http.api eth,net --authrpc.addr 127.0.0.1 --authrpc.jwtsecret ./jwt.hex
   ```

`etna-l2-genesis.json` must preserve the pinned Alethia devnet genesis fields outside
`alloc` and include the canonical EIP-4788 beacon-roots and EIP-2935 history-storage
predeploy code at their protocol addresses. The timestamp override alone does not install
these contracts. Build the allocation with the
pinned Etna genesis builder, `packages/protocol/script/layer2/build_etna_genesis.py` at
`PINNED_REVISION`, and use the same
resulting block-0 hash/state root when initializing the Inbox; `InitChain` verifies both
commitments against the local EL. Validate both predeploy runtimes in the allocation before
committing those values to the Inbox.

5. **Start the app**, then the **guarded signer and CometBFT**. The app must listen first:

   ```sh
   taiko-client abci --l1.http http://l1-node:8545 \
     --l2.http http://localhost:8545 --l2.auth http://localhost:8551 --jwt.secret ./jwt.hex \
     --data-dir ./abci-data --fee-recipient "$L2_FEE_RECIPIENT"
   ```

   ```sh
   # Build the host helper with Go 1.27.2 (also packaged as /app/etna-signer in the image).
   just signer
   # Once per chain_id, with the signer stopped: create its HRS and log it. The domains log
   # was created once with `init-domains-log`, on another volume than the HRS directory.
   ./target/etna-signer/etna-signer init-state --chain-id "$(jq -r .chain_id genesis.json)" \
     --priv-key /private/key/priv_validator_key.json \
     --priv-state "/private/hrs/$(jq -r .chain_id genesis.json).json" \
     --domains-log /private/domains/domains.log
   # In another terminal, supervise the signer and stock Comet together.
   ETNA_COMET_HOME="$PWD/cmt" ETNA_APP_STORE="$PWD/abci-data" \
     ETNA_SIGNER_BIN="$PWD/target/etna-signer/etna-signer" \
     ETNA_PRIV_KEY=/private/key/priv_validator_key.json \
     ETNA_PRIV_STATE_DIR=/private/hrs \
     ETNA_DOMAINS_LOG=/private/domains/domains.log \
     ETNA_CHAIN_ID="$(jq -r .chain_id genesis.json)" \
     bash script/start_etna_validator.sh
   ```

   The signer serves only `<ETNA_PRIV_STATE_DIR>/<ETNA_CHAIN_ID>.json`, one stock HRS per full
   chain_id, and refuses with exit 3 a missing or malformed domains log, a chain_id the log does
   not list, a logged chain_id whose state is missing and an unauthentic or ambiguous HRS
   (RECOV-8.2-1..3); see [the signer README](tools/etna-signer/README.md#refusal-matrix-and-exit-codes).

   The host supervisor requires Bash and Python 3.11+ (`tomllib`); the production image
   includes Python, the signer, this supervisor and stock Comet v0.40.0 (source
   `0880b4d378f347ab16e54ec677ff50d803f37d62`). Validators run the official upstream executable
   (CONS-3.1-1). [`comet-manifest.json`](comet-manifest.json), installed as
   `/app/comet-manifest.json`, is the deployment manifest: for each supported platform it names
   the upstream release artifact, the executable's digest, the source commit, the published build
   recipe and flags, and the configuration the supervisor enforces. On linux/amd64 the image
   copies `/usr/bin/cometbft` from the official image
   `cometbft/cometbft:v0.40.0@sha256:0703fb88…` (platform manifest `sha256:53421974…`) and checks
   its sha256 `5fbb1bf5…`; the supervisor checks the digest again before every Comet start, since
   a reported version string alone does not identify the build (the official executable also
   reports `0.39.0+0880b4d`). Upstream published no arm64 executable for v0.40.0: the GitHub
   release has no assets, and the official linux/arm64 image holds the same x86-64 executable.
   The arm64 image therefore keeps an unmodified source build only for development, and the
   supervisor refuses to start a validator on linux/arm64, naming that reason. `ETNA_COMET_MANIFEST`
   names another manifest, for example the one `script/build_stock_comet.sh` writes for a local
   source build in tests. CI checks every bundled ELF against the declared matrix platform before
   publishing the multiarch tag; emulated execution alone is insufficient.
   Its default entrypoint remains the app; the validator supervisor container uses
   `command: ["python3", "/app/script/etna_validator.py"]` with the same environment below.
   Run the app in a separate container sharing the private app-store socket and persisted
   state mounts; do not expose the socket outside the pod. The image runs supervisor/signer
   as root and drops the stock Comet child to UID/GID 10001 (`ETNA_COMET_UID/GID`). Prepare
   its persistent home owned by 10001, with `<comet-home>/run` owned by 10001, mode 0700 and
   not sticky (the supervisor refuses a sticky `run/` or one not owned by the Comet UID;
   without CAP_FOWNER it could not remove Comet's stale socket from a sticky `run/`); keep
   registered key, HRS directory and domains log root-owned 0600 in private directories outside
   that home and the app store. The Unix signer listener lives in that `run/`, never in the app's 0700 private
   store. This prevents the Comet child from reading registered signing secrets. The
   supervisor needs root with exactly CAP_SETUID and CAP_SETGID (start Comet as
   `ETNA_COMET_UID/GID` without supplementary groups), CAP_KILL (stop that Comet) and
   CAP_DAC_OVERRIDE (traverse the Comet-owned home and `run/`, connect the root signer to
   Comet's socket, and remove stale `run/signer-*.sock`); it needs no CAP_FOWNER or
   CAP_CHOWN. Comet runs as UID 10001 with zero effective capabilities. Persistent Comet
   volume ownership is prepared separately. The HRS state and its directory must be writable
   for atomic replacement. The key file may be read-only, but its directory must be writable for
   the signer's `<key>.lock`, so a read-only mount such as a Kubernetes Secret volume cannot
   hold the key directly: the signer exits 1. The domains log's directory must be writable too:
   the supervisor writes the `<chain_id>.signer-unsafe` marker beside the log, and the signer
   holds a lock on the log while it serves. The supervisor requires
   `priv_validator_laddr`, signing paths outside the Comet home and app store, and a matching
   genesis chain ID. A `unix://` value only selects Unix mode and is preferred; `noise://`
   uses stock Noise with both transport peer IDs pinned, and bare `tcp://` is refused. A
   nonvalidator full node, a sentry included, runs stock Comet without the signer, using an
   unregistered local identity, through `python3 /app/script/start_etna_full_node.py` with
   `ETNA_COMET_HOME` set. That launcher refuses a `priv_validator_laddr`, holds a writer lease
   beside the home and makes the supervisor's two pre-start checks (`script/etna_comet_guard.py`)
   before it execs Comet: the executable's sha256 must be the one the deployment manifest pins
   (CONS-3.1-1), and the pending-evidence store below is deleted (CONS-3.1-10). It execs the
   exact file it hashed.

   Every time it starts Comet, with Comet stopped, the supervisor (and the full-node launcher,
   under its writer lease) deletes the node's pending-evidence store, `<db_dir>/evidence.db` (stock goleveldb or pebbledb; `data/evidence.db`
   by default), and nothing else: the WAL, block and state stores, the app and EL stores and the
   signer's files stay (CONS-3.1-10). No block commits evidence (`evidence.max_bytes = 0`), so only
   expiry bounds the stock pool, and restarting a node under pressure empties it (LIMIT-12-22).

   Every Comet signer transport opens a new local trust session through the app's private
   mode-0600 `<data-dir>/checkpoint-trust.sock`. PubKey and Ping work while closed so the ABCI
   handshake can proceed. Each proposal, prevote or precommit (including nil votes, locked
   blocks, retained proposals and already signed retries) needs a fresh bounded CheckSession
   reply for the transport's current session that names the served chain ID, phase `ready` and
   the request's height as `eligible_height`, the one height the app admits (SYNC-9-10); the app
   reports `ready` only after its checkpoint and InitChain checks. Unavailable or malformed
   control, a closed or halted phase, a stale session and another height deny signing without
   touching FilePV; a pending decision is held for at most 3.5 s. The helper locks the existing
   state against a second helper process. No local signing fallback exists in the validator
   startup recipe.

   The helper atomically publishes private `signer-denial.json` observations: sequence zero
   establishes the session of a new connection (empty while the app could not begin one); a
   positive sequence records a refused signing request, including one whose trust query timed
   out. The supervisor's private `observe` request neither rearms the session nor authorizes
   signing. Stock Comet gives up at once only on a request the helper answered with an error and
   retries any other failure (no answer within its fixed 5 s signer read timeout, a dropped
   connection, a malformed answer), so the helper always refuses explicitly and in time. Comet
   never retries such a refusal; only a restarted Comet's WAL replay asks for that step again. So
   once exact deployment identity and private trust return Ready, a denial triggers a bounded
   stop/reap of both children and a restart of the pair together (SYNC-9-12): the signer connects
   to `priv_validator_laddr` promptly, begins a fresh closed session that the app checks while
   Comet's handshake runs, and holds the step that WAL replay requests again until that session
   is trusted. Another refusal repeats this once trust is Ready. This also handles a signer
   timeout while the app stays Ready. Every start, the first included, runs both together: a node
   that is behind regains trust only after Comet syncs, and Comet's startup needs the signer. If
   Comet exits before the signer's transport connected, as when the signer misses the 3 s accept
   of Comet's first GetPubKey, the supervisor starts the pair again after 1 s with the same signer
   state and no latch.
   Halted trust, another chain_id, an unsafe signer exit or unexplained Comet exit creates
   `<data-dir>/validator-supervisor.halted` and leaves the supervisor alive and quiescent.
   Any other signer exit (0, 1, 2 or a signal that the supervisor did not send) restarts the
   pair: Comet is reaped, then a fresh signer on the same state path and Comet start together,
   and the signer begins a new closed session on the fresh transport. Exit 3,
   a retained fence, a signer still running 5 s after the supervisor's SIGTERM (it is
   SIGKILLed) and the fifth such exit within 600 s latch instead (SYNC-9-14); the exit count
   lives in memory, so a supervisor restart resets it. All but the crash loop also create
   `<data-dir>/validator-supervisor.signer-unsafe`, independent of the first-cause latch, and
   `<chain_id>.signer-unsafe` beside the domains log, which a fresh app store cannot lose and
   which the signer refuses with exit 3 (RECOV-8.2-3); a kill is recorded in both, durably,
   before the SIGKILL is sent, and every start refuses while either exists. Never delete or
   replace an app store holding a latch or record; before running a validator on a new app
   store, check for both. See
   [the restart table](tools/etna-signer/README.md#supervisor-restarts-and-latches).
   The signer releases a signature only after it fsyncs the state file and its directory. If
   either fsync fails, it withholds the signature, writes `<priv-state>.uncertain` beside that
   chain's HRS and exits 3; a crash writes no fence. A retained fence blocks startup, including
   when the supervisor was killed before writing its app-store latch.
   If that latch cannot be written, the supervisor stops its children, stays quiescent and
   retries persistence. A signer it must kill is the exception: while its signer-unsafe record
   or marker cannot be written, the supervisor never sends the SIGKILL, so that signer is left
   running after Comet was stopped, and a SIGTERM to the supervisor waits too, until the
   kubelet's SIGKILL ends the pod. A stop takes up to 12 s for Comet plus the signer's 5 s
   grace, so set `terminationGracePeriodSeconds` above 17 s with margin for the fsyncs, for
   example the Kubernetes default of 30 s; a shorter one SIGKILLs a slow signer unrecorded.
   Container restart cannot clear a retained signer fence, signer-unsafe record or marker, or
   halt latch.
   A Comet EOF following observed control/trust loss also recovers after private Ready;
   a repeated configuration failure with continuously Ready trust stays latched. Exact app
   shutdown revocations wait for a fresh app incarnation; they never authorize signing.
   Repair the underlying cause and review durable evidence before explicitly removing it.
   Missing registered signing state fails closed; startup never creates replacement HRS.
   In Unix mode each signer+Comet start gets a fresh `<comet-home>/run/signer-<16 hex>.sock`:
   Comet is started with `--priv_validator_laddr unix://<that path>` and the signer dials the
   same address. Before each start, with both old children reaped and the home owner lock held,
   the supervisor opens `run/` without following a symlink and unlinks every
   `signer-*.sock` entry through that directory. These names are the supervisor's own
   namespace, so the stale socket of an unclean Comet exit is removed without type, inode
   or liveness checks; other names in `run/` are left alone. A missing or symlinked `run/`,
   a sticky `run/`, a `run/` not owned by `ETNA_COMET_UID` (by default the supervisor's
   effective UID), a `run/` open to its group or others (it must be mode 0700, so no other user
   can replace the socket), a prefixed entry that cannot be unlinked (such as a directory), and a
   Comet home whose socket path would exceed 103 bytes (the macOS `sun_path` limit, checked
   at startup) all fail startup. The `run/` checks run before every start, so a
   misconfigured `run/` fails the first start rather than the restart after an unclean
   Comet exit.
   Signing state, WAL, app history, the private trust socket and the durable halt latch remain
   untouched.

   On restart, CometBFT replays missing app commits while signing stays closed until the app
   authenticates its own latest finalized-L1 checkpoint and links it to durable committed
   state. A Comet-only restart/reconnect rearms trust. An app-only restart changes the session;
   the first stale signing request begins a new closed session and is held there for at most
   3.5 s, then signed if the app has checked that session, or refused and recovered as above. Keep WAL,
   blockstore, app state and FilePV state intact. Shutdown stops and reaps Comet before the
   signer; keep the app available until Comet has stopped. A signature already authorized by
   a fresh check can finish after a concurrent app crash; there is no cross-process atomic
   revocation guarantee.

   Read app `/trust` or `/status` through `abci_query` for Etna readiness. Stock Comet
   `catching_up=false`, Pod Ready and a moving EL head do not establish checkpoint trust.
   Keep a responsive observer peer with intact Comet history available for catch-up. On the
   pinned binary, a peer blocked waiting for an unavailable signer can also block consensus
   history gossip. An explicit signing-key handoff can restart that retained-history peer as
   an unregistered observer while preserving its Comet home/WAL and the real signing files.

   Public Comet/EL RPCs need a separate readiness-enforcing gateway if trusted output must be
   withheld before Ready; the signer controls signatures, not those public endpoints.

## Operations

### L1 node requirements

- **HTTP only.** `--l1.http` takes an `http` or `https` JSON-RPC endpoint. WebSocket is not
  supported: alloy's WebSocket client stops reconnecting after a few attempts, so a longer L1
  outage would leave every later L1 read failing until a restart.
- **Every node** reads L1 headers and the `finalized` block from its own L1 node to check that
  anchored L1 headers are canonical and final. Full nodes also run the background prefetches
  validators use for committee witnesses, so give them the same L1 proof access.
  Proposers also need exact-block historical admission logs for pending forced entries.
- **Validators** also build proposals, so their L1 node must serve `eth_getProof` (EIP-1186) for
  historical blocks. A proposal proves Inbox storage at its anchor, the own L1 node's
  `finalized` block when the anchor moves. At a switch height the proposer also
  reconstructs the registry entries at the committed parent anchor. The selected registry
  checkpoint can be older than that anchor. The state window or cached history must cover
  those historical entry reads as well as the parent-anchor proofs. Landers starting mid-epoch
  also need the earlier derivation snapshot's entries and the bounded EL ancestor headers.
- At switch height `S(t)`, the registry snapshot is the later of the committed `D(t)` anchor's
  L1 block and the current generation's L1 origin (`L1_0`, or R after a recovery), and its
  proofs verify under `S(t)`'s own anchor state root (spec section 4.3); `S(t)` keeps its
  parent's anchor unless it carries a newer one. An L1 finality stall keeps that anchor for up to
  `maxAnchorAge`, a per-deployment value above the L1 finality delay (spec PARAM-11-5): the age
  the newest finalized L1 block reaches just before the next finalization (1152 s on Ethereum)
  plus the deployment's allowance for slots missed at an epoch boundary and for import delay.
  1152 s itself is therefore too low on Ethereum, although the app refuses only values below it
  (spec START-10-9). At 12 s per L1 block, a 2 h value is 600 blocks, beyond a geth full node's
  128-block state window. So nodes discover the witness as soon as they commit the anchor (see
  below). That needs the
  L1 proof window to cover the finality lag plus one discovery and its retries; a node that was
  not live when the anchor was adopted, or restarted since, still needs historical state. The own
  L1 node behind `--l1.http` is the only source of these reads (spec SYNC-9-16), so configure its
  historical proof/state retention to cover the required history.
- Fully verified committee witnesses acquired locally or received in valid proposals are kept in
  memory only; nothing is written to the app data directory. Every node discovers the upcoming
  committee witness in the background under each committed anchor that can still be `D(t)`'s,
  starting with the live `Commit` of the block adopting it, and keeps it while the anchor stays.
  Every `PrepareProposal` and `ProcessProposal`, placeholder proposals included, and every live
  `Commit` start a missing discovery and restart a failed one, from scratch, once its backoff has
  passed (2 s, doubling per failure under the same anchor up to 60 s, so an L1 that cannot serve
  the state or rate-limits it sees one attempt per pause). A running discovery is never
  restarted: a proposer that needs the witness joins it and waits within its own deadline, and
  the discovery runs on past that deadline. An unreachable, lagging or timed-out own L1 leaves
  the witness unavailable, a liveness pause; malformed or contradictory replies from it halt the
  node (spec SYNC-9-7). An anchor can be `D(t)`'s only while `D(t)` passes back-pressure against the
  anchor's last checkpoint height and stays within `maxAnchorAge` of the anchor at one second per
  height at least, so this costs about one discovery per adopted anchor (one per L1 epoch) in the
  last `unsettled_limit` heights before each `D(t)`. An L1 finality stall that holds the anchor
  through `D(t)`, an anchor freshness stall or an outage therefore does not leave a running node's
  `S(t)` waiting on pruned state, provided the anchor's state was still served when it was
  adopted. A restart keeps no
  witness: the restarted node re-discovers it from its own L1, reading historical `eth_getProof`
  and registry state at the snapshot block. That block is fixed by the committed `D(t)` anchor (or
  the generation origin, spec COMM-4.3-11), not by `S(t)`'s own anchor, so it keeps ageing until
  `S(t)` commits, even when `S(t)` carries a newer anchor. Plan for at least `maxAnchorAge` plus
  the L1 finality lag of history, growing with any pause between committing `D(t)` and committing
  `S(t)`, an L1 finality stall longer than `maxAnchorAge` included. A restarted validator still
  needs that historical state on its own L1 (spec SYNC-9-16) to propose `S(t)`; otherwise it can
  only accept a peer's valid `S(t)` proposal, which needs some peer that still holds the witness.
  If every validator restarts, `S(t)` waits for an L1 node that has that history. Size the
  retained state and reth's `--rpc.eth-proof-window` (which limits historical proof access
  independently of retained state) for the longest pause you want a restart to survive, as well as
  for the history validators and landers need otherwise. Full nodes importing an older checkpoint
  can also need historical `eth_getProof` calls to reconstruct an inherited anchor and committee
  snapshots; retain that state and configure the proof window for the selected import history.
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
- The normal handshake cannot resume one case (spec CONS-3.1-9): a crash inside a generation's
  first block, between CometBFT saving that block and saving its state, when the generation's
  `initial_height` is above 1. Stock CometBFT v0.40.0 then stops at its handshake whatever the
  app reports, and the spec leaves the repair open (review question Q3.1-8). Generation 0 here
  always has `initial_height` 1; a recovery generation starts at c + 1, so one whose origin c is
  above 0 is exposed.
- The app checks alethia-reth against its committed head at every CometBFT handshake `Info`
  and syncs alethia-reth to that head if it lacks it; until then that `Info` stays pending, so
  CometBFT never sees a height alethia-reth does not hold. The check runs once per set of ABCI
  connections: a CometBFT restart under a running app opens new connections and is checked
  again, while RPC `/abci_info` calls on the open connections answer from the committed state.
  The app answers requests one at a time and finishes each one even after CometBFT has
  disconnected, so a CometBFT-only restart is re-checked only when the app is not stuck in a
  request: the new handshake's `Info` waits until the request in progress has been answered.
  On a validator a CometBFT restart also reconnects `etna-signer`, and every new trust session
  re-checks the committed head before signing reopens.
- If alethia-reth loses its recent execution tail while the app remains running, preparation,
  proposal validation and cold/cached finalization repair the committed parent before retrying
  execution. Startup `Info` uses the same local execution archive before peer sync. A Prepare
  deadline cancels only its waiter: context-bound payload recovery continues across rounds.
  The owned task never sends forkchoice; a live handler checks its result and canonicalizes the
  committed head. Commit, context replacement and app drop abort obsolete work. Retries are
  logged with backoff. `ProcessProposal` points forkchoice only at the trusted committed head;
  it never makes an undecided peer proposal canonical to repair missing history.
- Every successful finalization fsyncs its exact checksum-framed RLP execution body to
  `execution-block-<height>.bin` before its AppState can be committed. Preserve these files with
  the app store. Recovery authenticates the suffix backward from the committed hash, then
  re-feeds it in bounded memory from a surviving ancestor whose execution state is available.
  The archive grows with this generation's execution history above its authenticated origin or
  import floor; ordinary landings do not authorize pruning it, because even a recently landed
  checkpoint may still be volatile in the EL. Reclaim history only across a separately installed
  authenticated origin/import boundary with retained execution state.
- Existing stores without these auxiliary bodies keep the peer-sync path. Missing/corrupt bodies
  or unavailable origin/import state remain missing data, not permission to invent payloads or
  reset Comet/FilePV state. If no peer retains the data, restore a verified execution dataset and
  its state boundary; restarting alone cannot recreate lost data. No signed journal or AppState
  schema is migrated by this recovery path.
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

### Checkpoint trust

- Every app start and every signer session start closed (SYNC-9-4). The app reads the Inbox's
  latest checkpoint and `recoveryGeneration` at one block of its own L1 `finalized` view: the L1
  header and state root, exact account and storage proofs, canonicality and generation, then the
  checkpoint's slot 285 record at that same L1 block. Readiness is the trust phase alone:
  `/trust` reports it as `phase` and `/status` as `trust_phase`, one of `acquiring`,
  `catching_up`, `ready` or `halted`, and only `ready` means trusted. The signing gate reads the
  same value, so no signature needs an L1 read of its own. While closed, neither reports a
  `trusted_consensus_head` and `/trust` names no `eligible_height`; `trust_target` shows the
  latest known checkpoint and `trust_reason` why trust is still closed. Info, InitChain and
  historical Finalize/Commit replay continue normally meanwhile.
- Trust opens only after the target's hashes match durable committed history: the EL hash and
  the slot 285 Comet hash, or the EL hash alone while the target is the generation's origin (S,
  whose record holds Comet hash 0, or a recovery origin c, whose record keeps the old
  generation's Comet hash that a node joining through the generation's genesis does not hold;
  SYNC-9-5). A committed head already above the target must prove its complete `parentHash`
  ancestry down to the target; finding the target in alethia-reth is not enough. The EL hash is
  compared as soon as the node holds the target height, even while the slot 285 record is
  unavailable: a mismatch then halts at startup. A ready reply names `eligible_height`, the
  committed boundary plus one: the generation's `initial_height` before its first commit, s + 1
  right after an import at s (SYNC-9-10).
- A trusted node keeps following its own finalized L1 view (SYNC-9-6a). A checkpoint above the
  last matched one, read there or proven by a proposal's anchor, makes trust `catching_up`
  until the node has reached it and both hashes match; signing requests wait meanwhile (the
  signer polls for up to 3.5 s) and are refused explicitly after that, and a match restores trust
  without an operator. A checkpoint at or below the matched one needs no comparison. An
  unavailable read keeps the matched result and pauses further reads for 1 s, doubling up to
  30 s. A newer checkpoint whose EL or Comet hash conflicts with local history, or a larger
  `recoveryGeneration`, revokes trust at once although no proposal shows it: the phase becomes
  `halted`, the process keeps running, nothing is signed and the generic fatal record makes the
  next start refuse.
- A missing proof, missing history or transient I/O keeps trust closed and retries. An
  authenticated contradiction is a safety halt, and so is malformed or unverifiable data from
  the own L1 node or alethia-reth (a header whose hash or number does not match, a proof that
  fails against its state root, a second read returning a different hash for the same finalized
  number), because the node cannot tell it apart from forgery.
- Within one process the highest authenticated target survives across sessions and is never
  lowered by a lagging L1 answer; after a restart, the loaded state's authenticated anchor is
  the initial floor. Once trusted, ordinary advances of the L1 finalized head never expire an
  accepted proposal and are not a block-validity rule.
- Checkpoint ancestry: whenever a block carries an anchor witness, the anchor's proven
  `lastCheckpoint` must be at most the parent height and equal the local chain's EL block hash
  at that height (CONS-3.4-16). `ProcessProposal` rejects a conflict (`checkpoint_conflict` or
  `checkpoint_above_parent` in `abci_process_rejected_total`, logged at ERROR), a proposer
  proposes nothing on it, and a cold `FinalizeBlock` halts on it. A checkpoint above the parent
  leaves trust `catching_up` until the chain reaches it; a hash conflicting at a held height
  revokes trust, and the node does not keep producing on an older anchor. An EL that does not
  serve that block yet only makes the node wait.
- `ProcessProposal` rejects at once, without waiting, an anchor the own L1 node has not
  finalized, because its view is behind or it lags, is unreachable or times out (CONS-3.3-5,
  RECOV-8-5); a decided block's `FinalizeBlock` waits for it instead. The proposer keeps its
  parent's anchor for `--anchor.hold` seconds (default 12, one L1 slot) after its own L1 first
  shows a newer finalized block, while that anchor keeps the block fresh and within
  back-pressure, so validators slightly behind do not reject the proposal (CONS-3.3-4).
- Checkpoint fence: `FinalizeBlock` passes the `lastCheckpoint.hash` proven by the block's
  anchor as forkchoice `finalized`. alethia-reth rejects a head that does not descend from it
  with `-38002` (invalid forkchoice state), and the app stops with a safety halt. With
  back-pressure, this bounds a history forged with old keys to `unsettled_limit` blocks beyond
  its fork point.
- While untrusted, forkchoice passes `safe = 0`, so a replayed candidate never becomes the EL
  safe head, and still passes the historical checkpoint as `finalized`. Syncing alethia-reth to
  a block the app already persisted (at `InitChain`, at the handshake `Info`, or when a trust
  session finds alethia-reth missing the committed head) passes 0 for both `safe` and
  `finalized`, because that block passed the fence when it was finalized. Zero does not clear
  tags alethia-reth already holds.
- With these trust and signing gates, a forged suffix stays untrusted below the target or is
  refused at its hash, so the starting checkpoint needs no age limit under the own-L1 and
  proof-soundness assumptions. Historical replay is independent of this node-local check.

### Execution layer state history

- Cold replay judges each decided block from its authenticated parent. Inclusion and ineligible-byte
  skips need no singleton build. A due eligible entry absent from position zero requires a
  historical singleton and therefore the parent's execution state. Landers need the same history
  when authenticating eligible-transaction skips in decided batches.
- Keep the pinned alethia-reth behavior that processes payload attributes on historical canonical
  parents (`TaikoChainSpec::is_optimism() == true`). Leave
  `--engine.allow-unwind-canonical-header` disabled (the default): enabling it can rewind the shared
  canonical head. The lander checks the candidate parent's numeric canonical hash before probing;
  this guard is not an atomic lock against concurrent reorgs. ABCI supplies its committed-parent
  context without an equivalent numeric lookup. Neither path submits or forkchoices the singleton
  result. Engine builds are not universally read-only, especially on noncanonical parents.
- Retain execution state over the entire replay/landing distance, or use an archive node. A later
  snapshot may lack the required old state. Retryable unavailable-build RPC errors are
  non-consuming and logged with `method="forced_skip_probe"`; the `reason` diagnostic
  includes the parent number/hash and a qualified historical-state hint. A generic internal RPC
  error does not confirm pruning. Unknown payload IDs (`-38001`) restart the build to obtain a
  fresh ID. When state becomes available, retry resumes without advancing the cursor prematurely.
  Nonretryable Engine build failures stop through the safety-halt path, whose log uses
  `reason="forced_skip_probe"`. Restore the required state/history before restarting a
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

A future guest must bind the V1 statement, cut leaves, execution-only public payload, native
certificates and authenticated committee ancestry. The beneficiary is proposer-selected; full
execution must establish its fee credit. Prove the terminal active committee cutoff, FI behavior
and L1 reference ancestry. No real guest is implemented; the dummy verifier cannot establish
these claims, so this version is restricted to disposable development chains.

## Development

```sh
just fmt        # pinned nightly rustfmt + cargo sort (never call cargo fmt directly)
just fmt-check
just clippy     # doc lints on library code, then every target with -D warnings
```

### Tests

The [340 formal client vectors](crates/abci/tests/fixtures/etna_conformance/README.md)
are regenerated from #22292 at `4f38cfcc8`. They check the historical decoded model
and retain one documented height-bound divergence; they do not establish conformance
to the latest Etna specification. Current registry admission vectors belong to the
contract harness.

- `just test-dev` prints and runs native tests and Docker scenarios selected from local changes.
  It includes staged, unstaged and untracked files. Pass a Git ref to include commits since its
  merge base with HEAD, or add `--dry-run` to preview the commands. Shared changes add `just unit`
  and `just test-smoke`. A clean worktree runs smoke. This recipe defaults to `PULL_POLICY=missing`.
- `just unit` runs all unit tests, the Docker-free CLI startup/shutdown and entrypoint cleanup
  process tests and abci's Etna conformance vectors, then the abci doctests. No docker needed. It
  builds only those targets, and without extra arguments runs lander's library tests in one
  `cargo test` process, which loads the KZG trusted setup once instead of once per test.
- `just test` runs the serial Docker integration scenarios in `crates/abci/tests`,
  `crates/lander/tests`, `crates/test-harness/tests` and `bin/client/tests`. ABCI scenarios cover single validator,
  anchor finality, restart and lost-state replay, epoch switch with and without landing, back-pressure, generation
  bump, calldata inclusion, ineligible-byte skips, canonical skips, and unavailable-history
  retry/recovery, plus an L1 finality stall that pauses and resumes L2. The history test emulates
  the source-backed unavailable-build RPC shape through a delegating Engine adapter; it does not
  actually prune Reth state. Lander scenarios cover actual Inbox blob
  transactions, cross-epoch batching, four native validators with ordinary and forced
  transactions, 100% beneficiary fees, FI fees swept to the treasury, epoch transition, dummy
  0x00 landing, signer timeout recovery and offline catchup with retained HRS and Comet block
  IDs at or above the committed anchor's checkpoint,
  execution-DA replay, permissionless overlap races,
  verifier rejection, a pending L1 reference crossing the BLOCKHASH/EIP-2935 boundary, stock
  CometBFT collection, and actual-CLI SIGKILL/SIGTERM restarts, minimum/timeout batching, and
  pressure/epoch flushes; runner and store unit tests cover receipt reorgs and journal restarts.
  Each scenario boots its own devnet through the docker CLI (anvil as L1, alethia-reth,
  CometBFT), with phases that need the same history sharing one, so they run one at a time.
  CI runs two serial lanes: `native` (the `governance_recovery` binary: stock Comet, native EL
  and the recovery test image) and `devnet` (all other scenarios); set
  `TAIKO_CLIENT_RS_TEST_LANE` to run one locally. Extra arguments go to `cargo nextest run`,
  e.g. `just test restart` runs one scenario. Pull requests
  skip the L1 finality stall and the L=7 recovery (L=6 and L=8 cover the same recovery path);
  `just test-full` runs every scenario, as CI does on main, nightly and on manual dispatch.
  `tests/entrypoint.sh` lists selected cases before Docker checks and prepares their images and
  native helpers. For example, `just test --test cleanup` only needs the Foundry 1.8.5 image.
  The recovery image is built for its Linux consumer. On an ubuntu or
  debian Linux host, that image is the test-only `tests/docker/recovery-runtime.Dockerfile` on
  the host's own distribution, holding the client binary the listing built and the host-built
  signer and Comet helpers; other hosts build the production `Dockerfile`, which compiles the
  release binaries. Without `ALETHIA_RETH_IMAGE`, the entrypoint builds the pinned EL source once
  into the local `alethia-reth:etna-<revision>` image (the production `execution-runtime` target)
  and reuses it while present; it never pulls that image. When the native EL is needed, a Linux
  host whose Docker daemon has the same architecture copies it out of that image; another host,
  an overridden `ALETHIA_RETH_IMAGE` or a missing image builds it from the pinned source.
  Unsupported nextest run-only options conservatively prepare all images and helpers, after listing
  without those options. Override images with `ANVIL_IMAGE`,
  `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE` and `LANDER_ANVIL_IMAGE`, or set
  `PULL_POLICY=missing` to reuse local images. `just unit` also verifies the pinned contract
  artifact hashes.
  Harness RPC ports bind to host loopback. SIGINT/SIGTERM remove resources owned by the interrupted
  test process; the entrypoint and CI use the shared `taiko-client-rs.test-run` Docker label to
  remove any leftovers from that run, including lander fixtures. Set `TAIKO_CLIENT_RS_TEST_RUN`
  to a unique identifier when supervising a direct cargo/nextest run and retaining an external
  cleanup fallback for SIGKILL.

- `just test-smoke` runs exactly four representative Docker scenarios: single-validator header
  rules, epoch switch, the four-validator native acceptance flow, and lander CLI SIGKILL/SIGTERM restarts.
  This fixed recipe accepts no arguments. Use `just test` for targeted subsets or output options.
  None of the four is in the `native` lane, so `TAIKO_CLIENT_RS_TEST_LANE=native just test-smoke`
  selects no scenario.
- `just runtime-image-test IMAGE linux/arm64` (or `linux/amd64`) smoke-tests the actual Linux runtime composition, native
  bootstrap, Comet UID isolation and unchanged HRS without a Rust rebuild. Build the
  `runtime-tools` Docker target with repository-root context first. Multiarch final image CI
  remains required before deployment. The smoke requires an explicit platform and checks
  Comet, signer and, in a release image, client ELF architecture before child startup.
- `just verify` is the complete merge gate: the Go signer tests, the supervisor and test-script
  regressions, formatting, strict clippy, fast tests, the EL import helper's checks, committed
  artifact reproduction, the checkpoint-import resource profiles and all Docker scenarios
  (`just test-full`). Smoke is an iteration aid and never replaces this gate.

Regenerate lander ABI/deployment fixtures only when their inputs change, with
`script/gen_lander_artifacts.sh /path/to/taiko-mono-at-pinned-protocol-revision`.
The script requires the pinned protocol revision (see Fresh deployment; `PINNED_REVISION` in the
script) as HEAD, installs pnpm
dependencies before Foundry, builds `EtnaInboxBootstrap`, the Inbox, registry and
SignalService with their test fixtures, verifies compiler source hashes,
formats generated JSON, and records ABI/bytecode/compiler provenance. It also copies the Etna
vectors shared with the contracts (`testdata/etna_vectors`, which the `abci` and `lander` unit
tests read) from that revision and records their hashes. Run it twice and require identical
generated output.
The export includes the switching SignalService and an ABI-only Unzen cutoff artifact, whose
external library references are recorded in the manifest rather than exposing unlinked deployment
bytecode. Shared vectors follow the pinned contracts' schema 9. Test adapter updates and execution
are separate from this artifact refresh.

Regenerate the legacy Inbox, Anchor and PreconfWhitelist Rust bindings with
`PROTOCOL_DIR=/path/to/pinned-protocol/packages/protocol script/gen_bindings.sh`.
It uses the same protocol pin and the workspace's Alloy dependency, records source/ABI/generated
file hashes in `crates/bindings/protocol-manifest.json`, and removes the retired LookaheadStore
module. Generated binding sources and their manifest must not be edited or formatted manually.
`just check-lander-artifacts` (the CI job "Lander artifacts") runs it on the pinned revision in a
temporary git worktree, regenerates both the Etna artifacts and legacy bindings, and fails unless
every generated file equals the committed one.
Regenerate test-only `InboxSetter`, `ZkGasFixture` and `FeeRoutingFixture` artifacts with
`script/gen_test_harness_artifacts.sh /path/to/alethia-reth`; it verifies compiler settings and source hashes and records
bytecode provenance. Run that generator twice with identical output as well.

## License

See the [LICENSE](../../LICENSE) file for details.
