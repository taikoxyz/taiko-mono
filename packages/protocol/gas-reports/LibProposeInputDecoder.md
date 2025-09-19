# LibProposeInputDecoder Gas Report

## Total Cost (Calldata + Decoding)

| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |
|----------|-------------------------|----------------------|---------|
<<<<<<< HEAD
| Simple (1P, 0C, 0B) | 8,006 gas | 4,626 gas | 42% |
| Medium (2P, 1C, 0B) | 12,756 gas | 8,512 gas | 33% |
| Complex (3P, 2C, 2B) | 19,854 gas | 14,409 gas | 27% |
| Large (5P, 5C, 10B) | 41,289 gas | 32,329 gas | 21% |
=======
| Simple (1P, 0C, 0B) | 8,222 gas | 4,709 gas | 42% |
| Medium (2P, 1C, 0B) | 12,971 gas | 8,593 gas | 33% |
| Complex (3P, 2C, 2B) | 20,084 gas | 14,482 gas | 27% |
| Large (5P, 5C, 10B) | 41,607 gas | 32,355 gas | 22% |
>>>>>>> origin/main

**Note**: P = Proposals, C = Transition Records, B = Bond Instructions
**Note**: Gas measurements include both calldata and decode costs
