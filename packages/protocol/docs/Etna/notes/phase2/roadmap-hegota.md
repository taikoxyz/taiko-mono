# Ethereum "Hegotá" (H-star, Heze-Bogotá) fork — contents and status as of 2026-09-30

All fetches performed 2026-09-30. Ground truth for inclusion status is the merged `master` copy of the Hegotá Meta EIP (EIP-8081), fetched raw from GitHub; everything else is corroboration. Each claim is tagged **VERIFIED** (primary source fetched) or **UNVERIFIED**.

Status vocabulary (EIP-7723): **SFI** = Scheduled for Inclusion, **CFI** = Considered for Inclusion, **PFI** = Proposed for Inclusion, **DFI** = Declined for Inclusion.

## 0. Headline summary

- Meta EIP: **EIP-8081 "Hardfork Meta - Hegotá"**, status Draft, created 2025-11-11, authors Beiko/Stokes/Dietrichs/Nixo/Parithosh. **VERIFIED** — https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md
- **SFI (2):** EIP-7805 FOCIL (CL headliner) and EIP-8141 Frame Transaction (EL headliner, SFI'd on ACDE #244, 2026-08-27). **VERIFIED**
- **CFI (11):** 3298, 7668, 7906, 7979, 8015, 8131, 8163, 8250, 8253, 8272, 8279. **VERIFIED** (10 EL EIPs moved to CFI via PR #12377 merged 2026-09-24 after ACDE #246; 8015 via PR #12364 merged 2026-09-21 after ACDC #187).
- **PFI (27)** and **DFI (18)** — full lists in section 2.
- Nothing in the Hegotá meta touches: native rollups / EXECUTE precompile (EIP-8079), binary state tree (EIP-7864), slot-time reduction via EIP-7782 (superseded by EIP-8198 Quick Slots, which is only PFI), enshrined PBS/APS/execution tickets (ePBS EIP-7732 ships in Glamsterdam), EIP-7701 (Withdrawn), EIP-4788. **VERIFIED by absence in EIP-8081 master.**
- Official timing: ethereum.org roadmap page says "Expected on mainnet Q2 2027 · Date not yet confirmed". Activation table in EIP-8081 is empty. **VERIFIED**
- Glamsterdam (the fork before): Sepolia activation 2026-10-06 13:53:36 UTC; Hoodi and mainnet undecided as of EF announcement dated 2026-09-28. **VERIFIED**

## 1. Timing

| Milestone | Date | Source | Tag |
|---|---|---|---|
| Hegotá headliner proposal window | 2026-01-08 → 2026-02-04 | https://blog.ethereum.org/2025/12/22/hegota-timeline | VERIFIED (fetched 2026-09-30) |
| Headliner discussion/finalization on ACD calls | 2026-02-05 → 2026-02-26 (later extended into March) | same + Magicians meta thread (Feb 5 → Mar 26) | VERIFIED |
| FOCIL (EIP-7805) SFI as CL headliner | ACDC #175, 2026-02-19 (agenda item "Hegotá: Headliner selection") | https://github.com/ethereum/pm/issues/1930 (agenda) + Hegotá decisions sheet https://docs.google.com/spreadsheets/d/1UVm9UurwCMWrtLAM7aKvMjdeMtZYSsm7ay8AMwo52AE | VERIFIED via decisions sheet; call notes not fetched |
| Frame Transactions rejected as EL headliner, demoted to CFI | ACDE, 2026-03-26 | https://www.dlnews.com/articles/defi/ethereum-devs-lukewarm-on-buterin-backed-proposal-for-hegota/ ; https://blog.ethereum.org/2026/04/10/checkpoint-9 | VERIFIED (EF Checkpoint #9 confirms CFI "placeholder commitment to work on an AA proposal") |
| Non-headliner PFI window | opened 2026-04-09; closed 2026-08-06 (ACDC #184 was the last "proposal window" call) | Checkpoint #9; Magicians EIP-8081 thread; https://github.com/ethereum/pm/issues/2177 | VERIFIED |
| EIP-8141 Frame Transaction SFI'd (EL headliner) | ACDE #244, 2026-08-27 (decided "in the final three minutes"; spec/number "may change") | https://github.com/ethereum/pm/issues/2197 ; https://christinedkim.substack.com/p/acde-244 | VERIFIED (secondary write-up + pm agenda; SFI reflected in EIP-8081 master) |
| Client-team non-headliner rankings due | 24h before ACDE #245 (2026-09-10) | https://github.com/ethereum/pm/issues/2197 | VERIFIED |
| EF Protocol tier list published | 2026-09-07 | https://blog.ethereum.org/2026/09/07/protocol-hegota-eips | VERIFIED |
| ACDE #245 first scoping pass, 14 EL EIPs DFI'd | 2026-09-10 (PR #12335 merged 2026-09-14) | https://github.com/ethereum/pm/issues/2211 ; https://github.com/ethereum/EIPs/pull/12335 | VERIFIED |
| ACDC #187 CL scoping: 8015 CFI; 8237/8341/8367/8321/8243/8146/8375 DFI; 8411 PFI | 2026-09-17 (PR #12364 merged 2026-09-21) | https://github.com/ethereum/pm/issues/2222 ; https://github.com/ethereum/EIPs/pull/12364 ; decisions sheet | VERIFIED |
| ACDE #246: 10 EL EIPs CFI'd, 8304 DFI, 8368/8372 held for Glamsterdam mainnet data | 2026-09-24 (PR #12377 merged 2026-09-24) | https://github.com/ethereum/pm/issues/2223 ; https://github.com/ethereum/EIPs/pull/12377 | VERIFIED |
| Hegotá EL tracker / devnet plan opened | 2026-09-28 | https://github.com/ethereum/execution-specs/issues/3664 | VERIFIED |
| Remaining EL scoping calls (champions must attend) | ACDE 2026-10-08 and 2026-10-22; ACDC #188 2026-10-01 | https://github.com/ethereum/pm/issues/2197 ; https://github.com/ethereum/pm/issues/2227 | VERIFIED |
| Non-headliner CFI decisions target | "By Devcon" (Magicians meta thread); CFI→SFI decisions TBD | https://ethereum-magicians.org/t/eip-8081-hegota-network-upgrade-meta-thread/26876 | VERIFIED (thread summary) |
| EIP-8368/8372 (state-gas calibration) decision | after 30 days of Glamsterdam mainnet data | PR #12377; execution-specs #3664 | VERIFIED |
| Hegotá mainnet | "Expected on mainnet Q2 2027 · Date not yet confirmed"; next milestone Sepolia 2027 | https://ethereum.org/roadmap/hegota (page dated 2026-08-31) | VERIFIED |
| Glamsterdam Sepolia | 2026-10-06 13:53:36 UTC (epoch 353,024) | https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement (content dated 2026-09-28) | VERIFIED |
| Glamsterdam Hoodi / mainnet | Hoodi proposed 2026-10-26 (ACDE #244 agenda); mainnet "early December" per C. Kim; EF says both undecided | pm #2197; christinedkim acde-244; EF announcement | UNVERIFIED (proposals only, EF says not decided) |

Devnet plan (execution-specs #3664, opened 2026-09-28): three phases — frame-related changes first (8141, 8250, 8272), then gas adjustments, with calibration EIPs (8368/8372) on a separate branch pending mainnet data. **VERIFIED** (WebFetch summary of the issue).

## 2. EIP table

Columns: EIP | title | status in Hegotá | EIP `status:` field (raw master, 2026-09-30) | one-line effect on L2s | source URL | fetched.

### 2a. Scheduled for Inclusion (SFI) — VERIFIED from EIP-8081 master

| EIP | Title | Hegotá status | EIP status | Effect on L2s | Source | Fetched |
|---|---|---|---|---|---|---|
| 7805 | Fork-choice enforced Inclusion Lists (FOCIL) | **SFI, CL headliner** (ACDC #175, 2026-02-19) | Draft (created 2024-11-01) | Committee of validators force-includes txs each L1 block: strong censorship-resistance guarantee for L2 batch/proof/forced-inclusion txs on L1; based rollups' L1 proposer flow gets IL constraints; builders (incl. based-sequencer preconfers) must satisfy ILs. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7805.md | 2026-09-30 |
| 8141 | Frame Transaction | **SFI, EL headliner** (ACDE #244, 2026-08-27; caveat: "EIP number, implementation and specs may change") | Draft (created 2026-01-29) | New EIP-2718 tx type `0x06` with validation/payment/execution "frames", `SENDER`/`DEFAULT`/`VERIFY` modes, `APPROVE`, `TXPARAM`, `ENTRY_POINT`, `ORIGIN` returning frame caller, no access list, EIP-8037 state-gas hooks. Type-1 zkEVMs (Taiko) must add the tx type, mempool validation rules and new opcodes to stay equivalent; contract-account senders (`ORIGIN`==contract) break `tx.origin==msg.sender` assumptions; L2 teams (Base, Offchain Labs) favoured EIP-8130 Keystore Accounts instead and were promised further Frame modifications. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8141.md ; https://christinedkim.substack.com/p/acde-244 | 2026-09-30 |

Note: PR #12255 "Update EIP-8081: Call out Hegotá headliner" is still **open** (updated 2026-08-28), so the meta file does not yet label 8141 as headliner; ethereum.org and the EF tier list do. **VERIFIED** — https://github.com/ethereum/EIPs/pulls?q=is%3Apr+8081

### 2b. Considered for Inclusion (CFI) — VERIFIED from EIP-8081 master

| EIP | Title | Hegotá status | EIP status | Effect on L2s | Source | Fetched |
|---|---|---|---|---|---|---|
| 3298 | Remove storage-clear refund and refund cap | CFI (ACDE #246, 2026-09-24) | Draft (2021-02-26) | Removes SSTORE clearing refund; zkEVM gas accounting must follow; cheaper to reason about worst-case block gas; L2s mirroring L1 gas need to update. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-3298.md | 2026-09-30 |
| 7668 | Remove bloom filters | CFI (ACDE #246) | Stagnant (2024-03-31) | Drops `logsBloom` from L1 block/receipt; L1 header format changes (relevant to L1-header-reading contracts/light clients in bridges); L2 equivalence question whether to mirror. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7668.md | 2026-09-30 |
| 7906 | Transaction Assertions via State Diff Opcode | CFI (ACDE #246) | Draft (2025-02-21) | New opcodes exposing a tx's state diff for on-chain assertions; new EVM surface for a type-1 zkEVM to prove. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7906.md | 2026-09-30 |
| 7979 | Call and Return Opcodes for the EVM | CFI (ACDE #246; "punted for continued discussion" on the same agenda) | Draft (2025-12-17) | Three new control-flow instructions (subroutine calls); zkEVM circuits need new opcodes. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7979.md | 2026-09-30 |
| 8015 | Remove `deposit` and `eth1data` fields | CFI (ACDC #187, 2026-09-17) | Draft (2025-08-22) | CL-only: changes `BeaconBlockBody`/`BeaconState` SSZ layout, so generalized-index proofs against EIP-4788 beacon roots (used by CL-proof bridges/staking contracts) change. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8015.md | 2026-09-30 |
| 8131 | Unified Transaction Content Floor | CFI (ACDE #246) | Draft (2025-01-21) | Flat 64 gas/byte floor over all user-controlled tx fields (calldata, access lists, auth lists, blob hashes...), capping worst-case block size: raises the cost of calldata-heavy L1 batch posting relative to blobs. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8131.md | 2026-09-30 |
| 8163 | Reserve `EXTENSION (0xae)` opcode | CFI (ACDE #246; punted for discussion) | Review (2026-02-13) | Reserves 0xae as an extension prefix for non-L1 EVM chains: directly aimed at L2s wanting custom opcodes without colliding with future L1 opcodes. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8163.md | 2026-09-30 |
| 8250 | Keyed Nonces for Frame Transactions | CFI (ACDE #246) | Draft (2026-04-16) | Replaces the single sender nonce in frame txs with a bounded set of nonce keys sharing one sequence; `nonce_keys==[0]` aliases the account nonce, non-zero keys live in a `NONCE_MANAGER` system contract. Changes nonce semantics for frame-tx senders (parallel, replay-independent domains); must activate at/after 8141; zkEVMs need the system contract. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8250.md | 2026-09-30 |
| 8253 | Bump nonce of zero-nonce storage accounts | CFI (ACDE #246); **also proposed for Glamsterdam** at ACDE #245 (outcome not confirmed) | Draft (2026-05-05) | One-off irregular state transition: 28 mainnet accounts with code-less, zero-nonce, non-empty storage get `nonce=1` so EIP-684 blocks CREATE collisions (alternative to EIP-7610 runtime check). Non-mainnet chains "have to generate the list for their own state"; chains that never had such accounts "MAY ignore" it. Relevant to Taiko L2 genesis/state audit and to BAL (EIP-7928) encoding at index 0. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8253.md ; https://github.com/ethereum/pm/issues/2211 | 2026-09-30 |
| 8272 | Recent Roots for Frame Transactions | CFI (ACDE #246) | Draft (2026-05-15) | Frame txs can declare verified recent (state/block) roots; supports privacy protocols; another system-contract/validation rule to replicate on a type-1 L2. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8272.md | 2026-09-30 |
| 8279 | Block Access List Byte Floor | CFI (ACDE #246) | Draft (2026-05-23) | Meters EIP-7928 BAL bytes at runtime into the EIP-7623 floor: L1 txs touching many slots (e.g., large proof-verification or bridge txs) pay more; caps worst-case block size. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8279.md | 2026-09-30 |

### 2c. Proposed for Inclusion (PFI) — VERIFIED from EIP-8081 master (27 EIPs)

EF tier (from https://blog.ethereum.org/2026/09/07/protocol-hegota-eips, 2026-09-07) given in brackets; "A" = expected to ship, "B" = on the bubble, "C" = below the line, "DFI" = EF recommends decline.

| EIP | Title | Hegotá status | EIP status | Effect on L2s | Source | Fetched |
|---|---|---|---|---|---|---|
| 4758 | Deactivate SELFDESTRUCT | PFI [A] | Stagnant (2022-02-03) | SELFDESTRUCT → SENDALL; EVM-equivalence change to mirror. | raw eip-4758.md | 2026-09-30 |
| 5920 | PAY opcode | PFI [A] | Draft (2022-03-14) | ETH transfer without calling code; new opcode for zkEVMs. | raw eip-5920.md | 2026-09-30 |
| 7666 | EVM-ify the identity precompile | PFI [C] | Draft (2024-03-31) | Replaces precompile 0x04 with bytecode; minor. | raw eip-7666.md | 2026-09-30 |
| 7709 | Read BLOCKHASH from storage and update cost | PFI [B] | Draft (2024-05-18) | BLOCKHASH served from EIP-2935 contract, repriced as SLOAD; matters for L2s (Taiko) that read L1 block hashes / anchor logic. | raw eip-7709.md | 2026-09-30 |
| 7716 | Anti-correlation attestation penalties | PFI [EF: DFI] | (CL) | none for L2s. | EIP-8081 | 2026-09-30 |
| 8025 | Optional Execution Proofs | PFI [A] | Draft (2025-09-17) | Opt-in zk execution proofs gossiped on CL for stateless payload verification; groundwork toward L1 zkEVM proving (and eventually native/EXECUTE-style verification); no consensus change; requires 7732/7928/8282. | raw eip-8025.md | 2026-09-30 |
| 8077 | eth/XX announce transactions with nonce | PFI [B] | Draft (2025-11-07) | networking only. | raw eip-8077.md | 2026-09-30 |
| 8116 | Replace cumulative receipt fields | PFI [C] | Draft (2025-12-30) | Receipt format change (`gasUsed` per receipt): receipt-proof consumers (bridges, relayers) must update. | raw eip-8116.md | 2026-09-30 |
| 8142 | Block-in-Blobs (BiB) | PFI [EF: DFI] | Draft (2026-01-29) | Publishes L1 execution payload + BAL as blobs: competes with rollups for blob space / changes blob demand. | raw eip-8142.md | 2026-09-30 |
| 8148 | Custom sweep threshold for validators | PFI [EF: DFI] | (CL) | none. | EIP-8081 | 2026-09-30 |
| 8151 | Account Code Restricted ecRecover | PFI [A] | Draft (2026-02-09) | ecRecover only returns accounts with empty code or 7702 delegation: breaks contracts using ecrecover-derived addresses that later gained code; L2 EVM-equivalence item. | raw eip-8151.md | 2026-09-30 |
| 8173 | Foundations of EVM Control Flow | PFI (Informational; "no separate decision" per ACDE #245) | Draft, Informational (2026-02-16) | none directly. | raw eip-8173.md | 2026-09-30 |
| 8198 | Quick Slots | PFI [B]; ACDC "most demanding requirements" (full spec, prototype, downstream assessment) before any CFI | Draft (2026-03-17) | Variable slot-timing infrastructure + shorter slots (~10s discussed; draft 8s): affects based-rollup L1 cadence, preconf timing, L1 finality, 4788 buffer sizes. Not scheduled. | raw eip-8198.md ; https://blog.ethereum.org/2026/09/07/protocol-hegota-eips | 2026-09-30 |
| 8205 | Withdrawal credentials preregistration | PFI [EF: DFI] | (CL) | none. | EIP-8081 | 2026-09-30 |
| 8298 | SETCODEFROM Code Reuse Instruction | PFI [A] | Draft (2026-06-11) | Sets an account's code hash from an existing contract (cheap clones); new opcode + code-dedup semantics for zkEVMs. | raw eip-8298.md | 2026-09-30 |
| 8304 | Trustless log and transaction index | PFI in meta; **DFI decided ACDE #246** (PR #12377 note; punted for discussion on agenda) | Draft (2026-06-17) | Would have given trustless log lookups useful to bridges/relayers; declined. | raw eip-8304.md ; https://github.com/ethereum/EIPs/pull/12377 | 2026-09-30 |
| 8333 | Align Checkpoint with Epoch Boundary Block | PFI [EF: DFI] | (CL) | none. | EIP-8081 | 2026-09-30 |
| 8355 | Precompiles for ML-DSA verification | PFI [C] | Draft (2026-07-30) | Post-quantum signature precompiles; L2s would mirror. | raw eip-8355.md | 2026-09-30 |
| 8363 | Tapered Issuance Burn | PFI [EF: DFI]; sheet: "leaning DFI" | (CL/econ) | none. | decisions sheet | 2026-09-30 |
| 8365 | BLS withdrawal credential retirement | PFI [A]; sheet: "lean CFI, reduced scope" | Draft (2026-07-18) | none for L2s. | raw eip-8365.md ; decisions sheet | 2026-09-30 |
| 8368 | CPSB Recalibration for New Gas Limit | PFI [TBD] — decision after 30 days Glamsterdam mainnet data | Draft (2026-08-05) | Re-derives EIP-8037 cost-per-state-byte; changes L1 state-creation pricing for L2 contracts. | raw eip-8368.md ; PR #12377 | 2026-09-30 |
| 8369 | VOPS Profiles for FOCIL Eligibility | PFI [A]; sheet: "Informational, needs EL input" | Draft (2026-08-05) | Defines which txs get IL enforcement under FOCIL: determines whether L2 batch/forced-inclusion txs benefit from FOCIL. | raw eip-8369.md | 2026-09-30 |
| 8371 | RowDAS - Distributed Blob Reconstruction | PFI [C] | Draft (2026-08-05) | CL networking for blob reconstruction; indirectly enables higher blob counts (blob capacity itself moves via BPO forks, EIP-7892). | raw eip-8371.md | 2026-09-30 |
| 8372 | Normalized state gas limit | PFI [TBD] — after Glamsterdam mainnet data | Draft (2026-08-06) | Rescales state-gas limit vs execution gas; L1 cost of state-heavy L2 contract calls. | raw eip-8372.md | 2026-09-30 |
| 8379 | Top-up Sync | PFI [EF: DFI] | (CL) | none. | EIP-8081 | 2026-09-30 |
| 8383 | Reduce CL Block Retention Window | PFI [A] | Draft (2026-08-17) | Beacon block retention → 8192 epochs; CL-proof bridges relying on old beacon blocks need to fetch within the window. | raw eip-8383.md | 2026-09-30 |

Not yet in master but in flight: **EIP-8411** (segmented execution-payload propagation, PFI'd at ACDC #187 per PR #12364; raw file 404 on master), **EIP-8334** Bundled Attestation Propagation, **EIP-8374** Persist Warm Access Sets Across Reverts (EIPs PR #12128), **EIP-8358** Net Gas Metering for Account Changes, **EIP-8360** TCREATE (PFI PR #12074 still open; "placeholder" per ACDE #245). All **VERIFIED as absent from master (HTTP 404) on 2026-09-30**; their tier/status comes from the EF post and PR descriptions.

### 2d. Declined for Inclusion (DFI) — VERIFIED from EIP-8081 master (18 EIPs)

| EIP | Title | Decided | Effect on L2s |
|---|---|---|---|
| 2488 | Deprecate the CALLCODE opcode | ACDE #245 | none (declined) |
| 7645 | Alias ORIGIN to SENDER | ACDE #245 | none |
| 7807 | SSZ execution blocks | ACDE #245 | none (would have changed L1 block format for bridges) |
| 7819 | SETDELEGATE instruction (7702 extension) | ACDE #245 | none |
| 7851 | Code-Controlled EOA Delegation (7702 extension) | ACDE #245 | none |
| 7862 | Delayed State Root | ACDE #245 | none (would have affected L1 state-root timing for based rollups) |
| 7923 | Linear, Page-Based Memory Costing | ACDE #245 | none |
| 8094 | eth/vhash - Blob-Aware Mempool | ACDE #245 | none |
| 8115 | Batch priority fees at end of block | ACDE #245 | none |
| 8146 | Block Access List Sidecars | ACDC #187 | none |
| 8182 | Private ETH and ERC-20 Transfers | ACDE #245 | none |
| 8188 | Last-Written Block for Accounts and Slots | ACDE #245 | none |
| 8200 | EVMification (replace RIPEMD/MODEXP/BLAKE2f precompiles) | ACDE #245 | none |
| 8219 | Checked Arithmetic Opcodes | ACDE #245 | none |
| 8237 | Independent CL/EL Sync | ACDC #187 | none |
| 8243 | Batching Attestations at Source | ACDC #187 | none |
| 8304 | Trustless log and transaction index | ACDE #246 (moved by PR #12377; listed under PFI in the fetched master — check next revision) | none |
| 8321 | Hash-Chain RANDAO | ACDC #187 ("still work on well before I-star fork") | none |

Also DFI per decisions sheet / PR #12364 but not yet in master because the EIPs are unmerged: 8341 Partial Execution Payload Commitments, 8367 Balance sunset for retired BLS validators, 8375 ePBS Mandatory Burn of Execution Rewards. **VERIFIED via sheet and PR text.**

### 2e. Requested candidates NOT in the Hegotá meta

| EIP | Title | Hegotá status | EIP status | Effect on L2s | Source | Fetched |
|---|---|---|---|---|---|---|
| 8079 | Native rollups (EXECUTE precompile) | **Not proposed** — absent from EIP-8081 (all four lists) and from the EF tier list; no "Hegotá Headliner Proposal" thread found on Magicians (only FOCIL, Frame Transaction, EIP-8105 EEM found). PoC exists (ethrex PR #6186, March 2026). | Draft (2025-11-13); precompile address `TBD` | For Taiko: no L1 EXECUTE precompile in Hegotá; EIP-8025 optional execution proofs is the nearest groundwork. | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8079.md ; https://ethereum-magicians.org/t/eip-8079-native-rollups/26565 | 2026-09-30 — negative claim UNVERIFIED (search-based) |
| 7782 | Reduce Block Latency (12s→6s) | Not in EIP-8081; declined in Glamsterdam; superseded by EIP-8198 Quick Slots (PFI, B-tier) | Draft (2024-10-05) | See 8198. | raw eip-7782.md | 2026-09-30 |
| 7732 | Enshrined Proposer-Builder Separation (ePBS) | **Glamsterdam SFI**, not Hegotá | Review (2024-06-28) | ePBS ships before Hegotá; Hegotá follow-ups are 8411 (payload propagation, PFI) and 8375 (mandatory burn, DFI). ePBS empty-slot cases affect EIP-4788 root availability (see 4788 row). | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7773.md | 2026-09-30 |
| — | Attester-Proposer Separation / Execution Tickets | **No EIP, not proposed** for Hegotá; remains ethresear.ch research (Execution Tickets thread 17944). | n/a | none in Hegotá. | https://ethresear.ch/t/execution-tickets/17944 | 2026-09-30 — negative claim UNVERIFIED |
| 7701 | Native Account Abstraction | **Withdrawn**; superseded by 8141 | Withdrawn (2024-05-01) | none. | raw eip-7701.md | 2026-09-30 |
| 8130 | Keystore Accounts (AA alternative favoured by Base/Offchain Labs) | Not in EIP-8081; lost to 8141 on ACDE #244; proponents to work on Frame modifications | Draft (2025-10-14) | L2-friendly AA design (shared cross-chain keystore, no EVM changes) — not adopted. | raw eip-8130.md ; christinedkim acde-244 | 2026-09-30 |
| 7702 extensions | EIP-7819 SETDELEGATE, EIP-7851 Code-Controlled EOA Delegation | **DFI** (ACDE #245) | Draft | none. | EIP-8081 | 2026-09-30 |
| 2780 | Resource-based intrinsic transaction gas | **Glamsterdam SFI** (not Hegotá) | Review (2020-07-11) | Repricing lands one fork earlier. | raw eip-7773.md | 2026-09-30 |
| 8038 | State-access gas cost update | **Glamsterdam SFI** (with 8037 State Creation Gas Cost Increase) | Review (2025-10-03) | Same; Hegotá only recalibrates via 8368/8372 (PFI, TBD). | raw eip-7773.md | 2026-09-30 |
| 7864 | Ethereum state using a unified binary tree | **Not in EIP-8081**; no Hegotá proposal found; Verkle not on roadmap | Draft (2025-01-20) | No state-tree change in Hegotá; MPT proofs stay valid. | raw eip-7864.md | 2026-09-30 — negative claim UNVERIFIED |
| 4788 | Beacon block root in the EVM | **No Hegotá EIP modifies it.** Indirect: 8015 changes beacon SSZ layout (proof paths); 8253 orders its state bump before the 4788 system call; ePBS (Glamsterdam) can leave empty-payload beacon roots unrecorded (community HackMD analysis). | Final | Bridges/CL-proof consumers: re-derive generalized indices after 8015; handle ePBS root gaps. | raw eip-4788.md ; https://hackmd.io/@bchain/r1X_MVu5bg | 2026-09-30 (HackMD claim UNVERIFIED, secondary) |
| — | Blob changes | No blob-count EIP in Hegotá (capacity moves via EIP-7892 BPO forks). Related PFIs: 8142 Block-in-Blobs (EF: DFI), 8371 RowDAS (C-tier); 8094 blob-aware mempool DFI. | — | Blob supply/pricing unchanged by Hegotá itself. | EIP-8081 | 2026-09-30 |
| — | Contract nonce semantics | Two items: **8250** keyed nonces (frame-tx senders only; CFI) and **8253** nonce bump of 28 legacy accounts (CFI, also floated for Glamsterdam). No general change to CREATE nonce rules. | — | see rows above | EIP-8081 | 2026-09-30 |
| — | Inclusion lists | **7805 FOCIL SFI** (CL headliner) + 8369 VOPS profiles (PFI) defining eligibility. | — | see 7805 | EIP-8081 | 2026-09-30 |

## 3. Notes on the process state (2026-09-30)

- Client-team rankings were aggregated on Forkcast for the first scoping pass (ACDE #245). The seven highest-rated EL EIPs were 7906, 8250, 8272, 7668, 8253, 3298, 8131 (ACDE #246 agenda). **VERIFIED**
- The EF Protocol tier list (2026-09-07) is an *opinion* document; where it disagrees with the meta (e.g., it lists 8163 and 7979 as DFI, both now CFI), the meta EIP wins. **VERIFIED**
- Ethlabs, Lido, Prysm and Lodestar published their own tier lists in mid-September; Ethlabs pushes Quick Slots as S-tier. **VERIFIED** (Magicians meta-thread summary).
- The ACDE-244 write-up notes the 8141 SFI vote happened after a Base representative left the call and "does not preclude future modifications based on Layer-2 feedback". **VERIFIED (secondary source)**.

## 4. Sources (all fetched 2026-09-30)

Primary
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md (Hegotá meta, master)
- https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7773.md (Glamsterdam meta, master)
- Raw EIP files on master for: 7805, 8141, 8250, 8079, 7782, 7701, 2780, 8038, 7864, 8253, 8272, 7906, 8131, 8279, 3298, 7668, 8163, 7979, 8025, 8198, 8365, 8383, 8369, 8015, 5920, 8298, 8151, 4758, 8368, 8372, 8360, 8237, 8146, 8321, 8077, 7709, 8371, 8200, 7666, 8116, 8355, 7732, 7942, 7886, 7928, 8032, 4788, 7999, 8130, 7610, 8304, 8173, 8142 (pattern https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-NNNN.md). 404 on master: 8334, 8374, 8358, 8411, 8022, 8359, 8367, 8375, 8341.
- https://github.com/ethereum/EIPs/pull/12377 (ACDE 246 decisions, merged 2026-09-24)
- https://github.com/ethereum/EIPs/pull/12335 (ACDE 245 DFIs, merged 2026-09-14)
- https://github.com/ethereum/EIPs/pull/12364 (ACDC 187 decisions, merged 2026-09-21)
- https://github.com/ethereum/EIPs/pulls?q=is%3Apr+8081+sort%3Aupdated-desc
- https://github.com/ethereum/pm/issues/1930 (ACDC #175, 2026-02-19)
- https://github.com/ethereum/pm/issues/2177 (ACDC #184, 2026-08-06)
- https://github.com/ethereum/pm/issues/2197 (ACDE #244, 2026-08-27)
- https://github.com/ethereum/pm/issues/2211 (ACDE #245, 2026-09-10)
- https://github.com/ethereum/pm/issues/2222 (ACDC #187, 2026-09-17)
- https://github.com/ethereum/pm/issues/2223 (ACDE #246, 2026-09-24)
- https://github.com/ethereum/pm/issues/2227 (ACDC #188, 2026-10-01, scheduled)
- https://github.com/ethereum/execution-specs/issues/3664 (Hegotá EL tracker, 2026-09-28)
- https://blog.ethereum.org/2025/12/22/hegota-timeline
- https://blog.ethereum.org/2026/01/20/checkpoint-8
- https://blog.ethereum.org/2026/04/10/checkpoint-9
- https://blog.ethereum.org/2026/09/07/protocol-hegota-eips
- https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement
- https://ethereum.org/roadmap/hegota
- https://ethereum-magicians.org/t/eip-8081-hegota-network-upgrade-meta-thread/26876
- https://ethereum-magicians.org/t/hegota-headliner-proposal-frame-transaction/27618
- https://ethereum-magicians.org/t/eip-8079-native-rollups/26565
- https://docs.google.com/spreadsheets/d/1UVm9UurwCMWrtLAM7aKvMjdeMtZYSsm7ay8AMwo52AE (Hegotá ACD decisions sheet, "updated as of ACDC #187, 9/17/2026")

Secondary
- https://christinedkim.substack.com/p/acde-244 ; https://christinedkim.substack.com/p/acde-246 ; https://christinedkim.substack.com/p/acdc-187
- https://www.dlnews.com/articles/defi/ethereum-devs-lukewarm-on-buterin-backed-proposal-for-hegota/
- https://hackmd.io/@bchain/r1X_MVu5bg (EIP-4788 under ePBS)
- https://ethresear.ch/t/execution-tickets/17944

Fetch failures: api.github.com returned 403 for this session (repo not attached), `gh` not installed — worked around with github.com page fetches and raw.githubusercontent.com. forkcast.org pages are JS-rendered and returned only navigation.
