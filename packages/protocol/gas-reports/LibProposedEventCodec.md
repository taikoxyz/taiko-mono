# LibProposedEventCodec Gas Report

## Encoding + Emit Performance

| Blobs | abi.encode | LibProposedEventCodec | Savings |
|-------|------------|------------------------|---------|
| 0 | 6,779 gas | 3,700 gas | 45% |
| 3 | 7,869 gas | 4,927 gas | 37% |
| 6 | 8,963 gas | 6,154 gas | 31% |
| 10 | 10,431 gas | 7,810 gas | 25% |

## Size Comparison

| Blobs | abi.encode | LibProposedEventCodec | Reduction |
|-------|------------|------------------------|-----------|
| 0 | 544 bytes | 160 bytes | 70% |
| 3 | 640 bytes | 256 bytes | 60% |
| 6 | 736 bytes | 352 bytes | 52% |
| 10 | 864 bytes | 480 bytes | 44% |

**Note**: Gas measurements include event emission costs
