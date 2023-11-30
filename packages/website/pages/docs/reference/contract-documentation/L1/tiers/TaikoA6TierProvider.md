---
title: TaikoA6TierProvider
---

## TaikoA6TierProvider

_Labeled in AddressResolver as "tier_provider"
Assuming liveness bound is 250TKO._

### TIER_NOT_FOUND

```solidity
error TIER_NOT_FOUND()
```

### getTier

```solidity
function getTier(uint16 tierId) public pure returns (struct ITierProvider.Tier)
```

_Retrieves the configuration for a specified tier._

### getTierIds

```solidity
function getTierIds() public pure returns (uint16[] tiers)
```

_Retrieves the IDs of all supported tiers.
Note that the core protocol requires the number of tiers to be smaller
than 256. In reality, this number should be much smaller._

### getMinTier

```solidity
function getMinTier(uint256 rand) public pure returns (uint16)
```

_Determines the minimal tier for a block based on a random input._

