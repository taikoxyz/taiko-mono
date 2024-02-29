# Solidity Style Guide

This document outlines the coding and naming conventions for Solidity files within our project. It aims to ensure consistency, readability, and maintainability of the codebase. Please note that this guide is subject to updates and improvements over time.

## Scope

This style guide applies to all Solidity files in this directory, with the exception of those located within the following directories:

- `automata-attestation/`
- `thirdparty/`

These directories may contain externally sourced contracts or those following different conventions.

## Naming Conventions

To maintain clarity and consistency across our Solidity codebase, the following naming conventions are to be adhered to:

- **Function Parameters:** Prefix all function parameters with a leading underscore (`_`) to distinguish them from local and global variables and avoid naming conflicts.
  
- **Function Return Values:** Suffix names of function return variables with an underscore (`_`) to clearly differentiate them from other variables and parameters.

- **Private Functions:** Prefix private function names with a leading underscore (`_`). This convention signals the function's visibility level at a glance.

- **Private State Variables:** Prefix all private state variable names with a leading underscore (`_`), highlighting their limited scope within the contract.

## Reserved Storage Slots

To ensure upgradeability and prevent storage collisions in future contract versions, reserve a fixed number of storage slots at the end of each contract. This is achieved by declaring a placeholder array in the contract's storage layout as follows:

```solidity
// Reserve 50 storage slots for future use to ensure contract upgradeability.
uint256[50] private __gap;
```

Note: Replace `xx` with the actual number of slots you intend to reserve, as shown in the example above.

