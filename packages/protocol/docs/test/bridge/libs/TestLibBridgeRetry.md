# TestLibBridgeRetry









## Methods

### addressManager

```solidity
function addressManager() external view returns (address)
```

Returns the AddressManager&#39;s address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The AddressManager&#39;s address. |

### init

```solidity
function init(address _addressManager) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _addressManager | address | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### resolve

```solidity
function resolve(string name) external view returns (address payable)
```

Resolves a name to an address.

*This funcition will throw if the resolved address is `address(0)`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| name | string | The name to resolve |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | The name&#39;s corresponding address |

### resolve

```solidity
function resolve(uint256 chainId, string name) external view returns (address payable)
```

Resolves a name to an address.

*This funcition will throw if the resolved address is `address(0)`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| chainId | uint256 | The chainId |
| name | string | The name to resolve |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | The name&#39;s corresponding address |

### retryMessage

```solidity
function retryMessage(IBridge.Message message, bool lastAttempt) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| message | IBridge.Message | undefined |
| lastAttempt | bool | undefined |

### state

```solidity
function state() external view returns (uint256 nextMessageId, struct IBridge.Context ctx)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| nextMessageId | uint256 | undefined |
| ctx | IBridge.Context | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |



## Events

### Initialized

```solidity
event Initialized(uint8 version)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



