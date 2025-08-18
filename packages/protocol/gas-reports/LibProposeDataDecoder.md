# LibProposeDataDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeDataDecoder | Savings |
|----------|-------------------------|----------------------|---------|
| Simple (1P, 0C, 0B) | 9,787 gas | 6,029 gas | 38% |
| Medium (2P, 1C, 0B) | 19,912 gas | 13,755 gas | 30% |
| Complex (3P, 2C, 2B) | 32,513 gas | 23,734 gas | 27% |
| Large (5P, 5C, 10B) | 67,642 gas | 52,623 gas | 22% |

