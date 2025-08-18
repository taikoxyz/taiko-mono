# LibProvedEventEncoder Gas Report

## Encoding + Emit Performance

| Bonds | abi.encode | LibProvedEventEncoder | Savings |
|-------|------------|----------------------|---------|
| 0 | 5,249 gas | 3,777 gas | 28% |
| 1 | 6,579 gas | 4,841 gas | 26% |
| 3 | 9,242 gas | 6,701 gas | 27% |
| 5 | 11,933 gas | 8,565 gas | 28% |
| 10 | 18,661 gas | 13,094 gas | 29% |

## Size Comparison

| Bonds | abi.encode | LibProvedEventEncoder | Reduction |
|-------|------------|----------------------|-----------|
| 0 | 384 bytes | 183 bytes | 52% |
| 1 | 512 bytes | 230 bytes | 55% |
| 3 | 768 bytes | 324 bytes | 57% |
| 5 | 1,024 bytes | 418 bytes | 59% |
| 10 | 1,664 bytes | 653 bytes | 60% |

**Note**: Gas measurements include event emission costs
