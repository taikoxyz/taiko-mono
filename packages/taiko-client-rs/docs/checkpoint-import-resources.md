# Local checkpoint import resource acceptance

These are engineering acceptance limits for the reproducible local fixture,
chosen before measurement. They are not a deployment, snapshot download or
production launch budget. Import must retain the complete required window even
if it exceeds a limit; exceeding a limit fails the experiment rather than
shortening history.

The measured pipeline must use the actual Rust `authenticate_import` and the
pinned install-only stock and EL helpers on the same genuinely signed original
bytes, as `abci-import import` runs them.
Fixture generation/build are timed separately. Account-state verification has
separate native-provider tests; a synthetic native consensus fixture does not
represent a large deployed EL state.

| Per-profile local limit                                                                       | Threshold   |
| --------------------------------------------------------------------------------------------- | ----------- |
| Rust window authentication, writing the stock dir and the EL manifest                         | 600 seconds |
| Stock installation and reopen                                                                 | 600 seconds |
| Native EL helper installation (copy, verification and install) of the full 65,533-header tail | 600 seconds |
| Peak resident memory for each verifier process                                                | 2 GiB       |
| Complete input, staging and installed stock and EL data combined                              | 4 GiB       |

## Reproduce

From `packages/taiko-client-rs` run `just checkpoint-import-resources`. The recipe builds the pinned helper binaries and the optimized lander test executable before measuring. It runs natively on Linux and macOS with Python 3.11+ and a local filesystem. Each profile uses a private temporary directory. Each native phase is a separate process. The harness captures elapsed time, user/system CPU and maximum RSS with `wait4`, samples logical and allocated disk bytes every 200 ms, and checks both helpers' receipts against the authenticated window, state and header range. No network archive downloads occur.

The source generator models a settled generation-zero prefix rather than executing that prefix. It constructs the original genesis witness and actual authenticated L1 MPT trees. Each raw native frame has one original envelope, a full stock part-set ID, a native authorized low-S recoverable secp256k1eth precommit, the actual predecessor commit and a single-validator set. The commit vote time is the successor header's time. The generator writes the frames to the package's JSONL stream without retaining the whole array. As in `abci-import import`, the Rust authentication writes the stock dir (`blocks.jsonl`, `genesis.json`, `validator-state.bin`) from exactly the frames it verifies, and the stock helper reads only that. The boundary supplies only an EL header and a Comet header at w in addition to the original genesis. The inherited leading checkpoint is below w and is proven on L1. Its EL body, consensus block, commit and validator set are unavailable to the importer.

All profiles use U=65,532, an epoch length of 600,000 and the original native genesis identity. The final inherited checkpoint q=s−U remains inside the linked output. Rust authenticates the selected landing, complete frame stream, future validator state, reads only the own-L1 proofs/headers needed for metadata and emits the exact 65,533 linked execution headers for the native helper. Its interface has no historical execution, EL fetch or consensus-fetch source. A request for FI transaction data or unproven storage panics. The separate boundary controls refuse a missing w header and a changed EL(w) before reading past w+1. A genuinely executed native validator network independently exercises normal admission, execution and signing.

The EL account state is a small real devnet alloc with 64 accounts, 95 storage slots and 17 bytecodes. Its actual root is the synthetic stream's terminal state root. The official pinned Alethia binary initializes an independent local donor with a 128 MiB MDBX growth increment. One `etna-el-import install --source` run copies the stopped donor into an absent datadir, verifies the accounts, storage, code and header manifest, installs the authenticated tail and reopens it; there is no staging marker and no separate verify run. The Rust authentication time includes writing the stock dir and serializing the 65,533-header manifest; EL installation includes trie and native index reconstruction. One `etna-comet-import install --stock-dir --app-hash` run writes all three durable stock databases and reopens them for its read-back checks; there is no separate stock verify or export. Build time, original-frame generation and local donor initialization are outside verifier timing.

## Measurements

Host Mac16,8, 14 logical CPUs, 24 GiB RAM, macOS 27.0.1. Rust 1.95.0 compiled the resource fixture in release mode and the native EL runtime/importer in their normal local debug profiles. Go 1.27.2 built the release-style stock v0.40.0 helper. Alethia revision `6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4` uses reth `d9bd9875fe88dcc0183d78b187ce2ceab0c93e93`. These are historical measurements; the current source pin is `20a9282a24b14567ebad82c427f8ceeeaf40aab4` with Rust 1.99 and reth `3c5f2f11c4e5a5647e6e911cd131ccf1bada4f25`. Single observations on a shared development machine include concurrent development/process tests. They do not establish latency percentiles.

Measured scopes as seconds wall / seconds CPU (user + system) / peak RSS MiB. Elapsed time includes local filesystem work; CPU and RSS are per process. The stock installer reopens every native record before returning.

These figures, and the disk figures below, were measured with the earlier verify-then-install helpers. The `resources` CI job re-measures every profile on its next `main` run with the install-only phases above. Until then, the rows marked _pending_ have no figures.

| Phase                                                |        4 s, s=200004 |        4 s, s=400008 |        1 s, s=200004 |        1 s, s=400008 |
| ---------------------------------------------------- | -------------------: | -------------------: | -------------------: | -------------------: |
| Generate signed input                                | 12.88 / 11.52 / 12.4 | 12.51 / 11.37 / 12.2 | 19.67 / 19.56 / 12.3 | 19.79 / 19.55 / 12.3 |
| Rust authentication + stock dir + EL manifest        |            _pending_ |            _pending_ |            _pending_ |            _pending_ |
| Initialize independent EL alloc                      |  1.26 / 0.62 / 167.8 |  1.27 / 0.64 / 167.7 |  1.26 / 0.63 / 167.9 |  1.26 / 0.63 / 167.8 |
| Native EL install (copy + verify + install + reopen) |            _pending_ |            _pending_ |            _pending_ |            _pending_ |
| Stock install + reopen                               |            _pending_ |            _pending_ |            _pending_ |            _pending_ |

Disk values are bytes, shown as logical / allocated. The whole-directory peak includes the original inputs, native donor, private spool and all installed output. The peak is sampled; short-lived files can fall between samples.

| Period, s    | w / frame count / q         | JSONL / stock JSON bytes¹ | EL manifest bytes | Installed EL logical / allocated | Installed stock logical / allocated | Whole-profile peak logical / allocated | Own-L1 calls |
| ------------ | --------------------------- | ------------------------: | ----------------: | -------------------------------: | ----------------------------------: | -------------------------------------: | -----------: |
| 4 s, 200,004 | 100,003 / 100,001 / 134,472 | 300,709,677 / 300,727,025 |       103,804,548 |          89,379,036 / 73,617,408 |           123,808,326 / 124,940,288 |          1,417,724,304 / 1,273,278,464 |           17 |
| 4 s, 400,008 | 300,007 / 100,001 / 334,476 | 300,709,045 / 300,726,393 |       103,870,081 |          89,379,002 / 73,519,104 |           123,802,471 / 124,919,808 |          1,453,275,927 / 1,308,459,008 |           17 |
| 1 s, 200,004 | 27,203 / 172,801 / 134,472  | 519,472,917 / 519,490,265 |       103,804,548 |          89,379,008 / 72,585,216 |           210,506,628 / 211,804,160 |          2,186,426,626 / 2,039,431,168 |           19 |
| 1 s, 400,008 | 227,207 / 172,801 / 334,476 | 519,625,253 / 519,642,601 |       103,804,548 |          89,379,006 / 72,503,296 |           211,015,315 / 212,205,568 |          2,183,052,713 / 2,035,253,248 |           19 |

¹ The stock dir's `blocks.jsonl` replaces the stock JSON package; its size is re-measured with the rest.

Each profile reads exactly one EL prefix header at w and supplies the original genesis separately. The fast profiles additionally prove an intermediate checkpoint before the final inherited anchor. All profiles install q through s inclusive. The modeled L1 state authenticates the selected landing and both future sets. Every later-height commit in the stream is checked by Rust; the pinned Go helper decodes the stock dir and reads its own stores back.

## Failure and recovery measurements

The original Go installer exceeded 600 seconds on the first 100,001-frame profile. Its per-height synchronous stock and metadata writes targeted a new unpublished store. The corrected helper uses stock operations on the fresh LevelDB stores, then closes all three and syncs every file and directory, verifies the reopened native contents, and syncs the tree and parent before reporting success. A failed final barrier refuses the installation. A crashed private stage is discarded, and the rerun authenticates and installs again.

The initial full EL-index run reserved 4,294,967,296 logical MDBX bytes for the small native state. It took 34.14 seconds and reached 5,028,156,527 logical versus 786,939,904 allocated bytes for the whole stage, failing the 4 GiB logical budget. Increasing the donor's initial extent to 128 MiB alone still produced a 4 GiB working MDBX. Owned writable helper/scratch environments and owned EL startup now use 64 MiB growth increments with native durable sync mode and the original database maximum. Read-only verification keeps its source immutable. Larger real inputs may carry larger existing logical extents.

The Docker scenario `checkpoint_import_latest_full_node_restarts_forced_skips_and_retries` SIGKILLs `import` once its EL install has started. Its `checkpoint_crash seconds_to_quiescence` line reports how long the surviving EL helper kept `ROOT/import.lock`, and its `checkpoint_cli` lines time the rerun and the idempotent third run. On the development host above, the helper kept the lock 0.79 seconds after the kill, the rerun took 1.10 seconds and the third run 0.03 seconds. These observations describe that small fixture only.

The measurement covers pinned verifier, stock and EL installation costs plus a real small-account-state baseline. It excludes Internet download latency, full-size production state, large committees, worst-case evidence/witness bytes, production archive operations, proof guests, and production capacity/availability commitments. The long fixture measures the shared importer primitives. The separate public CLI tests exercise the root lock, atomic publication, ordinary restart, signer authorization and peer continuation.
