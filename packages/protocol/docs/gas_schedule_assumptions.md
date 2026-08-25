# Gas Schedule Assumptions in Taiko Contracts

**Status:** analysis / tracking document — no behavior change proposed yet.
**Context:** Glamsterdam repricing candidates ([EIP-8038](https://eips.ethereum.org/EIPS/eip-8038) /
[EIP-8037](https://eips.ethereum.org/EIPS/eip-8037) state-access repricing, calldata repricing
proposals) plus the already-live [EIP-7623](https://eips.ethereum.org/EIPS/eip-7623) calldata floor
(Pectra). This document inventories every place in `packages/protocol/contracts` where a specific
EVM gas schedule is assumed, and classifies what must be re-derived when a repricing fork ships —
on L1, and on Taiko L2 itself (as a type-1 rollup, Taiko is expected to adopt the same schedule in
a subsequent L2 hard fork).

Cross-check against the [ethereum/repricing-impact](https://ethereum.github.io/repricing-impact/affected-contracts.html?schedule=eip-8038)
dataset (2026-08-24, mainnet blocks 21,319,986–25,319,985): **no active Taiko L1 contract appears
in the EIP-8038 "potentially broken" set.** The findings below are therefore about *calibration*
(constants drifting out of tune) and *cost*, not about anything breaking outright.

Reference deltas used below (EIP-8038 draft, subject to change while in peer review):

| Constant | Today | EIP-8038 | Note |
| --- | --- | --- | --- |
| Cold account access | 2,600 | 3,000 | +400 |
| Storage write (dirty-slot update component) | 2,800 | 10,000 | net cold update ≈ 5,000 → 12,100 |
| Account write (value transfer) | 6,700 | 9,000 | +2,300 |
| New account/create access | 7,000 | 12,000 | +5,000 |
| Fresh storage slot (create + write) | ≈ 22,100 | ≈ 22,000 | effectively unchanged |
| Access list: address / storage key | 2,400 / 1,900 | 2,900 / 2,000 | |
| EXTCODESIZE / EXTCODECOPY | — | +100 | extra warm-access read |

## Summary

| # | Location | Assumption | Exposure | Action |
| --- | --- | --- | --- | --- |
| 1 | `shared/bridge/Bridge.sol` — `_SEND_ETHER_GAS_LIMIT` | measured receive() cost of EOAs and smart wallets (Safe ≈ 28k) | margin shrinks to ~3–4k under EIP-8038; a wallet whose receive() does storage writes can exceed the cap → `sendEtherAndVerify` reverts → message processing blocked for that owner | **applied: raised 35k → 50k**; re-measure wallet receive costs when the final schedule ships |
| 2 | `shared/bridge/Bridge.sol` — `_messageCalldataCost()` (16 gas/byte) | pre-EIP-7623 calldata pricing | EIP-7623 floor (40 gas per non-zero byte) can exceed 16/byte on calldata-dominated txs; future calldata repricing moves the 16 constant itself | re-derive; today the floor rarely binds for `processMessage` (execution-heavy), so fix opportunistically |
| 3 | `shared/bridge/Bridge.sol` — `GAS_OVERHEAD = 120_000` | intrinsic cost + typical proof calldata under today's prices | drifts with intrinsic/calldata/state repricing → relayer over/under-compensation (bounded by `message.fee` cap) | recalibrate from `MessageProcessed` production stats |
| 4 | `shared/bridge/Bridge.sol` — `_GAS_REFUND_PER_CACHE_OPERATION = 20_000` | one fresh SSTORE ≈ 22.1k | fresh-slot cost is ≈ unchanged under EIP-8038 (≈ 22k); other schedules may move it | keep tied to "cost of one cache write"; recheck per final schedule |
| 5 | `shared/bridge/Bridge.sol` — `GAS_RESERVE = 800_000` | bridge-side overhead around message invocation | overhead grows by roughly +5k (L1, transient-storage variant) to +40k (L2, storage variant) per message under EIP-8038 | headroom is ample; verify with production stats, no logic change expected |
| 6 | vanilla `Bridge.__ctx` + `EssentialContract.__reentry` (storage-based; used by the **L2** bridge deployment) | storage lock/context cheap enough | dirty-slot updates ≈ ×2.4 under EIP-8038 → ~+40k per L2 message | port the L1 `MainnetBridge`/`LibFasterReentryLock` transient-storage overrides to the L2 deployment |
| 7 | `layer2/core/Anchor.sol` — `ANCHOR_GAS_LIMIT = 1_000_000` (consensus constant, enforced by node) | anchor tx fits in 1M | anchorV4 ≈ low-100k range today; ≈ +tens-of-k under EIP-8038-on-L2 → ~10× headroom remains | no change; re-verify (contracts + Go/Rust clients together) when L2 adopts the fork |
| 8 | `Bridge` docs/`_checkForwardedGas` — 63/64 (EIP-150) math | EIP-150 unchanged | EIP-8038 does not touch call-gas forwarding | none; revisit only if a future EIP changes 63/64 |
| 9 | economic parameters (`MainnetInbox` config: bonds, forced-inclusion fees; relayer/SDK recommended gas limits, incl. first-time `BridgedERC20` deployment messages) | priced against today's L1 cost basis | repricing shifts the cost basis | governance/ops recalibration, not contract code |

The Shasta L1 `Inbox` contains **no** gas-schedule constants at all (hash-only ring-buffer
storage; proposer/prover clients estimate gas dynamically). Fee accounting in
`Bridge.processMessage` is self-measuring (`gasleft()` deltas), so only the additive constants
above — not the mechanism — need retuning.

## Details

### 1. `_SEND_ETHER_GAS_LIMIT = 35_000` — the only potential correctness issue

`Bridge.sol` caps every Ether payout (`processMessage` fee/refund, `recallMessage`,
`retryMessage`) at 35k gas, calibrated against measured wallet receive costs (EOA < 21k, Loopring
≈ 23k, Argent ≈ 24k, Safe ≈ 28k). Under EIP-8038 a Safe-style receive gains roughly +2.3k
(account write) +400 (cold singleton access), reaching ≈ 31k — still passing, but the safety
margin drops from ~7k to ~4k, and any wallet whose receive path performs a storage write gains
+7k per written slot and can cross the cap. Because `sendEtherAndVerify` reverts on failure, a
crossing wallet makes `processMessage` revert for that message (both the relayer path and the
destOwner self-processing path send the refund under this cap). The constant has been raised to
50k (the cap exists to bound recipient griefing, not to be tight — the extra 15k of griefing
surface is negligible against `GAS_RESERVE`). Re-run the wallet measurements once the final
schedule ships.

### 2. `_messageCalldataCost()` — 16 gas per byte

`((dataLength + 31) / 32 * 32 + 416) << 4` hardcodes 16 gas per (assumed non-zero) calldata byte.
Post-EIP-7623 the effective price is `max`-based: calldata-dominated transactions pay the floor of
10 gas per token (40 per non-zero byte). `processMessage` transactions carry heavy execution
(storage-proof verification), so the floor rarely binds in practice — but a transaction carrying a
proof near `RELAYER_MAX_PROOF_BYTES = 200_000` is firmly floor-priced. The constant feeds
`getMessageMinGasLimit()` and relayer fee accounting only (fee is capped by `message.fee`, and
raising the min-gas term retroactively *lowers* `_invocationGasLimit` for in-flight messages), so
any change must be sequenced with in-flight message handling in mind.

### 6. Transient storage on the L2 bridge

The L1 deployment (`MainnetBridge`, `MainnetInbox`) already uses EIP-1153 transient storage for
the reentry lock and message context (`LibFasterReentryLock`, `tstore` context overrides) — those
paths are immune to state repricing. The Taiko L2 bridge (`0x1670…0001`) runs the vanilla `Bridge`
with a storage-based `__ctx` (2 slots × 2 writes per message) and `EssentialContract.__reentry`
(2 writes per guarded call). Today that is ~17k per message; under EIP-8038-on-L2 it becomes
~40k. Deploying the transient-storage variant on L2 removes the exposure entirely with
already-written code.

### 7. `ANCHOR_GAS_LIMIT` is a cross-repo consensus constant

The constant lives in `Anchor.sol` and is mirrored/enforced by taiko-client (Go) and
taiko-client-rs (Rust bindings expose `ANCHOR_GAS_LIMIT()`), and anchor transactions are built
with exactly this limit. `anchorV4` costs are dominated by 255 `BLOCKHASH` reads, two 8KB keccaks,
one fresh `blockHashes[parent]` slot, a `_blockState` update, and `saveCheckpoint` (2 fresh
slots) — comfortably inside 1M under any published repricing draft. Any future change must ship
in contracts and both clients simultaneously (consensus-critical).

## What was explicitly verified as non-exposed

- **Shasta `Inbox` (L1):** no gas constants; ring-buffer slot reuse means proposing costs shift
  (dirty updates ×~2.4) but nothing is hardcoded against the schedule.
- **EIP-150 63/64 logic** (`_checkForwardedGas`, `processMessage` gas-limit guidance): untouched
  by the state-access repricing EIPs.
- **Signal/checkpoint writes:** fresh-slot dominated; fresh-slot cost is approximately unchanged
  under EIP-8038.
- **Vault contracts:** carry only user-supplied per-message gas limits; no schedule assumptions
  on-chain (off-chain recommended defaults live in bridge-ui/relayer/SDK and need re-estimation).
- **repricing-impact dataset:** all 188 L1 addresses ever recorded in
  `deployments/mainnet-contract-logs-L1.md` were checked against the EIP-8038 per-address shards;
  the only Taiko-related entry is the retired pre-Proposal0017 bridge implementation appearing as
  the revert site of a single third-party aggregator transaction — not a protocol operation.
