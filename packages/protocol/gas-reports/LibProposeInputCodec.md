# LibProposeInputCodec Gas Report

## Total Cost (Calldata + Decoding)

| Scenario             | abi.encode + abi.decode | LibProposeInputCodec | Savings |
| -------------------- | ----------------------- | -------------------- | ------- |
| Simple (1P, 0C, 0B)  | 8,458 gas               | 4,812 gas            | 43%     |
| Medium (2P, 1C, 0B)  | 13,208 gas              | 8,696 gas            | 34%     |
| Complex (3P, 2C, 2B) | 20,324 gas              | 14,587 gas           | 28%     |
| Large (5P, 5C, 10B)  | 41,858 gas              | 32,463 gas           | 22%     |

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
