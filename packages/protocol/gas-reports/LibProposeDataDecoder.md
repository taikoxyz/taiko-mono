# LibProposeDataDecoder Gas Report

## Decoding Performance

| Scenario             | abi.decode | LibProposeDataDecoder.decode | Overhead |
| -------------------- | ---------- | ---------------------------- | -------- |
| Simple (1P, 0C, 0B)  | 3,855 gas  | 5,079 gas                    | +31%     |
| Medium (2P, 1C, 0B)  | 7,279 gas  | 11,515 gas                   | +58%     |
| Complex (3P, 2C, 2B) | 11,950 gas | 22,291 gas                   | +87%     |
| Large (5P, 5C, 10B)  | 25,631 gas | 56,299 gas                   | +120%    |
