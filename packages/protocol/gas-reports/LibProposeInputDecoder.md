# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,577 gas | 5,009 gas | 41% |
| Medium (2P, 1C, 0B) | 13,261 gas | 9,008 gas | 32% |
| Complex (3P, 2C, 2B) | 20,300 gas | 15,013 gas | 26% |
| Large (5P, 5C, 10B) | 41,436 gas | 33,013 gas | 20% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
