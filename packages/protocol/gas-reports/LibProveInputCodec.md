# LibProveInputCodec Gas Report

## Total Cost (Calldata + Decoding)

| Scenario           | abi.encode + abi.decode | LibProveInputCodec | Savings |
| ------------------ | ----------------------- | ------------------ | ------- |
| Simple (1P+C, 0B)  | 8,623 gas               | 5,918 gas          | 31%     |
| Medium (3P+C, 2B)  | 26,518 gas              | 21,183 gas         | 20%     |
| Large (5P+C, 3B)   | 46,534 gas              | 39,079 gas         | 16%     |
| XLarge (10P+C, 4B) | 99,052 gas              | 87,390 gas         | 11%     |

**Note**: P = Proposals, T = Transitions, B = Blob Hashes per proposal
**Note**: Gas measurements include both calldata and decode costs
