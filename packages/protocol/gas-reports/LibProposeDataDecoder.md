# LibProposeDataDecoder Gas Report

## Overview

LibProposeDataDecoder optimizes for **L1 calldata costs** by using compact binary encoding.
While decoding gas increases, the significant reduction in data size provides net savings on L1.

## Size Comparison

| Scenario | abi.encode | LibProposeDataDecoder | Reduction |
|----------|------------|----------------------|-----------||
| Simple (1P, 0C, 0B) | 1,216 bytes | 421 bytes | 65% |
| Medium (2P, 1C, 0B) | 1,952 bytes | 712 bytes | 63% |
| Complex (3P, 2C, 2B) | 2,976 bytes | 1,144 bytes | 61% |
| Large (5P, 5C, 10B) | 5,600 bytes | 2,290 bytes | 59% |

## Decoding Gas Comparison

| Scenario | abi.decode | LibProposeDataDecoder | Overhead |
|----------|------------|----------------------|----------||
| Simple (1P, 0C, 0B) | 5,254 gas | 7,924 gas | +51% |
| Medium (2P, 1C, 0B) | 7,855 gas | 12,985 gas | +65% |
| Complex (3P, 2C, 2B) | 11,256 gas | 21,485 gas | +91% |
| Large (5P, 5C, 10B) | 22,354 gas | 44,125 gas | +97% |

## L1 Calldata Cost Analysis

Assuming 16 gas per non-zero byte and 4 gas per zero byte:

| Scenario | abi.encode Cost | Compact Cost | Savings |
|----------|----------------|--------------|---------||
| Simple | ~18,000 gas | ~6,300 gas | ~11,700 gas |
| Medium | ~29,000 gas | ~10,700 gas | ~18,300 gas |
| Complex | ~44,000 gas | ~17,200 gas | ~26,800 gas |
| Large | ~84,000 gas | ~34,400 gas | ~49,600 gas |

## Key Findings

- **Data size reduction**: 59-65% across all scenarios
- **Decoding overhead**: 51-97% increase in gas for unpacking
- **Net benefit on L1**: Significant savings due to reduced calldata costs
- **Best for**: L1 transactions where calldata dominates gas costs

**Legend**: P = Proposals, C = ClaimRecords, B = BondInstructions
