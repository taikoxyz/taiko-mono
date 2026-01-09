# PROPOSAL-0007: Lower L2 Base Fee Floor 2.5x to 0.01 gwei

## Executive Summary

- Reduce Taiko L2’s minimum base fee by 2.5x (from 0.025 gwei effective floor to 0.01 gwei).
- Upgrade L2 TaikoAnchor to lower `BASEFEE_MIN_VALUE` to 0.01 gwei.

## Rationale

With Ethereum scaling to 60M gas, there are periods where L1 price is almost as low or lower than Taiko's base fee. The recent L1 scaling allows us to lower the minimum base fee for Taiko Alethia to encourage more activity in the chain.
The current minimum base fee was set conservatively when preconfs were launched. This proposal adjusts the base fee to the current landscape.

## Technical Specification

### Actions

1. **Upgrade L2 TaikoAnchor (proxy: `0x1670000000000000000000000000000000010001`)**
   - New implementation: **`0xf381868dd6b2ac8cca468d63b42f9040de2257e9`**
   - Change: lower the `BASEFEE_MIN_VALUE` hard floor to `10_000_000` wei (0.01 gwei).

### Expected Post-Upgrade Behavior

- Minimum base fee hard floor is `10_000_000` wei (0.01 gwei).
- Under load, the EIP-1559 curve continues to drive price increases as today.

### Verification

Before submission:

- Confirm the new implementation address (`0xf381868dd6b2ac8cca468d63b42f9040de2257e9`) is deployed and verified on L2.

After execution:

1. On L2, call `BASEFEE_MIN_VALUE()` on the TaikoAnchor proxy; expect `10_000_000`.
2. Observe subsequent blocks’ `basefee` on Taiko L2 bottoming out around 0.01 gwei during low utilization.

## Security Contacts

- security@taiko.xyz
- Bug bounty: https://taiko.xyz/security
