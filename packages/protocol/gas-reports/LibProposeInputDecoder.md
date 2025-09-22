# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,223 gas | 4,699 gas | 42% |
| Medium (2P, 1C, 0B) | 12,975 gas | 8,583 gas | 33% |
| Complex (3P, 2C, 2B) | 20,070 gas | 14,481 gas | 27% |
| Large (5P, 5C, 10B) | 41,510 gas | 32,405 gas | 21% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
