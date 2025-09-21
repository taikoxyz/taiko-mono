# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 7,979 gas | 5,793 gas | 27% |
| Medium (2P, 1C, 0B) | 12,610 gas | 10,223 gas | 18% |
| Complex (3P, 2C, 2B) | 19,532 gas | 16,987 gas | 13% |
| Large (5P, 5C, 10B) | 40,466 gas | 37,746 gas | 6% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
