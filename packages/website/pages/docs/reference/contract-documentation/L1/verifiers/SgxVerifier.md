---
title: SgxVerifier
---

## SgxVerifier

This contract is the implementation of verifying SGX signature
proofs on-chain. Please see references below!
Reference #1: https://ethresear.ch/t/2fa-zk-rollups-using-sgx/14462
Reference #2: https://github.com/gramineproject/gramine/discussions/1579

### Instance

_Each public-private key pair (Ethereum address) is generated within
the SGX program when it boots up. The off-chain remote attestation
ensures the validity of the program hash and has the capability of
bootstrapping the network with trustworthy instances._

```solidity
struct Instance {
  address addr;
  uint64 addedAt;
}
```

### INSTANCE_EXPIRY

```solidity
uint256 INSTANCE_EXPIRY
```

### nextInstanceId

```solidity
uint256 nextInstanceId
```

_For gas savings, we shall assign each SGX instance with an id
so that when we need to set a new pub key, just write storage once._

### instances

```solidity
mapping(uint256 => struct SgxVerifier.Instance) instances
```

_One SGX instance is uniquely identified (on-chain) by it's ECDSA
public key (or rather ethereum address). Once that address is used (by
proof verification) it has to be overwritten by a new one (representing
the same instance). This is due to side-channel protection. Also this
public key shall expire after some time. (For now it is a long enough 6
months setting.)_

### InstanceAdded

```solidity
event InstanceAdded(uint256 id, address instance, address replaced, uint256 timstamp)
```

### SGX_INVALID_INSTANCE

```solidity
error SGX_INVALID_INSTANCE()
```

### SGX_INVALID_INSTANCES

```solidity
error SGX_INVALID_INSTANCES()
```

### SGX_INVALID_PROOF

```solidity
error SGX_INVALID_PROOF()
```

### init

```solidity
function init(address _addressManager) external
```

Initializes the contract with the provided address manager.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _addressManager | address | The address of the address manager contract. |

### addInstances

```solidity
function addInstances(address[] _instances) external returns (uint256[] ids)
```

Adds trusted SGX instances to the registry.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _instances | address[] | The address array of trusted SGX instances. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ids | uint256[] | The respective instanceId array per addresses. |

### addInstances

```solidity
function addInstances(uint256 id, address newInstance, address[] extraInstances, bytes signature) external returns (uint256[] ids)
```

Adds SGX instances to the registry by another SGX instance.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | uint256 | The id of the SGX instance who is adding new members. |
| newInstance | address | The new address of this instance. |
| extraInstances | address[] | The address array of SGX instances. |
| signature | bytes | The signature proving authenticity. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ids | uint256[] | The respective instanceId array per addresses. |

### verifyProof

```solidity
function verifyProof(struct IVerifier.Context ctx, struct TaikoData.Transition tran, struct TaikoData.TierProof proof) external
```

### getSignedHash

```solidity
function getSignedHash(struct TaikoData.Transition tran, address newInstance, address prover, bytes32 metaHash) public pure returns (bytes32 signedHash)
```

---
title: ProxiedSgxVerifier
---

## ProxiedSgxVerifier

Proxied version of the parent contract.

