# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 8,222 gas | 4,797 gas | 41% |
| Medium (2P, 1C, 0B) | 12,971 gas | 8,681 gas | 33% |
| Complex (3P, 2C, 2B) | 20,084 gas | 14,570 gas | 27% |
| Large (5P, 5C, 10B) | 41,607 gas | 32,443 gas | 22% |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
