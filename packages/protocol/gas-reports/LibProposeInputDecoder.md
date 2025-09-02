# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,005 gas | 4,625 gas | 42% |
| Medium (2P, 1C, 0B) | 12,964 gas | 8,629 gas | 33% |
| Complex (3P, 2C, 2B) | 20,291 gas | 14,648 gas | 27% |
| Large (5P, 5C, 10B) | 42,476 gas | 32,946 gas | 22% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
