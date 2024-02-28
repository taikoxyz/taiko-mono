# SOLIDITY STYLE GUIDE

This document is a work in progress.

## Naming Conventions

- All function parameters start with a leading underscore (`_`);
- All function return values end with a understore;
- All private function names start with a leading underscore;
- all private state variable names start with a leading underscore;

## Gaps
All contracts must reverse 50 slots using:

```solidity
uint128[xx] private __gap;
```