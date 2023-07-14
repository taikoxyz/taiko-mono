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

### MessageDeposit

```solidity
struct MessageDeposit {
  address token;
  uint256 amount;
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

### messageDeposits

```solidity
mapping(bytes32 => struct ERC20Vault.MessageDeposit) messageDeposits
```

### BridgedTokenDeployed

```solidity
event BridgedTokenDeployed(uint256 srcChainId, address canonicalToken, address bridgedToken, string canonicalTokenSymbol, string canonicalTokenName, uint8 canonicalTokenDecimal)
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

### receiveToken

```solidity
function receiveToken(struct ERC20Vault.CanonicalERC20 canonicalToken, address from, address to, uint256 amount) external
```

This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function.

#### Parameters

| Name           | Type                             | Description                                                                                                          |
| -------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| canonicalToken | struct ERC20Vault.CanonicalERC20 | The canonical ERC20 token which may or may not live on this chain. If not, a BridgedERC20 contract will be deployed. |
| from           | address                          | The source address.                                                                                                  |
| to             | address                          | The destination address.                                                                                             |
| amount         | uint256                          | The amount of tokens to be sent. 0 is a valid value.                                                                 |

---

## title: ProxiedERC20Vault

## ProxiedERC20Vault
