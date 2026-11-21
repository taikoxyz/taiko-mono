# Offline stock Comet checkpoint installer

Build from `tools/etna-signer` using the module's pinned Go toolchain:

```sh
go build -mod=readonly -o etna-comet-import ./cmd/etna-comet-import
go test -race -mod=readonly ./...
```

Package this binary beside `etna-signer` in runtime
images. It is the offline store tool that CONS-3.1-1 permits for 5.4 checkpoint
import and for the certified first-block repair of CONS-3.1-9
([below](#first-block-repair)): it links the pinned CometBFT v0.40.0 module and GoLevelDB only to write
and read back the native stores, unforked (DATA-5.4-5). Run it with CometBFT
stopped and the signer disconnected. It starts no service, never runs consensus
or signs, loads no signing keys and never reads or writes FilePV state, signer
state or the consensus WAL (DATA-5.4-7). The official CometBFT executable starts
only on the published home.

```sh
etna-comet-import install --home /absent/stock/home \
  --stock-dir /stage/stock --app-hash 0x<appHash(ELHash(s), valStateHash(s)), 32 bytes> --n-max <n_max>
```

`--n-max` is the deployment's committee cap, which the caller authenticated
(the committee configuration hash covers it). It fixes the genesis
`block.max_bytes` (START-10-21), so the helper refuses a genesis whose
consensus parameters are not exactly the fixed ones for it.

The helper only installs. The Rust caller's `authenticate_import` is the one
window authentication (DATA-5.4-2). It authenticates the original genesis and
generation against its own finalized L1, proves the window is complete (a longer
window is accepted), and checks every native commit, embedded LastCommit, chain
link, validator set, envelope and EL link. It then writes the stock dir and runs
this helper. The helper does not check any of those again.

## Stock dir

`--stock-dir` holds three files written by the Rust caller:

- `genesis.json`: the original stock GenesisDoc, with Etna's fixed consensus
  parameters and its original positive `initial_height`.
- `validator-state.bin`: the raw canonical appendix-A encoding of the validator
  state after s. Rust derives it (DATA-5.4-3) from the package's preimage after
  s-1, which it has checked against header(s)'s app_hash, and the validator
  updates of block s. It is not the package's preimage.
- `blocks.jsonl`: one JSON object per line, ascending from w+1 to s:

```json
{
  "block": "0x<original stock block protobuf>",
  "commit": "0x<own-height commit protobuf>",
  "validators": [{ "key": "0x<33-byte compressed SEC1>", "power": 10 }]
}
```

Each line is one Rust `WindowBlock`. The helper rejects noncanonical protobuf
bytes, a block with evidence (every Comet block has an empty evidence list,
CONS-3.1-10; `authenticate_import` already halts on a landed one), a malformed
preimage, an unsupported genesis and a terminal height that differs from the
preimage height. These are decode checks, not authentication.

## Install

`--home` must not exist. The helper creates it with `config/genesis.json` (the
original bytes) and the stock `state`, `blockstore` and `evidence` databases
under `data/` (DATA-5.4-3):

- Stock `SaveBlock` stores each block, its successor's LastCommit as C:h and
  the terminal seen commit SC:s. The helper also writes s's own verified commit
  as C:s, which a stock node writes only when it saves s+1: stock evidence
  verification reads C:x for the signed header at every height it accepts, s
  included.
- Historical records use the pinned public ValidatorsInfo/ConsensusParamsInfo
  protobufs and stock key formats: full validator sets at the first height,
  at changes and at periodic 100,000-height save heights. Metadata never points
  below the window. Every full set written, and the three post-s sets, must pass
  stock `ValidateBasic`, store one of its members as proposer and survive a
  protobuf round trip unchanged; this holds for historical sets too, although
  their priorities do not affect consensus after s.
- The `evidence` database is created empty: the stock evidence pool starts
  with no pending or committed evidence.
- Stock `Bootstrap` installs the post-s state (DATA-5.4-4): LastBlockHeight s,
  the terminal BlockID and time, LastValidators for s, and Validators and
  NextValidators for s+1 and s+2 with the priorities and stored proposers of
  `validator-state.bin`, each proposer index resolved against the members in
  canonical set order; LastHeightValidatorsChanged s+2,
  LastHeightConsensusParamsChanged s+1, AppHash `--app-hash` (appHash of
  ELHash(s) and that state; the terminal header's AppHash commits s-1), the
  fixed LastResultsHash and the original InitialHeight.
  `SetOfflineStateSyncHeight(s)` follows.

The helper then fsyncs every file and directory, reopens the databases
read-only and checks them against a second read of the stock dir, before any
P2P is enabled (DATA-5.4-3): the state bytes; at every window height, s
included, the block, stock `LoadBlockMeta` (the authenticated header, time and
BlockID), stock `LoadBlockCommit` (that height's own commit, byte for byte; at s
also `LoadSeenCommit`), the validator lookup (keys and powers hashing to the
height's set) and the consensus params; every stored full set, against the
checks above; and an empty evidence database. Stock `LoadValidators(x)`
rebuilds a height without a stored set by advancing the last stored set by the
height difference, so calling it at every height would cost the window length
squared times the set size. The check calls it at every stored full set and at
every height still inside either evidence age limit at s, the only heights a
stock pool at s or later passes to it (the pool rejects expired evidence first),
and reads the same stored record at the other heights through stock
`LoadValidatorsFast`, which only skips the in-memory priority advance. It
fsyncs the tree and the parent directory once more before it reports success.

On success, stdout carries one JSON line:

```json
{
  "first_height": 100,
  "last_height": 120,
  "block_id": { "hash": "0x…", "parts": { "total": 1, "hash": "0x…" } }
}
```

The caller compares it with the window it authenticated. Exit 0 means the home
is installed and durable. Exit 1 means any failure, with the reason on stderr.
A failed or interrupted run leaves an unpublished partial home: the caller
discards its whole stage and reruns.

## Export checks

`abci-import export` runs `verify-export` to compare the package's
validator-state preimage for s − 1 with an independent stock node's stopped
`state.db` (DATA-5.4-8). That snapshot must be at exactly s − 1. Stock
CometBFT cannot stop at a chosen height, so the producer reads the height of
the snapshot it took and lands the checkpoint after it:

```sh
etna-comet-import snapshot-height --comet-state-dir /srv/etna/stock-state
```

It opens `state.db` read-only and prints one JSON line,
`{"chain_id":"…","last_block_height":599}`; a generation's state after
InitChain reports its `initial_height` − 1. `verify-export` reads the snapshot's
stock `State` through `Store.Load()`, the state immediately after that height
(at the origin, the state after InitChain), refuses a snapshot at another height
or of another chain or predecessor and names both heights. It then compares the
`Validators` and `NextValidators` sets member by member (key, power and
priority, in canonical order) and their stored proposers in full, and exits 2 on
any difference. A later state, a historical `LoadValidators`, `/validators` or an
app's copy cannot stand in for this snapshot (SYNC-9-5c). See the
[producer procedure](../../../../docs/checkpoint-import.md#stock-snapshot-for-the-producer-check).

## First-block repair

When a generation's `initial_height` is above 1, stock CometBFT v0.40.0 stops at
its handshake after a crash between saving the generation's first block and
saving that block's state: its state stays at height 0 and its handshake
requires the block store to be at most one block above it (CONS-3.1-9). The
operator procedure is in
[First-block repair](../../../../docs/first-block-repair.md).

```sh
etna-comet-import repair-first-block --home /stopped/comet/home \
  --backup /absent/backup --app tcp://127.0.0.1:26658 [--peer-export first-block.json]
etna-comet-import export-first-block --home /stopped/comet/home > first-block.json
```

`repair-first-block` needs CometBFT stopped (it opens `state.db` and
`blockstore.db` read-only first, which fails while CometBFT holds them), the
signer fenced, and the app (`taiko-client abci`) serving `--app`. In order, it:

1. copies `<home>/data` to `--backup` (absent, outside `data/`) and syncs the
   copy; the original block store with its seen commit, the state store, the WAL
   and the evidence store are never deleted;
2. writes a fresh store instance ID, `<home>/data/etna-store-instance` (32
   lowercase hex characters and a newline, mode 0600, by temporary file, rename
   and directory sync), so the signer fences through the last height its key
   signed (RECOV-8.2-2);
3. takes the first block and its seen commit from the block store, or, when the
   block store holds no block, from `--peer-export`, and checks them against the
   home's genesis: canonical protobuf, chain_id and `initial_height`, no evidence
   (CONS-3.1-10), and a commit with more than 2/3 of the genesis committee's
   power for the full BlockID (stock `VerifyCommit`). A peer export must certify
   its block. When the stored seen commit does not certify the stored block, a
   peer export of the same BlockID supplies the commit (`"source": "peer_commit"`);
   without one the repair stops. A certified peer block that differs from the
   stored one is a contradiction (exit 2);
4. asks the app for `Info` and, before it writes anything, refuses an app at
   another height (exit 2) and an app at the first height without a kept
   FinalizeBlock response carrying the app's own app hash. It then writes the
   block store: a peer's block through stock `SaveBlock`, or a peer's commit as the
   seen commit (stock's `SC:h` key, synced), from which stock consensus rebuilds
   its LastCommit. It applies the block with the stock handshake's own steps: at
   app height 0, InitChain from the genesis (the state is saved as stock saves it)
   and stock `BlockExecutor.ApplyBlock` against the app, so the app runs
   FinalizeBlock and Commit and executes the block on its EL; at the first height
   (the app committed before the crash), stock's mock-app replay of the kept
   response. A FinalizeBlock result that differs from a kept response is refused
   before stock saves anything (exit 2);
5. reads back the state (the first height and BlockID), the block store (the
   block and a certifying seen commit) and the app's `Info` (the first height and
   the state's app hash), and prints one JSON line:

```json
{
  "height": 1001,
  "block_id": { "hash": "0x…", "parts": { "total": 1, "hash": "0x…" } },
  "app_hash": "0x…",
  "source": "local",
  "applied": "executed",
  "backup": "/absent/backup",
  "store_instance": "<32 hex>"
}
```

`source` is `local`, `peer` or `peer_commit`. `applied` is `executed`,
`replayed` (the kept response) or `already_repaired` (a rerun after the state
was saved, which only checks, apart from installing a peer's commit over a
damaged seen commit). Exit 0 means the home is repaired and stock CometBFT's
handshake finds its state, block store and app at the first height. Exit 1 is
any other failure. A refusal leaves the stores as stock left them, apart from
the backup and the instance ID; a failure after the block store was written
leaves the certified block and its certificate there, and stock's own write
order tells a rerun whether to execute or replay. Either way the operator fixes
the cause and reruns with a new `--backup`. Only goleveldb stores at the stock default `db_dir`,
`<home>/data`, are supported.

`export-first-block` prints the certified first block of a stopped home as one
`blocks.jsonl` line: the original block, its own-height commit (C:h if the node
saved the next block, else the seen commit) and the genesis keys and powers. It
refuses a block the genesis committee did not certify.
