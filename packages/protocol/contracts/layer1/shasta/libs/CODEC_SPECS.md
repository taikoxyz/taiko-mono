# Solidity Struct Codec Specification V2

## Improved with Implementation Lessons

## Goals

- **Minimize gas** for both `encode()` and `decode()`.
- **Pack fields to bits** to reduce event data size.
- Support **all Solidity types** with optional annotations for compression.
- **Validate annotated fields** during encoding to ensure data integrity.

---

## Critical Implementation Warnings ⚠️

### Memory Layout Mistakes to Avoid

1. **Struct Memory Layout != Storage Layout**
   - In memory, structs store **pointers** to nested structs/arrays, not the data inline
   - Example: A `Claim` struct inside `ClaimRecord` is stored as a pointer at offset 0x20

   ```solidity
   // WRONG: Assuming claim data is inline
   mstore(add(claimRecord_, 0x20), mload(add(ptr, 6))) // This stores data, not pointer!

   // CORRECT: Allocate struct and store pointer
   let claim := mload(0x40)  // Get free memory pointer
   mstore(0x40, add(claim, 0xe0))  // Update free memory pointer
   mstore(add(claimRecord_, 0x20), claim)  // Store pointer to claim
   mstore(claim, mload(add(ptr, 6)))  // Now store actual data in claim
   ```

2. **Reading Single Bytes**
   - No `mload8` function exists in assembly
   - Must use `and(mload(addr), 0xff)` or define helper function

   ```solidity
   // WRONG
   let value := mload8(ptr)

   // CORRECT - Option 1: Inline
   let value := and(mload(ptr), 0xff)

   // CORRECT - Option 2: Helper function
   function mload8(addr) -> result {
       result := and(mload(addr), 0xff)
   }
   ```

3. **Array Memory Allocation**
   - Dynamic arrays need proper length prefix and memory allocation

   ```solidity
   // Allocate array with N elements
   let array := mload(0x40)
   mstore(array, N)  // Store length at first slot
   mstore(0x40, add(array, mul(add(N, 1), 0x20)))  // Reserve N+1 slots

   // Store array pointer in struct
   mstore(add(structPtr, offset), array)

   // Access array elements
   let arrayData := add(array, 0x20)  // Skip length prefix
   ```

---

## Annotations

- `@max=N` — Values in `[0, N]` (inclusive) use exact byte width needed. Must validate `value <= N` during encoding.
- `@maxLength=N` — Dynamic arrays with max length N. Must validate `array.length <= N` during encoding.
- `@optional` — 1-bit presence flag; omit value bits if absent (default on decode).

---

## Implementation Requirements

### 1. Planning Your Codec

**Before writing any code:**

1. Document the exact byte layout of your encoded format
2. Calculate the base size and per-element sizes
3. Identify which fields can be packed together
4. Plan your memory allocation strategy for decoding

**Example Documentation:**

```
ClaimRecord Encoding Layout (182 base bytes):
Offset | Size | Field
-------|------|------
0      | 6    | proposalId (uint48)
6      | 32   | claim.proposalHash
38     | 32   | claim.parentClaimHash
70     | 6    | claim.endBlockNumber (uint48)
76     | 32   | claim.endBlockHash
108    | 32   | claim.endStateRoot
140    | 20   | claim.designatedProver (address)
160    | 20   | claim.actualProver (address)
180    | 1    | span (uint8)
181    | 1    | bondInstructions.length

Each BondInstruction (47 bytes):
0      | 6    | proposalId (uint48)
6      | 1    | bondType (enum/uint8)
7      | 20   | payer (address)
27     | 20   | receiver (address)
```

### 2. Encoding Implementation Pattern

```solidity
function encode(YourStruct memory _struct) internal pure returns (bytes memory) {
    // 1. Validate ALL annotated fields first
    if (_struct.someField > MAX_SOME_FIELD) {
        revert SOME_FIELD_EXCEEDS_MAX();
    }

    // 2. Calculate exact size
    uint256 dynamicElements = _struct.dynamicArray.length;
    uint256 size = BASE_SIZE + (dynamicElements * ELEMENT_SIZE);
    bytes memory result = new bytes(size);

    assembly {
        let ptr := add(result, 0x20)  // Skip length prefix
        let s := _struct

        // 3. Pack fixed-size fields
        // For uint48 (6 bytes) - use mstore8 for each byte
        let value := mload(s)  // Load proposalId
        mstore8(ptr, shr(40, value))
        mstore8(add(ptr, 1), shr(32, value))
        mstore8(add(ptr, 2), shr(24, value))
        mstore8(add(ptr, 3), shr(16, value))
        mstore8(add(ptr, 4), shr(8, value))
        mstore8(add(ptr, 5), value)

        // 4. For nested structs, load the pointer first
        let nestedStruct := mload(add(s, 0x20))  // Load pointer to nested struct

        // 5. Copy 32-byte values directly
        mstore(add(ptr, 6), mload(nestedStruct))  // Copy bytes32 field

        // 6. Pack addresses (20 bytes) with shift
        let addr := mload(add(nestedStruct, 0x40))
        mstore(add(ptr, 38), shl(96, addr))  // Left-align in 32 bytes

        // 7. Handle dynamic arrays
        let arrayPtr := mload(add(s, 0x60))  // Load pointer to array
        let arrayLen := mload(arrayPtr)  // Load array length
        mstore8(add(ptr, 181), arrayLen)  // Store length as single byte

        ptr := add(ptr, 182)  // Move to array data section
        let arrayData := add(arrayPtr, 0x20)  // Skip array length

        for { let i := 0 } lt(i, arrayLen) { i := add(i, 1) } {
            let element := mload(add(arrayData, mul(i, 0x20)))
            // Pack element fields...
            ptr := add(ptr, ELEMENT_SIZE)
        }
    }

    return result;
}
```

### 3. Decoding Implementation Pattern

```solidity
function decode(bytes memory _data)
    internal pure
    returns (YourStruct memory yourStruct_)
{
    if (_data.length < MIN_SIZE) revert INVALID_DATA_LENGTH();

    assembly {
        let ptr := add(_data, 0x20)  // Skip bytes length prefix

        // 1. Decode simple fields
        // For uint48 (6 bytes) - reconstruct from bytes
        let value := 0
        value := or(value, shl(40, and(mload(ptr), 0xff)))
        value := or(value, shl(32, and(mload(add(ptr, 1)), 0xff)))
        value := or(value, shl(24, and(mload(add(ptr, 2)), 0xff)))
        value := or(value, shl(16, and(mload(add(ptr, 3)), 0xff)))
        value := or(value, shl(8, and(mload(add(ptr, 4)), 0xff)))
        value := or(value, and(mload(add(ptr, 5)), 0xff))
        mstore(yourStruct_, value)

        // 2. Allocate and decode nested structs
        let nestedStruct := mload(0x40)  // Get free memory pointer
        mstore(0x40, add(nestedStruct, NESTED_STRUCT_SIZE))  // Reserve memory
        mstore(add(yourStruct_, 0x20), nestedStruct)  // Store pointer in parent

        // 3. Decode into nested struct
        mstore(nestedStruct, mload(add(ptr, 6)))  // Copy bytes32

        // 4. Decode addresses (20 bytes) with shift
        mstore(add(nestedStruct, 0x40), shr(96, mload(add(ptr, 38))))

        // 5. Decode dynamic arrays
        let arrayLen := and(mload(add(ptr, 181)), 0xff)

        // Allocate array
        let array := mload(0x40)
        mstore(array, arrayLen)
        mstore(0x40, add(array, mul(add(arrayLen, 1), 0x20)))
        mstore(add(yourStruct_, 0x60), array)

        // Decode array elements
        ptr := add(ptr, 182)
        let arrayData := add(array, 0x20)

        for { let i := 0 } lt(i, arrayLen) { i := add(i, 1) } {
            // Allocate element struct
            let element := mload(0x40)
            mstore(0x40, add(element, ELEMENT_SIZE))

            // Decode element fields...

            // Store element pointer in array
            mstore(add(arrayData, mul(i, 0x20)), element)

            ptr := add(ptr, PACKED_ELEMENT_SIZE)
        }

        // Helper function for reading single bytes
        function mload8(addr) -> result {
            result := and(mload(addr), 0xff)
        }
    }
}
```

### 4. Test Structure

#### Avoid Storage Variables in Tests

```solidity
// WRONG - Will cause "UnimplementedFeatureError" with structs containing arrays
contract MyCodecTest is CommonTest {
    MyStruct private testStruct;  // DON'T DO THIS!

    function setUp() public override {
        testStruct = MyStruct({...});  // This will fail compilation
    }
}

// CORRECT - Create structs in test functions
contract MyCodecTest is CommonTest {
    function test_roundtrip() public {
        MyStruct memory testStruct = MyStruct({...});  // Create locally
        // ... test logic
    }
}
```

#### Gas Test Console Output

```solidity
// Use string.concat and vm.toString for console output
console2.log("");  // Empty line for spacing
console2.log("Gas Comparison: Standard case");
console2.log("| Operation | Baseline | Optimized | Difference |");
console2.log("|-----------|----------|-----------|------------|");
console2.log(
    string.concat(
        "| Encode    | ",
        vm.toString(baselineGas),
        " | ",
        vm.toString(optimizedGas),
        " | ",
        optimizedGas > baselineGas ? "+" : "-",
        vm.toString(
            optimizedGas > baselineGas
                ? optimizedGas - baselineGas
                : baselineGas - optimizedGas
        ),
        " |"
    )
);
```

### 5. Common Assembly Patterns

#### Packing Multiple Small Fields

```solidity
// Packing: uint48 (6 bytes) + address (20 bytes) + uint48 (6 bytes)
// Total: 32 bytes - fits perfectly in one word!

// Encoding
let word := 0
word := or(word, shl(208, uint48_1))  // Shift 26 bytes left (26*8=208 bits)
word := or(word, shl(48, address_val)) // Shift 6 bytes left (6*8=48 bits)
word := or(word, uint48_2)             // No shift needed for last field
mstore(ptr, word)

// Decoding
let word := mload(ptr)
let uint48_1 := shr(208, word)  // Shift right 26 bytes
let address_val := and(shr(48, word), 0xffffffffffffffffffffffffffffffffffffffff)
let uint48_2 := and(word, 0xffffffffffff)  // Mask 6 bytes
```

#### Efficient Byte Extraction for Small Types

```solidity
// For uint48 (6 bytes) - avoid loops
// Encoding
mstore8(ptr, shr(40, value))       // Byte 0 (MSB)
mstore8(add(ptr, 1), shr(32, value)) // Byte 1
mstore8(add(ptr, 2), shr(24, value)) // Byte 2
mstore8(add(ptr, 3), shr(16, value)) // Byte 3
mstore8(add(ptr, 4), shr(8, value))  // Byte 4
mstore8(add(ptr, 5), value)          // Byte 5 (LSB)

// Decoding
let value := 0
value := or(value, shl(40, mload8(ptr)))
value := or(value, shl(32, mload8(add(ptr, 1))))
value := or(value, shl(24, mload8(add(ptr, 2))))
value := or(value, shl(16, mload8(add(ptr, 3))))
value := or(value, shl(8, mload8(add(ptr, 4))))
value := or(value, mload8(add(ptr, 5)))
```

### 6. Debugging Checklist

When tests fail:

1. **Check Memory Layout**
   - Are you storing pointers vs data correctly?
   - Are nested structs allocated before use?
   - Is the free memory pointer updated correctly?

2. **Check Byte Alignment**
   - Are addresses properly shifted (shl(96) for encoding, shr(96) for decoding)?
   - Are you using the correct masks for extraction?
   - Are multi-byte values assembled in the correct order?

3. **Check Array Handling**
   - Is the array length stored correctly?
   - Are array elements allocated individually (for structs)?
   - Is the array data pointer offset by 0x20 from the array pointer?

4. **Use Debugging Output**

   ```solidity
   // Add temporary debugging in tests
   bytes memory encoded = encode(myStruct);
   console2.logBytes(encoded);  // See the actual bytes

   // In assembly, store to memory and log
   let debug := mload(0x40)
   mstore(debug, someValue)
   log1(debug, 0x20, 0x1234)  // Emits event with value
   ```

### 7. Gas Optimization Priority

1. **Highest Impact**
   - Replace byte-by-byte loops with word operations
   - Pack multiple fields into single mstore operations
   - Use bulk copying for arrays

2. **Medium Impact**
   - Pre-calculate sizes instead of dynamic allocation
   - Minimize memory allocation by reusing pointers
   - Use bit operations instead of division/modulo

3. **Lower Impact**
   - Reorder fields for optimal packing
   - Use inline assembly for simple operations
   - Cache frequently accessed values

### 8. Validation Strategy

```solidity
// Put all validation at the start for clarity and gas efficiency
function encode(MyStruct memory _s) internal pure returns (bytes memory) {
    // Validate all annotated fields first
    if (_s.field1 > MAX_FIELD1) revert FIELD1_EXCEEDS_MAX();
    if (_s.field2 > MAX_FIELD2) revert FIELD2_EXCEEDS_MAX();
    if (_s.array.length > MAX_ARRAY_LENGTH) revert ARRAY_EXCEEDS_MAX();

    // Additional validation for array elements if needed
    for (uint256 i = 0; i < _s.array.length; i++) {
        if (uint256(_s.array[i].enumField) > MAX_ENUM_VALUE) {
            revert ENUM_VALUE_EXCEEDS_MAX();
        }
    }

    // Now proceed with encoding...
}
```

### 9. Final Implementation Checklist

Before considering your codec complete:

- [ ] **Memory Layout**
  - [ ] Document exact byte offsets for encoded format
  - [ ] Verify struct pointers are handled correctly
  - [ ] Confirm arrays are allocated with proper length prefix

- [ ] **Assembly Code**
  - [ ] No undefined functions (like mload8)
  - [ ] All helper functions defined if used
  - [ ] Correct bit shifting for packing/unpacking
  - [ ] Proper masking when extracting partial words

- [ ] **Validation**
  - [ ] All annotated fields validated before encoding
  - [ ] Custom errors defined without parameters
  - [ ] Array bounds checked

- [ ] **Testing**
  - [ ] No storage variables for structs with dynamic arrays
  - [ ] Console output uses string.concat + vm.toString
  - [ ] Gas comparison includes baseline implementation
  - [ ] Tests pass with perfect roundtrip

- [ ] **Optimization**
  - [ ] No byte-by-byte loops
  - [ ] Multiple fields packed into words where possible
  - [ ] Arrays copied in 32-byte chunks
  - [ ] Pre-calculated sizes for allocation

### 10. Example: Complete Working Pattern

Here's a minimal example showing all the correct patterns:

```solidity
library MiniCodec {
    error INVALID_DATA_LENGTH();
    error VALUE_EXCEEDS_MAX();

    struct MiniStruct {
        uint48 id;           // 6 bytes
        address owner;       // 20 bytes
        uint8[] values;      // @maxLength=10
    }

    function encode(MiniStruct memory _s) internal pure returns (bytes memory) {
        if (_s.values.length > 10) revert VALUE_EXCEEDS_MAX();

        uint256 size = 27 + _s.values.length;  // 6+20+1 + array
        bytes memory result = new bytes(size);

        assembly {
            let ptr := add(result, 0x20)

            // Pack id (6 bytes)
            let id := mload(_s)
            mstore8(ptr, shr(40, id))
            mstore8(add(ptr, 1), shr(32, id))
            mstore8(add(ptr, 2), shr(24, id))
            mstore8(add(ptr, 3), shr(16, id))
            mstore8(add(ptr, 4), shr(8, id))
            mstore8(add(ptr, 5), id)

            // Pack owner (20 bytes)
            mstore(add(ptr, 6), shl(96, mload(add(_s, 0x20))))

            // Pack array
            let arr := mload(add(_s, 0x40))
            let len := mload(arr)
            mstore8(add(ptr, 26), len)

            let arrData := add(arr, 0x20)
            ptr := add(ptr, 27)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore8(ptr, mload(add(arrData, mul(i, 0x20))))
                ptr := add(ptr, 1)
            }
        }

        return result;
    }

    function decode(bytes memory _data)
        internal pure
        returns (MiniStruct memory s_)
    {
        if (_data.length < 27) revert INVALID_DATA_LENGTH();

        assembly {
            let ptr := add(_data, 0x20)

            // Decode id
            let id := 0
            id := or(id, shl(40, and(mload(ptr), 0xff)))
            id := or(id, shl(32, and(mload(add(ptr, 1)), 0xff)))
            id := or(id, shl(24, and(mload(add(ptr, 2)), 0xff)))
            id := or(id, shl(16, and(mload(add(ptr, 3)), 0xff)))
            id := or(id, shl(8, and(mload(add(ptr, 4)), 0xff)))
            id := or(id, and(mload(add(ptr, 5)), 0xff))
            mstore(s_, id)

            // Decode owner
            mstore(add(s_, 0x20), shr(96, mload(add(ptr, 6))))

            // Decode array
            let len := and(mload(add(ptr, 26)), 0xff)
            let arr := mload(0x40)
            mstore(arr, len)
            mstore(0x40, add(arr, mul(add(len, 1), 0x20)))
            mstore(add(s_, 0x40), arr)

            let arrData := add(arr, 0x20)
            ptr := add(ptr, 27)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(add(arrData, mul(i, 0x20)), and(mload(ptr), 0xff))
                ptr := add(ptr, 1)
            }
        }
    }
}
```

This V2 specification includes all the hard-learned lessons about memory layout, assembly patterns, and common pitfalls that will help avoid the implementation mistakes encountered in the first version.
