---
title: IErc721Bridge
---

## IErc721Bridge

Bridge interface for NFT contracts.

_Ether is held by Bridges on L1 and by the EtherVault on L2,
not TokenVaults._

### Message

```solidity
struct Message {
  uint256 id;
  address sender;
  uint256 srcChainId;
  uint256 destChainId;
  address owner;
  address to;
  address refundAddress;
  address tokenContract;
  uint256[] tokenIds;
  uint256 processingFee;
  uint256 gasLimit;
  string tokenSymbol;
  string tokenName;
  string[] tokenURIs;
}
```

### Context

```solidity
struct Context {
  bytes32 msgHash;
  address sender;
  uint256 srcChainId;
}
```

### SignalSentErc721

```solidity
event SignalSentErc721(address sender, bytes32 msgHash)
```

### MessageSentErc721

```solidity
event MessageSentErc721(bytes32 msgHash, struct IErc721Bridge.Message message)
```

### sendMessageErc721

```solidity
function sendMessageErc721(struct IErc721Bridge.Message message) external payable returns (bytes32 msgHash)
```

Sends a message to the destination chain and takes custody
of the token(s) required in this contract.

### releaseTokenErc721

```solidity
function releaseTokenErc721(struct IErc721Bridge.Message message, bytes proof) external
```

### isMessageSentErc721

```solidity
function isMessageSentErc721(bytes32 msgHash) external view returns (bool)
```

Checks if a msgHash has been stored on the bridge contract by the
current address.

### isMessageReceivedErc721

```solidity
function isMessageReceivedErc721(bytes32 msgHash, uint256 srcChainId, bytes proof) external view returns (bool)
```

Checks if a msgHash has been received on the destination chain and
sent by the src chain.

### isMessageFailedErc721

```solidity
function isMessageFailedErc721(bytes32 msgHash, uint256 destChainId, bytes proof) external view returns (bool)
```

Checks if a msgHash has been failed on the destination chain.

### context

```solidity
function context() external view returns (struct IErc721Bridge.Context context)
```

Returns the bridge state context.

### hashMessage

```solidity
function hashMessage(struct IErc721Bridge.Message message) external pure returns (bytes32)
```

