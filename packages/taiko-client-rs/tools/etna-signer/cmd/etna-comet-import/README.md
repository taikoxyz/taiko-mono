# Offline stock Comet checkpoint installer

Build from `tools/etna-signer` using the module's pinned Go toolchain:

```sh
go build -mod=readonly -o etna-comet-import ./cmd/etna-comet-import
go test -race -mod=readonly ./...
```

Package this binary beside `etna-signer` in runtime
images. It uses unmodified CometBFT v0.40.0 and GoLevelDB (DATA-5.4-5). It
starts no service, loads no signing keys and never reads or writes FilePV state
or the consensus WAL.

```sh
etna-comet-import install --home /absent/stock/home \
  --stock-dir /stage/stock --app-hash 0x<ELHash(s), 32 bytes> --n-max <n_max>
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
bytes, a malformed preimage, an unsupported genesis and a terminal height that
differs from the preimage height. These are decode checks, not authentication.

## Install

`--home` must not exist. The helper creates it with `config/genesis.json` (the
original bytes) and the stock `state`, `blockstore` and `evidence` databases
under `data/` (DATA-5.4-3):

- Stock `SaveBlock` stores each block, its successor's LastCommit and the
  terminal seen commit. As on a stock node at state s, C:s is absent until s+1
  is saved, so stock evidence's signed-header lookup at height s fails the same
  way.
- Historical records use the pinned public ValidatorsInfo/ConsensusParamsInfo
  protobufs and stock key formats: full validator sets at the first height,
  at changes and at periodic 100,000-height checkpoints. Metadata never points
  below the window.
- Evidence `Pool.Update` records a committed-evidence marker for each evidence
  item the blocks carry, without validating it again. Pending evidence starts
  empty, and new evidence is validated by stock APIs.
- Stock `Bootstrap` installs the post-s state (DATA-5.4-4): LastBlockHeight s,
  the terminal BlockID and time, Last/Current/NextValidators with the
  preimage's priorities and stored proposers, LastHeightValidatorsChanged s+2,
  LastHeightConsensusParamsChanged s+1, AppHash `--app-hash` (appHash of
  ELHash(s) and that state; the terminal header's AppHash commits s-1), the
  fixed LastResultsHash and the original InitialHeight.
  `SetOfflineStateSyncHeight(s)` follows.

The helper then fsyncs every file and directory, reopens the databases
read-only and checks them against a second read of the stock dir: the state
bytes, each block hash, each stored commit's bytes against the input commit,
each height's validator hash through the stock `LoadValidatorsFast` path (no
slow fallback), the evidence markers, the consensus params and the terminal
seen commit. It fsyncs the tree and the parent directory once more before it
reports success.

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
InitChain reports its `initial_height` − 1. `verify-export` refuses a snapshot
at another height and names both heights. See the
[producer procedure](../../../../docs/checkpoint-import.md#stock-snapshot-for-the-producer-check).
