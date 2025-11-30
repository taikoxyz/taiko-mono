# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,961 gas | 5,393 gas | 39% |
| Medium (2P, 1C, 0B) | 14,029 gas | 9,778 gas | 30% |
| Complex (3P, 2C, 2B) | 21,457 gas | 16,171 gas | 24% |
| Large (5P, 5C, 10B) | 43,370 gas | 34,957 gas | 19% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
