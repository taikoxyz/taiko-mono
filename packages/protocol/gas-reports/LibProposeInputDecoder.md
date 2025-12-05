# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 5,438 gas | 2,534 gas | 53% |
| Medium (2P, 1C, 0B) | 7,893 gas | 4,337 gas | 45% |
| Complex (3P, 2C, 2B) | 12,681 gas | 8,073 gas | 36% |
| Large (5P, 5C, 10B) | 29,395 gas | 21,331 gas | 27% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
