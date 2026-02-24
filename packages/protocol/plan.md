# Implementation Plan: BridgedERC20V3 with EIP-3009 Support

## Overview

This plan outlines the step-by-step implementation of `BridgedERC20V3`, which extends `BridgedERC20V2` to add EIP-3009 (Transfer With Authorization) support. EIP-2612 (Permit) is already implemented in `BridgedERC20V2`.

**Goal**: Add gasless transfer capabilities via signed authorizations while maintaining full storage compatibility with existing deployed V2 proxies.

---

## Prerequisites

- [x] Research EIP-3009 specification completed (see `research_3009.md`)
- [x] Storage layout analysis completed
- [x] Base branch: `taiko-alethia-protocol-v3.0.0`

---

## Implementation Steps

### Step 1: Create EIP-3009 Interface

**File**: `contracts/shared/vault/IEIP3009.sol`

**Description**: Define the standard EIP-3009 interface for external consumers and type safety.

**Tasks**:
- [ ] Create `IEIP3009` interface with all required functions
- [ ] Define type hashes as constants
- [ ] Define events: `AuthorizationUsed`, `AuthorizationCanceled`

**Interface Functions**:
```solidity
function transferWithAuthorization(address from, address to, uint256 value, uint256 validAfter, uint256 validBefore, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external;
function receiveWithAuthorization(address from, address to, uint256 value, uint256 validAfter, uint256 validBefore, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external;
function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external;
function authorizationState(address authorizer, bytes32 nonce) external view returns (bool);
```

---

### Step 2: Create BridgedERC20V3 Contract

**File**: `contracts/shared/vault/BridgedERC20V3.sol`

**Description**: Main implementation extending BridgedERC20V2 with EIP-3009 support.

**Tasks**:
- [ ] Create contract extending `BridgedERC20V2`
- [ ] Implement `IEIP3009` interface
- [ ] Add storage for authorization states (mapping)
- [ ] Add proper storage gap for future upgrades
- [ ] Implement all EIP-3009 functions
- [ ] Add custom errors
- [ ] Override `supportsInterface` to include IEIP3009

**Storage Layout** (must follow V2):
```
Slot 403: _nonces (inherited from V2 - EIP-2612)
Slot 404-452: __gap (inherited from V2 - will be shadowed by V3)
Slot 453: _authorizationStates (NEW - EIP-3009)
Slot 454-501: __gap_v3 (NEW - 48 slots for future upgrades)
```

**Key Implementation Details**:
1. Use `reinitializer(3)` for `init3()` function
2. Reuse `_hashTypedDataV4()` from EIP712Upgradeable
3. Reuse `BTOKEN_INVALID_SIG` error from V2
4. Add modifiers: `whenNotPaused` for all external functions

---

### Step 3: Create Storage Layout Documentation

**File**: `contracts/shared/vault/BridgedERC20V3_Layout.sol`

**Description**: Auto-generated storage layout for V3 (run `pnpm layout` after implementation).

**Tasks**:
- [ ] Run `pnpm layout` to generate layout file
- [ ] Verify storage compatibility with V2
- [ ] Document any storage changes

---

### Step 4: Update CommonTest Helper

**File**: `test/shared/CommonTest.sol`

**Description**: Add helper function to deploy BridgedERC20V3 in tests.

**Tasks**:
- [ ] Add import for `BridgedERC20V3`
- [ ] Add `deployBridgedERC20V3()` helper function

---

### Step 5: Create Comprehensive Test Suite

**File**: `test/shared/vault/BridgedERC20V3.t.sol`

**Description**: Full test coverage for EIP-3009 functionality.

**Test Categories**:

#### 5.1 Basic EIP-3009 Functionality
- [ ] `test_transferWithAuthorization_succeeds` - Basic transfer with valid signature
- [ ] `test_receiveWithAuthorization_succeeds` - Payee-initiated transfer
- [ ] `test_cancelAuthorization_succeeds` - Cancel unused authorization
- [ ] `test_authorizationState_returnsCorrectState` - View function correctness

#### 5.2 Error Cases
- [ ] `test_transferWithAuthorization_RevertWhen_AuthorizationNotYetValid`
- [ ] `test_transferWithAuthorization_RevertWhen_AuthorizationExpired`
- [ ] `test_transferWithAuthorization_RevertWhen_NonceAlreadyUsed`
- [ ] `test_transferWithAuthorization_RevertWhen_InvalidSignature`
- [ ] `test_transferWithAuthorization_RevertWhen_Paused`
- [ ] `test_receiveWithAuthorization_RevertWhen_CallerNotPayee`
- [ ] `test_cancelAuthorization_RevertWhen_AlreadyUsed`

#### 5.3 Edge Cases
- [ ] `test_transferWithAuthorization_withZeroValue`
- [ ] `test_transferWithAuthorization_withMaxValue`
- [ ] `test_transferWithAuthorization_toSelf`
- [ ] `test_multipleAuthorizationsFromSameUser`
- [ ] `test_cancelThenTransfer_fails`
- [ ] `test_transferThenCancel_fails`

#### 5.4 EIP-2612 Compatibility (Inherited)
- [ ] `test_permit_stillWorks` - Verify V2 functionality preserved
- [ ] `test_permit_and_transferWithAuthorization_independent` - Both systems coexist

#### 5.5 Upgrade Tests
- [ ] `test_upgradeFromV2ToV3_preservesState` - Upgrade existing V2 proxy
- [ ] `test_init3_canOnlyBeCalledOnce` - Reinitializer check

#### 5.6 Integration Tests
- [ ] `test_mintAndTransferWithAuthorization` - Full flow with vault
- [ ] `test_migrationWithTransferAuthorization` - Migration compatibility

---

### Step 6: Create Fuzz Tests

**File**: `test/shared/vault/BridgedERC20V3.t.sol` (same file, additional tests)

**Description**: Fuzz testing for robustness.

**Tasks**:
- [ ] `testFuzz_transferWithAuthorization_randomAmounts`
- [ ] `testFuzz_transferWithAuthorization_randomNonces`
- [ ] `testFuzz_validityWindow_boundaries`

---

### Step 7: Create Gas Benchmarks

**Description**: Measure gas costs for EIP-3009 operations.

**Tasks**:
- [ ] Add gas snapshot tests for:
  - `transferWithAuthorization` gas cost
  - `receiveWithAuthorization` gas cost
  - `cancelAuthorization` gas cost
  - Compare with standard `transfer` and `permit + transferFrom`

---

### Step 8: Update ERC20Vault Integration (Optional)

**File**: `contracts/shared/vault/ERC20Vault.sol`

**Description**: Consider if vault should deploy V3 for new bridged tokens.

**Tasks**:
- [ ] Evaluate if new deployments should use V3
- [ ] Update deployment logic if needed
- [ ] Add configuration option for V2 vs V3

---

### Step 9: Documentation

**Tasks**:
- [ ] Add NatSpec comments to all public/external functions
- [ ] Document upgrade procedure for existing V2 proxies
- [ ] Update CHANGELOG.md

---

## Test Execution Commands

```bash
# Run all V3 tests
forge test --match-path "test/shared/vault/BridgedERC20V3.t.sol" -vvv

# Run specific test
forge test --match-test "test_transferWithAuthorization" -vvvv

# Run with gas report
forge test --match-path "test/shared/vault/BridgedERC20V3.t.sol" --gas-report

# Verify storage layout
pnpm layout

# Run coverage
pnpm test:coverage
```

---

## Validation Checklist

Before marking implementation complete:

- [ ] All tests pass: `forge test --match-path "test/shared/vault/BridgedERC20V3.t.sol"`
- [ ] Storage layout verified: `pnpm layout`
- [ ] No new compiler warnings
- [ ] Gas costs documented
- [ ] Code formatted: `pnpm fmt:sol`
- [ ] All NatSpec complete
- [ ] Upgrade from V2 tested

---

## File Summary

| File | Action | Description |
|------|--------|-------------|
| `contracts/shared/vault/IEIP3009.sol` | CREATE | EIP-3009 interface |
| `contracts/shared/vault/BridgedERC20V3.sol` | CREATE | Main V3 implementation |
| `contracts/shared/vault/BridgedERC20V3_Layout.sol` | GENERATE | Storage layout (auto-generated) |
| `test/shared/CommonTest.sol` | MODIFY | Add V3 deploy helper |
| `test/shared/vault/BridgedERC20V3.t.sol` | CREATE | Comprehensive test suite |

---

## Dependencies

**Inherited from BridgedERC20V2**:
- `@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol`
- `@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol`
- `@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol`

**No new dependencies required**.

---

## Security Considerations

1. **Signature Validation**: Must check `ecrecover` doesn't return zero address
2. **Nonce Uniqueness**: Use random 32-byte nonces, not sequential
3. **Time Bounds**: Validate `validAfter < block.timestamp < validBefore`
4. **Front-Running**: Use `receiveWithAuthorization` for smart contract integrations
5. **Replay Protection**: EIP-712 domain separator includes chainId and contract address

---

## Estimated Effort

| Step | Estimated Time |
|------|---------------|
| Step 1: Interface | 15 min |
| Step 2: Contract | 45 min |
| Step 3: Layout | 5 min |
| Step 4: CommonTest | 10 min |
| Step 5: Tests | 90 min |
| Step 6: Fuzz Tests | 30 min |
| Step 7: Gas Benchmarks | 15 min |
| Step 8: Vault Update | 20 min (optional) |
| Step 9: Documentation | 20 min |
| **Total** | **~4 hours** |

---

## Notes

- EIP-2612 (Permit) is already implemented in V2 and will be inherited
- The contract uses `reinitializer(3)` because V2 uses `reinitializer(2)`
- Storage is added AFTER V2's gap to ensure backward compatibility
- All V2 functionality (mint, burn, migration, permit) remains unchanged
