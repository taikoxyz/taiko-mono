# Codec Implementation Guide

## Overview

This document defines implementation requirements for gas-optimized encoding/decoding libraries (`LibCodecXXX.sol`) in the Taiko protocol. These libraries convert between Solidity structs and tightly-packed byte arrays to minimize gas costs and calldata size.

This file can be used by Claude Code to implement or reimplement these libraries.

## Core Requirements

### 1. Library Structure

- **Naming**: Each library follows the pattern `LibCodecXXX.sol` where XXX is the struct name
- **Functions**: Each library must implement:
  - `encode(StructType memory data) → bytes memory`
  - `decode(bytes memory data) → StructType memory`
- **Gas Optimization**: Functions marked with `/// @custom:encode optimize-gas` require assembly-level optimization

### 2. Gas Optimization Strategy

For `encode` functions, optimize two components:

1. **Execution gas**: Minimize encoding/decoding opcodes
2. **Calldata gas**: Minimize byte size (16 gas per non-zero byte, 4 gas per zero byte)

For `decode` functions, only optimize execution gas.

### 3. Implementation Constraints

- **No helper functions**: Do not define sub-functions. Inline all logic directly in encode/decode
- **No function calls**: For structs containing other structs, inline the encoding/decoding logic
- **Reusable patterns**: Use consistent assembly patterns across libraries, but copy the code rather than abstracting
- **Direct assembly**: Use inline assembly for all operations to maximize gas efficiency
- **Memory efficiency**: Minimize memory allocation and copying

## Encoding Rules

### Data Type Encoding

| Data Type   | Encoding             | Assembly Example                                         |
| ----------- | -------------------- | -------------------------------------------------------- |
| **bool**    | 1 bit                | `and(1, value)`                                          |
| **enum**    | Minimal bits         | Use ceil(log2(numValues)) bits                           |
| **uint8**   | 8 bits               | `and(0xff, value)`                                       |
| **uint16**  | 16 bits              | `and(0xffff, value)`                                     |
| **uint24**  | 24 bits              | `and(0xffffff, value)`                                   |
| **uint32**  | 32 bits              | `and(0xffffffff, value)`                                 |
| **uint48**  | 48 bits              | `and(0xffffffffffff, value)`                             |
| **uint64**  | 64 bits              | `and(0xffffffffffffffff, value)`                         |
| **uint128** | 128 bits             | Store as-is                                              |
| **uint256** | 256 bits             | Store as-is                                              |
| **address** | 160 bits             | `and(0xffffffffffffffffffffffffffffffffffffffff, value)` |
| **bytes32** | 256 bits             | Store as-is                                              |
| **bytes**   | uint16 length + data | Length prefix, then raw bytes                            |

### Optional Fields

Only fields marked with `/// @custom:encode optional` use a presence flag:

```
[1 bit flag][value if flag=1]
```

- Flag = 0: Field is absent/zero (no value bytes follow)
- Flag = 1: Field is present (value bytes follow)

**Important**: Regular fields without the Optional annotation are always encoded directly without a presence flag.

### Array Encoding

Arrays use a length prefix followed by elements:

- **Default max size**: type(uint8).max (255 elements) → use uint8 for length
- **Custom max size**: Annotated as `/// @custom:encode max-size=N`
  - N ≤ 15: use 4 bits for length
  - N ≤ 31: use 5 bits for length
  - N ≤ 63: use 6 bits for length
  - N ≤ 127: use 7 bits for length
  - N ≤ 255: use 8 bits for length
  - N ≤ 511: use 9 bits for length
  - N ≤ 1023: use 10 bits for length
  - N ≤ 65,535: use uint16 for length

### Validation

In `encode` functions:

- Check array lengths against maximum sizes
- Define custom error at library level: `error ArrayTooLarge();`
- Example: `if(data.blocks.length >= 512) revert ArrayTooLarge();`

### Field Reordering

Optimize field ordering for:

- **Bit packing**: Group small fields to pack into words
- **Gas efficiency**: Minimize memory operations
- **Alignment**: Reduce padding between fields

## Implementation Patterns

### Critical Assembly Operations

#### Efficient Bit Packing

```solidity
// Pack multiple small values into one word
let packed := or(
    shl(248, value1),              // 8 bits at position 248-255
    or(shl(232, value2),           // 16 bits at position 232-247
       or(shl(184, value3),        // 48 bits at position 184-231
          shl(24, value4)))        // 160 bits at position 24-183
)
```

#### Writing Partial Bytes

```solidity
// Write less than 32 bytes efficiently
if lt(remaining, 32) {
    let mask := shl(mul(8, sub(32, remaining)), sub(shl(mul(8, remaining), 1), 1))
    mstore(ptr, and(value, mask))
}
```

#### Handling Optional Fields with Bit Flags

```solidity
// Collect multiple optional flags in one byte
let flags := 0
if iszero(iszero(optionalField1)) { flags := or(flags, 0x80) }
if iszero(iszero(optionalField2)) { flags := or(flags, 0x40) }
if iszero(iszero(optionalField3)) { flags := or(flags, 0x20) }
mstore8(ptr, flags)
ptr := add(ptr, 1)
```

### Complete Encoding Example

```solidity
function encode(ProverAuth memory data) public pure returns (bytes memory) {
    // Validation
    if(data.signature.length >= 128) revert ArrayTooLarge();

    // Calculate size
    uint256 size = 20 + 6; // prover + fee
    uint256 flags = 0;
    if (data.feeToken != address(0)) { size += 20; flags |= 0x4; }
    if (data.validUntil != 0) { size += 6; flags |= 0x2; }
    if (data.batchId != 0) { size += 6; flags |= 0x1; }
    size += 1 + 1 + data.signature.length; // flags + sig length + sig data

    bytes memory result = new bytes(size);

    assembly {
        let ptr := add(result, 0x20)

        // Pack prover (160 bits) + fee (48 bits)
        let packed := or(shl(96, data.prover), data.fee)
        mstore(ptr, packed)
        ptr := add(ptr, 26) // 20 + 6 bytes

        // Write flags byte
        mstore8(ptr, flags)
        ptr := add(ptr, 1)

        // Write optional fields based on flags
        if and(flags, 0x4) {
            mstore(ptr, shl(96, data.feeToken))
            ptr := add(ptr, 20)
        }
        if and(flags, 0x2) {
            mstore(ptr, shl(208, data.validUntil))
            ptr := add(ptr, 6)
        }
        if and(flags, 0x1) {
            mstore(ptr, shl(208, data.batchId))
            ptr := add(ptr, 6)
        }

        // Write signature length (7 bits would suffice but use 8 for simplicity)
        let sigLen := mload(data.signature)
        mstore8(ptr, sigLen)
        ptr := add(ptr, 1)

        // Copy signature bytes
        let sigData := add(data.signature, 0x20)
        for { let i := 0 } lt(i, sigLen) { i := add(i, 32) } {
            mstore(add(ptr, i), mload(add(sigData, i)))
        }
    }

    return result;
}
```

### Complete Decoding Example

```solidity
function decode(bytes memory data) public pure returns (ProverAuth memory result) {
    assembly {
        let ptr := add(data, 0x20)

        // Read prover and fee (packed in 26 bytes)
        let packed := mload(ptr)
        result.prover := shr(96, packed)
        result.fee := and(0xffffffffffff, packed)
        ptr := add(ptr, 26)

        // Read flags
        let flags := byte(0, mload(ptr))
        ptr := add(ptr, 1)

        // Read optional fields
        if and(flags, 0x4) {
            result.feeToken := shr(96, mload(ptr))
            ptr := add(ptr, 20)
        }
        if and(flags, 0x2) {
            result.validUntil := shr(208, mload(ptr))
            ptr := add(ptr, 6)
        }
        if and(flags, 0x1) {
            result.batchId := shr(208, mload(ptr))
            ptr := add(ptr, 6)
        }

        // Read signature
        let sigLen := byte(0, mload(ptr))
        ptr := add(ptr, 1)

        // Allocate signature bytes
        let sig := mload(0x40)
        mstore(sig, sigLen)
        let sigData := add(sig, 0x20)
        mstore(0x40, add(sigData, add(sigLen, 0x1f)))

        // Copy signature data
        for { let i := 0 } lt(i, sigLen) { i := add(i, 32) } {
            mstore(add(sigData, i), mload(add(ptr, i)))
        }

        mstore(add(result, 0xa0), sig) // Store at signature offset
    }
}
```

## Edge Cases and Special Handling

### Empty Arrays

- Always encode length as 0
- No elements follow the length field
- Decoder must handle allocation of empty arrays correctly

### All Optional Fields Absent

- Flags byte should be 0x00
- No optional field data follows

### Nested Structs

- Inline the encoding logic completely
- Do not call another library's encode function
- Maintain consistent bit packing across nested structures

### Memory Alignment

- Be careful with partial byte writes
- Ensure proper masking when writing less than 32 bytes
- Account for Solidity's memory layout (32-byte slots)

## Testing Checklist

- [ ] Empty arrays encode/decode correctly
- [ ] Maximum array sizes are enforced with `ArrayTooLarge()` error
- [ ] Optional fields work with all 2^n combinations present/absent
- [ ] Gas usage is significantly lower than `abi.encode/decode`
- [ ] Round-trip encode/decode preserves exact data
- [ ] Bit packing/unpacking is correct for all field sizes
- [ ] Memory allocation is efficient (check memory expansion costs)
- [ ] No memory corruption or overwrites
- [ ] Handles maximum values for all numeric types
- [ ] Proper validation of all array lengths before encoding
- [ ] For every encode or decode function annotated with `/// @custom:encode optimize-gas`, make sure there is a corresponding gas measurement/comparison test at the end of its test file. The test should evaluate gas savings appropriately based on whether the function is for encoding or decoding.
