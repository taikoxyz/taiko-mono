# LibProposeDataDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario             | abi.encode + abi.decode | LibProposeDataDecoder | Savings |
| -------------------- | ----------------------- | --------------------- | ------- |
| Simple (1P, 0C, 0B)  | 9,599 gas               | 5,902 gas             | 38%     |
| Medium (2P, 1C, 0B)  | 19,503 gas              | 13,354 gas            | 31%     |
| Complex (3P, 2C, 2B) | 31,884 gas              | 23,032 gas            | 27%     |
| Large (5P, 5C, 10B)  | 66,552 gas              | 51,223 gas            | 23%     |
