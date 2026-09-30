# 02. L1 roadmap survey: Glamsterdam and Hegota

Etna project, phase 2. Synthesis of `roadmap-glamsterdam.md`, `roadmap-hegota.md` and `roadmap-classification.md` (same directory). Every EIP status stated in this document was re-fetched from `raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-NNNN.md` on **2026-09-30** (local copies and a `status-table.txt` in `raw-survey/`). Tags: **VERIFIED** (primary source fetched at run time, URL given) or **UNVERIFIED**.

Etna requirements used as the yardstick: **R1** permissionless (no whitelist); **R2** reuse existing SignalService/Bridge/Vault addresses; **R4** 1-second L2 preconfirmed blocks; **R5** no dependence on the CL proposer lookahead and no coupling to L1 slot time (12 s / 6 s / 4 s / 2 s must all work; may consume EIP-4788 roots); **R6** permissionless slashing verifiable on L1; **R7** propose-with-proof in one L1 action, blobs for DA. Baseline assumption: Frame Transactions (EIP-8141) are live before Etna launches.

## 0. Summary and the minimum L1 dependency set

Headline: **nothing scheduled for Glamsterdam or Hegotá is a hard dependency for Etna, and nothing in either fork breaks R1–R7 provided the "tolerate" notes below are honoured.** Etna can launch on today's Fusaka mainnet. The forks change Etna's *environment* (ePBS timing, gas repricing, header layout) more than its *primitives*.

Glamsterdam status snapshot (VERIFIED, EIP-7773 master, 2026-09-30): 18 core EIPs SFI, headliners ePBS (EIP-7732) and BALs (EIP-7928); Sepolia activation epoch 353024 = 2026-10-06 13:53:36 UTC; Hoodi and mainnet not set. Hegotá snapshot (VERIFIED, EIP-8081 master, last commit 2026-09-24 "Decisions from ACDE246"): SFI = FOCIL (EIP-7805) and Frame Transaction (EIP-8141); CFI = 11 EIPs; PFI = 25; DFI = 18; ethereum.org says "Q2 2027 · Date not yet confirmed". Slot time stays 12 s in every published config (VERIFIED, eth-clients mainnet/sepolia/hoodi `SLOT_DURATION_MS: 12000`).

### REQUIRED (all already live on mainnet; none comes from Glamsterdam or Hegotá)

- **EIP-4844 blob transactions + `BLOBHASH` + KZG point-evaluation precompile (0x0A, 50 000 gas)** — R7 DA and binding of the ZK proof to blob content. Status `Final`, VERIFIED (https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-4844.md). Fallback: **cannot launch without it** (calldata DA would violate R7 and, after EIP-7976, costs 64 gas/byte at the floor).
- **EIP-7594 PeerDAS as deployed** (sender-computed cell proofs; mainnet max 21 blobs/block since BPO2 epoch 419072). `Final`, VERIFIED (eip-7594.md; https://raw.githubusercontent.com/eth-clients/mainnet/main/metadata/config.yaml). Fallback: none needed; it is the baseline Etna tooling already targets.
- **EIP-7825 transaction gas cap (2^24 = 16 777 216)** — a *constraint* the single propose-with-proof tx must satisfy. `Final`, VERIFIED (eip-7825.md). Fallback: cap proofs/batches per tx; keep verifier gas well under ~10 M so the tx also fits a 2-s-slot block (see §5).
- **EVM primitives for verification and slashing**: `ecrecover` (with the EIP-8151 caveat, §4) and/or EIP-2537 BLS12-381 precompiles (`Final`, VERIFIED eip-2537.md); `block.timestamp` for all deadlines (R5); `PREVRANDAO` (EIP-4399 `Final`, VERIFIED) if randomness is needed; `BLOCKHASH` / EIP-2935 (`Final`, VERIFIED, 8191-block history contract) for anchoring recent L1 hashes. Fallback: none needed; all live.
- **No consensus-layer dependency at all**: no proposer lookahead (EIP-7917), no slot-length constant, no builder/relay API, no FOCIL, no EXECUTE precompile.

### OPTIONAL (Etna works without; adopting improves cost, latency, safety or simplicity)

- **EIP-8141 Frame Transactions** (Hegotá SFI, `Draft`) — baseline-assumed: sponsored/contract-sender blob-carrying proposals, atomic multi-frame propose+prove+bond, mempool-enforced timestamp expiry, validation-controlled nonce ("nonce as lock"). Degrades to type-3 txs from an EOA / EIP-7702 EOA (`Final`).
- **EIP-4788 beacon roots** (`Final`) + **EIP-7688** stable gindices (Glamsterdam SFI) — proving L1 validator facts (e.g. an L1-validator-backed preconfer's slashing under R6). Not mandatory; the registry can be self-contained.
- **EIP-7805 FOCIL** (Hegotá SFI) + **EIP-8369** VOPS profiles (PFI) — L1-level censorship-resistance floor for small forced-inclusion / slashing / registration txs. Post-launch; not for blob txs.
- **EIP-8272 recent roots** and **EIP-8250 keyed nonces** (Hegotá CFI) — mempool-level invalidation of race-losing proposals; concurrent submissions via private channels.
- **EIP-7843 SLOTNUM** (Glamsterdam SFI) — the only slot-length-agnostic slot primitive if any per-slot logic is ever wanted.
- **EIP-7892 BPO forks** (more blob capacity, no Etna change), **EIP-8261 / EIP-7928** (200 M gas limit enabler: lower base-fee pressure), **EIP-2780** (value-less call intrinsic 15 000 instead of 21 000), **EIP-7954** (64 KiB code), **EIP-7997** (deterministic factory).

### IGNORED (no dependency, no meaningful benefit; "tolerate" = environment changes the design must survive)

- **Tolerate — ePBS (EIP-7732)**: payload revealed at 50 % of slot, canonical-in-practice at slot N+1, *Empty* slots, builder monopoly on same-slot ordering.
- **Tolerate — header/proof formats**: `block_access_list_hash` (7928), `slotNumber` (7843), empty `logsBloom` (7668, Hegotá CFI), CL merkleization (7688), beacon SSZ layout (8015, Hegotá CFI).
- **Tolerate — gas repricing**: 8037 (97 920 state gas per new slot), 8038 (`STORAGE_WRITE` 10 000), 7778 (refunds excluded from block accounting), 7976 (64 gas/byte calldata floor), 7981, 3298/8131/8279 (Hegotá CFI), 8368/8372 recalibration (PFI, TBD), 7709 BLOCKHASH repricing (PFI).
- **Tolerate — mempool/DA environment**: 8070 sparse blobpool, 7918 blob reserve price (8192 × base fee per blob, live), 8142 Block-in-Blobs (EF: DFI).
- **Tolerate — slot time**: 7782 (Glamsterdam DFI), 8198 Quick Slots (Hegotá PFI, B-tier): all Etna timing in seconds / `block.timestamp`.
- **Tolerate — R6 hazard**: 8151 account-code-restricted ecRecover (PFI, A-tier) + 8298 SETCODEFROM (PFI, A-tier).
- **Ignore outright**: 8045, 8061, 8282, 7904, networking EIPs (7975/8136/8159/8189), 8253/7610, 7886, 7999, 8079 native rollups (not proposed), 8163, 8025, all CL-economics PFIs, the full Glamsterdam and Hegotá DFI lists, 7864 binary tree (unscheduled; latent R2 risk), APS/execution tickets (no EIP).

## 1. Method and date

All facts were fetched on **2026-09-30** from primary sources: the raw GitHub `master` copy of every EIP cited (`https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-NNNN.md`), the Gloas consensus specs (`https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/gloas/{beacon-chain,fork-choice,validator}.md`), the eth-clients network configs (`https://raw.githubusercontent.com/eth-clients/{mainnet,sepolia,hoodi}/main/metadata/config.yaml`), EF blog posts, ethereum.org roadmap pages, ethereum/pm agenda issues and the GitHub commit histories of the two meta EIPs. Where a claim rests only on a secondary write-up (e.g. a call recap on Substack), or where a fetch failed, it is tagged UNVERIFIED. ACD *meeting decisions* are only VERIFIED when they have been merged into the meta EIP on `master`; agenda issues show what was *proposed*, not what was decided (the fetched pm issues 2222, 2223, 2227, 2234 carry agendas only, no recorded outcomes — VERIFIED by fetching them).

Two different notions of "status" appear in this document and must not be conflated:

1. **EIP `status:` field** (front matter of the EIP file): `Draft` → `Review` → `Last Call` → `Final`, or `Stagnant` / `Withdrawn`. This tracks *document maturity*, not deployment. Example: EIP-7805 FOCIL is the locked-in Hegotá headliner but its file says `status: Draft` (VERIFIED); EIP-7610 is `Last Call` yet was removed from Glamsterdam (VERIFIED, commit f9976e6, 2026-08-20).
2. **Fork-inclusion status** per EIP-7723 "Network Upgrade Inclusion Stages" (`Last Call`, VERIFIED, https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7723.md): **PFI** Proposed for Inclusion, **CFI** Considered for Inclusion, **SFI** Scheduled for Inclusion, **DFI** Declined for Inclusion, and finally `Included`. EIP-7723 also says that when a meta EIP moves to `Review` "the `Proposed for Inclusion` and the `Declined for Inclusion` list **SHOULD** be removed" (VERIFIED) — which is exactly why EIP-7773 (now `Review`) carries only an SFI list while EIP-8081 (`Draft`) still carries all four.

"Live" means activated on mainnet per the Fusaka meta EIP-7607 (`Final`, mainnet epoch 411392 = 2025-12-03 21:49:11 UTC, VERIFIED) or earlier.

## 2. Glamsterdam (Gloas + Amsterdam)

Meta EIP-7773, `status: Review`, requires 7607 and 7723; last three commits: 2026-08-27 "Move to Review", 2026-09-15 "Align listed EIP titles", 2026-09-17 "Set Sepolia activation time" (VERIFIED, https://github.com/ethereum/EIPs/commits/master/EIPS/eip-7773.md).

| EIP | Title | Inclusion status | EIP status | What it changes | Effect on L2s | Etna stance | Source (all fetched 2026-09-30) |
|---|---|---|---|---|---|---|---|
| 7732 | Enshrined Proposer-Builder Separation | **SFI** (CL headliner) | Review | Beacon block carries a builder *bid*; execution payload revealed separately (Sepolia `PAYLOAD_DUE_BPS: 5000`, `PAYLOAD_ATTESTATION_DUE_BPS: 7500`); slots can be Full / Skipped / *Empty* | Batch tx "included in slot N ... is not widely validated until the proposer of slot N+1 releases their beacon block on top of block N"; blobs surface ~half a slot later; new empty-slot failure mode | IGNORES (tolerate) | raw eip-7732.md; sepolia config.yaml |
| 7928 | Block-Level Access Lists | **SFI** (EL headliner) | Review | Header gains `block_access_list_hash`; BAL in payload; enables parallel execution and the 200 M gas limit | Header parsers/provers must accept the new field; no per-tx gas change | OPTIONAL (indirect) | raw eip-7928.md |
| 2780 | Resource-based intrinsic transaction gas | SFI | Review | 21 000 decomposed; value-less call to a contract = 15 000 intrinsic | Cheaper batch txs; gas estimators must update | OPTIONAL (trivial) | raw eip-2780.md |
| 7976 | Increase Calldata Floor Cost | SFI | Review | Floor 10/40 → 64/64 gas per byte (`TOTAL_COST_FLOOR_PER_TOKEN` 16) | Calldata DA 1.6–6.4× costlier at the floor; pushes DA to blobs | IGNORES (tolerate) | raw eip-7976.md |
| 7981 | Increase Access List Cost | SFI | Review | +64 gas per access-list byte | Only if batch txs carry EIP-2930 lists | IGNORES | raw eip-7981.md |
| 7778 | Block Gas Accounting without Refunds | SFI | Review | Refunds no longer reduce gas counted against the block limit | Refund-heavy bookkeeping consumes more block capacity | IGNORES (tolerate) | raw eip-7778.md |
| 8038 | State-access gas cost update | SFI | Review | `COLD_ACCOUNT_ACCESS` 2 600→3 000; `STORAGE_WRITE` 10 000 (net-metered); `ACCOUNT_WRITE` 9 000 | Every SSTORE in L1 rollup contracts costs more | IGNORES (tolerate) | raw eip-8038.md |
| 8037 | State Creation Gas Cost Increase | SFI | Review | `CPSB` 1 530 gas per new state byte; new slot 64×1 530 = 97 920 state gas; new account 183 600; `TX_MAX_TOTAL_GAS_LIMIT` 2^32−1 | Fresh-slot writes and deployments far costlier; state gas escapes the 7825 cap | IGNORES (tolerate) — largest gas impact | raw eip-8037.md |
| 7708 | ETH transfers emit a log | SFI | Review | LOG3 `Transfer` from `SYSTEM_ADDRESS` on every non-zero ETH transfer | Receipt/indexer parsing sees new logs | IGNORES (tolerate) | raw eip-7708.md |
| 7843 | SLOTNUM opcode | SFI | Review | Opcode `0x4b` returns the CL slot; header gains `slotNumber` | Slot-length-agnostic slot access; header layout change | OPTIONAL | raw eip-7843.md |
| 7954 | Increase Maximum Contract Size | SFI | Review | Code 24→64 KiB, initcode 48→128 KiB | Larger monolithic L1 contracts (but 8037 charges `CPSB`/byte) | OPTIONAL | raw eip-7954.md |
| 7997 | Deterministic Factory Contract | SFI | Review | Guaranteed CREATE2 factory at `0x4e59…956C` | Identical-address deployments L1/L2 | OPTIONAL (minor) | raw eip-7997.md |
| 8024 | Backward compatible SWAPN, DUPN, EXCHANGE | SFI | Review | New stack opcodes `0xe6–0xe8` | Type-1 L2 EVM must add them | IGNORES (tolerate) | raw eip-8024.md |
| 8246 | Remove SELFDESTRUCT Burn | SFI | **Last Call** | Residual burn cases preserve balance | Equivalence item | IGNORES (tolerate) | raw eip-8246.md |
| 7688 | Forward compatible consensus data structures | SFI | Review | CL merkleization → `ProgressiveContainer`; "serialization ... is unchanged"; stable gindices | Beacon-proof verifiers update once, then stop tracking forks | OPTIONAL | raw eip-7688.md |
| 8045 | Exclude slashed validators from proposing | SFI | Review | CL proposer selection (requires 7917) | Lookahead detail; Etna does not use the lookahead (R5) | IGNORES | raw eip-8045.md |
| 8061 | Increase exit and consolidation churn | SFI | Review | Staking churn; weak-subjectivity ~7 days | None | IGNORES | raw eip-8061.md |
| 8282 | Builder Execution Requests | SFI | Review | Builder deposit/exit predeploys on the EIP-7685 bus | Only if an L2 team runs an in-protocol builder | IGNORES | raw eip-8282.md |
| 7975 / 8070 / 8136 / 8159 / 8189 | eth/70 partial receipts; eth/72 sparse blobpool; cell-level deltas; eth/71 BAL exchange; snap/2 BAL healing | Networking | 8070: Review (others not analysed) | Node-to-node protocols; 8070: nodes fetch full blobs with probability 0.15 and "MAY drop" a blob tx | Blob-tx propagation for batchers | IGNORES (8070: tolerate) | raw eip-7773.md; raw eip-8070.md |
| 8261 | Gas Limit Schedule | Informational | Review | CL `GAS_LIMIT_SCHEDULE` default/recommended max; "No consensus rules are changed" | Sepolia: 200 M at epoch 353024; mainnet: no entry | OPTIONAL (indirect) | raw eip-8261.md; sepolia/mainnet config.yaml |
| 7904 | Compute Gas Cost Analysis | Informational | Review | Analysis only; no precompile repricing scheduled | Verifier precompile costs unchanged | IGNORES | raw eip-7904.md |
| 7805 | FOCIL | **DFI** (per 2026-08-20 revision f9976e6); Hegotá SFI | Draft | — | See §3/§4 | OPTIONAL (post-launch) | raw eip-7773.md@f9976e6 (via input file); raw eip-7805.md |
| 7782 | Reduce Block Latency (6 s) | **DFI** | Draft | Would halve slot, gas limit and blob limits per block | Not in Glamsterdam | IGNORES (tolerate) | raw eip-7782.md |
| 7886 | Delayed execution | DFI | Stagnant | Superseded by ePBS deferred validation | None | IGNORES | raw eip-7886.md |
| 7610 | Revert creation in case of non-empty storage | Removed (commit f9976e6) | Last Call | — | None | IGNORES | commit history |
| 8253 | Bump nonce of zero-nonce storage accounts | Proposed at ACDE #245 for Glamsterdam; **not in EIP-7773 master**; Hegotá CFI | Draft | 28 mainnet accounts get nonce 1 | None ("chains which never had such accounts ... MAY ignore") | IGNORES | raw eip-8253.md |

Full Glamsterdam DFI list (last carried in revision f9976e6, 2026-08-20; taken from `roadmap-glamsterdam.md`, which fetched that revision — VERIFIED there, not re-fetched here): 2926, 5920, 6404, 6466, 7610, 7619, 7668, 7686, 7692 (EOF), 7745, 7782, 7791, 7793, 7805, 7819, 7872, 7886, 7903, 7907, 7919, 7923, 7932, 7937, 7942, 7949, 7971, 7973, 7979, 8011, 8013, 8030, 8032, 8051, 8053, 8057, 8058, 8059, 8062, 8068, 8071, 8080, 8254.

### Timing and activation

| Network | Epoch | Timestamp | UTC | Status |
|---|---|---|---|---|
| Sepolia | 353024 (slot 11 296 768) | 1791294816 | 2026-10-06 13:53:36 | **Scheduled** — VERIFIED (EIP-7773 activation table; `GLOAS_FORK_EPOCH: 353024` in eth-clients/sepolia config; EF blog https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement, article dated 2026-09-28) |
| Hoodi | — | — | — | **Not set** — VERIFIED (EIP-7773 row empty; no `GLOAS_FORK_EPOCH` in hoodi config; EF blog: "Hoodi and mainnet activation dates have not yet been decided"). Proposal on ACDC #187 agenda: "27 oct? would line up an early Dec mainnet date" (VERIFIED as an agenda line, https://github.com/ethereum/pm/issues/2222; decision UNVERIFIED) |
| Mainnet | — | — | — | **Not set** — VERIFIED (same sources). ethereum.org: "Q4 2026 · Date not yet confirmed" (VERIFIED, https://ethereum.org/roadmap/glamsterdam/). "Early December" is an estimate only (UNVERIFIED as a decision) |

Other Glamsterdam facts:
- Slot time unchanged: `SECONDS_PER_SLOT: 12` / `SLOT_DURATION_MS: 12000` on mainnet, Sepolia, Hoodi (VERIFIED, eth-clients configs). Gloas intra-slot deadlines on Sepolia: `ATTESTATION_DUE_BPS_GLOAS: 2500`, `PAYLOAD_DUE_BPS: 5000`, `PAYLOAD_ATTESTATION_DUE_BPS: 7500` (VERIFIED).
- No blob-parameter change: Sepolia and mainnet `BLOB_SCHEDULE` end at BPO2 (max 21); mainnet BPO1 epoch 412672 (2025-12-09), BPO2 epoch 419072 (2026-01-07) (VERIFIED, configs).
- Gas limit: Sepolia `GAS_LIMIT_SCHEDULE: 200000000 @ 353024` (VERIFIED). EF blog: Prysm and Teku "default to 60M after activation" and "Validators wishing to propose with a 200M gas limit must configure it explicitly" (VERIFIED). ACDE #246 agenda item "Gas limit increase: 200M good to go?" (VERIFIED as agenda, https://github.com/ethereum/pm/issues/2223); mainnet outcome UNVERIFIED; mainnet config has no `GAS_LIMIT_SCHEDULE` (VERIFIED).
- Client releases for Sepolia (VERIFIED, EF blog): Grandine, Lighthouse, Lodestar 1.49.0, Nimbus 26.9.0, Prysm 7.2.0, Teku 26.9.1; Besu 26.9.0, Ethrex 28.0.0, Erigon 3.7.0, go-ethereum 1.17.6, Nethermind 2.0.0, Reth 2.7.0.
- ethereum.org still says scope is "frozen but can still change before mainnet" (VERIFIED).

## 3. Hegotá (Heze + Bogotá)

Meta EIP-8081, `status: Draft`, created 2025-11-11, requires 7723 and 7773. Last commit 2026-09-24 `95176db` "Decisions from ACDE246"; preceding: 2026-09-23 add 8383 to PFI, 2026-09-21 "Decisions from ACDC187", 2026-09-14 "DFI decisions from ACDE245" (VERIFIED, https://github.com/ethereum/EIPs/commits/master/EIPS/eip-8081.md). All list memberships below were read from the `master` file on 2026-09-30 (VERIFIED). EF tier (S/A/B/C/DFI/TBD) is from the EF Protocol post of 2026-09-07 (VERIFIED, https://blog.ethereum.org/2026/09/07/protocol-hegota-eips) and is an *opinion* document; where it disagrees with the meta (8163 and 7979 are EF "DFI" but meta CFI), the meta wins.

| EIP | Title | Inclusion status | EIP status | What it changes | Effect on L2s | Etna stance | Source (all fetched 2026-09-30) |
|---|---|---|---|---|---|---|---|
| 7805 | Fork-choice enforced Inclusion Lists (FOCIL) | **SFI** (CL headliner; EF S-tier) | Draft | IL committee force-includes public-mempool txs; "Attesters only vote for the proposer's block if it includes transactions from all stored ILs" | Censorship-resistance floor for L1 txs of L2s; no blob-tx coverage | OPTIONAL | raw eip-7805.md |
| 8141 | Frame Transaction | **SFI** (EL headliner; EF S-tier) | Draft | Tx type with validation/payment/execution frames, `ATOMIC_BATCH_FLAG`, expiry verifier, `ORIGIN` = frame caller, no access list, blob-carrying variant | Type-1 zkEVMs must add the type; `tx.origin` assumptions break | OPTIONAL (baseline) | raw eip-8141.md |
| 3298 | Remove storage-clear refund and refund cap | CFI (A) | Draft | No SSTORE clear refund | Bookkeeping deletions earn nothing back | IGNORES (tolerate) | raw eip-3298.md |
| 7668 | Remove bloom filters | CFI (C) | Stagnant | `logsBloom` empty in header and receipts | Header RLP shape changes for L1-header provers | IGNORES (tolerate) | raw eip-7668.md |
| 7906 | Transaction Assertions via State Diff Opcode | CFI (A) | Draft | `POST_TX` frame + `TXDIFF`-style opcodes | zkVM backlog | IGNORES (tolerate) | raw eip-7906.md |
| 7979 | Call and Return Opcodes | CFI (EF: DFI) | Draft | Subroutine opcodes | zkVM backlog | IGNORES (tolerate) | raw eip-7979.md |
| 8015 | Remove `deposit` and `eth1data` fields | CFI (A) | Draft | Beacon SSZ layout change | 4788-proof gindices for removed fields | IGNORES (tolerate) | raw eip-8015.md |
| 8131 | Unified Transaction Content Floor | CFI (A) | Draft | 64 gas/byte over every user-controlled field incl. blob hashes | +2 048 floor gas per blob hash; non-binding for verifier txs | IGNORES (tolerate) | raw eip-8131.md |
| 8163 | Reserve `EXTENSION (0xae)` | CFI (EF: DFI) | Review | Reserves an opcode prefix for non-L1 EVMs | None for a type-1 L2 | IGNORES | raw eip-8163.md |
| 8250 | Keyed Nonces for Frame Transactions | CFI (A) | Draft | Nonce keys in a `NONCE_MANAGER` (0x…8250); "preserves EIP-8141's limit of one pending frame transaction per sender in the public mempool" | Concurrent submissions only via private channels | OPTIONAL (limited) | raw eip-8250.md |
| 8253 | Bump nonce of zero-nonce storage accounts | CFI (B) | Draft | 28 legacy accounts, one-off | None | IGNORES | raw eip-8253.md |
| 8272 | Recent Roots for Frame Transactions | CFI (A) | Draft | `VERIFY` frame against `(source_id, slot, root)`; failure "invalidates the transaction" | Mempool-validated preconditions for L2 proposals | OPTIONAL | raw eip-8272.md |
| 8279 | Block Access List Byte Floor | CFI (A) | Draft | BAL bytes metered at 64 gas/byte into the floor | Never binds for few-slot verifier txs | IGNORES (tolerate) | raw eip-8279.md |
| 8198 | Quick Slots | PFI (B) | Draft | `SLOT_DURATION_MS` becomes runtime config; gas limit and blobs scale with slot length; 8 s placeholder | Per-block capacity shrinks, per-second constant | IGNORES (tolerate) | raw eip-8198.md |
| 8369 | VOPS Profiles for FOCIL Eligibility | PFI (A, Informational) | Draft | Defines which txs FOCIL enforces; blob txs "are not candidates for either profile" | Determines what L2 txs FOCIL protects | OPTIONAL | raw eip-8369.md |
| 8151 | Account Code Restricted ecRecover | PFI (A) | Draft | `ecrecover` returns zero for addresses with non-7702 code | Slashing-by-signature hazard (§4) | IGNORES (tolerate, R6 hazard) | raw eip-8151.md |
| 8298 | SETCODEFROM | PFI (A) | Draft | Copy another account's code hash | Interacts with 8151 | IGNORES (tolerate) | raw eip-8298.md |
| 8025 | Optional Execution Proofs | PFI (A) | Draft | Opt-in ZK execution proofs on the CL; no consensus change | Groundwork, not L2 proof verification | IGNORES (watch) | raw eip-8025.md |
| 7709 | Read BLOCKHASH from storage | PFI (B) | Draft | `BLOCKHASH` served from EIP-2935 storage at SLOAD-like cost; window stays 256 | ~2 100 gas per anchored hash | IGNORES (tolerate) | raw eip-7709.md |
| 8368 / 8372 | CPSB recalibration / normalized state gas limit | PFI (TBD, after 30 days of Glamsterdam mainnet data) | Draft | Re-derive state-gas pricing | State-creation cost may move again | IGNORES (tolerate) | raw eip-8368.md, eip-8372.md |
| 8383 | Reduce CL Block Retention Window | PFI (A) | Draft | `MIN_EPOCHS_FOR_BLOCK_REQUESTS = 8192` | CL-proof consumers fetch within ~36 days | IGNORES (tolerate) | raw eip-8383.md |
| 8142 | Block-in-Blobs | PFI (EF: DFI) | Draft | L1 payload + BAL published as blobs | Competes for blob space | IGNORES (tolerate) | raw eip-8142.md |
| 4758 / 5920 | Deactivate SELFDESTRUCT / PAY | PFI (A / A) | Stagnant / Draft | SENDALL semantics; value transfer without call | Equivalence items | IGNORES (tolerate) | raw eip-4758.md, eip-5920.md |
| 8304 | Trustless log and transaction index | **DFI** on master (moved PFI → DFI by commit `95176db`, 2026-09-24, ACDE #246) | Draft | Provable log lookups | Declined | IGNORES | raw eip-8304.md; raw eip-8081.md (corrected after skeptic review) |
| 7666, 7716, 8077, 8116, 8148, 8173, 8205, 8333, 8355, 8363, 8365, 8371, 8379 | remaining PFIs | PFI | (various) | Precompile EVM-ification, CL economics, networking, receipts, ML-DSA, RowDAS | None or equivalence-only | IGNORES | raw eip-8081.md |
| 2488, 7645, 7807, 7819, 7851, 7862, 7923, 8094, 8115, 8146, 8182, 8188, 8200, 8219, 8237, 8243, 8304, 8321 | DFI list (18) | **DFI** | (various) | Notable: 7862 Delayed State Root declined (would have delayed SignalService storage-proof availability, R2); 7807 SSZ blocks declined (header stays RLP) | None | IGNORES | raw eip-8081.md |
| 8079 | Native rollups (EXECUTE precompile) | **Not proposed** (absent from all four lists) | Draft | `EXECUTE_PRECOMPILE_ADDRESS` = `TBD` | Etna verifies its own proofs | IGNORES | raw eip-8079.md; raw eip-8081.md |
| 7732 / 7782 / 7864 / 7701 / 8130 | ePBS / 6-s slots / binary tree / native AA / Keystore Accounts | Not in Hegotá (7732 is Glamsterdam SFI; 7701 Withdrawn) | Review / Draft / Draft / Withdrawn / Draft | — | — | see §2 / IGNORES | raw files |

Not yet merged to `master` but in flight (raw fetch 404 on 2026-09-30, VERIFIED absent): 8411 segmented payload propagation (PFI'd at ACDC #187 per PR #12364), 8334, 8374, 8358 (per `roadmap-hegota.md`). EIP-8360 "TCREATE Opcode" does exist on `master` as `Draft` (HTTP 200, 2026-09-30) and is on the ACDE #245/#246 agendas as an open candidate, though absent from every EIP-8081 list (corrected after skeptic review).

### Process timeline (VERIFIED unless noted; sources in §7)

- 2025-12-22: EF publishes the Hegotá timeline; headliner proposal window 2026-01-08 → 02-04 (https://blog.ethereum.org/2025/12/22/hegota-timeline).
- 2026-02-19: FOCIL selected as CL headliner (ACDC #175; VERIFIED via the decisions sheet cited in `roadmap-hegota.md`, call notes not fetched).
- 2026-03-26: Frame Transactions demoted to CFI as EL headliner (EF Checkpoint #9, 2026-04-10).
- 2026-04-09 → 2026-08-06: non-headliner PFI window.
- 2026-08-27: EIP-8141 SFI'd as EL headliner at ACDE #244 (meta commit `e400af2`, 2026-08-27, "Update EIP-8081: SFI EIP-8141"; the 2026-09-02 commit `260de0b` only added EIP-8355 to PFI; the "specs may change" caveat is from a secondary recap — UNVERIFIED wording). (Corrected after skeptic review.)
- 2026-09-07: EF Protocol tier list published.
- 2026-09-10: ACDE #245 declines 12 EL EIPs (commit `aad37d7`, 2026-09-14: 2488, 7645, 7807, 7819, 7851, 7862, 7923, 8094, 8115, 8182, 8188, 8200; same-day commit `7c073a9` adds 8219 for 13; 8304 followed at ACDE #246). (Corrected after skeptic review.)
- 2026-09-17: ACDC #187 CL scoping (8015 CFI; commit `24c0edb`, 2026-09-21).
- 2026-09-24: ACDE #246 moves 10 EL EIPs to CFI (commit `95176db`, same day); 8368/8372 held for 30 days of Glamsterdam mainnet data.
- 2026-09-28: Hegotá EL devnet tracker opened (execution-specs #3664; per input file, not re-fetched).
- Upcoming: ACDC #188 2026-10-01 (agenda: Glamsterdam / Hegotá / Misc, no detail — VERIFIED, pm #2227); ACDE #247 2026-10-08 (same — VERIFIED, pm #2234); further EL scoping 2026-10-22; CFI decisions targeted "by Devcon" (Magicians thread, via input file).
- Mainnet: "Expected on mainnet Q2 2027 · Date not yet confirmed"; next milestone "Sepolia fork, 2027"; page last updated 2026-08-31 (VERIFIED, https://ethereum.org/roadmap/hegota). Activation table in EIP-8081 empty (VERIFIED).

## 4. Feature-by-feature notes for Etna

### 4.1 ePBS (EIP-7732, Glamsterdam SFI, Review)

*Guarantees* (VERIFIED, raw eip-7732.md; Gloas specs): the beacon block commits to a builder bid and `block_hash` before the payload is revealed; "There is no possible *unbundling* of the builder's payload in the same slot"; the next proposer gets 6 s and other validators 9 s to validate; the PTC attests at 75 % of the slot. Slots are *Full*, *Skipped* or *Empty* ("The beacon block has been included on-chain, but the committed execution payload has not"). The Gloas fork-choice spec requires `is_data_available(envelope.beacon_block_root)` before importing a payload and asserts `envelope.parent_beacon_block_root == state.latest_block_header.parent_root` (VERIFIED, fork-choice.md lines 698, 1125).
*Does NOT guarantee*: that a tx in the payload of slot N is executed or canonical when the beacon block for N is seen ("not widely validated until the proposer of slot N+1 releases their beacon block on top of block N"); that Etna's tx is included at all if the builder withholds (Empty slot); ordering among competing Etna proposals in one slot (the builder orders); reorg-safety against "a colluding set of proposers and attesters ... more than 20% of the total stake".
*How Etna uses it*: treat "payload revealed **and** slot N+1 built on Full" as L1 inclusion; make the losing side of a same-slot propose race cheap (early revert before proof verification, or mempool-invalid via 8141 expiry / 8272 roots); L2 derivation must tolerate Empty slots and a ~1.5-slot confirmation lag, hidden from users by 1-s preconfs (R4).
*If it slips*: nothing changes for Etna except that today's MEV-Boost timing (payload at t≈0, blobs by ~4 s) persists; the tolerate design is strictly more conservative.

### 4.2 Block-Level Access Lists (EIP-7928, Glamsterdam SFI, Review)

*Guarantees*: header `block_access_list_hash`; "BALs enable parallel disk reads, parallel transaction validation, parallel state root computation and executionless state updates" (VERIFIED). *Does NOT*: change any gas cost, or speed up a single sequential verifier tx; parallelism is across txs. *Etna use*: none directly; indirectly BALs justify the 200 M gas limit (`GAS_LIMIT_SCHEDULE` on Sepolia), which lowers base-fee pressure for Etna's ~1 tx per block. Any Etna code that RLP-decodes or ZK-proves L1 headers must accept the post-Gloas layout (`block_access_list_hash`, `slotNumber`). *If it slips*: gas limit likely stays 60 M; Etna unaffected.

### 4.3 FOCIL (EIP-7805, Hegotá SFI, Draft) with EIP-8369 (PFI, Informational)

*Guarantees* (VERIFIED, raw eip-7805.md): "Attesters only vote for the proposer's block if it includes transactions from all stored ILs"; 1-of-N honesty of IL committee members; ILs built "after processing the block for slot N" from "transactions pending in the public mempool"; `MAX_BYTES_PER_INCLUSION_LIST = 8 KiB`.
*Does NOT guarantee*: inclusion when the block is full or the tx no longer fits ("Conditional inclusion: ... accepting blocks that may lack some transactions from ILs if they cannot append the transactions to the end of the block or if they are full"; "If `T.gas` > `gas_left`, then jump to the next transaction"); any position/ordering; inclusion of txs that became invalid (nonce consumed); anything for private-mempool txs; and — critically for Etna — **blob-carrying txs**: EIP-7805's text never discusses blob transactions (VERIFIED: the only four "blob" matches in the file are `/blob/` GitHub URL path segments), and EIP-8369 states "EIP-4844 transactions and frame transactions with a non-empty `blob_versioned_hashes` list are not candidates for either profile" (VERIFIED). The blob exclusion is therefore design intent in an Informational EIP, not a consensus rule (UNVERIFIED as final behaviour).
*Etna use*: the L1 leg of forced inclusion — a small calldata request tx, a slashing submission or a registration — becomes 1-of-N-honest includable within ~1–2 slots; Etna's own protocol then enforces the L2-side ordering by a timestamp deadline. The blob-carrying propose-with-proof tx is *not* FOCIL-protected; permissionless proposal rights (R1) are the substitute.
*If it slips* (Hegotá is post-launch anyway): forced-inclusion deadline in seconds of L1 time, long enough that ordinary builder-competition inclusion is overwhelmingly likely; no design change.

### 4.4 Frame Transactions (EIP-8141, Hegotá SFI, Draft) — Etna baseline

*Guarantees* (VERIFIED, raw eip-8141.md): blob-carrying variant (`blob_versioned_hashes` in the envelope; `max_fee_per_blob_gas`; "the payer is also the blob-fee payer"); `ATOMIC_BATCH_FLAG` ("All frames in a batch must succeed, or all of them revert"); expiry verifier frame ("The call reverts unless `block.timestamp <= expiry_timestamp`") and `VERIFY`-frame failure invalidates the tx; "Ensure `tx.nonce == state[tx.sender].nonce`" with `APPROVE` incrementing the nonce; `ORIGIN` "returns frame's `caller` throughout all call depths"; no access list.
*Does NOT guarantee*: public-mempool acceptance of validation that reads mutable Inbox state ("Public mempool rules apply only to the validation prefix" with `MAX_VERIFY_GAS = 100_000`); more than one pending frame tx per sender in the public mempool (preserved even by 8250); a frozen spec — the meta's own commit history shows it was SFI'd only on 2026-08-27 (commit `e400af2`), and the EIP is `Draft`.
*Etna use*: sponsored/contract-account proposer, atomic propose+prove+bond, mempool-enforced timestamp expiry (slot-agnostic, R5), nonce-as-lock for same-slot races.
*If it slips*: propose-with-proof runs as a type-3 EIP-4844 tx from an EOA or an EIP-7702-delegated EOA (both `Final`, VERIFIED); sponsorship → proposer prefunds; atomicity → one contract call; expiry → on-chain `require(block.timestamp <= deadline)` that reverts (gas paid) instead of invalidating; races → ordinary nonces / replace-by-fee. Etna must ship with this fallback path implemented, since 8141 is `Draft` and Hegotá is "Q2 2027".

### 4.5 Slot time (EIP-7782 DFI in Glamsterdam; EIP-8198 Quick Slots, Hegotá PFI B-tier)

*Guarantees today*: 12 s on every network (VERIFIED, configs). EIP-8198 (VERIFIED): `SLOT_DURATION_MS` becomes runtime config; `fork_gas_limit = (parent_gas_limit * SLOT_DURATION_MS) // old_slot_duration_ms`; `new_max_blobs = (old_max_blobs * SLOT_DURATION_MS) // old_slot_duration_ms`; "Eight seconds is chosen as a reasonable placeholder value"; intra-slot deadlines "are specified in basis points ... and scale automatically"; EF lists four prerequisites before A-tier (VERIFIED, EF post). EIP-7782 (VERIFIED): "The first execution block after the fork needs to specify half the previous gas limit ... The blob target and limit are also halved".
*Does NOT guarantee*: any particular target (8 s, 10 s, 6 s); feasibility ("Whether the resulting absolute deadlines remain feasible is a phase 2 question"); that "Based rollups inherit L1 block time as their sequencing interval" applies to Etna — it does not, by R4.
*Etna use*: none; R5 mandates that every window is in seconds via `block.timestamp` and every capacity limit is per second, not per block (§5).
*If it slips*: nothing; if it ships, nothing, provided §5 is honoured.

### 4.6 Blobs / PeerDAS / BPO

*Guarantees* (VERIFIED): EIP-4844 `Final` (KZG precompile 50 000 gas); EIP-7594 `Final`, live in Fusaka; EIP-7892 BPO mechanism `Final`; mainnet max 21 blobs since epoch 419072; EIP-7918 `Final`: reserve price `BLOB_BASE_COST (2**13) * base_fee_per_gas` per blob. *Does NOT*: schedule any new blob count with Glamsterdam or Hegotá (VERIFIED absent from configs and metas); guarantee full-blob retention in the mempool after EIP-8070 (p = 0.15 providers). *Etna use*: blob DA (R7); fill blobs before posting (reserve price makes part-empty blobs wasteful); submit blob txs to provider nodes or builders. *If BPO3 slips*: capacity stays 21 per 12 s ≈ 224 KiB/s; Etna sizes batches per second.

### 4.7 EIP-4788 beacon roots (`Final`, live; unchanged by both forks)

*Guarantees* (VERIFIED, raw eip-4788.md): `HISTORY_BUFFER_LENGTH = 8191`, keyed by `timestamp % 8191`; "8191 roots provides about a day of coverage"; "even if the slot times were to change, we would continue to use at most 8191 storage slots". *Does NOT*: keep a wall-clock window under shorter slots (4.55 h at 2 s); record every beacon root under ePBS — the payload of slot N writes root(N−1) (Gloas: `envelope.parent_beacon_block_root == state.latest_block_header.parent_root`, VERIFIED), so an *Empty* slot N leaves root(N−1) unwritten (inference from the spec; no client test fetched — UNVERIFIED as observed behaviour); stable gindices across forks before 7688, and even after 7688 "verifiers that process historical data predating this EIP still need to support the original merkleization scheme". *Etna use*: optional proofs of L1 validator facts; fallback for a missing root: prove root(N−1) via `state.block_roots` under root(N). *If 7688 slips*: gindices keep moving each fork; keep the beacon-proof verifier upgradeable or avoid 4788 entirely.

### 4.8 Gas repricing (2780, 7778, 7976, 7981, 8037, 8038 — all Glamsterdam SFI, Review; 3298/8131/8279 Hegotá CFI; 8368/8372 PFI TBD)

*Guarantees*: `STORAGE_WRITE` 10 000 net-metered; new slot 97 920 state gas; code deposit `CPSB` (1 530) per byte; intrinsic for a value-less contract call 15 000; calldata floor 64/64; state gas capped by `TX_MAX_TOTAL_GAS_LIMIT` (2^32−1) while EIP-7825's 2^24 "only applies to execution-gas" (all VERIFIED). *Does NOT*: reprice precompiles (7904 is Informational analysis; 8200 EVMification is Hegotá DFI) — so pairing/KZG verifier cost is unchanged; settle final values (8368/8372 wait for mainnet data). *Etna use*: O(1) SSTOREs per proposal into overwritten ring-buffer slots; never fresh slots on the hot path; price permissionless registrations (R1) at ≥97 920 state gas; upgrade existing proxies rather than redeploy (R2). *If it slips*: only cheaper.

### 4.9 Account abstraction

EIP-8141 is the only AA item scheduled (§4.4). EIP-7701 is `Withdrawn`; EIP-8130 Keystore Accounts is `Draft` and not in the meta; 7702 extensions 7819/7851 are Hegotá DFI (all VERIFIED). EIP-7702 itself is `Final` and is Etna's fallback smart-EOA path.

### 4.10 Nonce-semantics changes

Only two: **EIP-8250** keyed nonces (Hegotá CFI) — frame-tx senders only, `nonce_keys == [0]` aliases the legacy nonce, and the one-pending-per-sender public-mempool rule is preserved (VERIFIED); **EIP-8253** (Hegotá CFI; also floated for Glamsterdam — outcome UNVERIFIED, not in EIP-7773 master) — a one-off nonce bump on 28 legacy mainnet accounts, ordered "before any pre-execution system contract calls (e.g. ... EIP-4788)" (VERIFIED). No general change to EOA or `CREATE` nonce rules. Etna's one-tx-per-L1-block concurrency problem is not solved by L1; use multiple sender keys, builder-direct submission or 8141/8272 invalidation.

### 4.11 Native rollups / EXECUTE (EIP-8079, Draft)

Absent from EIP-8081's SFI/CFI/PFI/DFI lists and from the EF tier list; `EXECUTE_PRECOMPILE_ADDRESS` is `TBD` (VERIFIED). The nearest scheduled groundwork is EIP-8025 optional execution proofs (PFI, A-tier), which is "fully opt-in and does not change consensus validity rules" and does not verify L2 proofs. Etna verifies its own ZK proofs on L1; no path to a native-rollup dependency exists before 2027 at the earliest. (Negative claim "no Hegotá headliner proposal thread exists for 8079" is search-based — UNVERIFIED.)

## 5. Slot-time robustness table

Assumptions (VERIFIED): mainnet `SLOT_DURATION_MS: 12000`, max 21 blobs; EIP-7782 halves gas and blob limits at 6 s; EIP-8198 scales gas limit and max blobs by `new/old` and keeps 32 slots per epoch; EIP-4788 8191 roots keyed by timestamp; EIP-2935 8191 hashes, `BLOCKHASH` 256; EIP-7825 cap fixed; ePBS deadlines in basis points. The 4 s and 2 s columns extrapolate the 8198 rule — no EIP specifies those parameters (**UNVERIFIED as protocol values; arithmetic only**).

| L1 fact | 12 s (today) | 6 s (7782 rule) | 4 s (8198 rule, extrapolated) | 2 s (8198 rule, extrapolated) | Reliable? / Etna behaviour when everything is in seconds or L1 block numbers |
|---|---|---|---|---|---|
| Max one execution block per slot; Skipped/Empty slots possible | 1 / 12 s | 1 / 6 s | 1 / 4 s | 1 / 2 s | Reliable at all slot times. 1-s L2 blocks per L1 block: 12 / 6 / 4 / 2. Batch by *time*, never "one batch per L1 block"; at 2 s the verifier's fixed gas dominates unless proofs aggregate several L1 blocks of L2 blocks. |
| Gas per block (200 M schedule / 60 M today) | 200 M / 60 M | 100 M / 30 M | 66.7 M / 20 M | 33.3 M / 10 M | Changes. EIP-7825 cap (16.78 M) is fixed: a max-size propose tx is 8 % / 17 % / 25 % / 50 % of a 200 M-derived block and **does not fit** a 10 M block. Keep the propose tx under ~10 M. |
| Max blobs per block (from 21) | 21 | 10 | 7 | 3 | Changes per block, ~constant per second (~224 KiB/s). Batch-size cap must be per second; reserve price 8 192 × base fee per blob at every slot time. |
| Blob/payload inclusion latency under ePBS (content frozen at bid ≈ slot start; payload at 50 %; PTC 75 %; canonical-in-practice at N+1) | reveal +6 s; confirmed ≈ +12–18 s | +3 s; ≈ +6–9 s | +2 s; ≈ +4–6 s | +1 s; ≈ +2–3 s | Latency in *slots* is constant (~1.5), wall-clock shrinks. Preconfs (R4) hide it. Feasibility of sub-4-s deadlines is an open L1 question (8198 "phase 2"). |
| Reorg / finality (justification 32 slots, finality 64 slots) | 6.4 / 12.8 min | 3.2 / 6.4 min | 2.1 / 4.3 min | 1.1 / 2.1 min | Same *slot* depth. Windows in seconds are unaffected; anything counted in L1 block numbers now spans less wall-clock time — a "wait 64 L1 blocks" rule loses safety margin only in seconds, not in slots, so it is *safe but shorter*; a "wait 1 hour" rule stays 1 hour and covers *more* slots. ePBS adds Empty slots and the >20 %-stake payload reorg. |
| EIP-4788 root window (8191 roots) | 27.3 h | 13.65 h | 9.1 h | 4.55 h | Shrinks in wall-clock. Any 4788-based proof must be submitted within the window: size proving/slashing-evidence windows for ≤ 4.5 h or fall back to `historical_summaries` proofs. Empty slots leave root(N−1) unwritten at every slot time. |
| EIP-2935 (8191 blocks) / `BLOCKHASH` (256 blocks) | 27.3 h / 51 min | 13.65 h / 25.6 min | 9.1 h / 17 min | 4.55 h / 8.5 min | Shrinks. L1-hash anchoring must be within the window; at 2 s `BLOCKHASH` covers only 8.5 min. A window expressed in *block numbers* keeps working (same block count), one expressed in seconds may exceed the buffer. |
| Blob retention (`MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS` 4096 epochs) | 18.2 d | UNVERIFIED (7782 silent) | ≈ 18 d (8198: windows "scaled inversely to preserve wall-clock duration") | ≈ 18 d | Reliable in wall-clock under 8198. Etna nodes syncing from blobs must catch up within ~18 days. |
| Epoch length (32 slots) | 384 s | 192 s | 128 s | 64 s | Changes. Express validator-fact windows in epochs, not seconds. |
| Proposer lookahead (EIP-7917) | available | available | available | available | Reliable but **not used** (R5). |
| `block.timestamp` monotonic, second granularity | yes | yes | yes | yes | Reliable. The only timing primitive Etna's contracts should consume. |

Etna timing assumptions that break if hard-coded in slots or blocks: forced-inclusion deadline; proof window for the previous batch; bond lock/unbond delay; slashing-evidence validity window; L1-anchor freshness; preconfirmation horizon; "batches per L1 block" and "blobs per batch". Assumptions that survive all slot times: 1-s L2 blocks driven by wall-clock preconfs (R4); one L1 action per batch (R7); blob DA with KZG binding; permissionless proposer/prover set with on-chain bonds (R1/R6); reuse of SignalService/Bridge/Vault addresses (R2) as long as the L1 state tree stays MPT (EIP-7864 is `Draft`, unscheduled — VERIFIED).

## 6. Things we verified that contradict common belief

1. **"Glamsterdam includes FOCIL."** No: EIP-7805 was DFI for Glamsterdam and is the Hegotá CL headliner (VERIFIED, EIP-8081 SFI list; absent from EIP-7773 SFI list).
2. **"Glamsterdam shortens slots to 6 s."** No: EIP-7782 was DFI; all configs keep `SLOT_DURATION_MS: 12000`; Quick Slots (8198) is only PFI/B-tier for Hegotá with four EF prerequisites (VERIFIED).
3. **"Glamsterdam raises blob counts."** No blob-parameter change is scheduled in any config; mainnet stays at 21 (VERIFIED). The 200 M figure is a *gas* schedule, on Sepolia only, and clients still default to 60 M unless validators opt in (VERIFIED, EF blog).
4. **"A tx included in an ePBS block is confirmed when the beacon block lands."** No: the payload lands at 50 % of the slot and "is not widely validated until the proposer of slot N+1 releases their beacon block"; Empty slots exist and the proposer is still paid (VERIFIED, EIP-7732 and Gloas beacon-chain `settle_builder_payment`).
5. **"FOCIL guarantees inclusion of rollup batch txs."** Under the current design, blob-carrying txs are explicitly "not candidates for either profile" (EIP-8369) and EIP-7805 itself is silent on blobs (VERIFIED); inclusion is conditional and unordered.
6. **"BALs make proof verification cheaper."** No gas change; parallelism is across txs (VERIFIED, EIP-7928). The only gas *reductions* in Glamsterdam are 2780's intrinsic decomposition and 8246; everything else on the propose path gets pricier (8037/8038).
7. **"EIP status `Last Call` means it ships next."** EIP-7610 is `Last Call` and was removed from Glamsterdam; EIP-7805 is `Draft` and is a locked-in headliner (VERIFIED). Document maturity and fork inclusion are independent axes.
8. **"Native rollups / EXECUTE are on the Hegotá track."** EIP-8079 appears in none of EIP-8081's four lists and its precompile address is `TBD` (VERIFIED).
9. **"The Hegotá EF tier list is the decision."** The meta EIP disagrees with it in at least two places (8163 and 7979: EF "DFI", meta CFI) — the meta wins (VERIFIED).
10. **"Under ePBS the state root is delayed."** Not in these forks: EIP-7862 Delayed State Root is Hegotá DFI, and 7886 Delayed execution is Stagnant/Glamsterdam DFI (VERIFIED).

## 7. Sources (all fetched 2026-09-30)

Primary — EIPs (raw GitHub `master`, pattern `https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-NNNN.md`; HTTP 200 for every one listed; statuses recorded in `raw-survey/status-table.txt`): 7773, 8081, 7723, 7607, 7732, 7928, 7805, 7782, 8198, 8141, 4788, 2780, 7976, 7981, 7778, 8038, 8037, 7708, 7843, 7954, 7997, 8024, 8246, 7688, 8045, 8061, 8282, 8261, 7904, 8070, 7825, 7594, 7892, 7918, 7917, 7886, 7999, 8250, 8272, 8279, 8131, 3298, 7668, 7906, 7979, 8015, 8163, 8253, 7709, 8025, 8151, 8298, 8369, 8383, 8368, 8372, 8079, 7701, 8130, 7864, 4844, 7702, 2935, 2537, 4399, 8142, 8304, 4758, 5920, 7610, 7862, 7807. HTTP 404: 8411.
Primary — consensus specs: https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/gloas/fork-choice.md ; .../beacon-chain.md ; .../validator.md
Primary — network configs: https://raw.githubusercontent.com/eth-clients/mainnet/main/metadata/config.yaml ; https://raw.githubusercontent.com/eth-clients/sepolia/main/metadata/config.yaml ; https://raw.githubusercontent.com/eth-clients/hoodi/main/metadata/config.yaml
Primary — EF / ethereum.org: https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement (content dated 2026-09-28) ; https://blog.ethereum.org/2026/09/07/protocol-hegota-eips ; https://ethereum.org/roadmap/glamsterdam/ ; https://ethereum.org/roadmap/hegota
Primary — GitHub process pages: https://github.com/ethereum/EIPs/commits/master/EIPS/eip-7773.md ; https://github.com/ethereum/EIPs/commits/master/EIPS/eip-8081.md ; https://github.com/ethereum/pm/issues/2222 (ACDC #187) ; https://github.com/ethereum/pm/issues/2223 (ACDE #246) ; https://github.com/ethereum/pm/issues/2227 (ACDC #188) ; https://github.com/ethereum/pm/issues/2234 (ACDE #247)
Carried over from the input files (fetched there on 2026-09-30, not re-fetched here): https://raw.githubusercontent.com/ethereum/EIPs/f9976e6/EIPS/eip-7773.md (Glamsterdam DFI list) ; https://blog.ethereum.org/2025/12/22/hegota-timeline ; https://blog.ethereum.org/2026/04/10/checkpoint-9 ; https://github.com/ethereum/EIPs/pull/12335 ; /pull/12364 ; /pull/12377 ; https://github.com/ethereum/pm/issues/1930 ; /2177 ; /2197 ; /2211 ; https://github.com/ethereum/execution-specs/issues/3664 ; https://ethereum-magicians.org/t/eip-8081-hegota-network-upgrade-meta-thread/26876 ; https://ethereum-magicians.org/t/eip-8079-native-rollups/26565 ; Hegotá ACD decisions sheet (Google Sheets id 1UVm9UurwCMWrtLAM7aKvMjdeMtZYSsm7ay8AMwo52AE).
Secondary (UNVERIFIED-grade, used only for attributed context): https://christinedkim.substack.com/p/acde-244 ; https://hackmd.io/@bchain/r1X_MVu5bg ; https://ethresear.ch/t/execution-tickets/17944.

### UNVERIFIED items (consolidated)

- Glamsterdam Hoodi/mainnet activation dates ("27 Oct" / "early December") and the mainnet 200 M gas-limit decision.
- Whether EIP-8253 was added to Glamsterdam at ACDE #245 (not in EIP-7773 master).
- The "specs may change" caveat on EIP-8141's SFI (secondary recap).
- FOCIL's treatment of blob txs as a consensus rule (stated only in Informational EIP-8369).
- 4 s / 2 s slot-time rows (arithmetic extrapolation); blob-retention scaling under EIP-7782.
- The EVM-visible consequence of ePBS Empty slots for the EIP-4788 ring buffer (derived from spec assertions; no client test fetched).
- Absence of any Hegotá headliner proposal thread for EIP-8079 (search-based negative).
- Hegotá mainnet "Q2 2027" is an ethereum.org estimate, not an ACD decision.
- ACD call decisions after 2026-09-24 (ACDC #188, ACDE #247 agendas fetched carry no outcomes).

## 8. Verification record

This survey was produced by a research sub-agent and then independently re-verified by a skeptic sub-agent instructed to refute it (report: [`notes/02.verify.md`](notes/02.verify.md), 2026-09-30). The skeptic re-fetched 113 EIP files, the three eth-clients configs, the three Gloas consensus-spec files, and revision-pinned copies of both meta EIPs. Every EIP number, title, `status:` field, fork-inclusion membership, config value, activation timestamp, and verbatim quote checked was correct, and no EIP on either fork's current list was found missing. Six errors were found, all in Hegotá process bookkeeping (PFI count, EIP-8304's list, the EIP-8141 SFI commit date, the ACDE #245 decline count, EIP-8360's existence, and a double count of 8304); each has been corrected in place above and marked "corrected after skeptic review". None affects the survey's Etna conclusions: nothing in either fork is a hard dependency, slot time stays 12 s, FOCIL does not cover blob transactions, and EIP-8141 is a Draft that needs a fallback.
