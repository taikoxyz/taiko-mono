# Keccak256 Optimization: Anchor ProverAuth

## Summary
Optimized `keccak256(abi.encode(...))` in `Anchor._hashProverAuthMessage()` using inline assembly to eliminate ABI encoding overhead for simple types.

## Location
- File: `contracts/layer2/core/Anchor.sol`
- Function: `_hashProverAuthMessage()`
- Line: 500

## Original Implementation
```solidity
function _hashProverAuthMessage(ProverAuth memory _auth) private pure returns (bytes32) {
    return keccak256(abi.encode(_auth.proposalId, _auth.proposer, _auth.provingFee));
}
```

## Optimized Implementation
```solidity
function _hashProverAuthMessage(ProverAuth memory _auth) private pure returns (bytes32 result_) {
    assembly {
        let ptr := mload(0x40)

        // Load and store struct fields
        mstore(ptr, mload(_auth))                   // proposalId
        mstore(add(ptr, 0x20), mload(add(_auth, 0x20)))  // proposer
        mstore(add(ptr, 0x40), mload(add(_auth, 0x40)))  // provingFee

        // Hash 96 bytes
        result_ := keccak256(ptr, 0x60)
    }
}
```

## Gas Savings
- **Original gas cost**: 276 gas
- **Optimized gas cost**: 66 gas
- **Gas saved**: 210 gas
- **Savings percentage**: 76.1%

## Testing
### Test File
- `test/layer2/core/LibHashProverAuth.t.sol`

### Test Results
```
[PASS] testFuzz_hashEquivalence(uint48,address,uint256) (runs: 201, μ: 4009, ~: 4009)
[PASS] test_gasComparison() (gas: 11926)
  Original gas: 276
  Optimized gas: 66
  Gas saved: 210
  Savings %: 76
[PASS] test_hashEquivalence() (gas: 3757)
```

### Existing Tests
All existing Anchor tests pass:
- `test/layer2/core/Anchor.t.sol` - 6 tests passed

## Safety Analysis
### Correctness
- Fuzz tested with 201 runs covering all input parameter ranges
- Hash output verified to match original implementation exactly
- Existing integration tests confirm no behavioral changes

### Security
- No external calls or storage modifications
- Pure function with deterministic output
- Memory safety: uses free memory pointer correctly
- No unchecked arithmetic or overflows possible

### Maintainability
- Assembly code is well-commented
- Matches ABI encoding specification exactly
- Helper library (`LibHashProverAuth.sol`) provides reference implementation

## Impact
This function is called during prover authorization validation in the Anchor contract. The 76% gas savings apply to every prover designation signature verification on L2.

### Use Cases
- Prover authorization validation
- Signature verification for designated provers
- Bond distribution logic

## Why Such Large Savings?
The optimization is particularly effective here because:
1. Only 3 simple types being encoded (uint48, address, uint256)
2. `abi.encode` adds significant overhead for memory allocation and copying
3. Assembly directly lays out the data without intermediate steps
4. No dynamic types involved (pure fixed-size data)

## Rollup L1 Cost
This optimization is for L2-only operations (Anchor contract). There is no L1 gas impact.
