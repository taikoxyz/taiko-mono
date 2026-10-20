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
  parent; valid inclusion and ineligible-byte skips need no singleton build. At each switch height the
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
even when the last registry mutation is older. Snapshot entries are fully verified before base eligibility and lowest-bond-id pubkey
deduplication. The top `n_max` seats are then selected by stake before heartbeat filtering;
missing heartbeats leave those seats empty without backfilling from lower-ranked entries.
Committees 0, 1 and 2 retain their launch heartbeat exemption. A later committee keeps a seat
holder only if its heartbeat sequence is nonzero and its last heartbeat is at or after the start
of the heartbeat window before the one containing the snapshot.

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

The config hash binds ten ABI words under `ETNA_PARENT_ANCHOR_V5`: L2 chain id,
registry, `vp_unit`, `s_min`, `n_max`, `heartbeat_window`, recipient-bound committee encoding
version 2, `d_max` and `margin_v`. The opening is exactly 320 bytes.
The coordinated format is envelope v6, payload v6, V10 statement (21 words / 672 bytes),
journal schema 12, committee encoding version 2 and `APP_VERSION = 4`. State files must
carry that exact app version and all authenticated genesis, anchor and FI fields. Old app/config versions and structural formats
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
a recovery-generation bootstrap or an implicit replacement set. Governance recovery and the
recovery-generation bootstrap remain unimplemented; the supported deployment path is
new-genesis-only.

## New-genesis deployment order

Deploy the registry and register nonzero immutable L2 recipients first. Predict the Inbox proxy
CREATE address, export a constructor-resolved `L2FeeVault` runtime bound to that Inbox/L1 chain,
and install it at the canonical treasury with zero balance, alongside the explicit EIP-4788 roots
and EIP-2935 history runtimes. Set `BasefeeSharingPctg = 0`. Preserve canonical devnet genesis fields except alloc and the derived top-level
`stateRoot`, which must be omitted after changing alloc. Start the custom-genesis EL and verify its actual block-0 hash/state root
before initializing Inbox with those commitments. Keep the deployment wallet's nonce unchanged
between address prediction and deployment. Only after L1 initialization finality should
`abci-genesis` construct the CometBFT genesis. The deploy script always leaves the registry
unbound. Verify the authenticated config, EL genesis and intended node startup (prefer a first
finalized landing where practical), then have the registry owner explicitly call `bindInbox(inbox)`
once. This binding cannot be redirected; an unverified candidate can be replaced before binding
by repeating address prediction and genesis setup. Withdrawals fail closed until bound; registration,
consensus and landing can proceed. See the complete
[protocol deployment instructions](https://github.com/taikoxyz/taiko-mono/blob/08bcaca2cf764a9e951a9163e302849a016f7862/packages/protocol/contracts/layer1/etna/README.md#genesis-initialization).

The required [EL dependency](https://github.com/taikoxyz/alethia-reth/pull/251) is revision
`5d4d21ac472c024703082ba46c6eacfa3b8ec1bf`, image `us-docker.pkg.dev/evmchain/images/alethia-reth:sha-5d4d21a`,
verified manifest digest `sha256:85d23ce00bfe9e917bd3c327256d2c11cc05085a83c7afa33af8f11f50c8d495`.
It rebuilds the chainspec for an alloc-only canonical devnet override before computing block 0.
The genesis input/source hashes are indexed in `crates/test-harness/contracts/genesis.manifest.json`;
real runtime acceptance verifies immutable vault configuration, roots/history and fee movement.
The protocol dependency is [PR #22286](https://github.com/taikoxyz/taiko-mono/pull/22286); its exact
immutable revision appears in the artifact index below. This is new-genesis-only deployment.

## Genesis schedule bounds and pacing

Inbox initialization fixes `L1_0` (the initialization block) and `L = epochLenL2`, and the
configuration hash fixes the unsettled cap `U = d_max - margin_v`, so only a new deployment
corrects a bad value. `abci`, `abci-genesis` and the lander reject:

- `d_max <= margin_v` (`U = 0`): block 1 would already exceed the cap against the genesis
  checkpoint at height 0, so the chain could never produce it;
- `L < 3` or `L < U + 3`;
- `h_first(1) = L + 1` above `type(uint48).max`, the last height `land` accepts;
- `L1_0` above `type(uint48).max`, the last anchor number the `extraData` encodes; every
  anchor is at or above `L1_0`.

Only the first transition is range-checked; at practical values the `uint48` limits lie millions
of years ahead. The contract checks `3 <= L < type(uint48).max`. `U = 0` is already rejected by
`abci-committee-record` before deployment, but the schedule bounds are first checked by
`abci-genesis` after initialization, so check `L + 1` before deploying.

Pacing is the deployer's obligation, not a validity rule. Epochs place no floor on the anchor:
a block's anchor only has to be at or after its parent's and at most `maxAnchorAge` older than
the block, so the L2 block rate is not tied to L1's. Back-pressure paces settlement: L2 pauses
(`back_pressure`) while `U` blocks are unlanded, so choose `U` above the number of blocks
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
  cap. Matching canonical low-fee-cap transactions may also be included. Ordinary transactions
  may follow; matching a later transaction is insufficient.
- Nonempty witness bytes always match the proven hash and byte limit, including historical
  envelopes that redundantly carry them. RLP decoding bounds the bytes before copying them.
  A due entry absent from position zero must authenticate its preimage before any skip decision;
  omitted bytes cannot authorize skipping a nonempty admission.
- An entry absent from position zero cannot be consumed early. Once due, empty, malformed,
  noncanonical or low-fee-cap bytes consume the entry directly as an ineligible-byte skip.
  The declared execution fee cap must reach `FI_MIN_EXEC_FEE_CAP = 1 gwei` (`gasPrice` for
  types 0/1, `maxFeePerGas` otherwise) to require a singleton check. This classification
  does not depend on the live base fee or reject a matching canonical inclusion.
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
remains future work. `land` pays the consumed L1 forced-inclusion fees to the statement-bound
`feeRecipient`, the lander's sending address. The batch's base-fee reward is recorded in a receipt
and paid separately on L2 through `L2FeeVault.claim` to `l2RewardRecipient`.

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
the ten-word contract configuration does not commit these fields; changing them requires a
coordinated protocol/built-in update. `d_max` and `margin_v` are committed, so a chain may set
its own; every node and lander of that chain must use the values its Inbox configuration hash
opens with. The authenticated Inbox address
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

`PrepareProposal` and `ProcessProposal` also refuse a block that could not land on its own: one
whose execution block, zlib-compressed as payload V6 compresses it, plus a 1,024-byte header allowance
exceeds 776,168 bytes (six landing blobs less 4 KiB of payload framing). This landing capacity
guard keeps every decided block landable; it is a liveness guard, not a validity rule, so
`FinalizeBlock` does not re-check it. The allowance covers the published header prefix (at most
768 bytes) and the framing of the lander's single-block fallback, which compresses the execution block
exactly as the guard does (see payload V6 below).

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
the anchor number or state root committed in an L2 header. V10 binds the Inbox, registry, both
chain ids, generation, checkpoint, committee configuration, terminal block/root, blobs, FI cursor
before/after, L1 fee recipient, L2 reward recipient, exact batch basefee amount and terminal active committee snapshot. Committees are
independently derived from authenticated historical snapshots; starting-set hints are not authority.

`LandInput.activeCommitteeSnapshot` names the committee active at the terminal height according to
`schedule.epoch_of(height)` in the implemented normal schedule. Epoch zero uses `genesisCutoff`;
every later epoch uses the L1 anchor in its authenticated derivation parent `D(t) = H(t) - 3`.
At `S = H(t) - 2` and `S + 1`, the incoming committee is still pending, so those terminal blocks
retain the outgoing cutoff. This also applies when a batch starts or ends partway through an
epoch. A batch ending at `H(t)` or
`H(t) + 1` uses the incoming committee's cutoff; the epoch number alone does not freeze that
cutoff across successive landings. The validity proof must authenticate the actual terminal
signing committee's provenance; neither the reference block, terminal anchor nor pending
committee can substitute for it. A future governance recovery that replaces a signing committee
within an epoch must prove the replacement's provenance and specify its re-emission schedule; that
recovery path and its bootstrap are unimplemented. Restore validation checks the
cutoff against committed ancestry and retained committee provenance even if the digest is
recomputed. Schema 10 journals are rejected intact, including their outstanding signed nonce.
The receipt remains ten words and its batch id is unchanged.

Before registry withdrawals can use the landed cutoff, its owner must call `bindInbox(address)`
once with the initialized Inbox that names that registry. `withdraw()` requires the existing
exit wait and `activeCommitteeSnapshot >= exitEffectiveL1`. The client never advances that
cutoff from the reference block or a pending committee.

Every block is held to the shared ABCI calldata classifier and asynchronous skip checker. Its
witness authenticates the cursor's entry under that block's anchor. Inclusion must match the exact
canonical bytes at position zero; a due invalid-byte skip consumes directly, while a due canonical
skip requires Engine evidence. Unavailable evidence retries without cursor advancement. The cursor
starts at the snapshot's Inbox head and advances by at most one per block. `forcedInclusionHead`
in `LandInput` is the cursor after the batch's last block.
`LandInput.feeRecipient` is the lander's sending address: `land` pays consumed fees to it and emits
`ForcedInclusionsConsumed`. The statement binding prevents copied landing transactions from
redirecting fees. The Inbox rejects a zero recipient (`ZeroFeeRecipient`); the lander treats that
revert as a configuration error. Envelope v6 carries at most 8192 FI skip-preimage bytes as private proving input.
Included transactions are published once in the execution block; omitted and skipped admissions
are not execution DA.

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

Blob payload V6 is 0x06 followed by one zlib stream of
RLP([[comet_header_proto_bytes, execution_block_rlp_bytes], ...]). Each second item is an
opaque byte string containing canonical RLP [full EL header, ordered EIP-2718 transactions].
V6 acceptance is fixed by the companion Inbox NatSpec/README, not by operator CLI values:

1. One to six ordered Kona-v0 blobs; chunks contain 1..130044 bytes, every nonfinal chunk is
   full, every field element's top two bits are clear, and all unused bits/bytes are zero.
2. Exactly one complete RFC1950 zlib stream after 0x06, without a preset dictionary,
   truncation, concatenated streams or trailing bytes. The inflated RLP list is at most
   67,108,864 bytes; each header/EL message byte string is at most 22,020,096 bytes.
3. Canonical exact RLP/protobuf/domain encoding. At height 1, the PUBLISHED Comet header omits
   last_block_id; Go's present empty BlockID (2a 02 12 00) is valid only in private raw_block.
4. Exactly N=lastHeight-parentHeight pairs, with 0<N<=the deployed Inbox maxBatchBlocks:
   both height sequences cover parentHeight+1..lastHeight, internal Comet and EL links match,
   the first EL parent is parentHash, and the terminal EL hash/root are lastBlockHash/lastStateRoot.
   Public recovery uses codec::decode_landed with an authenticated L1 range BEFORE importing
   any block. codec::decode alone supplies structural checks, without checkpoint authentication.
   Lower local max-blocks or memory budgets may refuse work for operational capacity; they cannot
   relax these guest validity rules. Recovery uses fixed protocol limits and the landed range,
   independently of the source node's collection settings.

Complete canonical CometBFT v0_38 headers remain published. Original envelope v6 bytes,
anchor/committee/forced witnesses, registry entries, skip preimages, evidence, commits and
signatures stay private proof inputs. Public decoding checks canonical framing and consecutive
Comet/EL links, not the omitted envelope against data_hash. Before publication and journal
restoration, the lander authenticates the original envelope's data_hash and matches its exact
execution projection. A real guest must additionally verify every certificate (ZIP215 Ed25519),
all original witness/committee/FI rules, execution, and the projection against the bound blobs.

Recovery assumes a sound real ZK landing proof, a finalized canonical L1 checkpoint and archived
blob bytes plus genesis/execution context. Those suffice to reconstruct the landed EL chain and
check its terminal hash/state root without historical original witnesses/signatures. Blob
commitments alone cannot recover unavailable data. This is not L1-only stock CometBFT state
bootstrap; unlanded blocks keep their full consensus/proving requirements. Dummy proofs do not
establish these soundness guarantees.

Batch sizing counts compressed execution DA; max-blobs remains six. Compression uses pinned
stock C zlib 1.3.2. A single-block fallback retries best compression, then full-flushes before
execution bytes so the capacity guard's bound holds independently of prefix alignment.
Larger prefixes retain bounded default-level work. Published decompressed DA and retained
private block/commit protobufs have separate 64 MiB budgets, alongside per-message limits,
the 32 MiB selection deflate budget and the final 256 MiB journal bound. Prefix selection stops
before either DA or private input budgets overflow; smaller DA cannot make private inputs
unbounded. Existing back-pressure, generation and contract maxBatchBlocks are unchanged.
The existing BlobCoder handles field-element encoding and multi-blob chunking.
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

2. **Initialize the CometBFT home** and install the genesis:

   ```sh
   cometbft init --home ./cmt
   cp ./genesis.json ./cmt/config/genesis.json
   ```

   Keep the registered validator's existing `priv_validator_key.json` and its existing
   `priv_validator_state.json` together in a private signer directory outside the Comet home
   and outside every Comet container mount. Preserve the state across every restart; never
   initialize, reset or replace it to recover consensus. The local key created by `cometbft init`
   is an unused random identity: do not replace it with the registered key. Only `etna-signer`
   may access the registered private key and signing state. Use separate users or container
   mounts so the Comet process cannot read that private signer directory.

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
     --data-dir ./abci-data
   ```

   ```sh
   # Build the host helper with Go 1.27.2 (also packaged as /app/etna-signer in the image).
   just signer
   # In another terminal, supervise the signer and stock Comet together.
   ETNA_COMET_HOME="$PWD/cmt" ETNA_APP_STORE="$PWD/abci-data" \
     ETNA_PRIV_KEY=/private/validator/priv_validator_key.json \
     ETNA_PRIV_STATE=/private/validator/priv_validator_state.json \
     ETNA_CHAIN_ID="$(jq -r .chain_id genesis.json)" \
     bash script/start_etna_validator.sh
   ```

   The host supervisor requires Bash and Python 3.11+ (`tomllib`); the production image
   packages the two binaries and uses the app entrypoint. The supervisor requires
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

A future guest must bind the V10 recipient and actual executed-header basefee sum, authenticate
the recipient-bound committee, and verify each beneficiary against the original proposer in
that block's certified CometBFT header under that height's committee, including retained blocks.
The lander-selected batch recipient is independent of these per-block proposer recipients.
It must also prove the terminal active committee snapshot from its authenticated derivation
header (or the explicit genesis cutoff), including outgoing selection at the switch boundary.
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

The own L2 endpoint must expose the intended ABCI-produced canonical executed chain. While the
EL remains at genesis, the command waits for its first committed execution block before decoding
Etna `extraData` or acquiring a receipt proof. Malformed nonzero execution headers remain fatal. Preparation
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
reverted). Before each actual send or rebroadcast, it simulates the original signed transaction
with its sender, calldata, gas, nonce and fees at that canonical snapshot and rechecks its hash.
A failed or timed-out simulation retains the journal without sending or replacing the transaction.
Simulation cannot guarantee success against state changes after the check. It refreshes a
contradictory moving view once. Another
payer can consume the reward first: authoritative canonical claimed state returns AlreadyClaimed,
retains any original transaction, and stops broadcasting. This does not assert that our transaction
succeeded; a revert selector alone is never sufficient authority.

Included is the end state. Etna L2 blocks are final once CometBFT commits them, so the command
does not wait for a later L1 landing to cover the claim block. A recovery that rewinds L2 can drop
the claim transaction: rerun the same command and key after any recovery. It reconciles the retained
signed bytes, reports Included again while the claim stays canonical, and otherwise rebroadcasts the
same bytes. Journals that recorded the former `Finalized` state load as Included.

`--rpc.timeout` (default 30 seconds, 1–3600) bounds individual calls and each reconciliation step.
Claim HTTP responses are capped at 2 MiB before JSON decoding, including chunked responses;
redirects are disabled. Direct typed capacity or unsupported-capability errors can stop the claim.
The existing `RpcL1Source` adapter erases some `eth_getProof` errors, including response-cap and
unsupported-capability failures, into sanitized retryable unavailability. Those failures can keep
retrying until the operator cancels and fixes the endpoint; the response allocation bound still
holds. Required history includes hash-pinned account/storage proofs and raw L1 headers. Missing
history cannot be bypassed by trusting events or claimed state.

Unsigned Prepared jobs can refresh their anchor proof before estimation. Roots validity depends on
whether the timestamp's modulo ring slot still stores that entry, not on a fixed wall-clock expiry.
Unsigned InvalidAnchorRoot estimates can refresh the proof. After signing, an InvalidAnchorRoot
simulation retries only the retained transaction, without broadcasting or refreshing its proof.
Retain the exact proof and raw bytes. Before archiving an old signed job and opening a new dedicated claim directory, establish
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
  transactions, cross-epoch batching without reward cutoffs, real EL/Comet basefee claims with
  genuine L1 account/storage proofs, replay rejection, claim-spend
  independence in the next batch, and a forced inclusion landing that
  pays its fee, permissionless races,
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
  rules, epoch switch, real L2 rewards claim/fee continuation, and lander CLI SIGKILL/SIGTERM restarts.
  This fixed recipe accepts no arguments. Use `just test` for targeted subsets or output options.
- `just verify` is the complete merge gate: formatting, strict clippy, fast tests, committed
  artifact reproduction, and all Docker scenarios (`just test-full`). Smoke is an iteration aid and never replaces
  this gate. After each coherent code change batch, run `just fmt && just clippy-fix` and targeted
  tests; run the complete gate once on the final change batch.

Regenerate lander ABI/deployment fixtures only when their inputs change, with
`script/gen_lander_artifacts.sh /path/to/taiko-mono-at-pinned-protocol-revision`.
The script requires protocol HEAD `08bcaca2cf764a9e951a9163e302849a016f7862` (also the
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
