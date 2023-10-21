---
title: ERC20Vault
---

## ERC20Vault

This vault holds all ERC20 tokens (excluding Ether) that users have
deposited. It also manages the mapping between canonical ERC20 tokens and
their bridged tokens.

### CanonicalERC20

```solidity
struct CanonicalERC20 {
  uint256 chainId;
  address addr;
  uint8 decimals;
  string symbol;
  string name;
}
```

### BridgeTransferOp

```solidity
struct BridgeTransferOp {
  uint256 destChainId;
  address to;
  address token;
  uint256 amount;
  uint256 gasLimit;
  uint256 fee;
  address refundTo;
  string memo;
}
```

### isBridgedToken

```solidity
mapping(address => bool) isBridgedToken
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
event TokenSent(bytes32 msgHash, address from, address to, uint256 destChainId, address token, uint256 amount)
```

### TokenReleased

```solidity
event TokenReleased(bytes32 msgHash, address from, address token, uint256 amount)
```

### TokenReceived

```solidity
event TokenReceived(bytes32 msgHash, address from, address to, uint256 srcChainId, address token, uint256 amount)
```

### VAULT_INVALID_TO

```solidity
error VAULT_INVALID_TO()
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

### onlyValidAddresses

```solidity
modifier onlyValidAddresses(uint256 chainId, bytes32 name, address to, address token)
```

### init

```solidity
function init(address addressManager) external
```

Initializes the contract with the address manager.

#### Parameters

| Name           | Type    | Description                       |
| -------------- | ------- | --------------------------------- |
| addressManager | address | Address manager contract address. |

### sendToken

```solidity
function sendToken(struct ERC20Vault.BridgeTransferOp opt) external payable
```

Transfers ERC20 tokens to this vault and sends a message to the
destination chain so the user can receive the same amount of tokens by
invoking the message call.

#### Parameters

| Name | Type                               | Description                      |
| ---- | ---------------------------------- | -------------------------------- |
| opt  | struct ERC20Vault.BridgeTransferOp | Option for sending ERC20 tokens. |

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
function onMessageRecalled(struct IBridge.Message message) external payable
```

Releases deposited ERC20 tokens back to the user on the source
ERC20Vault with a proof that the message processing on the destination
Bridge has failed.

#### Parameters

| Name    | Type                   | Description                                                            |
| ------- | ---------------------- | ---------------------------------------------------------------------- |
| message | struct IBridge.Message | The message that corresponds to the ERC20 deposit on the source chain. |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

Checks if the contract supports the given interface.

#### Parameters

| Name        | Type   | Description               |
| ----------- | ------ | ------------------------- |
| interfaceId | bytes4 | The interface identifier. |

#### Return Values

| Name | Type | Description                                                   |
| ---- | ---- | ------------------------------------------------------------- |
| [0]  | bool | true if the contract supports the interface, false otherwise. |

---

## title: ProxiedERC20Vault

## ProxiedERC20Vault

Proxied version of the parent contract.
