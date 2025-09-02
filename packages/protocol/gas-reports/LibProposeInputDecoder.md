# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 7,750 gas | 4,376 gas | 43% |
| Medium (2P, 1C, 0B) | 12,449 gas | 8,062 gas | 35% |
| Complex (3P, 2C, 2B) | 19,510 gas | 13,748 gas | 29% |
| Large (5P, 5C, 10B) | 41,129 gas | 31,273 gas | 23% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
