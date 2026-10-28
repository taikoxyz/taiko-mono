# S2 public-data substitution — sources

Retrieval times are UTC, 2026-10-07. "Status label" is the label used in the report.

## First-party on-chain measurements (RPC reads)

| # | Source | Endpoint | What was read | Retrieved | Window covered |
|---|---|---|---|---|---|
| S-1 | Ethereum mainnet (chain id 1) | https://rpc.mevblocker.io | 20,000 block headers (number, timestamp, hash) | 13:24:19-13:25:48Z | blocks 26,120,733-26,140,732 = 2026-10-04T18:17:59Z-2026-10-07T13:12:59Z |
| S-2 | Ethereum mainnet (cross-check) | https://ethereum-rpc.publicnode.com | 10,556 of the same block headers | 13:13-13:23Z | blocks 26,120,733-26,131,288 |
| S-3 | Taiko mainnet L2 (chain id 167000) | https://rpc.taiko.xyz | 20,000 block headers | 13:13:58-13:21:43Z | L2 blocks 12,347,771-12,367,770 = 2026-10-07T02:03:47Z-13:10:27Z |
| S-4 | Taiko Shasta Inbox on L1, 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f | https://mainnet.gateway.tenderly.co (archive getLogs) | 1,898 logs: 1,581 Proposed, 317 Proved | 13:22Z | L1 blocks 26,090,333-26,140,732 (7 days) |
| S-5 | Ethereum mainnet (headers for the S-4 blocks) | https://rpc.mevblocker.io | 1,891 block headers | 13:23Z | same range as S-4 |

Labels used: [on-chain measured]. S-1..S-5 are first-party reads of Taiko's shipped
mainnet system (S-3..S-5) and of Ethereum mainnet (S-1, S-2).

## Third-party on-chain measurements (production consensus chains, comparison only)

| # | Network | Endpoint | What was read | Retrieved | Window |
|---|---|---|---|---|---|
| S-6 | Cosmos Hub (cosmoshub-4, CometBFT 0.38.22), 180 bonded validators | https://cosmos-rpc.polkachu.com (/blockchain) | 1,000 block headers | 13:34-13:37Z | heights 33,298,949-33,299,948 = 2026-10-07T11:59:57Z-13:34:47Z |
| S-7 | Celestia (celestia, CometBFT 0.38.17), 95 bonded validators | https://celestia-rpc.polkachu.com (/blockchain) | 1,000 block headers | 13:34-13:37Z | heights 14,736,527-14,737,526 = 2026-10-07T12:47:04Z-13:34:48Z |
| S-8 | dYdX Chain (dydx-mainnet-1, CometBFT 0.38.5), 21 bonded validators | https://dydx-rpc.publicnode.com | 1,000 block headers | 13:22-13:23Z | heights 108,446,206-108,447,205 = 2026-10-07T13:12:43Z-13:22:59Z |

Validator counts were taken both from the node's /validators endpoint and from the
Cosmos SDK REST endpoint /cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED
(count_total): 180, 95 and 21 respectively. Label used: [on-chain measured, third-party
network] - these are not Taiko and are not a controlled experiment.

## Third-party published sources

| # | Source | URL | Method / content used | Retrieved |
|---|---|---|---|---|
| S-9 | Cason, Fynn, Milosevic, Milosevic, Buchman, Pedone, "The design, architecture and performance of the Tendermint Blockchain Network", SRDS 2021 (peer-reviewed practical experience report; USI + Informal Systems) | https://www.inf.usi.ch/faculty/pedone/Paper/2021/srds2021a.pdf | Tendermint v0.33.8, Go 1.15, default config; 128 validators on AWS VMs spread evenly over 16 AWS regions on all continents, plus one seed/client instance; 1 KB txs, closed-loop clients saturating the system; 30 blocks per fault-free run, 60 per fault run; reports mean commit-to-commit block latency at n=16/32/64/128, throughput, a crash fault that kills 42/128 validators, and a Byzantine fault in which 128 nodes share 64 validator keys | 13:14Z (PDF), text extracted with pypdf 6.19.0 |
| S-10 | Senn, Cachin, "Benchmarking CometBFT with Asymmetric Grid Quorum Systems", artifact appendix, CCS 2026 (Univ. Bern); raw run data in cryptobern/tenderload tag ccs26 | https://zenodo.org/api/records/21828731 and https://github.com/cryptobern/tenderload | Baseline (unmodified) CometBFT on 49 VMs (4 vCPU / 4 GiB each, high-speed network), series n=28 and n=49; the published CSVs report aggregate client throughput only | 13:20-13:22Z |
| S-11 | CometBFT repository (cometbft/cometbft) | https://github.com/cometbft/cometbft | Checked for a published latency benchmark table: docs/references/benchmarks* and docs/architecture/benchmarks* do not exist on main or on the v0.34.x / v0.37.x / v0.38.x lines (HTTP 404). Present: test/loadtime/README.md (tooling only) and docs/references/rfc/tendermint-core/rfc-003-performance-questions.md (a taxonomy with no measurements) | 13:19Z |
| S-12 | Taiko documentation, "Preconfirmations" | https://docs.taiko.xyz/protocol/preconfirmations | States that preconfirmation reduces confirmation time to "the preconfer's configured block time, which could realistically be 500 milliseconds to 2 seconds" | 13:44Z |
| S-13 | taikoxyz/taiko-mono issue #20044, "Define initial base fee and block time" (closed) | https://github.com/taikoxyz/taiko-mono/issues/20044 | Repo discussion of the Shasta L2 block-time target ("2s?"), opened 2025-08-31 | 13:44Z |

Checked and not used: Karmegam et al., "Setchain Algorithms for Blockchain Scalability"
(IMDEA/SSS 2025) - it builds variants on top of CometBFT but is not a CometBFT
round-timing study; the extracted text is kept only as
thirdparty/imdea-sss2025-extracted.txt for auditability.
