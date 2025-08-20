# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 7,530 gas | 4,329 gas | 42% |
| Medium (2P, 1C, 0B) | 11,981 gas | 7,951 gas | 33% |
| Complex (3P, 2C, 2B) | 18,798 gas | 13,547 gas | 27% |
| Large (5P, 5C, 10B) | 39,624 gas | 30,742 gas | 22% |

**Note**: P = Proposals, C = Claim Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
