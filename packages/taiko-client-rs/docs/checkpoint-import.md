# Offline landed checkpoint import

`taiko-client abci-import` builds three fresh stores at a selected L1-landed global height. Use it when you have the generation's **original stock genesis**, a complete consensus/app package, and an independently obtained offline EL state dataset at that exact height. The command never downloads an execution snapshot, imports signing authority, creates a registered key, resets HRS, or copies a consensus WAL. An installed checkpoint may be older than the latest finalized admission target. Only normal ABCI checkpoint authentication opens a live session.

## Inputs

Use absolute canonical paths (including resolved parents; on macOS, for example, use `/private/tmp/…` rather than its `/tmp` alias). Input files must be regular, singly linked files. Place the output under an existing protected parent, owned by the controller or root and not group/world writable. Do not use an existing app, Comet or EL home as a destination. Keep all participating services quiesced when acquiring an offline dataset. For an EL you own, stop and reap the process first, then create an independent offline copy of **only** `db/mdbx.dat` and `db/database.version` under a dedicated effective datadir. A filesystem snapshot with the same guarantees is also suitable. Do not delete a source writer lock, copy files while the source is changing, or hardlink mutable databases. The importer refuses an input containing `db/lock` and acquires the sibling Etna ownership lease.

The private schema-1 profile is JSON, mode 0600. Use the persistent `goleveldb` backend in the stock template. Use lowercase stock TOML keys in every section. Ordinary dotted TOML table syntax is supported; a quoted key containing a literal dot or a case-folding alias is refused before normalization. A validator template also requires `install.signer_binary` set to the canonical native guarded signer executable. Omit that field for full nodes. All object keys are strict. `archive` is needed only by export; `install` is needed by prepare/install. The same exact private profile must be supplied to both prepare and install. Example for a local Etna devnet (replace addresses, paths and chain IDs with your deployment):

```json
{
  "schema": 1,
  "l1_chain_id": "0x7a69",
  "l2_chain_id": 167001,
  "l1_http": "http://127.0.0.1:8545",
  "chain_config": "/srv/etna/config/app-chain.toml",
  "archive": {
    "comet_http": "http://127.0.0.1:26657",
    "l2_http": "http://127.0.0.1:9545",
    "comet_genesis": "/srv/etna/source/comet/config/genesis.json",
    "comet_helper": "/app/etna-comet-import"
  },
  "install": {
    "el_source": "/srv/etna/offline-db-at-600",
    "el_chain": "/srv/etna/config/el-genesis.json",
    "comet_config": "/srv/etna/config/full-node.toml",
    "comet_binary": "/usr/bin/cometbft",
    "comet_helper": "/app/etna-comet-import",
    "el_helper": "/app/etna-el-import",
    "el_binary": "/app/alethia-reth",
    "devnet_etna_timestamp": 0
  }
}
```

The chain config opens the original committee configuration. The operator's own finalized L1 endpoint must supply the proofs/headers, including historical ones. The L1 endpoint's full-width chain ID must match the profile; for export, the EL archive's RPC chain ID must match as well. For recovery, add `"recovery_bootstrap":"/…/recovery-bootstrap.json"` inside `archive`, alongside the original recovery Comet genesis. The EL chain JSON always identifies the **original deployment**, even when the recovery origin is nonzero. Use the reviewed Alethia binary built at revision `6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4`, the stock v0.40 helper, and the matching EL helper. The Reth version banner is not an Alethia revision attestation. `devnet_etna_timestamp` selects the same devnet override as the original node; omit it when the pinned chainspec already fixes activation.

To run Comet with a separate UID, configure numeric `comet_uid` and `comet_gid` together in `install`. A root controller can assign the **new stock subtree only** to that identity. All ancestors above the operation root must be searchable by that identity. Metadata is private; only the root and ready parent permit search. The launcher and app must share a PID namespace and see the same protected canonical mounts and native client executable inode. A separate container must share these explicitly so the launcher can verify the live app’s kernel peer credentials. Configure the same UID/GID on the validator supervisor. Never use a writable shared parent for component leases.

## Export and preserve a package

```sh
taiko-client abci-import export --profile /srv/etna/config/export.json \
  --height 600 --out /srv/etna/archive/cp-600
```

Export reserves a small protected sibling directory named `.<output-name>.etna-export`. It holds a process lease and an inode-bound work tree while the archive is assembled. On interruption, rerun the same command to reclaim the private frame and native verifier spools before rebuilding. The output is a directory containing exactly `package.json` (typed schema-1 import metadata) and `blocks.jsonl` (one ascending native block, its own commit and original signing keys/powers per line). Do not add files. Export walks backward through the required evidence, committee and anchor context, reads only the boundary header below that window, and spools bytes to disk, then independently authenticates the result against own finalized L1 and verifies the stock input. It never asks for the successor of the selected landing or executes any old block. The archived EL header RPC must expose `debug_getRawHeader` privately. Do not expose the node's debug API publicly.

The source app normally prunes validator-state preimages below its checkpoint floor. To preserve them before pruning, start that app with `--checkpoint-archive-dir /srv/etna/grid-archive` (existing protected directory). Each committed grid preimage is fsynced into `<keccak256(UTF8(generation-qualified-Comet-chain-ID))>-<global-height>.bin` before the state commit. Equal retries are allowed; conflicting contents halt the write. Use the raw file for a previously pruned height:

```sh
taiko-client abci-import export --profile /srv/etna/config/export.json \
  --height 600 --out /srv/etna/archive/cp-600 \
  --validator-state /srv/etna/grid-archive/0xACTUAL_DOMAIN_DIGEST-600.bin
```

Without the raw preimage, authenticated original blocks/commits/signing sets, or required header history, export fails. A downloaded/archived package is still only a candidate. Keep original history for independent full replay; these bounded stores do not reconstruct the entire consensus prefix.

## Prepare, install, inspect, retry

```sh
taiko-client abci-import prepare --profile /srv/etna/config/import.json \
  --package /srv/etna/archive/cp-600 --root /srv/etna/operations/import-600
taiko-client abci-import install --profile /srv/etna/config/import.json \
  --root /srv/etna/operations/import-600
taiko-client abci-import status --root /srv/etna/operations/import-600
```

The root archives the original package and binds its contents, local input hashes, helper executables, chain config and paths. Prepare verifies actual local account/storage/code leaves against the authenticated header state root. Install reads the retained package again under own finality, requires matching independent stock reports, installs the verified native EL header/history baseline, and starts the pinned native EL with private regular and Engine IPC sockets. Each connection verifies the kernel-reported PID and user of the actual child before sending a request. It checks head `s`, finalized `q` from the inherited anchor and actual state availability, then reaps the node. The app state, terminal sidecars, immutable recovery bootstrap where applicable, and stock genesis/InitialHeight remain in the original domain. At the fixed origin it uses normal genesis initialization, without inventing a stock block/commit. At a fixed recovery origin the R proof supplies the new generation’s finality fence. The old terminal block’s historical anchor is retained for recovery validation only; the first new-generation block must carry its own anchor at or after R.

The only published runtime is `ROOT/ready/{app,comet,el}`. It appears by one atomic rename after fsync and a fresh own-finalized generation/landing check. A stopped or killed operation may leave a protected unpublished stage. A private lifetime pipe closes on controller death; the process guardian then terminates and reaps its owned helper or test EL. Failed native subprocess diagnostics remain in the unpublished stage until retry. Rerun the same operation with the same inputs and profile. A retry refuses a live lease; stop any surviving externally managed or orphaned process that demonstrably belongs to that operation before retrying. Never adopt a PID from a file, reuse a different package in the same root, or delete a signing state file. An unrelated or mismatched stage is not overwritten. A safety contradiction creates durable `ROOT/halted.json` (export uses a sibling halt record) and exits 2. Bad publisher bytes and missing input fail without latching; investigate safety evidence rather than blindly retrying. Status is local and nonmutating: **`live_trust` is always false**, including installed and halted operations.

## Start the installed node

Start the app and its bound native execution node in one foreground process. Select the same canonical root and private profile used for installation and the normal proposed-block fee recipient.

```sh
taiko-client abci-import run-app --root /srv/etna/operations/import-600 \
  --profile /srv/etna/config/import.json --fee-recipient 0x0000000000000000000000000000000000000001
```

Use `--el-http-port PORT` if a separate loopback EL reader is needed. Keep this listener private and gate any external RPC route on the running app’s checkpoint readiness. The app uses two private Unix sockets throughout its lifetime. The guardian announces its actual child PID on an inherited descriptor. Each normal or authenticated RPC connection checks that kernel peer identity before sending bytes. External Engine URLs and JWTs cannot redirect the imported app’s forkchoice or payload writes. A normal restart checks the retained execution floor and current committed state and resumes from the current head. Use `--checkpoint-archive-dir PATH` to preserve subsequent grid preimages. The installed Comet template supplies the ABCI listener.

After the app has started, set `ETNA_APP_STORE=ROOT/ready/app` and `ETNA_COMET_HOME=ROOT/ready/comet`. Run `python3 /app/script/start_etna_full_node.py` for a full node with an unregistered identity. For a validator, run the guarded supervisor with the existing external registered key, authoritative HRS, authority directory, and explicit domain/generation settings. See the [authority enrollment and rollback procedures](governance-recovery.md).

Imported signers publish denial events in a fresh private per-incarnation directory under the app store. Keep registered key/HRS, authority storage and WAL outside diagnostic routes. The supervisor preserves uncertain files and refuses a diagnostic override pointing outside the imported app store.

The launchers authenticate the client and native Comet executable against the installation. They check a fresh live app/EL response, all three database installation keys, their roles, normalized config, and filesystem identities before starting stock. Comet receives a clean environment and the checked canonical home. Configure listeners and peers in the template before prepare. Imported validators use only the bound signer executable. Container adapters and command or environment override JSON are rejected. Stop Comet/the supervisor first, then stop `run-app` so it can reap its execution process. Start `run-app` before restarting Comet. Keep the controller binaries, paths, private mounts and installation identities stable across restart.

After an older import, stock P2P must reach the latest finalized target and the app must authenticate it under its own L1 before readiness/signing. Inspect the running app's `/status` or `/trust` separately; imported nodes include `execution_floor` in `/status`. `execution_floor=s` is the oldest independently installed state: there is no pre-`s` transaction, receipt, body or FI trial history in these stores. Real later blocks create normal execution history. Keep post-floor state available for FI replay. Package export covers app/consensus inputs only; public EL snapshot distribution and Unzen are outside this workflow.

For sizing, use the [measured local profiles](checkpoint-import-resources.md). The offline
helper and the owned native EL use 64 MiB MDBX growth increments for writable import
storage. A donor may already have a much larger sparse extent; provision for its actual
copy, scratch files, complete native window and installed indexes. The source file stays
offline and immutable. Fresh stock stores are rebuilt under the unpublished stage. The
installer closes the three databases, flushes all of their files and directories, checks
the reopened stock contents, and flushes again before handing them to publication.

External signer enrollment belongs to source bootstrap. Stop and reap the old validator
before starting its imported successor with the same external key, authority and HRS
paths. An older checkpoint requires an available peer suffix to the latest target.
Preserve the stopped source WAL and fully replayed archive separately for historical
proving and recovery investigation.
