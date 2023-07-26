---
title: LibEthDepositing_A3
---

## LibEthDepositing_A3

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

### L1_INVALID_ETH_DEPOSIT

```solidity
error L1_INVALID_ETH_DEPOSIT()
```

### depositEtherToL2

```solidity
function depositEtherToL2(struct TaikoData.State state, struct TaikoData.Config config, contract AddressResolver resolver) internal
```

### processDeposits

```solidity
function processDeposits(struct TaikoData.State state, struct TaikoData.Config config, address beneficiary) internal returns (struct TaikoData.EthDeposit[] depositsProcessed)
```

### hashEthDeposits

```solidity
function hashEthDeposits(struct TaikoData.EthDeposit[] deposits) internal pure returns (bytes32)
```

