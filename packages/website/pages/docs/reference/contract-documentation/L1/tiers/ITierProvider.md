---
title: ITierProvider
---

## ITierProvider

Defines interface to return tier configuration.

### Tier

```solidity
struct Tier {
  bytes32 verifierName;
  uint96 validityBond;
  uint96 contestBond;
  uint24 cooldownWindow;
  uint16 provingWindow;
  uint8 maxBlocksToVerify;
}
```

### getTier

```solidity
function getTier(uint16 tierId) external view returns (struct ITierProvider.Tier)
```

_Retrieves the configuration for a specified tier._

### getTierIds

```solidity
function getTierIds() external view returns (uint16[])
```

_Retrieves the IDs of all supported tiers.
Note that the core protocol requires the number of tiers to be smaller
than 256. In reality, this number should be much smaller._

### getMinTier

```solidity
function getMinTier(uint256 rand) external view returns (uint16)
```

_Determines the minimal tier for a block based on a random input._

---
title: LibTiers
---

## LibTiers

_Tier ID cannot be zero!_

### TIER_OPTIMISTIC

```solidity
uint16 TIER_OPTIMISTIC
```

### TIER_SGX

```solidity
uint16 TIER_SGX
```

### TIER_PSE_ZKEVM

```solidity
uint16 TIER_PSE_ZKEVM
```

### TIER_SGX_AND_PSE_ZKEVM

```solidity
uint16 TIER_SGX_AND_PSE_ZKEVM
```

### TIER_GUARDIAN

```solidity
uint16 TIER_GUARDIAN
```

