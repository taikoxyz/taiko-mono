# Offline stock Comet checkpoint installer

Build from `tools/etna-signer` using the module's pinned Go toolchain:

```sh
go build -mod=readonly -o etna-comet-import ./cmd/etna-comet-import
go test -race -mod=readonly ./...
```

Package this binary beside `etna-signer` in runtime
images. It is the offline store tool that CONS-3.1-1 permits for 5.4 checkpoint
import: it links the pinned CometBFT v0.40.0 module and GoLevelDB only to write
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
