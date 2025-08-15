# Solidity Struct Codec Specification

## Goals
- **Minimize gas** for both `encode()` and `decode()`.
- **Pack fields to bits** to reduce event data size.
- Support **all Solidity types** with optional annotations for compression.
- **Validate annotated fields** during encoding to ensure data integrity.

---

## Annotations
- `@max=N` — Values in `[0, N]` (inclusive) use exact byte width needed. Must validate `value <= N` during encoding.
- `@maxLength=N` — Dynamic arrays with max length N. Must validate `array.length <= N` during encoding.
- `@optional` — 1-bit presence flag; omit value bits if absent (default on decode).

**Important:** Annotations are added by the user only. Implementation should not add annotations but must validate all user-provided annotations.

---

## Implementation Requirements

### 1. File Structure
Create the following files:
- `LibCodec.sol` - Core library with optimized encoding/decoding functions
- `test/LibCodecCore.t.sol` - Core functionality tests (roundtrip, min/max values, validation)
- `test/LibCodecFuzz.t.sol` - Comprehensive fuzz tests for all input combinations
- `test/LibCodecGas.t.sol` - Gas comparison tests with baseline implementation

### 2. Memory Layout and Bit-Packing

For optimal gas efficiency, use the following exact memory layout:

#### Proposal Structure
```
- id: 6 bytes (uint48)
- proposer: 20 bytes (address)
- originTimestamp: 6 bytes (uint48)
- originBlockNumber: 6 bytes (uint48)
- isForcedInclusion: 1 byte (bool)
- basefeeSharingPctg: 1 byte (uint8, @max=100)
- blobSlice.blobHashes.length: 3 bytes (uint24, @maxLength=64)
- blobSlice.blobHashes: 32 bytes each
- blobSlice.offset: 3 bytes (uint24)
- blobSlice.timestamp: 6 bytes (uint48)
- coreStateHash: 32 bytes
```

#### CoreState Structure
```
- nextProposalId: 6 bytes (uint48)
- lastFinalizedProposalId: 6 bytes (uint48)
- lastFinalizedClaimHash: 32 bytes
- bondInstructionsHash: 32 bytes
```

### 3. Critical Implementation Details

#### Encoding Function
```solidity
function encodeProposedEventData(
    IInbox.Proposal memory _proposal,
    IInbox.CoreState memory _coreState
) internal pure returns (bytes memory) {
    // 1. VALIDATE annotated fields first
    if (_proposal.basefeeSharingPctg > MAX_BASEFEE_PCTG) {
        revert VALUE_EXCEEDS_MAX_LIMIT("basefeeSharingPctg", _proposal.basefeeSharingPctg, MAX_BASEFEE_PCTG);
    }
    if (_proposal.blobSlice.blobHashes.length > MAX_BLOB_HASHES) {
        revert ARRAY_LENGTH_EXCEEDS_MAX("blobHashes", hashCount, MAX_BLOB_HASHES);
    }
    
    // 2. Calculate EXACT size: 158 + (hashCount * 32) bytes
    uint256 size = 158 + (hashCount * 32);
    bytes memory result = new bytes(size);
    
    // 3. Use assembly for efficient packing
    assembly {
        // Use helper function to write N bytes from a value
        function writeBytes(dest, value, numBytes) {
            for { let i := 0 } lt(i, numBytes) { i := add(i, 1) } {
                mstore8(add(dest, i), shr(mul(sub(sub(numBytes, 1), i), 8), value))
            }
        }
        
        // Pack fields in exact order with exact byte widths
        // IMPORTANT: Use mstore for 20/32 byte fields, writeBytes for others
    }
}
```

#### Decoding Function
```solidity
function decodeProposedEventData(bytes memory _data)
    internal pure
    returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_) 
{
    if (_data.length < 158) revert INVALID_DATA_LENGTH();
    
    assembly {
        // Helper to read N bytes as uint
        function readBytes(src, numBytes) -> result {
            for { let i := 0 } lt(i, numBytes) { i := add(i, 1) } {
                result := or(result, shl(mul(sub(sub(numBytes, 1), i), 8), byte(0, mload(add(src, i)))))
            }
        }
        
        // Unpack fields in exact order
        // IMPORTANT: Allocate memory for dynamic arrays properly
    }
}
```

### 4. Common Pitfalls to Avoid

1. **Boolean Encoding**: Use full bytes for booleans, not bits. Assembly `mstore8` for single bytes.

2. **Array Length Encoding**: Use 3 bytes (uint24) for array lengths to support up to 16M elements while saving gas.

3. **Memory Allocation**: When decoding dynamic arrays:
   ```solidity
   let hashArray := mload(0x40)
   mstore(hashArray, arrayLen)
   mstore(0x40, add(hashArray, mul(add(arrayLen, 1), 0x20)))
   ```

4. **Address Handling**: For 20-byte addresses:
   ```solidity
   // Encoding: mstore(ptr, shl(96, address))
   // Decoding: shr(96, mload(ptr))
   ```

5. **Validation Errors**: Define custom errors with parameters:
   ```solidity
   error VALUE_EXCEEDS_MAX_LIMIT(string field, uint256 value, uint256 maxLimit);
   error ARRAY_LENGTH_EXCEEDS_MAX(string field, uint256 length, uint256 maxLength);
   ```

### 5. Test Requirements

#### Core Tests (LibCodecCore.t.sol)
- Basic roundtrip test with typical values
- Minimum values test (all zeros/empty)
- Maximum values test (type max values)
- Validation tests for annotated fields
- Data integrity test (multiple encode/decode cycles)

#### Fuzz Tests (LibCodecFuzz.t.sol)
- Single proposal with random values
- Variable array sizes (1-64 elements)
- Extreme values (min/max)
- Hash collision resistance
- Differential testing against baseline

#### Gas Tests (LibCodecGas.t.sol)
- Include baseline implementation using `abi.encode/decode`
- Compare gas for standard (3 hashes), minimal (1 hash), maximum (64 hashes)
- Test gas scaling with different array sizes
- Comprehensive benchmark across multiple scenarios
- Validation overhead test
- **Output markdown table for gas comparison**: Tests must log a markdown table showing:
  - Baseline gas for encode and decode operations
  - Optimized gas for encode and decode operations
  - Difference (positive for gas increase, negative for gas savings)
  
  Example output format:
  ```
  Gas Comparison: Standard (3 hashes)
  | Operation | Baseline | Optimized | Difference |
  |-----------|----------|-----------|------------|
  | Encode    | 1147     | 5256      | +4109      |
  | Decode    | 2824     | 6126      | +3302      |
  ```
  
  Run test with command:
  ```bash
  FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/ProposalCoreStateCodec/LibProposalCoreStateCodec_Gas.t.sol" -vv
  ```
  This generates both console output with markdown tables and GasReport events showing encode/decode gas usage

### 6. Gas Optimization Techniques

1. **Pre-calculate sizes**: Calculate total size once before allocation
2. **Use helper functions**: Reduce bytecode size with internal assembly helpers
3. **Batch operations**: Copy arrays in 32-byte chunks where possible
4. **Minimize storage reads**: Cache frequently accessed values in memory
5. **Avoid redundant operations**: Don't recalculate known constants

### 7. Validation Requirements

For each annotated field, validate BEFORE encoding:
- `@max=N`: Ensure `value <= N`
- `@maxLength=N`: Ensure `array.length <= N`

Use descriptive revert messages that include:
- Field name
- Actual value
- Maximum allowed value

### 8. Testing Baseline Comparison

The baseline implementation should be in the test file, NOT in the main library:

```solidity
// In LibCodecGas.t.sol
function encodeBaseline(
    IInbox.Proposal memory _proposal,
    IInbox.CoreState memory _coreState
) private pure returns (bytes memory) {
    return abi.encode(_proposal, _coreState);
}

function decodeBaseline(bytes memory _data)
    private pure
    returns (IInbox.Proposal memory, IInbox.CoreState memory) 
{
    return abi.decode(_data, (IInbox.Proposal, IInbox.CoreState));
}
```

### 9. Expected Results

The optimized implementation should achieve:
- **Size reduction**: ~50-70% smaller than abi.encode for typical data
- **Gas efficiency**: Lower gas for encoding despite validation overhead
- **Correctness**: Perfect roundtrip for all valid inputs
- **Validation**: Proper rejection of invalid annotated values

### 10. Assembly Tips

1. **Reading bytes**: Use `byte(0, mload(ptr))` for single bytes
2. **Writing bytes**: Use `mstore8(ptr, value)` for single bytes
3. **Shifting**: Use `shl` and `shr` for efficient bit manipulation
4. **Loops**: Keep them simple with clear increment logic
5. **Memory pointers**: Always track current position accurately

---

## Complete Example Structure

```solidity
library LibCodec {
    // Constants for validation
    uint256 private constant _MAX_FIELD_A = 100;
    uint256 private constant _MAX_FIELD_B = 64;
    
    // Custom errors
    error INVALID_DATA_LENGTH();
    error VALUE_EXCEEDS_MAX_LIMIT(string field, uint256 value, uint256 maxLimit);
    error ARRAY_LENGTH_EXCEEDS_MAX(string field, uint256 length, uint256 maxLength);
    
    function encode(MyStruct memory _struct) internal pure returns (bytes memory) {
        // Validate -> Calculate size -> Allocate -> Pack with assembly
    }
    
    function decode(bytes memory _data) internal pure returns (MyStruct memory _struct) {
        // Check length -> Unpack with assembly -> Return structs
    }
}
```

This specification provides all necessary details to recreate the optimized codec implementation with proper validation, testing, and gas optimization.