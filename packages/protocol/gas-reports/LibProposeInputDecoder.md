# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,617 gas | 4,914 gas | 42% |
| Medium (2P, 1C, 0B) | 13,381 gas | 8,800 gas | 34% |
| Complex (3P, 2C, 2B) | 20,501 gas | 14,695 gas | 28% |
| Large (5P, 5C, 10B) | 42,031 gas | 32,583 gas | 22% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
