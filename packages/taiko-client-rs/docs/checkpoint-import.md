# Offline landed checkpoint import

`taiko-client abci-import` builds fresh app, stock Comet and EL stores at a global height that L1 has landed. It has three commands:

1. `export` collects a portable package from an archive node.
2. `import` authenticates the package and installs the three stores.
3. `status` reports on an import root.

The result is `ROOT/ready/{app,comet,el}`: ordinary stores that the ordinary `abci`, EL and Comet processes run. Nothing is downloaded, no signing authority is imported, no key is created, HRS is never reset and no consensus WAL is copied (DATA-5.4-7).

Trust model: the package publisher is untrusted. Your own L1 node, your own EL dataset and the local operator are trusted. A package is only a candidate until `import` has authenticated it against your own finalized L1.

## Export a package

```sh
taiko-client abci-import export --l1.http http://127.0.0.1:8545 --l2.chain-id 167001 \
  --chain-config /srv/etna/config/app-chain.toml \
  --comet.http http://127.0.0.1:26657 --l2.http http://127.0.0.1:9545 \
  --comet-genesis /srv/etna/source/comet/config/genesis.json \
  --comet-state-dir /srv/etna/stock-state-at-599 --comet-helper /app/etna-comet-import \
  --height 600 --out /srv/etna/archive/cp-600
```

- `--l1.http` is your own L1 node. It must serve the finalized Inbox proofs and the historical L1 headers the checkpoint needs. Export also reads from it the fallback key list whose hash s's anchor proves: `getFallbackKeys()` at the anchor's L1 block, else the Inbox's `FallbackKeysUpdated` logs, scanned back from that block. Each L1 read has its own 30 s deadline, and the reads as a whole have none. `--chain-config` is needed only to override the built-in chain parameters (devnet).
- `--comet.http` and `--l2.http` are an archive node of the selected generation. Export reads only Comet blocks, commits and validator sets, EL headers through `debug_getRawHeader`, and the `EtnaStaking` proxy's `eth_getProof` at s, so that EL must still serve the state at s. Keep that debug API private.
- `--comet-genesis` is the generation's original stock `genesis.json`. For a recovery generation, also pass `--recovery-bootstrap /…/recovery-bootstrap.json`.
- For a checkpoint above the fixed origin, `--comet-state-dir` must contain the `state.db` of an independent stock CometBFT v0.40.0 node at exactly **s − 1**. Take it as described in [Stock snapshot for the producer check](#stock-snapshot-for-the-producer-check). The verifier opens the snapshot read-only and reads its stock `State` (`Store.Load()`), the state immediately after s − 1; when s − 1 is the generation origin, that is the state after InitChain. It binds the snapshot to header(s)'s chain, predecessor and app hash, and compares `Validators` and `NextValidators` with the package's preimage: every member's key, power and priority, and the stored proposers (DATA-5.4-8). Export refuses a snapshot at another height, naming both heights. It refuses and logs an error on a validator-state difference, and publishes nothing. A later state, a historical `LoadValidators` or `/validators` answer, an app's copy or a state DB installed from a checkpoint package cannot serve as this independent evidence (SYNC-9-5c).
- `--out` must not exist. Export writes into a private `.<name>.export-*` directory beside it, authenticates the result against your own finalized L1 exactly as `import` does, then renames it to `--out`. An interrupted export leaves only that private directory; delete it and rerun.

The package contains exactly `package.json` (schema-3 metadata, including the validator-state preimage after s − 1 that header(s)'s app_hash commits, the staking proof at s and the fallback key list s's anchor proves; see [The signing sets after s](#the-signing-sets-after-s)), `execution_headers.jsonl` (the linked EL headers from the header floor through w, one per line and at most 262,145, outside `package.json`'s 256 MiB bound) and `blocks.jsonl` (one native block, its own commit and its signing keys and powers per line). An import above the fixed origin only needs the origin header when it is part of the required EL ancestry or window boundary. Beyond the staking proof at s, the package holds no EL state. Export walks backward only as far as [the window](#the-window) requires and never executes an old block.

### The window

The package's consensus window (w, s] is the shortest suffix of the current generation that ends at s and contains (DATA-5.4-2):

- every height x ≤ s still within either stock evidence age limit at s: `s − x ≤ 16` or `Time(s) − Time(x) ≤ 3 min`, by the authenticated Comet header times (START-10-21). A height exactly at either limit stays in;
- the latest block at or below s that carries an anchor witness.

The window stops at the origin (w = o) or at the first excluded height w. The package then carries w's Comet header as `boundary_header`: w + 1's LastBlockID links it, and it must show both limits strictly exceeded (`s − w > 16` and `Time(s) − Time(w) > 3 min`). w is never below o. Export writes the shortest such window. Import accepts any longer authenticated window and reports one that misses a required height as `checkpoint material unavailable`.

### The signing sets after s

Import installs the sets that sign s + 1 and s + 2 as a node that executed s holds them:

- **s + 1**: the set header(s)'s `next_validators_hash` commits, from the authenticated preimage. s − 1 decided it, and the package holds no state of s − 1, so `/signers` reports only what the import can tell: at s = o + 1 the origin record's fallback keys; otherwise, against the anchor of s − 1, which the window holds, the fallback key list that anchor proves (reason `min_total_stake_max` under a minimum total stake of 2^256 − 1, else `imported`), or else the candidate taken at s − 1 with `total_stake` null. A set other than the origin keys at o + 2, or other than the list under the maximal minimum, halts the import as an `authenticated checkpoint contradiction`.
- **s + 2**: decided at s under 4.3, as FinalizeBlock(s) decides it. The package's staking proof proves the candidate snapshot (`snapshotHeight`, `snapshotTotalStake` and the 128 seat records) in s's post-state under the stateRoot of s's EL header, whose hash s's slot-285 record holds; a proven-absent staking account holds zero words. The candidate signs when it is usable under the `minTotalStake` s's anchor proves; otherwise the package's fallback key list signs, each key at power 1, recorded without the snapshot's total stake under a `minTotalStake` of 2^256 − 1, as FinalizeBlock(s) records it. That list must hash to the `fallbackKeysHash` s's anchor proves, whichever source wins, and the app keeps it. A proof that does not verify under that root, or a list with another hash, only makes the package an invalid candidate.

The validator state after s is the preimage's state advanced once by the updates FinalizeBlock(s) returns: the difference between the sets for s + 1 and s + 2. The set that signs s, which s + 1's LastCommit lists, is the preimage's current set. The `missBitmap` of a window block depends on its parent's key-to-seat words, which the package does not hold, so import checks no bitmap at or below s; the landings' proofs cover them, and FinalizeBlock checks it from s + 1 on.

Every Comet block has an empty evidence list (CONS-3.1-10). A window block whose header commits evidence halts the import as an `authenticated checkpoint contradiction` once the landed chain authenticates it; one that does not link to the landed chain, or evidence bytes its header does not commit, only make the package an invalid candidate.

Export reads the preimage for s − 1 from the source app's `/val_state/<s−1>` query. The source app keeps validator-state preimages only from one height below the checkpoint its committed anchor proves, and prunes older ones. To keep them, start that app with `--checkpoint-archive-dir /srv/etna/val-state-archive` (an existing directory). The preimage of every committed height is written there as `<keccak256(UTF8(generation-qualified Comet chain id))>-<height>.bin` before its state commit. For a checkpoint whose s − 1 is already pruned, pass the file for s − 1 (599 for s = 600):

```sh
taiko-client abci-import export … --height 600 --out /srv/etna/archive/cp-600 \
  --validator-state /srv/etna/val-state-archive/0xACTUAL_DOMAIN_DIGEST-599.bin
```

### Stock snapshot for the producer check

Stock CometBFT cannot be told to stop at a height, and a landing can end at any height. So take the snapshot first and choose s from it:

1. Stop your regular lander before anything else. By default it lands any decided block within 30 seconds (`--min-blocks 1`, `--max-batch-wait 30`), so while it runs it would land past the snapshot before you land s. Keep its key and journal (`--data-dir`) for step 5.
2. Stop the independent stock node: a node of this generation whose own CometBFT committed these heights, not one installed from a package.
3. Copy its `data/state.db` directory into a new directory, for example `/srv/etna/stock-state/state.db`, then restart the node.
4. Read the snapshot's height x from the copy:

   ```sh
   etna-comet-import snapshot-height --comet-state-dir /srv/etna/stock-state
   # {"chain_id":"…","last_block_height":599}
   ```

5. Land exactly s = x + 1 with a one-shot lander run on the regular lander's key and journal:

   ```sh
   taiko-client lander … --land-to 600
   ```

   If the journal still holds a landing the regular lander already sent, the run settles that landing first; one that ends exactly at s counts as this landing. Otherwise the run submits one batch from the latest checkpoint to s, waits until s is decided, and exits 0 once the landing is confirmed like any other landing. It exits nonzero without landing in these cases:

   - the latest checkpoint is already at or above s, for example because that earlier landing ended past s;
   - s lies more than the batch cap above the latest checkpoint (the lower of `--max-blocks` and the Inbox's `maxBatchBlocks`);
   - another lander reaches or passes s first.

   In any of these cases, take a new snapshot from step 2, with the regular lander still stopped.

6. Restart your regular lander.
7. Once your own L1 has finalized the landing, export s = 600 with `--comet-state-dir /srv/etna/stock-state`.

Keep the snapshot, and the application's archived preimages, for every checkpoint you plan to publish.

## Prepare the EL source

Import copies the EL state at the checkpoint from a **stopped** EL datadir: `--el-source` must hold `db/mdbx.dat` and `db/database.version` at exactly that height. Stop and reap the alethia-reth that owns it first, and run nothing on it until the import finishes. The helper copies the files and never writes the source. A copy torn by a live writer is never installed: it fails the state-root check (an invalid candidate) or leaves a database the helper cannot read (unavailable). A filesystem snapshot of a stopped node also works.

## Import

```sh
taiko-client abci-import import --l1.http http://127.0.0.1:8545 --l2.chain-id 167001 \
  --chain-config /srv/etna/config/app-chain.toml \
  --package /srv/etna/archive/cp-600 --root /srv/etna/import-600 \
  --el-source /srv/etna/stopped-el-at-600 --el-chain /srv/etna/config/el-genesis.json \
  --el-helper /app/etna-el-import --comet-helper /app/etna-comet-import \
  --comet-config /srv/etna/config/full-node.toml
```

- `--el-chain` is the operator-selected EL chain JSON of the **original deployment**, including when Etna starts at a nonzero S or the selected generation is a recovery. The helper derives the original block-zero identity from this configuration; the Inbox's start hash H\* identifies the block at S separately.
- `--comet-config` is the stock `config.toml`. It is copied verbatim to `ready/comet/config/config.toml`. Its `db_backend` must be absent or `goleveldb` and its `db_dir` absent or `data`, the stock default: the imported stores are goleveldb databases in `<home>/data`. Set listeners, peers and any `priv_validator_laddr` here.
- No input may lie inside `--root`.

`--root` is dedicated to this import: every run replaces `ROOT/stage`. Run `import` as root or as the owner of ROOT, which it must chmod when it publishes; another user fails only at that last step. `import` creates ROOT and any missing parent with mode 0700, so create the parents yourself first, searchable by the Comet UID (see Run the imported node). It then runs these steps:

1. Takes the `ROOT/import.lock` flock. A busy lock is reported as unavailable.
2. Refuses a root with `ROOT/halted.json`.
3. If `ROOT/ready` exists, it only reports it (a lost acknowledgement).
4. Otherwise it discards any earlier `ROOT/stage` and starts a new private one.
5. Authenticates the package against your own finalized L1 (DATA-5.4-2): the original genesis and generation, the landing at the selected height, and every block, commit, link, validator set and envelope of the window. The frames it verifies are written, as it verifies them, to the stage's stock directory. The package is not read again.
6. Installs the stock Comet stores, or at the generation origin only the original `genesis.json`. `etna-comet-import` is the offline store tool CONS-3.1-1 permits: it writes the stock block and state databases and an empty evidence database with Comet stopped and no signer connected, never runs consensus or signs, and reads the stores back through stock lookups before anything is published. At every window height, s included, `LoadBlockMeta`, `LoadBlockCommit` and the validator lookup must return the authenticated header and time, that height's own commit and its validator set; s's own commit is installed under the block-commit lookup as well as the seen commit, and every full validator set stored passes stock `ValidateBasic` with a member as its proposer (DATA-5.4-3). See its [README](../tools/etna-signer/cmd/etna-comet-import/README.md).
7. Reads the original runtime chain identity with `etna-el-import chain-identity --chain PATH --chain-id N`, then installs the EL store once from `--el-source`, with every authenticated header from the header floor through the checkpoint. Both operations use the same operator-selected `--el-chain` and pinned runtime chainspec. The install requires that block-zero hash and checks it again; imported metadata never selects it.
8. Installs the app store at the checkpoint, with its execution floor. At the generation origin it writes only the recovery bootstrap, if any: InitChain builds the origin state (DATA-5.4-1).
9. Makes `stage/ready` and ROOT traverse-only (0711), fsyncs them, and publishes `stage/ready` as `ROOT/ready` by one rename. `ready/app`, `ready/el`, the stage, `import.lock` and `halted.json` stay owner-only.

Each helper inherits the root lock and writes only into the stage. Its receipt must name exactly the authenticated window, state and header range. On success, `import` prints one JSON line, the same as `status`:

```json
{ "phase": "ready", "generation": 0, "execution_floor": 600 }
```

`generation` and `execution_floor` are `null` for an import at the generation origin, which has no app state until InitChain.

### Interruption, failure and `halted.json`

Rerun the same command after any interruption or failure. A rerun discards the unpublished stage and starts again, so stores from different attempts are never mixed (DATA-5.4-5). A rerun after success prints the published result again.

If a killed import left a helper running, that helper still holds `ROOT/import.lock`, and a rerun reports the root as busy until the helper exits. A large EL install can take minutes. Do not delete the lock file or the stage while the lock is held.

Errors:

- `invalid checkpoint candidate` (exit 1): the package or an input is wrong. Use another package or fix the input.
- `checkpoint material unavailable` (exit 1): something missing, a busy root, a local storage error or a helper failure. Helpers write their diagnostics to stderr. Fix the cause and rerun.
- `authenticated checkpoint contradiction` (exit 2): your own L1 and data it authenticates contradict each other. One example is a landed window block that breaks a block rule, such as one carrying evidence; no other publisher can supply different bytes for it. The import writes `ROOT/halted.json`, keeps the halted run's stage as evidence and refuses every rerun of that root. Investigate; do not just delete the file. Because your own L1 authenticated the contradiction, another package of the same landed window cannot clear it: check your L1 node first, then escalate it as a possible bad landing. Leave the halted root in place and import any other checkpoint into a new root.

```sh
taiko-client abci-import status --root /srv/etna/import-600
```

`status` only reads. It reports `absent`, `interrupted` (an unpublished stage; an import may also still be running), `ready` or `halted`.

## Run the imported node

Keep the three stores in `ROOT/ready`, or move them together while every process is stopped, under parents the Comet UID can traverse. They are ordinary stores:

1. **EL.** Run the alethia-reth binary built from the pinned revision in the README's [Fresh deployment](../README.md#fresh-deployment) section, the revision `etna-el-import` is built against and names in its receipt; the Reth version banner does not attest an Alethia revision. Run it on `ready/el` with the original chain and with `--http.api eth,net,debug`. `abci` reads pruned imported ancestors through `debug_getRawHeader`; keep that API private. Keep the state at the checkpoint s, and the parent state of every block executed after it, readable (DATA-5.4-6): the app checks the state at s at every start, and a pruned one makes every restart wait as missing data; replaying a canonical forced-inclusion skip builds on the parent's state, and a parent state that is gone for good is a safety halt (RECOV-8-13). Run it without `--full` or `--minimal`, which both prune history, and without account- or storage-history pruning (`--prune.account-history.*`, `--prune.storage-history.*` or the same settings in a `[prune]` config section).
2. **App.** Run plain `taiko-client abci --data-dir ROOT/ready/app` with the usual `--l1.http`, `--l2.http`, `--l2.auth`, `--jwt.secret`, `--abci.addr` and `--fee-recipient` flags. It starts from the installed state and, before it opens its ABCI socket and again at every later CometBFT handshake (the first request on each new set of ABCI connections), checks that the EL serves the block and state at `execution_floor`. Add `--checkpoint-archive-dir PATH` to preserve later preimages.
3. **Comet.** Set `ETNA_COMET_HOME=ROOT/ready/comet` for `start_etna_full_node.py`, or that and `ETNA_APP_STORE=ROOT/ready/app` for the validator supervisor. Both check the executable's digest against the deployment manifest (CONS-3.1-1) and delete the pending-evidence store (CONS-3.1-10) before they start Comet, and both start Comet like on any other store, as `ETNA_COMET_UID:ETNA_COMET_GID` when set (the image sets 10001:10001; set both or neither). Before that, `chown -R ETNA_COMET_UID:ETNA_COMET_GID ROOT/ready/comet`, as for any Comet home. ROOT and `ROOT/ready` are traverse-only, so that UID reaches `ready/comet` and nothing else in the root. Run the launcher itself as the user that ran `import` (root included): it takes its writer lease `ready/.comet.etna-owner.lock` beside the Comet home and refuses a `ready` owned by anyone but itself or root. The launchers pass their environment to Comet, which also reads configuration from its environment (Viper), so start them without Comet environment overrides. `import` checks only `db_backend` in `--comet-config` and copies everything else unchanged, so write the config in Comet's own lowercase keys. `import` writes no `config/node_key.json`: copy the node's existing key there before the first start. Validators accept inbound connections only from the node IDs they list, so a fresh key that stock Comet generates is refused until every peer lists its ID.

Comet syncs blocks from s + 1 over stock P2P, and the app executes each through normal FinalizeBlock and all of its checks (DATA-5.4-6). After an older import, Comet must first reach the latest finalized target, and the app must authenticate it against your own L1, before it reports ready. `/status` shows `execution_floor`. There is no transaction, receipt, body or FI trial history before it in these stores.

Signer state is never imported (DATA-5.4-7): the import runs with no signer connected, writes no key, HRS or WAL, and its completion grants no signing authority. A registered validator resumes with its registered key, the same chain_id's HRS and its domains log, all outside the import root, once its own node has matched the target. The imported stores are rebuilt stores, so RECOV-8.2-2's height floor applies: a key that has signed for this chain_id may sign again only above the last height H its HRS records, with no WAL or lock from H to replay. Run the imported node without the signer until it has committed H, so that the app's eligible height, the only height the signer signs, is above H. Stop the old validator before starting the imported one with the same key. If this key already has a logged state for this chain_id, move the domains log and the `<chain_id>.json` state with the key, byte for byte, as in the signer README's [Failover](../tools/etna-signer/README.md#failover) section; never run `init-state` for it and never create a fresh HRS (RECOV-8.2-1, RECOV-8.2-6). If this key has never signed for this chain_id, so no domains log anywhere lists it, run `init-state` once, with the old signer stopped. See the [signer state rules](../tools/etna-signer/README.md#refusal-matrix-and-exit-codes).

An imported app store is a new app store: the old one may hold the only app-store evidence that the HRS is uncertain. Never discard an old app store that holds a `validator-supervisor.halted` latch or a `validator-supervisor.signer-unsafe` record, nor a `<chain_id>.signer-unsafe` marker beside the domains log; keep them as evidence. Running on the imported store is fine once the checks below pass. Before running a validator for a chain_id on the imported store, check the old app store for a signer-unsafe record or a latch for an unsafe signer exit or a killed signer, and the domains log's directory for a `<chain_id>.signer-unsafe` marker. Any one of them is uncertain signing state, resolved through governance (RECOV-8.2-3), never by a new store (ACCEPTANCE §7.7). The supervisor and the signer both refuse the marker. See [Supervisor restarts and latches](../tools/etna-signer/README.md#supervisor-restarts-and-latches).

For sizing, use the [measured local profiles](checkpoint-import-resources.md). Provision space for the EL copy, the helper scratch, the stock window and the installed indexes. Keep the original history separately for full replay and investigation: these bounded stores do not reconstruct the consensus prefix.
