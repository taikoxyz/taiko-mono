> **Scope**: Solidity contracts (L1/L2), Foundry tests, gas, and upgrade safety. Use this file for anything under `/packages/protocol`.

## Quick Rules (enforce strictly)

- **Imports**: `import {Contract} from "./Contract.sol";` (named imports only; no wildcard/side‑effect imports)
- **Naming**:

  - Private/internal funcs & state: `_prefix`
  - Function params: start with `_`
  - Return vars: end with `_`
  - Events: **past tense** (e.g., `BlockProposed`, `ProofVerified`)
  - Mappings: use **named parameters**

- **Errors**: prefer custom errors; avoid require strings; define errors at end of implementation (not in interfaces).
- **Docs**: `/// @notice` on external/public; `/// @dev` on internal/private; include `/// @custom:security-contact security@taiko.xyz` in all non‑test Solidity files; license **MIT** at top of each Solidity file.
- **Upgradeable safety**: never reorder existing storage; append new vars only; include `uint256[50] __gap` in upgradeables; always verify layout before/after edits.

## Layout & Key Files

- L1 contracts: `contracts/layer1/`
- L2 contracts: `contracts/layer2/`
- Shared libs: `contracts/shared/`
- **Shasta focus**:

  - `contracts/layer1/shasta/impl/Inbox.sol` — propose/prove/finalize core
  - `contracts/layer1/shasta/iface/` — interfaces & structs
  - `contracts/layer2/based/ShastaAnchor.sol` — L1→L2 anchor + bond management

- Patterns: UUPS upgradeable (OZ), Resolver for cross‑contract discovery, storage gaps on upgradeables.

## Runbook (copy‑paste)

```bash
# Compile
pnpm compile            # all contracts
pnpm compile:l1         # FOUNDRY_PROFILE=layer1
pnpm compile:l2         # FOUNDRY_PROFILE=layer2

# Tests
pnpm test               # all tests
pnpm test:l1            # L1 only
pnpm test:l2            # L2 only
pnpm test:coverage      # coverage report
forge test --match-test <name>
forge test --match-path <path>
forge test -vvvv
forge test --match-path <path> --summary   # show gas per test

# Shasta‑only inner loop (Inbox)
forge test --match-path "test/layer1/shasta/inbox/suite2/*" -vvvv

# Gas & storage layout (L1 critical)
pnpm snapshot:l1                      # writes gas-reports/layer1-contracts.txt
pnpm layout                           # verify storage layout; run before/after
forge test --gas-report
```

## Test Style

- Positive: `test_functionName_Description`
- Negative: `test_functionName_RevertWhen_Description`
- Inherit from **`CommonTest`** and use built‑in accounts (Alice, Bob, Carol, David, Emma)
- Use `vm.expectEmit()` without parameters (treats all topics/data as checked)
- Prefer real implementations over mocks when feasible to mirror prod deps

## Gas Optimization Workflow

1. **Baseline**: `pnpm snapshot:l1` → save `gas-reports/layer1-contracts.txt` as reference
2. **Optimize**: minimize storage R/W; pack vars; prefer memory; batch ops; use `calldata`; store hashes of large structs when viable
3. **Measure**: re‑run snapshot; compare diffs in `gas-reports/` and `snapshots/`; document deltas in PR body

## Storage Layout Verification

```bash
pnpm layout
# Attach/record before & after summaries in the PR when touching upgradeables
```

## PR Checklist (Protocol)

- [ ] Solidity formatted: `pnpm fmt:sol`
- [ ] Tests pass: `pnpm test` (and targeted suites)
- [ ] Coverage reviewed: `pnpm test:coverage`
- [ ] **Storage layout** verified: `pnpm layout` (summaries captured)
- [ ] **Gas snapshot** updated: `pnpm snapshot:l1` (deltas noted)
- [ ] Negative tests cover revert reasons; events asserted via `vm.expectEmit()`
- [ ] Performance notes for critical paths (why trade‑offs are safe)

## Common Pitfalls (auto‑warn)

- Running full Shasta tests unnecessarily → use the specific suite path above.
- Reordering storage in upgradeables.
- Using require strings instead of custom errors.
- Event names not in past tense.
- Missing `security@taiko.xyz` custom tag.
- Skipping `pnpm install` before Foundry work in a fresh checkout.

## New Upgradeable Contract: Minimal Header

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact security@taiko.xyz
contract MyContract is Initializable, UUPSUpgradeable {
    uint256 private _x;
    uint256[50] private __gap;

    function initialize(uint256 _x_) public initializer {
        _x = _x_;
    }

    function _authorizeUpgrade(address _newImpl_) internal override {}

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------
}
```
