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
**Recommendation:** Split codecs by struct type for better maintainability and gas optimization:
- `LibProposalCoreStateCodec.sol` - Codec for Proposal and CoreState structs
- `LibClaimRecordCodec.sol` - Codec for ClaimRecord struct
- `test/ProposalCoreStateCodec/LibProposalCoreStateCodec_Core.t.sol` - Core functionality tests
- `test/ProposalCoreStateCodec/LibProposalCoreStateCodec_Fuzz.t.sol` - Fuzz tests
- `test/ProposalCoreStateCodec/LibProposalCoreStateCodec_Gas.t.sol` - Gas comparison tests

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
function encode(
    IInbox.Proposal memory _proposal,
    IInbox.CoreState memory _coreState
) internal pure returns (bytes memory) {
    // 1. VALIDATE annotated fields first
    if (_proposal.basefeeSharingPctg > MAX_BASEFEE_PCTG) {
        revert BASEFEE_SHARING_PCTG_EXCEEDS_MAX();
    }
    if (_proposal.blobSlice.blobHashes.length > MAX_BLOB_HASHES) {
        revert BLOB_HASHES_ARRAY_EXCEEDS_MAX();
    }
    
    // 2. Calculate EXACT size: 158 + (hashCount * 32) bytes
    uint256 size = 158 + (hashCount * 32);
    bytes memory result = new bytes(size);
    
    // 3. Use assembly for efficient packing
    assembly {
        // IMPORTANT OPTIMIZATION: Avoid byte-by-byte loops!
        // Instead, use bulk memory operations with bit shifting:
        
        // Pack multiple small fields into single words, then mstore
        let word := or(shl(208, mload(p)), shl(48, mload(add(p, 0x20))))
        mstore(ptr, word)
        
        // For arrays, copy in 32-byte chunks
        for { let end := add(src, mul(len, 32)) } lt(src, end) { } {
            mstore(dst, mload(src))
            src := add(src, 32)
            dst := add(dst, 32)
        }
    }
}
```

#### Decoding Function
```solidity
function decode(bytes memory _data)
    internal pure
    returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_) 
{
    if (_data.length < 158) revert INVALID_DATA_LENGTH();
    
    assembly {
        // IMPORTANT OPTIMIZATION: Avoid byte-by-byte loops!
        // Read full words and extract fields with bit operations:
        
        // Read full word and extract multiple fields
        let word := mload(ptr)
        mstore(proposal_, shr(208, word)) // id (6 bytes)
        mstore(add(proposal_, 0x20), and(shr(48, word), 0xffffffffffffffffffffffffffffffffffffffff)) // proposer
        
        // For arrays, copy in 32-byte chunks
        for { let end := add(src, mul(arrayLen, 32)) } lt(src, end) { } {
            mstore(dst, mload(src))
            src := add(src, 32)
            dst := add(dst, 0x20)
        }
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
   // Encoding: Pack with other fields in a word
   let word := or(shl(208, id), shl(48, proposer))
   mstore(ptr, word)
   // Decoding: Extract from packed word
   let word := mload(ptr)
   let proposer := and(shr(48, word), 0xffffffffffffffffffffffffffffffffffffffff)
   ```

5. **Validation Errors**: Use simple custom errors without parameters for gas efficiency:
   ```solidity
   error INVALID_DATA_LENGTH();
   error BASEFEE_SHARING_PCTG_EXCEEDS_MAX();
   error BLOB_HASHES_ARRAY_EXCEEDS_MAX();
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

1. **Avoid byte-by-byte loops**: Never iterate over individual bytes. Instead:
   - Pack multiple small fields into words using bit shifts
   - Use bulk memory operations (mstore/mload for full 32-byte words)
   - Only use mstore8 for individual bytes when absolutely necessary

2. **Efficient word packing**: Combine multiple fields in single operations:
   ```solidity
   // Good: Pack 6-byte id and 20-byte address in one operation
   let word := or(shl(208, id), shl(48, proposer))
   mstore(ptr, word)
   
   // Bad: Write fields individually
   writeBytes(ptr, id, 6)
   writeBytes(add(ptr, 6), proposer, 20)
   ```

3. **Bulk array copying**: Always copy arrays in 32-byte chunks:
   ```solidity
   for { let end := add(src, mul(len, 32)) } lt(src, end) { } {
       mstore(dst, mload(src))
       src := add(src, 32)
       dst := add(dst, 32)
   }
   ```

4. **Pre-calculate sizes**: Calculate total size once before allocation
5. **Minimize computational overhead**: Only pack data where storage savings significantly outweigh computational cost

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
- **Gas efficiency**: 
  - Encoding: Slightly higher gas (+10-15%) due to packing overhead
  - Decoding: Significantly lower gas (-40-60%) due to smaller data size
  - Overall: Net gas savings when considering both operations
- **Correctness**: Perfect roundtrip for all valid inputs
- **Validation**: Proper rejection of invalid annotated values

**Real-world results from implementation:**
```
Standard (3 hashes):
| Operation | Baseline | Optimized | Difference |
|-----------|----------|-----------|------------|
| Encode    | 1147     | 1303      | +156       |
| Decode    | 2824     | 1331      | -1493      |
```

### 10. Assembly Tips

1. **Reading packed data**: Extract fields from words using masks and shifts:
   ```solidity
   let word := mload(ptr)
   let field1 := shr(208, word)  // First 6 bytes
   let field2 := and(shr(48, word), 0xfff...)  // Next 20 bytes
   ```

2. **Writing packed data**: Combine fields before storing:
   ```solidity
   let word := or(shl(208, field1), or(shl(160, field2), shl(112, field3)))
   mstore(ptr, word)
   ```

3. **Single bytes**: Only use `mstore8` for truly individual bytes (booleans, small uints)
4. **Loops**: Optimize for 32-byte boundaries when possible
5. **Memory pointers**: Track position using offsets from base pointer

---

## Complete Example Structure

```solidity
library LibProposalCoreStateCodec {
    // Constants for validation
    uint256 private constant MAX_BASEFEE_PCTG = 100;
    uint256 private constant MAX_BLOB_HASHES = 64;
    
    // Simple custom errors (no parameters for gas efficiency)
    error INVALID_DATA_LENGTH();
    error BASEFEE_SHARING_PCTG_EXCEEDS_MAX();
    error BLOB_HASHES_ARRAY_EXCEEDS_MAX();
    
    function encode(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    ) internal pure returns (bytes memory) {
        // Validate annotated fields
        // Calculate exact size
        // Pack using bulk operations and word packing
    }
    
    function decode(bytes memory _data) 
        internal pure 
        returns (IInbox.Proposal memory, IInbox.CoreState memory) {
        // Check minimum length
        // Unpack using word extraction and bulk copies
    }
}
```

## Lessons Learned from Implementation

### Key Optimization Insights

1. **Bulk Operations Are Critical**: The most significant gas savings come from avoiding byte-by-byte operations. Always pack multiple small fields into words and use full 32-byte memory operations.

2. **Trade-offs in Encoding vs Decoding**: 
   - Encoding may use slightly more gas due to packing overhead
   - Decoding benefits significantly from smaller data size
   - Overall system benefits from reduced calldata/event costs

3. **Separation of Concerns**: Splitting codecs by struct type (e.g., `LibProposalCoreStateCodec` vs `LibClaimRecordCodec`) provides:
   - Better code organization
   - Easier testing and maintenance
   - Potential for struct-specific optimizations

4. **Simplified Error Handling**: Using parameterless custom errors reduces gas costs while still providing clear failure reasons.

5. **Assembly Patterns That Work**:
   - Pack fields into words before storing: `or(shl(208, field1), shl(48, field2))`
   - Extract fields using masks and shifts: `and(shr(48, word), 0xfff...)`
   - Copy arrays in 32-byte chunks for maximum efficiency

### Implementation Checklist

- [ ] Validate all annotated fields before encoding
- [ ] Use bulk memory operations (avoid loops over individual bytes)
- [ ] Pack multiple small fields into single words
- [ ] Copy arrays in 32-byte chunks
- [ ] Use simple custom errors without parameters
- [ ] Test with gas comparison against baseline
- [ ] Verify perfect roundtrip for all valid inputs
- [ ] Document exact memory layout for maintainability

This specification provides all necessary details to recreate the optimized codec implementation with proper validation, testing, and gas optimization.