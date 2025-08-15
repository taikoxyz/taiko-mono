# Solidity Struct Codec Optimization Guide - Proven Patterns

## Overview

This guide contains **proven optimization patterns** extracted from successful codec implementations (LibProposalCoreStateCodec). These patterns provide measurable gas savings for L1 deployment.

## Key Optimizations That Work

### 1. Essential Optimizations (Always Apply)

#### Memory-Safe Assembly Annotation

```solidity
assembly ("memory-safe") {
    // Your assembly code
}
```

#### Unchecked Blocks for Safe Arithmetic

```solidity
uint256 size;
unchecked {
    size = 182 + (bondCount * 47);  // Safe when bounds are validated
}
```

#### Bit Shifts Instead of Multiplication/Division

```solidity
// Replace: mul(arrayLen, 32) or mul(arrayLen, 0x20)
// With: shl(5, arrayLen)

let offset := shl(5, arrayLen)  // arrayLen * 32
let index := shr(5, position)    // position / 32
```

#### Cached Memory Pointers

```solidity
// Cache frequently accessed pointers at the start
let p20 := add(p, 0x20)
let p40 := add(p, 0x40)
let p60 := add(p, 0x60)

// Use cached pointers throughout
mstore(ptr, mload(p20))  // Instead of mload(add(p, 0x20))
```

### 2. Efficient 6-Byte Value Encoding/Decoding

For uint48 values (proposalId, timestamps, block numbers):

**Encoding - Use single mstore with shift:**

```solidity
// Store 6 bytes efficiently
mstore(ptr, shl(208, value))  // Shifts 48-bit value to high bytes
```

**Decoding - Extract from word:**

```solidity
// Read 6 bytes from high bytes
let value := shr(208, mload(ptr))
```

### 3. Packing Multiple Small Fields

Pack multiple fields into single word operations:

```solidity
// Encode: Pack id (6 bytes) and proposer (20 bytes) in one word
let word := or(shl(208, mload(p)), shl(48, mload(p20)))
mstore(ptr, word)

// Decode: Extract both fields from single read
let word := mload(ptr)
mstore(proposal_, shr(208, word))  // id
mstore(p20, and(shr(48, word), 0xffffffffffffffffffffffffffffffffffffffff))  // proposer
```

### 4. Address Encoding (20 bytes)

```solidity
// Encode: Shift left by 96 bits
mstore(ptr, shl(96, addressValue))

// Decode: Shift right by 96 bits
let addr := shr(96, mload(ptr))
```

### 5. Loop Unrolling for Small Arrays

Only unroll when array size is commonly small (1-4 elements):

```solidity
// Unroll for common small sizes
if lt(len, 5) {
    if iszero(iszero(len)) {
        mstore(dst, mload(src))
        if gt(len, 1) {
            mstore(add(dst, 32), mload(add(src, 32)))
            if gt(len, 2) {
                mstore(add(dst, 64), mload(add(src, 64)))
                if gt(len, 3) {
                    mstore(add(dst, 96), mload(add(src, 96)))
                }
            }
        }
    }
    dst := add(dst, shl(5, len))  // Update pointer with bit shift
}

// Regular loop for larger arrays
if gt(len, 4) {
    let end := add(src, shl(5, len))
    for { } lt(src, end) { } {
        mstore(dst, mload(src))
        src := add(src, 32)
        dst := add(dst, 32)
    }
}
```

## Complete Working Example

Based on LibProposalCoreStateCodec (proven to work):

```solidity
function encode(YourStruct memory _s) internal pure returns (bytes memory) {
    // 1. Validate annotated fields first
    if (_s.someField > MAX_VALUE) revert FIELD_EXCEEDS_MAX();

    // 2. Calculate size with unchecked and bit shift
    uint256 arrayLen = _s.array.length;
    uint256 size;
    unchecked {
        size = BASE_SIZE + (arrayLen << 5);  // bit shift for *32
    }

    bytes memory result = new bytes(size);

    assembly ("memory-safe") {
        let ptr := add(result, 0x20)

        // 3. Cache frequently used pointers
        let s20 := add(_s, 0x20)
        let s40 := add(_s, 0x40)

        // 4. Pack small fields efficiently
        // For uint48 (6 bytes):
        mstore(ptr, shl(208, mload(_s)))

        // For address (20 bytes):
        mstore(add(ptr, 6), shl(96, mload(s20)))

        // 5. Copy arrays efficiently
        let src := add(mload(s40), 0x20)  // Array data start
        let dst := add(ptr, OFFSET)
        let len := mload(mload(s40))      // Array length

        // Simple loop (no complex unrolling if not needed)
        let end := add(src, shl(5, len))
        for { } lt(src, end) { } {
            mstore(dst, mload(src))
            src := add(src, 32)
            dst := add(dst, 32)
        }
    }

    return result;
}

function decode(bytes memory _data) internal pure returns (YourStruct memory s_) {
    if (_data.length < MIN_SIZE) revert INVALID_DATA_LENGTH();

    assembly ("memory-safe") {
        let ptr := add(_data, 0x20)

        // Cache struct field pointers
        let s20 := add(s_, 0x20)
        let s40 := add(s_, 0x40)

        // Decode uint48 (6 bytes)
        mstore(s_, shr(208, mload(ptr)))

        // Decode address (20 bytes)
        mstore(s20, shr(96, mload(add(ptr, 6))))

        // Decode arrays
        let arrayLen := byte(0, mload(add(ptr, OFFSET)))

        // Allocate array
        let array := mload(0x40)
        mstore(array, arrayLen)
        let newFreePtr := add(array, shl(5, add(arrayLen, 1)))
        mstore(0x40, newFreePtr)
        mstore(s40, array)

        // Copy array data
        let src := add(ptr, ARRAY_OFFSET)
        let dst := add(array, 0x20)
        let end := add(src, shl(5, arrayLen))
        for { } lt(src, end) { } {
            mstore(dst, mload(src))
            src := add(src, 32)
            dst := add(dst, 32)
        }
    }
}
```

## Critical Rules

### DO:

- ✅ Use `assembly ("memory-safe")`
- ✅ Use `unchecked` for safe arithmetic
- ✅ Use `shl(5, x)` instead of `mul(x, 32)`
- ✅ Cache memory pointers that are used multiple times
- ✅ Use `shl(208, value)` for 6-byte values
- ✅ Use `shl(96, value)` for addresses
- ✅ Use `byte(0, mload(ptr))` for single bytes

### DON'T:

- ❌ Over-complicate with excessive loop unrolling
- ❌ Use `mstore8` multiple times when you can use single `mstore`
- ❌ Use `mul` when bit shifts work
- ❌ Forget to validate array lengths before calculating sizes

## Testing Pattern

Always test against baseline `abi.encode/decode`:

```solidity
function test_roundtrip() public {
    YourStruct memory original = createTestStruct();

    // Test optimized codec
    bytes memory encoded = YourCodec.encode(original);
    YourStruct memory decoded = YourCodec.decode(encoded);

    // Verify all fields match
    assertEq(decoded.field1, original.field1);
    assertEq(decoded.field2, original.field2);
    // ... test all fields
}

function test_gasComparison() public {
    YourStruct memory data = createTestStruct();

    uint256 gas = gasleft();
    bytes memory baseline = abi.encode(data);
    uint256 baselineGas = gas - gasleft();

    gas = gasleft();
    bytes memory optimized = YourCodec.encode(data);
    uint256 optimizedGas = gas - gasleft();

    console2.log("Baseline:", baselineGas);
    console2.log("Optimized:", optimizedGas);
    console2.log("Savings:", baselineGas - optimizedGas);
}
```

## Expected Performance

With these optimizations properly applied:

- **Encode**: Slight increase for small data, 5-15% savings for large data
- **Decode**: 20-50% gas savings across all sizes
- **Data size**: Significant reduction through bit-packing

The key is **consistency and simplicity** - apply the proven patterns systematically without over-engineering.
