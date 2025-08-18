# Shasta Inbox Test Suite

## Overview

Comprehensive test suite for the Shasta Inbox contracts, supporting multiple optimized implementations with a unified testing framework. The suite ensures consistent behavior across all implementations while validating optimization benefits.

## Inbox Implementations

1. **Inbox.sol** — The base, fundamental implementation
2. **InboxOptimized1** — Fully compatible with `Inbox.sol`, includes slot reuse optimizations
3. **InboxOptimized2** — Uses custom encoder for event data to reduce gas costs
4. **InboxOptimized3** — Uses custom decoding functions for calldata (others use `abi.decode`)

## Quick Start

### Using the Test Runner Script (Recommended)

```bash
# Run all tests for all implementations
./test/layer1/shasta/inbox/run-inbox-tests.sh all

# Run specific test file for all implementations
./test/layer1/shasta/inbox/run-inbox-tests.sh all InboxBasicTest.t.sol

# Run tests for a specific implementation
./test/layer1/shasta/inbox/run-inbox-tests.sh single opt3

# Run specific test across all implementations
./test/layer1/shasta/inbox/run-inbox-tests.sh test test_propose_single_valid

# Compare gas usage across implementations
./test/layer1/shasta/inbox/run-inbox-tests.sh gas

# Generate test coverage report
./test/layer1/shasta/inbox/run-inbox-tests.sh coverage opt2

# Generate summary report
./test/layer1/shasta/inbox/run-inbox-tests.sh summary
```

### Manual Testing

Use the `INBOX` environment variable to select which implementation to test:

```bash
# Test base implementation (default)
INBOX=base FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol"

# Test InboxOptimized1
INBOX=opt1 FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol"

# Test InboxOptimized2
INBOX=opt2 FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol"

# Test InboxOptimized3
INBOX=opt3 FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol"
```

## Test Suite Architecture

### Core Infrastructure

- **InboxTest.sol** - Comprehensive base test contract with:

  - Unified setup and configuration management
  - Advanced test data factories and builders
  - Performance measurement utilities
  - Gas tracking and benchmarking tools
  - Test isolation and state management
  - Rich assertion library
  - Mock management and setup helpers

- **InboxTestLib.sol** - Shared test utilities library providing:

  - Data structure creation helpers
  - Hash computation functions
  - Chain creation utilities
  - Common test constants

- **TestInboxFactory.sol** - Factory for deploying different Inbox implementations
- **InboxTestAdapter.sol** - Adapter handling encoding/decoding differences between implementations
- **ITestInbox.sol** - Common interface for all test implementations
- **InboxMockContracts.sol** - Mock implementations for external dependencies

### Test Implementations

- **TestInboxCore.sol** - Test wrapper for base Inbox
- **TestInboxOptimized1.sol** - Test wrapper for InboxOptimized1
- **TestInboxOptimized2.sol** - Test wrapper for InboxOptimized2
- **TestInboxOptimized3.sol** - Test wrapper for InboxOptimized3

### How It Works

1. The `InboxTest` base contract reads the `INBOX` environment variable
2. It uses `TestInboxFactory` to deploy the selected implementation
3. `InboxTestAdapter` handles encoding/decoding differences:
   - InboxOptimized3 uses custom calldata encoding
   - InboxOptimized2 & 3 use custom event encoding
   - Base & Optimized1 use standard ABI encoding
4. Tests interact through the common `ITestInbox` interface

## Compatibility Notes

### Base & InboxOptimized1

- Must behave identically (except InboxOptimized1 supports claim aggregation)
- Use standard ABI encoding for both calldata and events
- Test assertions should produce identical results for non-aggregation scenarios

### InboxOptimized2

- Uses custom event encoder (`LibProposedEventEncoder`, `LibProvedEventEncoder`)
- Calldata encoding remains standard
- Event decoding in tests handled by adapter

### InboxOptimized3

- Uses custom calldata decoder (`LibProposeDataDecoder`, `LibProveDataDecoder`)
- Also uses custom event encoding like Optimized2
- Both calldata and event encoding handled by adapter

## Test Categories

### Current Test Files

1. **InboxInit.t.sol** - Contract initialization and genesis state
2. **InboxBasicTest.t.sol** - Fundamental operations and basic flows
3. **InboxProposeValidation.t.sol** - Proposal validation and error cases
4. **InboxProveBasic.t.sol** - Proof submission and validation
5. **InboxChainAdvancement.t.sol** - Chain progression and finalization
6. **InboxFinalization.t.sol** - Finalization mechanics and limits
7. **InboxRingBuffer.t.sol** - Ring buffer management and overflow
8. **InboxOutOfOrderProving.t.sol** - Non-sequential proving scenarios
9. **InboxForceInclusion.t.sol** - Forced inclusion handling

## Writing New Tests

### Best Practices

1. **Inherit from InboxTest base contract** for access to utilities
2. **Use helper functions** from InboxTest for common operations
3. **Leverage builder patterns** for test data creation
4. **Use the adapter** for implementation-agnostic encoding
5. **Follow naming conventions**:
   - Test functions: `test_<feature>_<scenario>()`
   - Helper functions: descriptive camelCase
   - Constants: UPPER_SNAKE_CASE

### Example Test Structure

```solidity
contract MyInboxTest is InboxTest {
    using InboxTestLib for *;

    function test_myFeature_happyPath() public {
        // Arrange: Set up test data using builders
        ProposalBuilder memory builder = newProposal(1)
            .withProposer(Alice)
            .withForcedInclusion(false);

        IInbox.Proposal memory proposal = buildProposal(builder);

        // Act: Execute the operation
        submitProposal(1, Alice);

        // Assert: Verify results using helper assertions
        assertProposalStored(1);
        assertProposalHashMatches(1, proposal);
    }

    function test_myFeature_errorCase() public {
        // Use expectRevertWithReason for clear error testing
        expectRevertWithReason(
            InvalidState.selector,
            "Should reject invalid state"
        );

        // Attempt invalid operation
        // ...
    }

    function test_myFeature_gasOptimization() public {
        // Use gas tracking for performance tests
        GasSnapshot memory snapshot = startGasTracking("propose");
        submitProposal(1, Alice);
        uint256 gasUsed = endGasTracking(snapshot);

        // Assert gas is within expected bounds
        assertGasUsage(gasUsed, 100_000, 10_000, "propose operation");
    }
}
```

### Using Test Utilities

```solidity
// Create test scenarios quickly
(IInbox.Proposal[] memory proposals, IInbox.Claim[] memory claims) =
    createProvenChain(1, 5, getGenesisClaimHash());

// Use performance benchmarking
TestScenario memory scenario = TestScenario({
    proposalCount: 10,
    proposer: Alice,
    prover: Bob,
    shouldProve: true,
    shouldFinalize: true,
    // ... other config
});

PerformanceMetrics memory metrics = benchmarkScenario(scenario, "bulk operations");

// Test with different ring buffer sizes
setupSmallRingBuffer();  // 3 slots
setupMediumRingBuffer(); // 10 slots
setupLargeRingBuffer();  // 1000 slots
```

## Debugging

To see which implementation is being tested, check the test output for:

```
Testing with: [Implementation Name]
```

This is logged at the beginning of each test run in the `setUp()` phase.

## Performance Analysis

### Automated Gas Comparison

```bash
# Compare gas usage across all implementations
./test/layer1/shasta/inbox/run-inbox-tests.sh gas

# Generate detailed gas reports
INBOX=base FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol" --gas-report
INBOX=opt3 FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol" --gas-report

# Use built-in gas snapshots
pnpm snapshot:l1
```

### Expected Optimizations

| Operation | Base → Opt1 | Base → Opt2 | Base → Opt3 |
| --------- | ----------- | ----------- | ----------- |
| Propose   | ~10-15%     | ~20-30%     | ~30-50%     |
| Prove     | ~5-10%      | ~15-25%     | ~20-40%     |
| Finalize  | ~10-15%     | ~20-30%     | ~25-45%     |

## Troubleshooting

### Common Issues

1. **Tests pass for base but fail for optimized**

   - Check encoding/decoding in InboxTestAdapter
   - Verify event format handling
   - Review custom decoder logic

2. **Gas measurements inconsistent**

   - Run warmup operations first
   - Use consistent test data sizes
   - Check for state dependencies

3. **Ring buffer tests failing**
   - Verify buffer size configuration
   - Check finalization order
   - Review capacity calculations

### Debug Commands

```bash
# Run with maximum verbosity
INBOX=opt3 FOUNDRY_PROFILE=layer1 forge test --match-test test_name -vvvv

# Run with debug traces
INBOX=base FOUNDRY_PROFILE=layer1 forge test --debug test_name

# Check storage layout differences
forge inspect Inbox storage-layout
forge inspect InboxOptimized3 storage-layout
```

## Contributing

When contributing to the test suite:

1. Ensure all implementations pass your tests
2. Document any implementation-specific behavior
3. Add performance benchmarks for new features
4. Update this README with new test categories
5. Run the full test suite before submitting:
   ```bash
   ./test/layer1/shasta/inbox/run-inbox-tests.sh all
   ```
