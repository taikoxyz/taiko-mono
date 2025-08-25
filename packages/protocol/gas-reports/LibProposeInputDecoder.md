# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 7,750 gas | 4,350 gas | 43% |
| Medium (2P, 1C, 0B) | 12,237 gas | 7,962 gas | 34% |
| Complex (3P, 2C, 2B) | 19,080 gas | 13,562 gas | 28% |
| Large (5P, 5C, 10B) | 40,032 gas | 30,794 gas | 23% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
