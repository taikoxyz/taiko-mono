# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,458 gas | 4,812 gas | 43% |
| Medium (2P, 1C, 0B) | 12,965 gas | 8,609 gas | 33% |
| Complex (3P, 2C, 2B) | 19,835 gas | 14,394 gas | 27% |
| Large (5P, 5C, 10B) | 40,609 gas | 31,913 gas | 21% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
