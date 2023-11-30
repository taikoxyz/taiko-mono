---
title: ERC20Vault
---

## ERC20Vault

This vault holds all ERC20 tokens (excluding Ether) that users have
deposited. It also manages the mapping between canonical ERC20 tokens and
their bridged tokens.

_Labeled in AddressResolver as "erc20_vault"_

### CanonicalERC20

```solidity
struct CanonicalERC20 {
  uint64 chainId;
  address addr;
  uint8 decimals;
  string symbol;
  string name;
}
```

### BridgeTransferOp

```solidity
struct BridgeTransferOp {
  uint64 destChainId;
  address to;
  address token;
  uint256 amount;
  uint256 gasLimit;
  uint256 fee;
  address refundTo;
  string memo;
}
```

### bridgedToCanonical

```solidity
mapping(address => struct ERC20Vault.CanonicalERC20) bridgedToCanonical
```

### canonicalToBridged

```solidity
mapping(uint256 => mapping(address => address)) canonicalToBridged
```

### BridgedTokenDeployed

```solidity
event BridgedTokenDeployed(uint256 srcChainId, address ctoken, address btoken, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
```

### TokenSent

```solidity
event TokenSent(bytes32 msgHash, address from, address to, uint64 destChainId, address token, uint256 amount)
```

### TokenReleased

```solidity
event TokenReleased(bytes32 msgHash, address from, address token, uint256 amount)
```

### TokenReceived

```solidity
event TokenReceived(bytes32 msgHash, address from, address to, uint64 srcChainId, address token, uint256 amount)
```

### VAULT_INVALID_TOKEN

```solidity
error VAULT_INVALID_TOKEN()
```

### VAULT_INVALID_AMOUNT

```solidity
error VAULT_INVALID_AMOUNT()
```

### VAULT_INVALID_USER

```solidity
error VAULT_INVALID_USER()
```

### VAULT_INVALID_FROM

```solidity
error VAULT_INVALID_FROM()
```

### VAULT_INVALID_SRC_CHAIN_ID

```solidity
error VAULT_INVALID_SRC_CHAIN_ID()
```

### VAULT_MESSAGE_NOT_FAILED

```solidity
error VAULT_MESSAGE_NOT_FAILED()
```

### VAULT_MESSAGE_RELEASED_ALREADY

```solidity
error VAULT_MESSAGE_RELEASED_ALREADY()
```

### sendToken

```solidity
function sendToken(struct ERC20Vault.BridgeTransferOp op) external payable returns (struct IBridge.Message _message)
```

Transfers ERC20 tokens to this vault and sends a message to the
destination chain so the user can receive the same amount of tokens by
invoking the message call.

#### Parameters

| Name | Type                               | Description                      |
| ---- | ---------------------------------- | -------------------------------- |
| op   | struct ERC20Vault.BridgeTransferOp | Option for sending ERC20 tokens. |

### receiveToken

```solidity
function receiveToken(struct ERC20Vault.CanonicalERC20 ctoken, address from, address to, uint256 amount) external payable
```

Receive bridged ERC20 tokens and Ether.

#### Parameters

| Name   | Type                             | Description                                        |
| ------ | -------------------------------- | -------------------------------------------------- |
| ctoken | struct ERC20Vault.CanonicalERC20 | Canonical ERC20 data for the token being received. |
| from   | address                          | Source address.                                    |
| to     | address                          | Destination address.                               |
| amount | uint256                          | Amount of tokens being received.                   |

### onMessageRecalled

```solidity
function onMessageRecalled(struct IBridge.Message message, bytes32 msgHash) external payable
```

### name

```solidity
function name() public pure returns (bytes32)
```

---

## title: ProxiedSingletonERC20Vault

## ProxiedSingletonERC20Vault

Proxied version of the parent contract.

_Deploy this contract as a singleton per chain for use by multiple L2s
or L3s. No singleton check is performed within the code; it's the deployer's
responsibility to ensure this. Singleton deployment is essential for
enabling multi-hop bridging across all Taiko L2/L3s._
