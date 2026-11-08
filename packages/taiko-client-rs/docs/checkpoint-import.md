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
  --height 600 --out /srv/etna/archive/cp-600
```

- `--l1.http` is your own L1 node. It must serve the finalized Inbox proofs and the historical L1 headers the checkpoint needs. `--chain-config` is needed only to override the built-in chain parameters (devnet).
- `--comet.http` and `--l2.http` are an archive node of the selected generation. Export reads only Comet blocks, commits and validator sets, and EL headers through `debug_getRawHeader`. Keep that debug API private.
- `--comet-genesis` is the generation's original stock `genesis.json`. For a recovery generation, also pass `--recovery-bootstrap /…/recovery-bootstrap.json`.
- `--out` must not exist. Export writes into a private `.<name>.export-*` directory beside it, authenticates the result against your own finalized L1 exactly as `import` does, then renames it to `--out`. An interrupted export leaves only that private directory; delete it and rerun.

The package contains exactly `package.json` (schema-1 metadata) and `blocks.jsonl` (one native block, its own commit and its signing keys and powers per line). It holds no EL state. Export walks backward only as far as the required evidence, committee and anchor context, and never executes an old block.

The source app prunes validator-state preimages below its checkpoint floor. To keep them, start that app with `--checkpoint-archive-dir /srv/etna/grid-archive` (an existing directory). Each committed grid preimage is written there as `<keccak256(UTF8(generation-qualified Comet chain id))>-<height>.bin` before its state commit. Pass the file for an already pruned height:

```sh
taiko-client abci-import export … --height 600 --out /srv/etna/archive/cp-600 \
  --validator-state /srv/etna/grid-archive/0xACTUAL_DOMAIN_DIGEST-600.bin
```

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

- `--el-chain` is the EL chain JSON of the **original deployment**, even when the recovery origin is not zero.
- `--comet-config` is the stock `config.toml`. It is copied verbatim to `ready/comet/config/config.toml`. Its `db_backend` must be absent or `goleveldb`. Set listeners, peers and any `priv_validator_laddr` here.
- No input may lie inside `--root`.

`--root` is dedicated to this import: every run replaces `ROOT/stage`. Run `import` as root or as the owner of ROOT, which it must chmod when it publishes; another user fails only at that last step. `import` creates ROOT and any missing parent with mode 0700, so create the parents yourself first, searchable by the Comet UID (see Run the imported node). It then runs these steps:

1. Takes the `ROOT/import.lock` flock. A busy lock is reported as unavailable.
2. Refuses a root with `ROOT/halted.json`.
3. If `ROOT/ready` exists, it only reports it (a lost acknowledgement).
4. Otherwise it discards any earlier `ROOT/stage` and starts a new private one.
5. Authenticates the package against your own finalized L1 (DATA-5.4-2): the original genesis and generation, the landing at the selected height, and every block, commit, link, validator set and envelope of the window. The frames it verifies are written, as it verifies them, to the stage's stock directory. The package is not read again.
6. Installs the stock Comet stores (`etna-comet-import`), or at the generation origin only the original `genesis.json`.
7. Installs the EL store once from `--el-source` (`etna-el-import`), with every authenticated header from the header floor through the checkpoint.
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
- `authenticated checkpoint contradiction` (exit 2): your own L1 and data it authenticates contradict each other. One example is a landed window block that breaks a block rule; no other publisher can supply different bytes for it. The import writes `ROOT/halted.json`, keeps the halted run's stage as evidence and refuses every rerun of that root. Investigate; do not just delete the file. Because your own L1 authenticated the contradiction, another package of the same landed window cannot clear it: check your L1 node first, then escalate it as a possible bad landing. Leave the halted root in place and import any other checkpoint into a new root.

```sh
taiko-client abci-import status --root /srv/etna/import-600
```

`status` only reads. It reports `absent`, `interrupted` (an unpublished stage; an import may also still be running), `ready` or `halted`.

## Run the imported node

Keep the three stores in `ROOT/ready`, or move them together while every process is stopped, under parents the Comet UID can traverse. They are ordinary stores:

1. **EL.** Run the alethia-reth binary built from the pinned revision in the README's [Fresh deployment](../README.md#fresh-deployment) section, the revision `etna-el-import` is built against and names in its receipt; the Reth version banner does not attest an Alethia revision. Run it on `ready/el` with the original chain and with `--http.api eth,net,debug`. `abci` reads pruned imported ancestors through `debug_getRawHeader`; keep that API private. Keep the state at the checkpoint s, and the parent state of every block executed after it, readable (DATA-5.4-6): the app checks the state at s at every start, and a pruned one makes every restart wait as missing data; replaying a canonical forced-inclusion skip builds on the parent's state, and a parent state that is gone for good is a safety halt (RECOV-8-13). Run it without `--full` or `--minimal`, which both prune history, and without account- or storage-history pruning (`--prune.account-history.*`, `--prune.storage-history.*` or the same settings in a `[prune]` config section).
2. **App.** Run plain `taiko-client abci --data-dir ROOT/ready/app` with the usual `--l1.http`, `--l2.http`, `--l2.auth`, `--jwt.secret`, `--abci.addr` and `--fee-recipient` flags. It starts from the installed state and checks once that the EL serves the block and state at `execution_floor`. Add `--checkpoint-archive-dir PATH` to preserve later grid preimages.
3. **Comet.** Run stock `cometbft start --home ROOT/ready/comet`. Or set `ETNA_COMET_HOME=ROOT/ready/comet` for `start_etna_full_node.py`, or that and `ETNA_APP_STORE=ROOT/ready/app` for the validator supervisor. Both start Comet like on any other store, as `ETNA_COMET_UID:ETNA_COMET_GID` when set (the image sets 10001:10001; set both or neither). Before that, `chown -R ETNA_COMET_UID:ETNA_COMET_GID ROOT/ready/comet`, as for any Comet home. ROOT and `ROOT/ready` are traverse-only, so that UID reaches `ready/comet` and nothing else in the root. Run the launcher itself as the user that ran `import` (root included): it takes its writer lease `ready/.comet.etna-owner.lock` beside the Comet home and refuses a `ready` owned by anyone but itself or root. The launchers pass their environment to Comet, which also reads configuration from its environment (Viper), so start them without Comet environment overrides. `import` checks only `db_backend` in `--comet-config` and copies everything else unchanged, so write the config in Comet's own lowercase keys.

Comet syncs blocks from s + 1 over stock P2P, and the app executes each through normal FinalizeBlock and all of its checks (DATA-5.4-6). After an older import, Comet must first reach the latest finalized target, and the app must authenticate it against your own L1, before it reports ready. `/status` shows `execution_floor`. There is no transaction, receipt, body or FI trial history before it in these stores.

Signer state is never imported (DATA-5.4-7). A registered validator resumes with its registered key, the same chain_id's HRS and its domains log, all outside the import root, once its own node has matched the target. Stop the old validator before starting the imported one with the same key. See the [signer state rules](../tools/etna-signer/README.md#refusal-matrix-and-exit-codes).

An imported app store is a new app store: the old one may hold the only app-store evidence that the HRS is uncertain. Never delete or replace an app store that holds a `validator-supervisor.halted` latch or a `validator-supervisor.signer-unsafe` record. Before running a validator for a chain_id on the imported store, check the old app store for a signer-unsafe record or a latch for an unsafe signer exit or a killed signer, and the domains log's directory for a `<chain_id>.signer-unsafe` marker. Any one of them is uncertain signing state, resolved through governance (RECOV-8.2-3), never by a new store (ACCEPTANCE §7.7). The supervisor and the signer both refuse the marker. See [Supervisor restarts and latches](../tools/etna-signer/README.md#supervisor-restarts-and-latches).

For sizing, use the [measured local profiles](checkpoint-import-resources.md). Provision space for the EL copy, the helper scratch, the stock window and the installed indexes. Keep the original history separately for full replay and investigation: these bounded stores do not reconstruct the consensus prefix.
