# Unified Inbox Test Suite

This test suite allows running the same set of tests against any of the four Inbox contract implementations.

## Inbox Implementations

1. **Inbox.sol** — The base, fundamental implementation
2. **InboxOptimized1** — Fully compatible with `Inbox.sol`, includes slot reuse optimizations
3. **InboxOptimized2** — Uses custom encoder for event data to reduce gas costs
4. **InboxOptimized3** — Uses custom decoding functions for calldata (others use `abi.decode`)

## Running Tests

### Testing Specific Implementation

Use the `INBOX` environment variable to select which implementation to test:

```bash
# Test base implementation (default)
INBOX=base forge test

# Test InboxOptimized1
INBOX=opt1 forge test

# Test InboxOptimized2
INBOX=opt2 forge test

# Test InboxOptimized3
INBOX=opt3 forge test
```

### Running All Implementations

To test all implementations sequentially:

```bash
# Run test script for all implementations
./test-all-inbox-implementations.sh
```

## Architecture

### Test Infrastructure

- **InboxTest.sol** - Base test contract that all test files inherit from
- **TestInboxFactory.sol** - Factory for deploying different Inbox implementations
- **InboxTestAdapter.sol** - Adapter handling encoding/decoding differences between implementations
- **ITestInbox.sol** - Common interface for all test implementations

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

## Adding New Tests

When adding new tests:

1. Inherit from `InboxTest` base contract
2. Use the `inbox` variable (type `ITestInbox`) for all interactions
3. Use `InboxTestAdapter` for encoding/decoding when needed
4. Avoid implementation-specific logic in tests

Example:

```solidity
contract MyInboxTest is InboxTest {
    function test_myFeature() public {
        // This will work with any implementation
        bytes memory data = InboxTestAdapter.encodeProposalData(
            inboxType,
            deadline,
            coreState,
            proposals,
            blobRef,
            claimRecords
        );

        inbox.propose(bytes(""), data);
        // Test continues...
    }
}
```

## Debugging

To see which implementation is being tested, check the test output for:

```
Testing with: [Implementation Name]
```

This is logged at the beginning of each test run in the `setUp()` phase.

## Performance Comparison

Run gas snapshots for each implementation:

```bash
# Generate gas reports for all implementations
INBOX_TYPE=core forge snapshot --match-path "test/layer1/shasta/inbox/*.t.sol"
INBOX_TYPE=opt1 forge snapshot --match-path "test/layer1/shasta/inbox/*.t.sol"
INBOX_TYPE=opt2 forge snapshot --match-path "test/layer1/shasta/inbox/*.t.sol"
INBOX_TYPE=opt3 forge snapshot --match-path "test/layer1/shasta/inbox/*.t.sol"

# Compare results
diff .gas-snapshot-core .gas-snapshot-opt3
```
