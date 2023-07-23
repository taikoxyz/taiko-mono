---
title: ERC20Vault
---

## ERC20Vault

This vault holds all ERC20 tokens (but not Ether) that users have deposited.
It also manages the mapping between canonical ERC20 tokens and their bridged
tokens.

_Ether is held by Bridges on L1 and by the EtherVault on L2, not
ERC20Vaults._

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
  uint256 processingFee;
  address refundAddress;
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

### releasedMessages

```solidity
mapping(bytes32 => bool) releasedMessages
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

Thrown when the `to` address in an operation is invalid.
This can happen if it's zero address or the address of the token vault.

### VAULT_INVALID_TOKEN

```solidity
error VAULT_INVALID_TOKEN()
```

Thrown when the token address in a transaction is invalid.
This could happen if the token address is zero or doesn't conform to the
ERC20 standard.

### VAULT_INVALID_AMOUNT

```solidity
error VAULT_INVALID_AMOUNT()
```

Thrown when the amount in a transaction is invalid.
This could happen if the amount is zero or exceeds the sender's balance.

### VAULT_INVALID_OWNER

```solidity
error VAULT_INVALID_OWNER()
```

Thrown when the owner address in a message is invalid.
This could happen if the owner address is zero or doesn't match the
expected owner.

### VAULT_INVALID_SENDER

```solidity
error VAULT_INVALID_SENDER()
```

Thrown when the sender in a message context is invalid.
This could happen if the sender isn't the expected token vault on the
source chain.

### VAULT_INVALID_SRC_CHAIN_ID

```solidity
error VAULT_INVALID_SRC_CHAIN_ID()
```

Thrown when the source chain ID in a message is invalid.
This could happen if the source chain ID doesn't match the current
chain's ID.

### VAULT_MESSAGE_NOT_FAILED

```solidity
error VAULT_MESSAGE_NOT_FAILED()
```

Thrown when a message has not failed.
This could happen if trying to release a message deposit without proof of
failure.

### VAULT_MESSAGE_RELEASED_ALREADY

```solidity
error VAULT_MESSAGE_RELEASED_ALREADY()
```

Thrown when a message has already released

### onlyValidAddresses

```solidity
modifier onlyValidAddresses(uint256 chainId, bytes32 name, address to, address token)
```

### init

```solidity
function init(address addressManager) external
```

### sendToken

```solidity
function sendToken(struct ERC20Vault.BridgeTransferOp opt) external payable
```

Transfers ERC20 tokens to this vault and sends a message to the
destination chain so the user can receive the same amount of tokens
by invoking the message call.

#### Parameters

| Name | Type                               | Description                      |
| ---- | ---------------------------------- | -------------------------------- |
| opt  | struct ERC20Vault.BridgeTransferOp | Option for sending ERC20 tokens. |

### receiveToken

```solidity
function receiveToken(struct ERC20Vault.CanonicalERC20 ctoken, address from, address to, uint256 amount) external
```

This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function.

#### Parameters

| Name   | Type                             | Description                                                                                                          |
| ------ | -------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| ctoken | struct ERC20Vault.CanonicalERC20 | The canonical ERC20 token which may or may not live on this chain. If not, a BridgedERC20 contract will be deployed. |
| from   | address                          | The source address.                                                                                                  |
| to     | address                          | The destination address.                                                                                             |
| amount | uint256                          | The amount of tokens to be sent. 0 is a valid value.                                                                 |

### releaseToken

```solidity
function releaseToken(struct IBridge.Message message, bytes proof) external
```

Release deposited ERC20 back to the owner on the source ERC20Vault with
a proof that the message processing on the destination Bridge has failed.

#### Parameters

| Name    | Type                   | Description                                                            |
| ------- | ---------------------- | ---------------------------------------------------------------------- |
| message | struct IBridge.Message | The message that corresponds to the ERC20 deposit on the source chain. |
| proof   | bytes                  | The proof from the destination chain to show the message has failed.   |

---

## title: ProxiedERC20Vault

## ProxiedERC20Vault
