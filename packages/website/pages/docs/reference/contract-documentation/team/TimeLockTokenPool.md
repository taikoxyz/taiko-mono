---
title: TimeLockTokenPool
---

## TimeLockTokenPool

### Grant

```solidity
struct Grant {
  uint128 amount;
  uint64 grantStart;
  uint64 grantCliff;
  uint32 grantPeriod;
  uint64 unlockStart;
  uint64 unlockCliff;
  uint32 unlockPeriod;
}
```

### Recipient

```solidity
struct Recipient {
  uint128 amountWithdrawn;
  struct TimeLockTokenPool.Grant[] grants;
}
```

### MAX_GRANTS_PER_ADDRESS

```solidity
uint256 MAX_GRANTS_PER_ADDRESS
```

### taikoToken

```solidity
address taikoToken
```

### sharedVault

```solidity
address sharedVault
```

### totalAmountGranted

```solidity
uint128 totalAmountGranted
```

### totalAmountVoided

```solidity
uint128 totalAmountVoided
```

### totalAmountWithdrawn

```solidity
uint128 totalAmountWithdrawn
```

### recipients

```solidity
mapping(address => struct TimeLockTokenPool.Recipient) recipients
```

### Granted

```solidity
event Granted(address recipient, struct TimeLockTokenPool.Grant grant)
```

### Voided

```solidity
event Voided(address recipient, uint128 amount)
```

### Withdrawn

```solidity
event Withdrawn(address recipient, address to, uint128 amount)
```

### INVALID_GRANT

```solidity
error INVALID_GRANT()
```

### INVALID_PARAM

```solidity
error INVALID_PARAM()
```

### NOTHING_TO_VOID

```solidity
error NOTHING_TO_VOID()
```

### NOTHING_TO_WITHDRAW

```solidity
error NOTHING_TO_WITHDRAW()
```

### TOO_MANY

```solidity
error TOO_MANY()
```

### init

```solidity
function init(address _taikoToken, address _sharedVault) external
```

### grant

```solidity
function grant(address recipient, struct TimeLockTokenPool.Grant g) external
```

Gives a new grant to a address with its own unlock schedule.
This transaction should happen on a regular basis, e.g., quarterly.

_It is strongly recommended to add one Grant per receipient address
so that such a grant can be voided without voiding other grants for the
same recipient._

### void

```solidity
function void(address recipient) external
```

Puts a stop to all grants for a given recipient.Tokens already
granted to the recipient will NOT be voided but are subject to the
original unlock schedule.

### withdraw

```solidity
function withdraw() external
```

Withdraws all withdrawable tokens.

### withdraw

```solidity
function withdraw(address to, bytes sig) external
```

Withdraws all withdrawable tokens.

### getMyGrantSummary

```solidity
function getMyGrantSummary(address recipient) public view returns (uint128 amountOwned, uint128 amountUnlocked, uint128 amountWithdrawn, uint128 amountWithdrawable)
```

### getMyGrants

```solidity
function getMyGrants(address recipient) public view returns (struct TimeLockTokenPool.Grant[])
```

---

## title: ProxiedTimeLockTokenPool

## ProxiedTimeLockTokenPool

Proxied version of the parent contract.
