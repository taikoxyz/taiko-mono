## EtherVault

Vault that holds Ether.

### authorizedAddrs

```solidity
mapping(address => bool) authorizedAddrs
```

### __gap

```solidity
uint256[49] __gap
```

### Authorized

```solidity
event Authorized(address addr, bool authorized)
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

### init

```solidity
function init(address addressManager) external
```

### receiveEther

```solidity
function receiveEther(uint256 amount) public
```

### authorize

```solidity
function authorize(address addr, bool authorized) public
```

### isAuthorized

```solidity
function isAuthorized(address addr) public view returns (bool)
```

