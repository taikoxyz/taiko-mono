# LibProposeDataDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario             | abi.encode + abi.decode | LibProposeDataDecoder | Result        |
| -------------------- | ----------------------- | --------------------- | ------------- |
| Simple (1P, 0C, 0B)  | 9,599 gas               | 8,358 gas             | -12% savings  |
| Medium (2P, 1C, 0B)  | 19,503 gas              | 19,073 gas            | -2% savings   |
| Complex (3P, 2C, 2B) | 31,884 gas              | 34,688 gas            | +8% overhead  |
| Large (5P, 5C, 10B)  | 66,552 gas              | 81,790 gas            | +22% overhead |
