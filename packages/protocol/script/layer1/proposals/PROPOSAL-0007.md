# PROPOSAL-0005: Lower L2 Base Fee Floor to 0.0025 gwei

## Executive Summary

- Reduce Taiko L2’s minimum base fee by 10x (from 0.025 gwei effective floor to ~0.0025 gwei).
- Upgrade L1 TaikoInbox to ship the lower `minGasExcess` (curve floor) while keeping all other pacaya parameters unchanged.
- Upgrade L2 TaikoAnchor to adjust `BASEFEE_MIN_VALUE` to also use 0.0025 gwei.

## Rationale

With Ethereum scaling to 60M gas, there are periods where L1 price is almost as low or lower than Taiko's. The current minimum base fee was set conservately when preconfs were launched. This proposal adjusts the base fee to the current landscape.

## Technical Specification

### Actions

1. **Upgrade L1 TaikoInbox (proxy: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`)**
   - New implementation: **`TAIKO_INBOX_NEW_IMPL`** (to be set before submission).
   - Change: `baseFeeConfig.minGasExcess` set to `1_289_447_652`, which yields ~0.0025 gwei with `gasTarget = 5_000_000 * 8 = 40_000_000`.
   - Other pacaya config fields remain unchanged.

2. **Upgrade L2 TaikoAnchor (proxy: `0x1670000000000000000000000000000000010001`)**
   - New implementation: **`TAIKO_L2_NEW_IMPL`** (to be set before submission).
   - Change: update `BASEFEE_MIN_VALUE` hard floor;

### Expected Post-Upgrade Behavior

- Minimum base fee ≈ `exp(1_289_447_652 / 40_000_000) / 40_000_000 ≈ 2_500_000 wei` (0.0025 gwei).
- Under load, the EIP-1559 curve and `minGasExcess` guard continue to drive price increases as today.

### Verification

Before submission:

- Confirm new implementation addresses (`TAIKO_INBOX_NEW_IMPL`, `TAIKO_L2_NEW_IMPL`) are deployed and verified from this commit.

After execution:

1. On L1, call `pacayaConfig().baseFeeConfig.minGasExcess` on TaikoInbox proxy; expect `1_289_447_652`.
2. On L2, call `getBasefeeV2` on TaikoAnchor with `_parentGasUsed=0` and the L1-provided `baseFeeConfig`; expect a result ≥ 2_500_000 wei.
3. Observe subsequent blocks’ `basefee` on Taiko L2 bottoming out around 0.0025 gwei during low utilization.

## Security Contacts

- security@taiko.xyz
- Bug bounty: https://taiko.xyz/security
