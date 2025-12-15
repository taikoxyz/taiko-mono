# Protocol Development Guide

This guide provides specific instructions for working with Taiko's smart contracts in the `packages/protocol` directory.

## 🎨 Solidity Coding Standards

### Import Conventions

- Use named imports
  - ✅ `import {Contract} from "./contract.sol"`
  - ❌ `import "./contract.sol"`

### Naming Conventions

- Private state variables and private/internal functions: prefix with underscore `_`
- Event names: use past tense (e.g., `BlockProposed`, `ProofVerified`)
- Function parameters: always start with `_`
- Return values: always end with `_`
- Use named parameters on mapping definitions

### Code Organization

```solidity
// ---------------------------------------------------------------
// External & Public Functions
// ---------------------------------------------------------------

// ---------------------------------------------------------------
// Internal Functions
// ---------------------------------------------------------------

// ---------------------------------------------------------------
// Private Functions
// ---------------------------------------------------------------

// ---------------------------------------------------------------
// Custom Errors
// ---------------------------------------------------------------
```

### Error Handling

- Prefer straightforward custom errors over require strings
- No natspec comments for errors
- Place errors at the end of implementation file, not in interface

### Documentation

- Use `///` for natspec comments
- External/public functions: include `@notice`
- Internal/private functions: only `@dev`
- All files (except tests): include `/// @custom:security-contact security@taiko.xyz`
- License: MIT for all Solidity files

## 🏗️ Contract Architecture

### Directory Structure

- `contracts/layer1/`: L1 contracts
- `contracts/layer2/`: L2 contracts
- `contracts/shared/`: Shared utilities
- `test/`: Test files (mirror contract structure)
- `test/layer1/shasta/inbox`: Test files for the shasta inbox (our main focus at the moment)

### 📍 Key Contract Locations (Shasta)

- `contracts/layer1/impl/Inbox.sol`: main rollup contract that handles propose, prove and finalization.
- `contracts/layer1/iface`: interfaces for protocol contracts, including most data structures.
- `contracts/layer2/based/ShastaAnchor.sol`: Anchor contract for synchronizing L1 state into the L2 and also does bond management.

### Design Patterns

- UUPS upgradeable pattern with OpenZeppelin
- Resolver pattern for cross-contract discovery
- Storage gaps (`uint256[50] __gap`) for upgrade safety (upgradeable contracts only)

## 🧪 Testing Methodology

**IMPORTANT**: Always use the `solidity-tester` subagent (via Task tool) for running tests, writing tests, or debugging test failures.

### Test Naming Convention

- Positive tests: `test_functionName_Description`
- Negative tests: `test_functionName_RevertWhen_Description`

### Test Structure

```solidity
// Inherit from CommonTest
contract MyTest is CommonTest {
    // Use provided test accounts: Alice, Bob, Carol, David, Emma

    function test_myFunction_succeeds() external {
        // Setup
        // Action with vm.expectEmit() for events
        // Assert storage and events
    }
}
```

### Testing best practices

- Use `vm.expectEmit()` without parameters (sets all to true)
- Prefer actual implementations instead of mocks for tests when possible. The setup should reflect the actual dependency as much as possible.

### Optimizing Gas Usage

1. Baseline: `pnpm snapshot:l1` and save results
2. Focus on reducing storage operations
3. Run `pnpm snapshot:l1` after changes
4. Compare diffs in `gas-reports/` and `snapshots/`
5. Document improvements in PR

### Debugging failed tests

```
forge test --match-test test_name -vvvv

# Check specific contract
forge test --match-path path/to/test.sol -vvvv
```

## 🚀 Development Commands

### Compilation

```bash
pnpm compile              # All contracts
pnpm compile:l1          # Layer 1 only (FOUNDRY_PROFILE=layer1)
pnpm compile:l2          # Layer 2 only (FOUNDRY_PROFILE=layer2)
```

### Testing

```bash
pnpm test                # Run all tests
pnpm test:l1            # L1 tests only
pnpm test:l2            # L2 tests only
pnpm test:coverage      # Generate coverage report

# Single test execution
forge test --match-test <name>   # Test by name
forge test --match-path <path>   # Test by file
forge test -vvvv                # Debug with max verbosity
forge test --match-path <path> --summary  # Test summary with gas usage
```

### ⚠️ SHASTA PROTOCOL TESTING

```bash
# IMPORTANT: When testing shasta changes, run ONLY:
forge test --match-path "test/layer1/shasta/inbox/*"
# DO NOT run the entire test suite for shasta development
```

### Performance Analysis

```bash
forge test --gas-report         # Generate gas usage report
forge test --match-path <path> --gas-limit <limit>  # Test with gas constraints
```

## ⛽ Gas Optimization Workflow

L1 contracts require aggressive gas optimization. Follow this workflow:

### 1. Baseline Measurement

```bash
pnpm snapshot:l1
# Save gas-reports/layer1-contracts.txt as baseline
```

### 2. Optimization Targets

- Minimize storage reads/writes
- Pack storage variables
- Use memory over storage where possible
- Batch operations
- Use calldata instead of memory when possible
- Store hashes of structs instead of entire structs

### 3. Impact Analysis

```bash
pnpm snapshot:l1
# Compare new gas-reports/layer1-contracts.txt with baseline
# Review gas-reports/*.txt for Foundry's snapshotGas measurements
```

### Storage Layout Verification

```bash
pnpm layout  # CRITICAL: Run before and after changes to upgradeable contracts
```

## 🔢 Unchecked Arithmetic Guidelines

### Overview

The Inbox contract and its optimized variant use unchecked blocks aggressively for gas optimization. All unchecked operations have been verified safe through:

- Bounded loop counters (limited by array lengths or configuration parameters)
- Modulo operations (mathematically cannot overflow)
- Increments with protocol invariant guarantees (e.g., proposal IDs, span counters)
- Timestamp/block number arithmetic with practical overflow impossibility

See inline comments for specific safety justifications on each unchecked block.

### IMPORTANT - Type Conversions in Unchecked Blocks

Due to aggressive use of unchecked blocks throughout these contracts, developers **MUST** explicitly cast values to their proper types before performing mathematical operations when mixing different numeric types. Without explicit casts, Solidity may perform implicit conversions that could lead to unexpected results within unchecked blocks.

**Example:**

```solidity
// ✅ CORRECT - Explicit casting
uint256(uint48Value) + uint256(anotherUint48)

// ❌ WRONG - May cause unexpected behavior
uint48Value + anotherUint48  // Could overflow in unchecked block
```

### Best Practices for Unchecked Blocks

1. **Always document safety**: Add inline comments explaining why each unchecked operation is safe
2. **Use explicit type casting**: Convert to the target type before operations
3. **Verify bounds**: Ensure all values are within safe ranges before unchecked operations
4. **Test edge cases**: Include tests for maximum values and boundary conditions
5. **Review carefully**: All unchecked blocks should be reviewed by multiple developers

## 📋 Pre-Commit Checklist

Before submitting any changes:

1. **Format code**: `pnpm fmt:sol`
2. **Run full test suite**: `pnpm test`
3. **Check coverage**: `pnpm test:coverage`
4. **Verify storage layout**: `pnpm layout` (compare before/after)
5. **Check gas impact**: `pnpm snapshot:l1`
6. **Run performance benchmarks** for critical contracts
7. **Validate test isolation** and cleanup
8. **Review gas usage patterns** and optimization opportunities

## 🏛️ Upgrade Safety Guidelines

For upgradeable contracts:

1. Never modify existing storage variable order
2. Always add new variables at the end
3. Include storage gaps: `uint256[50] __gap`
4. Run `pnpm layout` before and after changes
5. Document storage layout changes in PR

---

**Note**: For monorepo-wide guidance, see root `/CLAUDE.md`
