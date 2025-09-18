# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,006 gas | 4,626 gas | 42% |
| Medium (2P, 1C, 0B) | 12,756 gas | 8,512 gas | 33% |
| Complex (3P, 2C, 2B) | 19,854 gas | 14,409 gas | 27% |
| Large (5P, 5C, 10B) | 41,289 gas | 32,329 gas | 21% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
