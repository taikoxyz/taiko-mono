## LibAnchorSignature

### TAIKO_GOLDEN_TOUCH_ADDRESS

```solidity
address TAIKO_GOLDEN_TOUCH_ADDRESS
```

### TAIKO_GOLDEN_TOUCH_PRIVATEKEY

```solidity
uint256 TAIKO_GOLDEN_TOUCH_PRIVATEKEY
```

### GX

```solidity
uint256 GX
```

### GY

```solidity
uint256 GY
```

### GX2

```solidity
uint256 GX2
```

### GY2

```solidity
uint256 GY2
```

### N

```solidity
uint256 N
```

### GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW

```solidity
uint256 GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW
```

### GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH

```solidity
uint256 GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH
```

### GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW

```solidity
uint256 GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW
```

### GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH

```solidity
uint256 GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH
```

### K_2_INVM_N

```solidity
uint256 K_2_INVM_N
```

### signTransaction

```solidity
function signTransaction(bytes32 digest, uint8 k) internal view returns (uint8 v, uint256 r, uint256 s)
```

### expmod

```solidity
function expmod(uint256 baseLow, uint256 baseHigh, uint256 e, uint256 m) internal view returns (uint256 o)
```
