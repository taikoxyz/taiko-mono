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

| Per-profile local limit                                                                      | Threshold   |
| -------------------------------------------------------------------------------------------- | ----------- |
| Rust window authentication, writing the stock dir and the EL manifest                        | 600 seconds |
| Stock installation and reopen                                                                | 600 seconds |
| Native EL helper installation (copy, verification and install) of the full U + 1 header tail | 600 seconds |
| Peak resident memory for each verifier process                                               | 2 GiB       |
| Complete input, staging and installed stock and EL data combined                             | 4 GiB       |

## Reproduce

From `packages/taiko-client-rs` run `just checkpoint-import-resources`. The recipe builds the pinned helper binaries and the optimized lander test executable before measuring. It runs natively on Linux and macOS with Python 3.11+ and a local filesystem. Each profile uses a private temporary directory. Each native phase is a separate process. The harness captures elapsed time, user/system CPU and maximum RSS with `wait4`, samples logical and allocated disk bytes every 200 ms, and checks both helpers' receipts against the authenticated window, state and header range. No network archive downloads occur.

The source generator models a settled generation-zero prefix rather than executing that prefix. It constructs the original genesis witness and actual authenticated L1 MPT trees. Each raw native frame has one original envelope, a full stock part-set ID, a native authorized low-S recoverable secp256k1eth precommit, the actual predecessor commit and a single-validator set. The commit vote time is the successor header's time. The generator writes the frames to the package's JSONL stream without retaining the whole array, and the package's EL header at w to its `execution_headers.jsonl`. As in `abci-import import`, the Rust authentication writes the stock dir (`blocks.jsonl`, `genesis.json`, `validator-state.bin`) from exactly the frames it verifies, and the stock helper reads only that. The boundary supplies only an EL header and a Comet header at w in addition to the original genesis. The inherited leading checkpoint is below w and is proven on L1. Its EL body, consensus block, commit and validator set are unavailable to the importer.

The profiles measure U=151,200 (the devnet's) and U=262,144 (the largest U), each at s=400,008 and s=800,016 and at 4 s and 1 s per block, with the original native genesis identity. Under the stock evidence limits (16 blocks and 3 min) the newest expired evidence height is s−46 at 4 s per block and s−181 at 1 s, so the latest anchor witness, carried by block s−U+1, sets every window: w = s−U and U frames (`window` in `crates/lander/src/test_utils/import_resources.rs` asserts that the evidence bound lies inside U and returns U). The final inherited checkpoint q=s−U remains inside the linked output. Rust authenticates the selected landing, complete frame stream, future validator state, reads only the own-L1 proofs/headers needed for metadata and emits the exact U+1 linked execution headers (151,201 or 262,145) for the native helper, which reads its JSON Lines manifest one header per line rather than as one bounded document. Its interface has no historical execution, EL fetch or consensus-fetch source. A request for FI transaction data or unproven storage panics. The separate boundary controls refuse a missing w header and a changed EL(w) before reading past w+1. A genuinely executed native validator network independently exercises normal admission, execution and signing.

The EL account state is a small real devnet alloc with 64 accounts, 95 storage slots and 17 bytecodes. Its actual root is the synthetic stream's terminal state root. The official pinned Alethia binary initializes an independent local donor with a 128 MiB MDBX growth increment. One `etna-el-import install --source` run copies the stopped donor into an absent datadir, verifies the accounts, storage, code and header manifest, installs the authenticated tail and reopens it; there is no staging marker and no separate verify run. The Rust authentication time includes writing the stock dir and streaming the U+1-header manifest; EL installation includes trie and native index reconstruction. One `etna-comet-import install --stock-dir --app-hash` run writes all three durable stock databases and reopens them for its read-back checks; there is no separate stock verify or export. Build time, original-frame generation and local donor initialization are outside verifier timing.

## Measurements

Host: a Linux VM (Debian 13, kernel 6.12) with 8 vCPUs (AMD EPYC 7B13), 31 GiB RAM and an ext4 disk, measured on 2026-11-23. Rust 1.99.0 compiled the resource fixture in release mode and the native EL runtime/importer in their normal local debug profiles. Go 1.27.2 built the release-style stock v0.40.0 helper. Alethia revision `7174fd0064c69fa75ce784b8ec13702fffa5d429` uses reth `ed91041f36b973eda3521ff90b3a25165087c133`. The run was niced on a shared development machine while other builds ran. These are single observations; they do not establish latency percentiles.

Every profile stayed within every limit above. The slowest phase was Rust authentication at U=262,144 (147.58 seconds, against 600), the largest verifier RSS the native EL install at U=262,144 (533.4 MiB, against 2 GiB) and the largest whole-profile peak 2,927,676,639 logical bytes (against 4 GiB). Generation and the independent EL alloc are outside verifier timing.

Measured scopes as seconds wall / seconds CPU (user + system) / peak RSS MiB. Elapsed time includes local filesystem work; CPU and RSS are per process. The stock installer reopens every native record before returning.

U=151,200:

| Phase                                                |        4 s, s=400,008 |        4 s, s=800,016 |        1 s, s=400,008 |        1 s, s=800,016 |
| ---------------------------------------------------- | --------------------: | --------------------: | --------------------: | --------------------: |
| Generate signed input                                |  18.84 / 18.58 / 18.1 |  18.44 / 18.42 / 18.6 |  18.44 / 18.40 / 18.6 |  18.44 / 18.40 / 18.6 |
| Rust authentication + stock dir + EL manifest        | 84.62 / 84.49 / 138.0 | 84.61 / 84.31 / 138.1 | 85.22 / 84.88 / 137.5 | 84.42 / 84.32 / 137.9 |
| Boundary refusals (missing w header, changed EL(w))  |    0.20 / 0.01 / 18.2 |    0.20 / 0.01 / 18.6 |    0.20 / 0.01 / 18.6 |    0.20 / 0.01 / 18.6 |
| Initialize independent EL alloc                      |   1.21 / 0.35 / 279.8 |   0.40 / 0.19 / 278.1 |   0.40 / 0.19 / 278.3 |   0.40 / 0.19 / 280.3 |
| Native EL install (copy + verify + install + reopen) | 19.33 / 18.70 / 340.4 | 19.53 / 18.83 / 336.4 | 19.33 / 18.63 / 339.8 | 19.55 / 18.83 / 340.5 |
| Stock install + reopen                               | 43.89 / 57.23 / 126.1 | 45.10 / 58.45 / 136.3 | 43.70 / 56.66 / 130.5 | 43.93 / 56.76 / 122.9 |

U=262,144:

| Phase                                                |          4 s, s=400,008 |          4 s, s=800,016 |          1 s, s=400,008 |          1 s, s=800,016 |
| ---------------------------------------------------- | ----------------------: | ----------------------: | ----------------------: | ----------------------: |
| Generate signed input                                |    32.07 / 31.97 / 18.6 |    31.87 / 31.81 / 18.6 |    32.27 / 32.12 / 18.6 |    32.27 / 32.09 / 18.6 |
| Rust authentication + stock dir + EL manifest        | 146.17 / 145.84 / 228.4 | 147.58 / 147.38 / 228.5 | 147.19 / 146.87 / 229.1 | 146.78 / 146.37 / 228.3 |
| Boundary refusals (missing w header, changed EL(w))  |      0.20 / 0.01 / 18.6 |      0.20 / 0.01 / 18.6 |      0.20 / 0.01 / 18.6 |      0.20 / 0.01 / 18.6 |
| Initialize independent EL alloc                      |     0.40 / 0.18 / 278.7 |     0.40 / 0.19 / 279.1 |     0.40 / 0.20 / 278.2 |     0.40 / 0.20 / 278.2 |
| Native EL install (copy + verify + install + reopen) |   33.62 / 32.62 / 533.3 |   33.83 / 32.65 / 530.0 |   33.83 / 32.70 / 533.4 |   33.63 / 32.50 / 529.0 |
| Stock install + reopen                               |  80.68 / 107.38 / 137.2 |  83.62 / 111.09 / 132.8 |  80.96 / 108.18 / 135.1 |  81.18 / 108.31 / 135.4 |

Disk values are bytes, shown as logical / allocated. The package JSONL is the frame stream Rust authenticates; the stock dir is what it writes for the stock helper. The whole-profile peak is the largest sampled size of the profile directory, which holds the original inputs, native donor, private spool and all installed output. The peak is sampled; short-lived files can fall between samples.

| U, period, s          | w / frame count / q         | Package JSONL / stock dir bytes | EL manifest bytes | Installed EL logical / allocated | Installed stock logical / allocated | Whole-profile peak logical / allocated | Own-L1 calls |
| --------------------- | --------------------------- | ------------------------------: | ----------------: | -------------------------------: | ----------------------------------: | -------------------------------------: | -----------: |
| 151,200, 4 s, 400,008 | 248,808 / 151,200 / 248,808 |       459,202,752 / 459,216,389 |       244,478,849 |        185,879,738 / 174,759,936 |           189,591,450 / 189,820,928 |          1,775,860,823 / 1,631,318,016 |           13 |
| 151,200, 4 s, 800,016 | 648,816 / 151,200 / 648,816 |       460,109,952 / 460,123,589 |       244,492,160 |        185,879,508 / 174,735,360 |           186,519,593 / 186,753,024 |          1,763,457,318 / 1,618,866,176 |           13 |
| 151,200, 1 s, 400,008 | 248,808 / 151,200 / 248,808 |       459,202,752 / 459,216,389 |       244,340,959 |        185,879,348 / 174,702,592 |           189,550,075 / 189,820,928 |          1,772,332,610 / 1,627,795,456 |           13 |
| 151,200, 1 s, 800,016 | 648,816 / 151,200 / 648,816 |       459,202,752 / 459,216,389 |       244,340,959 |        185,879,382 / 174,645,248 |           189,535,778 / 189,788,160 |          1,761,293,273 / 1,616,670,720 |           13 |
| 262,144, 4 s, 400,008 | 137,864 / 262,144 / 137,864 |       796,139,610 / 796,153,247 |       423,764,353 |        357,838,972 / 302,587,904 |           323,915,038 / 324,284,416 |          2,924,393,946 / 2,735,833,088 |           13 |
| 262,144, 4 s, 800,016 | 537,872 / 262,144 / 537,872 |       797,713,002 / 797,726,639 |       423,888,608 |        357,838,932 / 302,247,936 |           322,114,361 / 322,453,504 |          2,927,676,639 / 2,738,737,152 |           13 |
| 262,144, 1 s, 400,008 | 137,864 / 262,144 / 137,864 |       796,139,610 / 796,153,247 |       423,626,463 |        357,838,519 / 302,477,312 |           323,821,999 / 324,190,208 |          2,921,288,380 / 2,732,634,112 |           13 |
| 262,144, 1 s, 800,016 | 537,872 / 262,144 / 537,872 |       796,140,138 / 796,153,775 |       423,626,463 |        357,838,787 / 302,493,696 |           323,816,906 / 324,206,592 |          2,923,487,204 / 2,734,870,528 |           13 |

Each profile reads exactly one EL prefix header at w and supplies the original genesis separately; the first window block carries the latest anchor witness, so w and q are both s−U. All profiles install q through s inclusive. The modeled L1 state authenticates the selected landing and both future sets. Every later-height commit in the stream is checked by Rust; the pinned Go helper decodes the stock dir and reads its own stores back.

## Failure and recovery measurements

The original Go installer exceeded 600 seconds on the first 100,001-frame profile (earlier evidence limits). Its per-height synchronous stock and metadata writes targeted a new unpublished store. The corrected helper uses stock operations on the fresh LevelDB stores, then closes all three and syncs every file and directory, verifies the reopened native contents, and syncs the tree and parent before reporting success. A failed final barrier refuses the installation. A crashed private stage is discarded, and the rerun authenticates and installs again.

The initial full EL-index run reserved 4,294,967,296 logical MDBX bytes for the small native state. It took 34.14 seconds and reached 5,028,156,527 logical versus 786,939,904 allocated bytes for the whole stage, failing the 4 GiB logical budget. Increasing the donor's initial extent to 128 MiB alone still produced a 4 GiB working MDBX. Owned writable helper/scratch environments and owned EL startup now use 64 MiB growth increments with native durable sync mode and the original database maximum. Read-only verification keeps its source immutable. Larger real inputs may carry larger existing logical extents.

The Docker scenario `checkpoint_import_latest_full_node_restarts_forced_skips_and_retries` SIGKILLs `import` once its EL install has started. Its `checkpoint_crash seconds_to_quiescence` line reports how long the surviving EL helper kept `ROOT/import.lock`, and its `checkpoint_cli` lines time the rerun and the idempotent third run. On an earlier macOS development host (Mac16,8, 14 logical CPUs, 24 GiB RAM), the helper kept the lock 0.79 seconds after the kill, the rerun took 1.10 seconds and the third run 0.03 seconds. These observations describe that small fixture only.

The measurement covers pinned verifier, stock and EL installation costs plus a real small-account-state baseline. It excludes Internet download latency, full-size production state, large committees, worst-case evidence/witness bytes, production archive operations, proof guests, and production capacity/availability commitments. The long fixture measures the shared importer primitives. The separate public CLI tests exercise the root lock, atomic publication, ordinary restart, signer authorization and peer continuation.
