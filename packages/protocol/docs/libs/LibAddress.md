## LibAddress

This library offers address-related methods.

### sendEther

```solidity
function sendEther(address to, uint256 amount) internal
```

Sends Ether to an address. Zero-value will also be sent.
See more information at:
https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now.

#### Parameters

| Name   | Type    | Description                  |
| ------ | ------- | ---------------------------- |
| to     | address | The target address.          |
| amount | uint256 | The amount of Ether to send. |

### codeHash

```solidity
function codeHash(address addr) internal view returns (bytes32 codehash)
```
