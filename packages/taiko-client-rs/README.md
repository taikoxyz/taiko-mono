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
  L1 header plus EIP-1186 storage proofs of the Inbox and the staking registry; while an entry the
  chain has not consumed is queued at the anchor, that entry's proof and exact calldata bytes),
  into the CometBFT block. Validators check with their own L1 node that the anchored header is
  canonical and final. `FinalizeBlock`, replay and block sync read no L1 state or admission logs;
  for a block the node never judged, they confirm its anchor header (see Restarts). Canonical
  forced transactions omitted at position zero require Engine checks against the authenticated
  parent; valid inclusion and ineligible-byte skips need no singleton build. At each switch height the
  app derives the target committee from the committed parent anchor and hands CometBFT the
  validator updates, effective two heights later. Its state is persisted atomically at every
  `Commit`. The genesis record includes the authenticated committee config hash, and the epoch
  schedule is derived from it. Only canonical `genesis` and `status` fields are accepted; legacy
  aliases, redundant persisted schedules, and missing config hash or Inbox binding are rejected.
- **alethia-reth** executes blocks; the app drives it with `engine_forkchoiceUpdatedV3`,
  `engine_getPayloadV5` and `engine_newPayloadV4`. CometBFT height equals the EL block number; Etna starts at L2 block 0, and consensus starts at height 1.

## Project structure

| Path                   | Description                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------- |
| `bin/client/`          | The `taiko-client` binary (`abci`, `abci-genesis`, `abci-committee-record`, `lander`) |
| `crates/lander/`       | Permissionless batch/blob construction, proof trait and durable L1 submission         |
| `crates/abci/`         | The ABCI++ application of the Etna PoS chain                                          |
| `crates/protocol/`     | Shared helpers; `shasta` and `FixedKSigner` serve raiko2                              |
| `crates/rpc/`          | Engine API and JWT helpers                                                            |
| `crates/bindings/`     | Generated Anchor contract bindings, kept for protocol's anchor builder (raiko2)       |
| `crates/test-harness/` | Docker devnet (anvil, alethia-reth, CometBFT) and calldata admission fixtures         |
| `script/`              | Maintenance scripts (binding generation)                                              |
| `tests/`               | The integration test entrypoint and the test JWT secret                               |

## Committees and fresh-genesis runtime

The ABCI runtime follows the V1 specification with native stock CometBFT 0.40.0
`secp256k1eth` validator keys. Its 48-byte chain ID is `etna-` plus the unpadded base64url
Keccak digest of the ABI-encoded `ETNA_COMET_DOMAIN_V1` tag, full L1 and L2 chain IDs,
Inbox address and uint48 generation. P2P node keys are separate Ed25519 identities.
Only fresh generation zero starts are supported.

For every epoch, `H(t)=1+tL` and `epoch(h)=floor((h-1)/L)` for positive heights.
For incoming epochs t>=1, `S(t)=H(t)-2` and `D(t)=H(t)-3`.
The switch block derives the next committee using the committed D(t) anchor number as its
cutoff (at least L1_0), but authenticates its complete registry proof under S(t)'s own anchor
root. The outgoing committee signs S(t) and S(t)+1; Comet activates the returned updates
at H(t). At L=3 the first switch is block 2 and activation is block 4. With the default
L=900, D(1)=898, S(1)=899 and H(1)=901.
Eligible keys must be unique; selection orders stake descending with set-key tie breaking.
There are no heartbeat or registered-recipient rules.

The seven-word `ETNA_PARENT_ANCHOR_V1` hash binds the L2 chain ID, registry, vpUnit,
sMin, nMax and direct unsettled limit U. U is a multiple of six in 6..=65536, independent of L.
The schedule requires L>=3 and L+1 within uint48. Registry entries are
`[ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1]`; committee records contain
`[targetEpoch, cutoffL1Block, checkpointIndex, setRoot, totalPower]`.

Every consensus handler enforces the 124000-byte raw ExecutionBlock RLP limit. Etna Engine
builds include `max_block_bytes=Some(124000)`, including singleton FI probes, and the build
fingerprint includes that bound. The header fee-sharing byte is 100. A proposer chooses its
beneficiary locally; validators validate the certified block's beneficiary without a registry
recipient binding. Historical state error -38100 stops the node with durable fatal evidence. A hash-canonical
unsupported L1 header makes ProcessProposal reject without a fatal latch; FinalizeBlock waits
for parser support. Transient dependency failures remain retryable.

Envelope version remains 6; the app protocol version is 1 and its state schema is 13.
Older state shapes and deployment domains are refused, with no implicit migration. Never reset
signed state or Comet history to force startup. The app persists `last_comet_hash` with each
commit and writes `comet-hash-{height}.json` first; retain this history for checkpoint trust.
`fatal-evidence.txt` survives restarts and records the first safety failure for operator repair.

The aligned dependencies are protocol commit `23963b68e43b4cbeaf83113eeb61fbc1bddb4c46`
and EL `b046734a0a47b17ca66c33ccbc7c9087cbbf9b1e`. Fresh genesis must set fee sharing to 100,
start the EL and verify block 0, then initialize Inbox and authenticate its finalized L1 record,
including generation origin slot 290. Genesis generation is always zero. The CLI, lander and
pinned contract artifacts share this format; the deployment runbook requires a fresh chain.
This supports dummy-proof devnet operation, not deployed-state migration or a real validity guest.

## Forced inclusion

A user can submit one exact transaction byte string to the Etna Inbox with `saveForcedInclusion(bytes)`.
The maximum is 8192 bytes; empty and undecodable bytes are admissible input but cannot count as
valid inclusion. The admission event records the raw bytes. Queue entries commit their Keccak-256
hash and pack a uint48 L1 timestamp followed by a uint48 L1 submission block; the high
bits are unused. Admission fees grow with unsettled entries and are not stored in this metadata.
The app tracks `forced_cursor`, and each landing advances the Inbox's queue head to its
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
  cap. Matching canonical low-fee-cap transactions may also be included. Ordinary transactions
  may follow; matching a later transaction is insufficient.
- Nonempty witness bytes always match the proven hash and byte limit, including historical
  envelopes that redundantly carry them. RLP decoding bounds the bytes before copying them.
  A due entry absent from position zero must authenticate its preimage before any skip decision;
  omitted bytes cannot authorize skipping a nonempty admission.
- An entry absent from position zero cannot be consumed early. Once due, bytes that fail
  canonical eligibility (including malformed encoding/signatures, unsupported blob transactions
  or excess gas limits) consume the entry as an ineligible-byte skip. A low or zero fee cap
  alone does not make otherwise eligible bytes ineligible; they still require the completed
  singleton check, including when their cap is below the current base fee.
- Due eligible bytes absent from position zero require the shared Engine skip checker. It
  builds the singleton on the supplied authenticated parent and requires the result to preserve
  the consensus-derived header and retain no transaction. ABCI supplies its committed-parent
  context; the lander additionally checks that parent's numeric canonical hash before probing.
  Filtering or zk-gas overflow can yield the empty result and authorize the skip. RPC errors,
  missing history, malformed results and a signature-recovery failure in a transaction the block
  claims to include never authorize consumption.

At or after due, a block that neither includes the entry nor completes an authenticated valid
skip is invalid; it cannot retain the cursor.

At most one queue entry is consumed per block. Included and ineligible-byte cases require no
singleton build. `ProcessProposal`, cold `FinalizeBlock` and the lander share the classifier and
skip checker. Prepare reclassifies its final candidate after an ordinary fallback, reusing a
successful singleton confirmation only when the decision and its build context are unchanged.
Host Engine checks establish current dummy-proof behavior; an independent validity proof guest
remains future work. `land` sends consumed L1 forced-inclusion fees to the configured protocol
treasury. L2 base fees and tips are credited immediately to the proposer-selected beneficiary.

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

Proposal selection prefers the newest usable finalized anchor (L1 `finalized` less
`l1_finality_extra_depth`, never below the committed parent anchor). Acceptance checks the
proposal's fixed derived block timestamp instead. A moved anchor must still be canonical and
final in the validator's own L1 view, but its distance from that view's current finalized head is
not checked. Advancing that head alone cannot expire an accepted proposal, including for a
validator receiving it for the first time or replaying it without an acceptance cache; otherwise a
locked block re-proposed unchanged in a later round might never gather more than 2/3 of the
voting power.

For the current authenticated queue head, a block timestamp at or beyond
`entry.timestamp + D + maxAnchorAge` implies that the entry is due at the block's anchor.
The FI rules then require inclusion or an authenticated skip; they process at most one queue
head per block. Later queued entries are processed only after they become the head.
A proposer whose newest usable anchor is too old relative to the derived block
timestamp proposes nothing and records `anchor_too_old`. Finality must resume before a proposer
can use a sufficiently recent anchor; a delayed entry never expires.

This is a bound in block time, with no promised fixed wall-clock FI deadline. Etna does not enable
proposer-based timestamps (PBTS): BFT time is the voting-power-weighted median of the precommit
timestamps included in the block's last commit. The normal liveness assumption is less than one
third Byzantine voting power, reasonably synchronized honest clocks and continued L1 finality,
L2 consensus, execution and settlement progress. The age rule alone does not guarantee that
block timestamps track wall-clock time; a coalition above the normal Byzantine threshold can
manipulate the commit's median time. Neither the deterministic age bound nor continuing block
production establishes a wall-clock inclusion guarantee against every coalition below two thirds.

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

| Flag                                    | Env                    | Description                                                                    |
| --------------------------------------- | ---------------------- | ------------------------------------------------------------------------------ |
| `--abci.addr`                           | `ABCI_ADDR`            | Socket CometBFT's `proxy_app` connects to (default `tcp://127.0.0.1:26658`)    |
| `--fee-recipient`                       | `ABCI_FEE_RECIPIENT`   | Required explicit local execution beneficiary; receives all base fees and tips |
| `--data-dir`                            | `ABCI_DATA_DIR`        | Directory of the persisted app state (`abci-state.json`), required             |
| `--chain-config`                        | `ABCI_CHAIN_CONFIG`    | Optional TOML overriding the built-in chain parameters (devnet only)           |
| `--l1.http`                             | `L1_HTTP`              | The operator's own L1 node, HTTP(S) only, required (see L1 node requirements)  |
| `--l1.archive`                          | `ABCI_L1_ARCHIVE`      | Optional archive RPC for fixed committee registry snapshots only               |
| `--l2.http`                             | `L2_HTTP`              | alethia-reth's JSON-RPC endpoint, required                                     |
| `--l2.auth`                             | `L2_AUTH`              | alethia-reth's Engine API endpoint, plain `http` only, required                |
| `--jwt.secret`                          | `JWT_SECRET`           | Engine API JWT secret file, required                                           |
| `--l1.timeout`                          | `ABCI_L1_TIMEOUT`      | Deadline of one L1 read, in seconds (default 3)                                |
| `--engine.timeout`                      | `ABCI_ENGINE_TIMEOUT`  | Deadline of one Engine API or EL RPC call, in seconds (default 5)              |
| `--elsync.timeout`                      | `ABCI_ELSYNC_TIMEOUT`  | Deadline of an EL sync to a trusted head, in seconds (default 600)             |
| `--prepare.timeout`                     | `ABCI_PREPARE_TIMEOUT` | `PrepareProposal` deadline in seconds (default 2), below `timeout_propose`     |
| `--metrics.enabled` / `.addr` / `.port` | `METRICS_*`            | Prometheus metrics server (default off, `0.0.0.0:9090`)                        |
| `-v`, `--verbosity`                     | `VERBOSITY`            | Log level, 0 = error … 4 = trace (default 2); `RUST_LOG` overrides it          |

The four timeouts accept 1 to 3600 seconds. The L2 chain id is read from `--l2.http` and
selects the built-in chain parameters. Only the internal devnet (chain id `167001`) has Etna PoS
parameters so far; on other chains `abci` refuses to start. The `--chain-config` TOML uses the
snake_case names of `abci::ChainParams` (for example `unsettled_limit = 3600`); absent keys keep their
built-in values. The removed `d_max`, `margin_v`, `heartbeat_window` and `fee_vault` keys are
rejected. `block_gas_limit` stays fixed by the built-in EL parameters. The required
`--fee-recipient` overrides the local TOML beneficiary. Full uint256 L1 identity is read from
`--l1.http`; an explicit `l1_chain_id` TOML value must match, while an omitted value uses the RPC
identity. L2 IDs are checked without truncation and values above uint64 are explicitly refused;
all nodes must use the authenticated seven-word committee configuration. The Inbox address
is also required in persisted state and checked again on restart. `InitChain` requires the exact
L1_0 genesis time, canonical representable CometBFT consensus parameters, and an EL genesis
header whose hash and state root match H* and S*.

A safety halt (a committed block or the execution engine contradicting the app state) exits the
process with status 2; investigate before restarting. Liveness halts (anchor not final, anchor
older than `maxAnchorAge`, back-pressure, committee discovery unavailable, a due forced
inclusion event unavailable) keep the process running and CometBFT rounding; the ABCI query
`/status` reports the head, epoch, generation and halt reason. A superseded generation is
permanent. A proposal whose anchor shows a higher Inbox `recoveryGeneration` is refused and trust
is revoked while the process keeps running. A decided block carrying such an anchor, or a startup
or signer-session trust check finding a different generation, is a safety halt. Restart only
under the new generation.

`PrepareProposal`, `ProcessProposal` and `FinalizeBlock` enforce the raw 124000-byte
execution-block RLP bound. Each Engine build requests that same bound. Public landing data
contains execution blocks only; original consensus envelopes remain private authenticated inputs.

### `lander`

The permissionless lander collects native Comet blocks/certificates, authenticates historical
committee witnesses and execution/FI rules, and submits `land(input, leaves, proof)` blob
transactions. `DummyProofProvider` returns exactly `0x00`; use an explicitly compatible dummy
verifier on a disposable devnet. This does not establish validity-proof soundness.

Required inputs are `--l1.http`, `--l2.http`, `--l2.auth`, `--jwt.secret`, `--comet.http`, a
`--signing-key` file containing a hex key, an exclusive `--data-dir`, `--max-blocks`,
`--max-blobs`, all three positive fee caps and `--sidecar`. `--l2.reward-recipient` and the
`lander-claim` command are removed and rejected. Execution fees go directly to each block's
locally selected beneficiary; consumed FI fees go to the protocol treasury.

```sh
taiko-client lander --l1.http http://l1-node:8545 \
  --l2.http http://localhost:8545 --l2.auth http://localhost:8551 --jwt.secret ./jwt.hex \
  --comet.http http://localhost:26657 --chain-config ./chain.toml \
  --signing-key ./lander.key --data-dir ./lander-data \
  --min-blocks 60 --max-blocks 120 --max-batch-wait 300 --max-blobs 6 --sidecar eip7594 \
  --max-fee-per-gas "$LANDER_MAX_FEE_PER_GAS" \
  --max-priority-fee-per-gas "$LANDER_MAX_PRIORITY_FEE_PER_GAS" \
  --max-fee-per-blob-gas "$LANDER_MAX_FEE_PER_BLOB_GAS"
```

The deployed Inbox must permit the selected maximum. A batch must fit a complete K=6 segment,
so `--max-blocks` must be at least 6; endpoints are grid heights. `--max-blobs` is exactly 6.
`--min-blocks` defaults to 1 and `--max-batch-wait` to 30 seconds, but neither permits a partial
segment. The minimum is 1 through `--max-blocks`; wait expiry or consensus pressure can flush
an available complete prefix below it. Batches can cross epoch transitions. Pressure uses the
checkpoint in the decided tip's authenticated anchor and direct `unsettled_limit`, not an
unauthenticated newer checkpoint. Switch urgency does not change committee activation timing.

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

Public DA is exactly `0x06 || zlib(rlp([ExecutionBlock,...]))`. Original envelopes, native
headers/commits, evidence, 65-byte signatures and witnesses remain private. Import and journal
restoration enforce the raw 124000-byte execution bound, Unzen shape and authenticated
projection. Pinned stock zlib, bounded decompression/private protobuf budgets and the existing
BlobCoder protect capacity; eip4844/eip7594 select sidecar formats for the same payload.
Native certificate verification retains complete committee proofs, strict greater-than-two-thirds
quorum and stock secp256k1eth semantics, including the 301-member library regression.

The eight-field LandInput binds parent/last height, terminal EL/Comet hashes and state root,
L1 reference, terminal FI cursor and active committee cutoff. The 21-word/672-byte
`TAIKO_ETNA_LAND_V1` statement additionally binds the full chain IDs, Inbox/registry, generation, checkpoint,
committee config and immutable cut leaves. The journal separately checks the current deployment
implementation and immutable getters before signing or sending. The reference authenticates ancestry without changing individual execution anchors.
The terminal committee uses genesisCutoff in epoch zero and the authenticated committed D(t)
anchor thereafter; pending S(t) updates activate only at H(t).

`lander-state.json` uses schema 13 and is protected by `lander.lock`. Old schemas and legacy
claim-directory markers reject intact. Signed bytes and blob sidecars are durably written before
broadcast. For an original range (p,h] and competing checkpoint p<=c<h, the original input,
leaves, proof, blobs, nonce and signed bytes remain unchanged. At c>=h, never-broadcast work
can finish; possibly-broadcast work remains pending until canonical receipt/nonce reconciliation.
An ambiguous send or dropped transaction never authorizes recycling its nonce.

Canonical ordinary reverts stop once after clearing the spent job. A gas-exhausted landing may
rebuild once with fresh estimation; repeated gas exhaustion on the same checkpoint stops.
Use one active lander per signing account and preserve journals across restarts. Keep unpruned
Comet blocks/commits, EL ancestry/execution state and historical L1 headers/proofs/registry
snapshots. Real proving, governance recovery and automatic operator nonce repair remain excluded.

### `abci-genesis`

Reads the Ethereum-final genesis record from L1 and writes the CometBFT `genesis.json`
(48-byte `etna-` deployment-domain chain id, initial height 1, native validator set and the genesis
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
effective stake of at least `max(s_min, vp_unit)`, unique eligible native keys, at most
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
every member's compressed 33-byte public key and voting power, total voting power, and the committee
config hash required by Inbox initialization.
Committee 0 uses this explicit genesis cutoff; later committees use the committed derivation parent anchor. A
cutoff after the L1 node's `finalized` block is refused, as the initialization fixes it irreversibly,
and so is a cutoff at which no entry is eligible: initializing with it would leave the chain
without validators. `--json` prints each member's effective stake as a decimal string. Its top-level fields are
`record_hash`, `committee_config_hash`, `record`, `members`, `proving_block`. The record has
`target_epoch`, `cutoff_l1_block`, `checkpoint_index`, `set_root`, `total_power`; each member has
`pubkey`, `eff_stake`, `power`. Logs go to
standard error.

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

   Keep the registered validator's existing `priv_validator_key.json` and its existing
   `priv_validator_state.json` together in a private signer directory outside the Comet home
   and outside every separate Comet container mount. Preserve the state across every restart; never
   initialize, reset or replace it to recover consensus. The local key created by `cometbft init`
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
   priv_validator_laddr = "unix:///absolute/path/run/comet-sign.sock" # mandatory for validators

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

5. **Start the app**, then the **guarded signer and CometBFT**. The app must listen first:

   ```sh
   taiko-client abci --l1.http http://l1-node:8545 \
     --l2.http http://localhost:8545 --l2.auth http://localhost:8551 --jwt.secret ./jwt.hex \
     --data-dir ./abci-data --fee-recipient "$L2_FEE_RECIPIENT"
   ```

   ```sh
   # Build the host helper with Go 1.27.2 (also packaged as /app/etna-signer in the image).
   just signer
   # In another terminal, supervise the signer and stock Comet together.
   ETNA_COMET_HOME="$PWD/cmt" ETNA_APP_STORE="$PWD/abci-data" \
     ETNA_SIGNER_BIN="$PWD/target/etna-signer/etna-signer" \
     ETNA_PRIV_KEY=/private/validator/priv_validator_key.json \
     ETNA_PRIV_STATE=/private/validator/priv_validator_state.json \
     ETNA_CHAIN_ID="$(jq -r .chain_id genesis.json)" \
     bash script/start_etna_validator.sh
   ```

   The host supervisor requires Bash and Python 3.11+ (`tomllib`); the production image
   includes Python, the signer, this supervisor and a native build of unmodified stock
   Comet v0.40.0 source `0880b4d378f347ab16e54ec677ff50d803f37d62`. The pinned Go1.27.2
   builder uses the official `make build-linux` target with explicit target architecture,
   default build tags and readonly modules; source identity and a clean tree are checked.
   The official v0.40.0 ARM64 image contains an x86-64 Comet executable, so it is not used
   as the binary source. CI checks every bundled ELF against the declared matrix platform
   before publishing the multiarch tag; emulated execution alone is insufficient.
   Its default entrypoint remains the app; the validator supervisor container uses
   `command: ["python3", "/app/script/etna_validator.py"]` with the same environment below.
   Run the app in a separate container sharing the private app-store socket and persisted
   state mounts; do not expose the socket outside the pod. The image runs supervisor/signer
   as root and drops the stock Comet child to UID/GID10001 (`ETNA_COMET_UID/GID`). Prepare
   its persistent home and signer-listener directory owned by10001; keep registered key/HRS
   root-owned0600 in a private directory outside that home. Put the Unix signer listener
   directly inside `<comet-home>/run`, not the app's0700 private store. This prevents the Comet
   child from reading registered signing secrets. Supervisor needs root with SETUID, SETGID,
   KILL and DAC_OVERRIDE capabilities: the root signer must connect to the Comet-owned Unix
   socket. Comet runs as UID10001 with zero effective capabilities. Persistent Comet volume
   ownership is prepared separately. HRS
   and its parent must be writable for atomic replacement, even when the key is read-only.
   The supervisor requires
   `priv_validator_laddr`, existing signing files outside the Comet
   home, and matching genesis chain ID. UNIX is preferred; `tcp://` uses CometBFT's official
   encrypted SecretConnection, never raw signer protobuf over TCP. A nonvalidator full node
   may run stock Comet without the helper, using an unregistered local identity.

   Every Comet signer transport opens a new local trust session through the app's private
   mode-0600 `<data-dir>/checkpoint-trust.sock`. PubKey and Ping work while closed so the ABCI
   handshake can proceed. Each proposal, prevote or precommit (including nil votes, locked
   blocks, retained proposals and already signed retries) needs a fresh bounded CheckSession
   response with the exact opaque session and verified chain ID, Ready and committed checkpoint
   evidence. Unavailable/malformed control, proof/history failure or a stale session denies
   signing without touching FilePV. The helper locks the existing state against a second
   helper process. No local signing fallback exists in the validator startup recipe.

   The helper atomically publishes private `signer-denial.json` observations: sequence zero
   establishes the current session; a positive sequence records a refused or timed-out
   signing request. The supervisor's private `observe` request neither rearms the session
   nor authorizes signing. A denial triggers bounded stop/reap and a fresh signer/Comet pair
   only after exact deployment identity and private trust return Ready. This also handles a
   signer timeout while the app stays Ready. The new transport initially closes trust;
   PubKey/Ping and safe catchup remain available while signing waits for revalidation.
   Halted trust, stale generation/domain, signer exit, or unexplained Comet exit creates
   `<data-dir>/validator-supervisor.halted` and leaves the supervisor alive and quiescent.
   The latch survives container restart: `restartAlways` cannot reopen the signing path.
   A Comet EOF following observed control/trust loss also recovers after private Ready;
   a repeated configuration failure with continuously Ready trust stays latched. Exact app
   shutdown revocations wait for a fresh app incarnation; they never authorize signing.
   Repair the underlying cause and review durable evidence before explicitly removing it.
   Missing registered signing state fails closed; startup never creates replacement HRS.
   Before spawning a new local Unix pair, after the old children are reaped, the supervisor
   atomically moves a disconnected socket from `<comet-home>/run` into a fresh supervisor-owned
   0700 `capture` directory inside a held private `.etna-transport-*` directory, and verifies
   the selected inode before deleting it. A nonempty outer directory is refused; the fresh
   inner capture destination is created only under its protected parent.
   Live listeners, symlinks, non-socket files, changed inodes and uncertain connection errors
   fail closed. A raced replacement is preserved as `capture/endpoint` in that private directory;
   restoring its original name never removes this protected backup. Both directories after
   successful cleanup are retained too, avoiding unsafe name-based directory deletion.
   This adds two small directories per stale-socket restart; capture directories are
   always newly created and prior outer contents are never reused. Optional manual cleanup requires the validator fully stopped and each directory
   inspected; preserve mismatch evidence for repair. No automatic garbage collector runs.
   Signing state, WAL, app history, the private trust socket and the durable halt latch remain
   untouched.

   On restart, CometBFT replays missing app commits while signing stays closed until the app
   authenticates its own latest finalized-L1 checkpoint and links it to durable committed
   state. A Comet-only restart/reconnect rearms trust. An app-only restart changes the session;
   the first stale signing request is denied and rearms a new closed session. Keep WAL,
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
  anchor (one per L1 epoch) in the last `unsettled_limit` heights before each `D(t)`. An L1
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
- The app checks alethia-reth against its committed head at CometBFT's first handshake `Info`
  (once per process) and syncs alethia-reth to that head if it lacks it. A later CometBFT restart
  under a running app does not repeat that `Info` check. On a validator it reconnects
  `etna-signer`, and every new trust session re-checks the committed head before signing reopens.
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

### Checkpoint trust

- Every app start and every signer session start closed. The app pins one block of its own L1
  `finalized` view and authenticates the Inbox's latest checkpoint there: the L1 header and
  state root, exact account and storage proofs, canonicality, generation and both the checkpoint EL hash and slot-285 Comet hash.
  While closed, `/trust` and `/status` report `trust_ready = false`, `syncing = true` and no
  `trusted_consensus_head`; `trust_target` shows the pinned checkpoint and `trust_reason` why
  trust is still closed. Info, InitChain and historical Finalize/Commit replay continue
  normally meanwhile.
- Trust opens only after both target hashes match durable committed history. A committed head already
  above the target must prove its complete `parentHash` ancestry down to the target; finding
  the target in alethia-reth is not enough. Readiness opens after the matching state is durable
  and the latest finalized checkpoint has been read again; if that checkpoint is now higher,
  catch-up continues to it.
- A missing proof, missing history or transient I/O keeps trust closed and retries. An
  authenticated contradiction is a safety halt, and so is malformed or unverifiable data from
  the own L1 node or alethia-reth (a header whose hash or number does not match, a proof that
  fails against its state root, a second read returning a different hash for the same finalized
  number), because the node cannot tell it apart from forgery.
- Within one process the highest authenticated target survives across sessions and is never
  lowered by a lagging L1 answer; after a restart, the loaded state's authenticated anchor is
  the initial floor. Once trusted, ordinary advances of the L1 finalized head never expire an
  accepted proposal and are not a block-validity rule.
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

- `just unit` runs all unit tests and the `native_cli` process tests, then protocol
  tests without default features and the abci doctests. No docker needed. It builds only those
  targets, and without extra arguments runs lander's library tests in one `cargo test` process,
  which loads the KZG trusted setup once instead of once per test.
- `just test` runs the serial Docker integration scenarios in `crates/abci/tests`,
  `crates/lander/tests`, `crates/test-harness/tests` and `bin/client/tests`. ABCI scenarios cover single validator,
  anchor finality, restart and lost-state replay, epoch switch with and without landing, back-pressure, generation
  bump, calldata inclusion, invalid-byte skips, canonical skips, and unavailable-history
  retry/recovery, plus an L1 finality stall that pauses and resumes L2. The history test emulates
  the source-backed unavailable-build RPC shape through a delegating Engine adapter; it does not
  actually prune Reth state. Lander scenarios cover actual Inbox blob
  transactions, cross-epoch batching, four native validators with ordinary and forced
  transactions, 100% beneficiary fees, protocol-treasury FI fees, epoch transition, dummy
  0x00 landing, signer timeout recovery and offline catchup with retained HRS/history,
  execution-DA replay, permissionless overlap races,
  verifier rejection, a pending L1 reference crossing the BLOCKHASH/EIP-2935 boundary, stock
  CometBFT collection, and actual-CLI SIGKILL/SIGTERM restarts, minimum/timeout batching, and
  pressure/epoch flushes; runner and store unit tests cover receipt reorgs and journal restarts.
  Each scenario boots its own devnet through the docker CLI (anvil as L1, alethia-reth,
  CometBFT), with phases that need the same history sharing one, so they run one at a time; the
  suite takes about ten minutes. Extra
  arguments go to `cargo nextest run`, e.g. `just test restart` runs one scenario. Pull requests
  skip the slowest scenario, the L1 finality stall, whose halt-and-resume rule unit tests cover;
  `just test-full` runs every scenario, as CI does on main, nightly and on manual dispatch.
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
  rules, epoch switch, the four-validator native acceptance flow, and lander CLI SIGKILL/SIGTERM restarts.
  This fixed recipe accepts no arguments. Use `just test` for targeted subsets or output options.
- `just runtime-image-test IMAGE linux/arm64` (or `linux/amd64`) smoke-tests the actual Linux runtime composition, native
  bootstrap, Comet UID isolation and unchanged HRS without a Rust rebuild. Build the
  `runtime-tools` Docker target with repository-root context first. Multiarch final image CI
  remains required before deployment. The smoke requires an explicit platform and checks
  Comet, signer and, in a release image, client ELF architecture before child startup.
- `just verify` is the complete merge gate: Go signer race tests, supervisor process tests, formatting, strict clippy, fast tests, committed
  artifact reproduction, and all Docker scenarios (`just test-full`). Smoke is an iteration aid and never replaces
  this gate. After each coherent code change batch, run `just fmt && just clippy-fix` and targeted
  tests; run the complete gate once on the final change batch.

Regenerate lander ABI/deployment fixtures only when their inputs change, with
`script/gen_lander_artifacts.sh /path/to/taiko-mono-at-pinned-protocol-revision`.
The script requires protocol HEAD `23963b68e43b4cbeaf83113eeb61fbc1bddb4c46` (also the
`PROTOCOL_REVISION` in `crates/lander/src/contracts.rs`),
installs pnpm dependencies before Foundry, builds `EtnaInboxBootstrap`, the Inbox, registry and
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
