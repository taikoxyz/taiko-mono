## ConfigManager

### kv

```solidity
mapping(bytes32 => bytes) kv
```

### Updated

```solidity
event Updated(string name, bytes newVal, bytes oldVal)
```

### init

```solidity
function init() external
```

### setValue

```solidity
function setValue(string name, bytes val) external
```

### getValue

```solidity
function getValue(string name) public view returns (bytes)
```

