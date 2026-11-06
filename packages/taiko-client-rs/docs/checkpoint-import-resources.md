# Local checkpoint import resource acceptance

These are engineering acceptance limits for the reproducible local fixture,
chosen before measurement. They are not a deployment, snapshot download or
production launch budget. Import must retain the complete required window even
if it exceeds a limit; exceeding a limit fails the experiment rather than
shortening history.

The measured pipeline must use the actual Rust `authenticate_import` and pinned
stock helper verification/install on the same genuinely signed original bytes.
Fixture generation/build are timed separately. Account-state verification has
separate native-provider tests; a synthetic native consensus fixture does not
represent a large deployed EL state.

| Per-profile local limit                                                            | Threshold   |
| ---------------------------------------------------------------------------------- | ----------- |
| Rust window authentication                                                         | 600 seconds |
| Stock verification                                                                 | 600 seconds |
| Stock installation and reopen                                                      | 600 seconds |
| Native EL helper verification or installation of the full 65,533-header tail, each | 600 seconds |
| Peak resident memory for each verifier process                                     | 2 GiB       |
| Complete input, staging and installed stock and EL data combined                   | 4 GiB       |

## Reproduce

From `packages/taiko-client-rs` run `just checkpoint-import-resources`. The recipe builds the pinned helper binaries and the optimized lander test executable before measuring. It runs natively on Linux and macOS with Python 3.11+ and a local filesystem. Each profile uses a private temporary directory. Each native phase is a separate process. The harness captures elapsed time, user/system CPU and maximum RSS with `wait4`, samples logical and allocated disk bytes every 200 ms, and checks exact stock results and the terminal record exported from the reopened LevelDB stores. No network archive downloads occur.

The source generator models a settled generation-zero prefix rather than executing that prefix. It constructs the original genesis witness and actual authenticated L1 MPT trees. Each raw native frame has one original envelope, a full stock part-set ID, a native authorized low-S recoverable secp256k1eth precommit, the actual predecessor commit and a single-validator set. The commit vote time is the successor header's time. The generator writes the same frame bytes to the Rust JSONL stream and Go package without retaining the whole array. The boundary supplies only an EL header and a Comet header at w in addition to the original genesis. The inherited leading checkpoint is below w and is proven on L1. Its EL body, consensus block, commit and validator set are unavailable to the importer.

All profiles use U=65,532, an epoch length of 600,000 and the original native genesis identity. The final inherited checkpoint q=s−U remains inside the linked output. Rust authenticates the selected landing, complete frame stream, future validator state, reads only the own-L1 proofs/headers needed for metadata and emits the exact 65,533 linked execution headers for the native helper. Its interface has no historical execution, EL fetch or consensus-fetch source. A request for FI transaction data or unproven storage panics. The separate boundary controls refuse a missing w header and a changed EL(w) before reading past w+1. A genuinely executed native validator network independently exercises normal admission, execution and signing.

The EL account state is a small real devnet alloc with 64 accounts, 95 storage slots and 17 bytecodes. Its actual root is the synthetic stream's terminal state root. The official pinned Alethia binary initializes an independent local donor with a 128 MiB MDBX growth increment. The native import helper verifies the accounts, storage, code and header manifest, installs the authenticated tail into the private working copy and reopens it. The Rust authentication time includes serializing the 65,533-header manifest; EL installation includes trie and native index reconstruction. The standalone stock install includes a second stock verification, all three durable databases and full stock reopen verification. The terminal export shown separately performs another independent read. Build time, original-frame generation and local donor initialization are outside verifier timing.

## Measurements

Host Mac16,8, 14 logical CPUs, 24 GiB RAM, macOS 27.0.1. Rust 1.95.0 compiled the resource fixture in release mode and the native EL runtime/importer in their normal local debug profiles. Go 1.27.2 built the release-style stock v0.40.0 helper. Alethia revision `6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4` uses reth `d9bd9875fe88dcc0183d78b187ce2ceab0c93e93`. Single observations on a shared development machine include concurrent development/process tests. They do not establish latency percentiles.

Measured scopes as seconds wall / seconds CPU (user + system) / peak RSS MiB. Elapsed time includes local filesystem work; CPU and RSS are per process. The stock installer verifies the full input a second time and reopens every native record before returning.

| Phase                                  |           4 s, s=200004 |          4 s, s=400008 |           1 s, s=200004 |           1 s, s=400008 |
| -------------------------------------- | ----------------------: | ---------------------: | ----------------------: | ----------------------: |
| Generate signed input                  |    12.88 / 11.52 / 12.4 |   12.51 / 11.37 / 12.2 |    19.67 / 19.56 / 12.3 |    19.79 / 19.55 / 12.3 |
| Rust authentication + emit EL manifest |   42.33 / 41.06 / 166.8 |  42.69 / 41.34 / 166.8 |   73.36 / 71.21 / 164.9 |   72.90 / 70.59 / 163.6 |
| Initialize independent EL alloc        |     1.26 / 0.62 / 167.8 |    1.27 / 0.64 / 167.7 |     1.26 / 0.63 / 167.9 |     1.26 / 0.63 / 167.8 |
| Native EL verify                       |   11.65 / 11.46 / 270.0 |  11.68 / 11.52 / 262.9 |   11.74 / 11.48 / 269.9 |   11.57 / 11.45 / 269.9 |
| Native EL install + reopen             |   27.84 / 26.72 / 381.1 |  27.52 / 26.74 / 210.3 |   30.80 / 29.21 / 322.0 |   27.32 / 26.68 / 381.4 |
| Stock verify                           |    44.57 / 52.39 / 35.1 |   47.25 / 55.09 / 33.3 |    81.26 / 94.01 / 38.5 |    77.16 / 90.10 / 35.5 |
| Stock install + full reopen            | 142.54 / 155.56 / 100.5 | 144.46 / 157.75 / 98.5 | 248.53 / 273.20 / 115.6 | 247.27 / 273.57 / 113.2 |
| Independent terminal stock export      |      0.22 / 0.06 / 48.1 |     0.21 / 0.06 / 44.8 |      0.22 / 0.07 / 53.4 |      0.21 / 0.07 / 53.9 |

Disk values are bytes, shown as logical / allocated. The whole-directory peak includes the original inputs, native donor, private spool and all installed output. The peak is sampled; short-lived files can fall between samples.

| Period, s    | w / frame count / q         |  JSONL / stock JSON bytes | EL manifest bytes | Installed EL logical / allocated | Installed stock logical / allocated | Whole-profile peak logical / allocated | Own-L1 calls |
| ------------ | --------------------------- | ------------------------: | ----------------: | -------------------------------: | ----------------------------------: | -------------------------------------: | -----------: |
| 4 s, 200,004 | 100,003 / 100,001 / 134,472 | 300,709,677 / 300,727,025 |       103,804,548 |          89,379,036 / 73,617,408 |           123,808,326 / 124,940,288 |          1,417,724,304 / 1,273,278,464 |           17 |
| 4 s, 400,008 | 300,007 / 100,001 / 334,476 | 300,709,045 / 300,726,393 |       103,870,081 |          89,379,002 / 73,519,104 |           123,802,471 / 124,919,808 |          1,453,275,927 / 1,308,459,008 |           17 |
| 1 s, 200,004 | 27,203 / 172,801 / 134,472  | 519,472,917 / 519,490,265 |       103,804,548 |          89,379,008 / 72,585,216 |           210,506,628 / 211,804,160 |          2,186,426,626 / 2,039,431,168 |           19 |
| 1 s, 400,008 | 227,207 / 172,801 / 334,476 | 519,625,253 / 519,642,601 |       103,804,548 |          89,379,006 / 72,503,296 |           211,015,315 / 212,205,568 |          2,183,052,713 / 2,035,253,248 |           19 |

Each profile reads exactly one EL prefix header at w and supplies the original genesis separately. The fast profiles additionally prove an intermediate checkpoint before the final inherited anchor. All profiles install q through s inclusive. The modeled L1 state authenticates the selected landing and both future sets. Every later-height commit in the stream is independently checked by Rust and by the pinned Go helper.

## Failure and recovery measurements

The original Go installer exceeded 600 seconds on the first 100,001-frame profile. Its per-height synchronous stock and metadata writes targeted a new unpublished store. The corrected helper uses stock operations on the fresh LevelDB stores, then closes all three and syncs every file and directory, verifies the reopened native contents, and syncs the tree and parent before reporting success. A failed final barrier refuses the installation. A crashed private stage must be discarded and verified again.

The initial full EL-index run reserved 4,294,967,296 logical MDBX bytes for the small native state. It took 34.14 seconds and reached 5,028,156,527 logical versus 786,939,904 allocated bytes for the whole stage, failing the 4 GiB logical budget. Increasing the donor's initial extent to 128 MiB alone still produced a 4 GiB working MDBX. Owned writable helper/scratch environments and owned EL startup now use 64 MiB growth increments with native durable sync mode and the original database maximum. Read-only verification keeps its source immutable. Larger real inputs may carry larger existing logical extents.

In the separate real 6-to-12 fullnode import, a SIGKILL at the EL copy, stock DB, EL completion, app journal and completed-but-unpublished seal took respectively 0.669, 1.094, 2.502, 2.705 and 5.712 seconds from process start. The barriers were free after 0.001, 0.108, 0.107, 0.002 and 0.004 seconds. Successful prepare took 1.183 seconds, install took 4.782 seconds and the post-publication idempotent retry took 0.435 seconds. These observations describe that small fixture only.

The measurement covers pinned verifier, stock and EL installation costs plus a real small-account-state baseline. It excludes Internet download latency, full-size production state, large committees, worst-case evidence/witness bytes, production archive operations, proof guests, and production capacity/availability commitments. The long fixture measures the shared importer primitives. The separate public CLI tests exercise lifecycle leases, atomic publication, guarded restart, signer authorization and peer continuation.
