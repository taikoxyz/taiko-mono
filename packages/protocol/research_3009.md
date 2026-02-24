# EIP-3009 Research: Transfer With Authorization

## Executive Summary

This document provides research findings on implementing [EIP-3009](https://eips.ethereum.org/EIPS/eip-3009) support for Taiko's bridged tokens, specifically focusing on:

1. Adding EIP-3009 to `BridgedERC20V2` while maintaining storage layout compatibility
2. Understanding the current bridged USDC token on Taiko (proxy: `0x07d83526730c7438048D55A4fc0b850e2aaB6f0b`)
3. Upgrade path to Circle USDC v2/v2.2 with EIP-3009 support

**Key Finding**: The bridged USDC on Taiko already uses Circle's `FiatTokenV2_2` implementation, which **already supports EIP-3009**. No upgrade is needed for EIP-3009 functionality on the existing bridged USDC.

---

## 1. EIP-3009 Specification Overview

### What is EIP-3009?

EIP-3009 ("Transfer With Authorization") enables meta-transactions for ERC-20 tokens via signed authorizations conforming to [EIP-712](https://eips.ethereum.org/EIPS/eip-712).

### Key Benefits

- **Gas abstraction**: Users can delegate gas payment to relayers
- **Atomic transfers**: Unlike EIP-2612 (permit), which only authorizes approval, EIP-3009 authorizes the complete transfer
- **Random nonces**: Uses 32-byte random nonces instead of sequential nonces, allowing multiple concurrent transactions
- **Validity windows**: `validAfter` and `validBefore` parameters provide time-bounded authorizations

### Required Functions

```solidity
// Core functions
function transferWithAuthorization(
    address from,
    address to,
    uint256 value,
    uint256 validAfter,
    uint256 validBefore,
    bytes32 nonce,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;

function receiveWithAuthorization(
    address from,
    address to,
    uint256 value,
    uint256 validAfter,
    uint256 validBefore,
    bytes32 nonce,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;

// Optional but recommended
function cancelAuthorization(
    address authorizer,
    bytes32 nonce,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;

function authorizationState(
    address authorizer,
    bytes32 nonce
) external view returns (bool);
```

### Required Storage

```solidity
// Tracks used nonces per authorizer
mapping(address => mapping(bytes32 => bool)) private _authorizationStates;
```

### Type Hashes

```solidity
bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
    keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
// = 0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267

bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
    keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
// = 0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8

bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH =
    keccak256("CancelAuthorization(address authorizer,bytes32 nonce)");
// = 0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429
```

### Events

```solidity
event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);
event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);
```

---

## 2. Current BridgedERC20V2 Storage Layout Analysis

### Storage Layout (from `BridgedERC20V2_Layout.sol`)

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0 | `_initialized` / `_initializing` | uint8 / bool | Initializable |
| 1-50 | `__gap` | uint256[50] | Initializable gap |
| 51 | `_owner` | address | Ownable |
| 52-100 | `__gap` | uint256[49] | Ownable gap |
| 101 | `_pendingOwner` | address | Ownable2Step |
| 102-150 | `__gap` | uint256[49] | Ownable2Step gap |
| 151-200 | `__gapFromOldAddressResolver` | uint256[50] | Legacy gap |
| 201 | `__reentry` / `__paused` | uint8 / uint8 | EssentialContract |
| 202-250 | `__gap` | uint256[49] | EssentialContract gap |
| 251 | `_balances` | mapping | ERC20 |
| 252 | `_allowances` | mapping | ERC20 |
| 253 | `_totalSupply` | uint256 | ERC20 |
| 254 | `_name` | string | ERC20 |
| 255 | `_symbol` | string | ERC20 |
| 256-300 | `__gap` | uint256[45] | ERC20 gap |
| 301 | `srcToken` / `__srcDecimals` | address / uint8 | BridgedERC20 |
| 302 | `srcChainId` | uint256 | BridgedERC20 |
| 303 | `migratingAddress` / `migratingInbound` | address / bool | BridgedERC20 |
| 304-350 | `__gap` | uint256[47] | BridgedERC20 gap |
| 351 | `_hashedName` | bytes32 | EIP712 |
| 352 | `_hashedVersion` | bytes32 | EIP712 |
| 353 | `_name` | string | EIP712 |
| 354 | `_version` | string | EIP712 |
| 355-402 | `__gap` | uint256[48] | EIP712 gap |
| **403** | `_nonces` | mapping(address => Counter) | **EIP-2612 permit nonces** |
| 404-452 | `__gap` | uint256[49] | BridgedERC20V2 gap |

### Current Features

- **EIP-2612 (Permit)**: Already implemented via `_nonces` mapping at slot 403
- **EIP-712**: Domain separator support via `EIP712Upgradeable`

### Available Storage for EIP-3009

The `__gap` at slots 404-452 provides **49 available slots** for new storage variables.

---

## 3. Storage-Compatible EIP-3009 Extension Design

### Option A: Create BridgedERC20V3 (Recommended)

Create a new contract version that extends `BridgedERC20V2` with EIP-3009 support.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgedERC20V2.sol";

/// @title BridgedERC20V3
/// @notice BridgedERC20V2 with EIP-3009 (transferWithAuthorization) support
contract BridgedERC20V3 is BridgedERC20V2 {

    // Type hashes
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
        0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

    bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH =
        0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;

    // New storage - uses slot from parent's __gap
    // Must be placed after _nonces (slot 403) and before __gap (slots 404-452)
    mapping(address authorizer => mapping(bytes32 nonce => bool used)) private _authorizationStates;

    // Reduced gap: 49 - 1 = 48 slots
    uint256[48] private __gap_v3;

    // Events
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);

    // Errors
    error BTOKEN_AUTHORIZATION_NOT_YET_VALID();
    error BTOKEN_AUTHORIZATION_EXPIRED();
    error BTOKEN_AUTHORIZATION_USED();
    error BTOKEN_CALLER_NOT_PAYEE();

    constructor(address _erc20Vault) BridgedERC20V2(_erc20Vault) { }

    /// @notice Initialize V3 - must be called after V2 initialization
    function init3() external reinitializer(3) {
        // No additional initialization needed for EIP-3009
        // Domain separator is already set up by V2
    }

    /// @notice Returns the state of an authorization
    function authorizationState(
        address authorizer,
        bytes32 nonce
    ) external view returns (bool) {
        return _authorizationStates[authorizer][nonce];
    }

    /// @notice Execute a transfer with a signed authorization
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        bytes32 structHash = keccak256(abi.encode(
            TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce
        ));

        _validateSignature(from, structHash, v, r, s);
        _markAuthorizationAsUsed(from, nonce);
        _transfer(from, to, value);
    }

    /// @notice Receive a transfer with a signed authorization from the payer
    /// @dev Prevents front-running by requiring caller to be the payee
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        if (to != msg.sender) revert BTOKEN_CALLER_NOT_PAYEE();

        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        bytes32 structHash = keccak256(abi.encode(
            RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce
        ));

        _validateSignature(from, structHash, v, r, s);
        _markAuthorizationAsUsed(from, nonce);
        _transfer(from, to, value);
    }

    /// @notice Attempt to cancel an authorization
    function cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        if (_authorizationStates[authorizer][nonce]) revert BTOKEN_AUTHORIZATION_USED();

        bytes32 structHash = keccak256(abi.encode(
            CANCEL_AUTHORIZATION_TYPEHASH,
            authorizer,
            nonce
        ));

        _validateSignature(authorizer, structHash, v, r, s);
        _authorizationStates[authorizer][nonce] = true;
        emit AuthorizationCanceled(authorizer, nonce);
    }

    function _requireValidAuthorization(
        address authorizer,
        bytes32 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) private view {
        if (block.timestamp <= validAfter) revert BTOKEN_AUTHORIZATION_NOT_YET_VALID();
        if (block.timestamp >= validBefore) revert BTOKEN_AUTHORIZATION_EXPIRED();
        if (_authorizationStates[authorizer][nonce]) revert BTOKEN_AUTHORIZATION_USED();
    }

    function _validateSignature(
        address signer,
        bytes32 structHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private view {
        bytes32 hash = _hashTypedDataV4(structHash);
        address recovered = ECDSAUpgradeable.recover(hash, v, r, s);
        if (recovered != signer) revert BTOKEN_INVALID_SIG();
    }

    function _markAuthorizationAsUsed(address authorizer, bytes32 nonce) private {
        _authorizationStates[authorizer][nonce] = true;
        emit AuthorizationUsed(authorizer, nonce);
    }

    function supportsInterface(bytes4 _interfaceId) public pure virtual override returns (bool) {
        // Add EIP-3009 interface check if standardized
        return super.supportsInterface(_interfaceId);
    }
}
```

### Storage Layout After Extension

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| ... | (inherited from V2) | ... | ... |
| 403 | `_nonces` | mapping | EIP-2612 (unchanged) |
| 404-452 | `__gap` | uint256[49] | **V2 gap - will be shadowed** |
| 453 | `_authorizationStates` | mapping | **NEW: EIP-3009** |
| 454-501 | `__gap_v3` | uint256[48] | **NEW: V3 gap** |

**Important**: The V3 contract adds storage AFTER the parent's gap, ensuring full backward compatibility.

### Option B: In-Place Modification (Not Recommended)

Modifying the existing `__gap` in `BridgedERC20V2` would require:
1. Reducing gap from `uint256[49]` to `uint256[48]`
2. Adding `_authorizationStates` at slot 404

**Risk**: This approach breaks storage compatibility for already-deployed V2 proxies.

---

## 4. Bridged USDC Analysis on Taiko

### Contract Details

| Property | Value |
|----------|-------|
| Proxy Address | `0x07d83526730c7438048D55A4fc0b850e2aaB6f0b` |
| Proxy Type | `FiatTokenProxy` (Circle's AdminUpgradeabilityProxy) |
| Implementation | `0x996a7a32c387fd83e127a358fbc192e110459f2d` |
| Implementation Name | `FiatTokenV2_2` |
| Solidity Version | 0.6.12 |

### Current Implementation Features

The `FiatTokenV2_2` implementation **already includes**:

1. **EIP-3009 Support**:
   - `transferWithAuthorization(from, to, value, validAfter, validBefore, nonce, signature)`
   - `receiveWithAuthorization(from, to, value, validAfter, validBefore, nonce, signature)`
   - `cancelAuthorization(authorizer, nonce, signature)`
   - `authorizationState(authorizer, nonce)` view function

2. **EIP-2612 Support**:
   - `permit(owner, spender, value, deadline, v, r, s)`
   - `permit(owner, spender, value, deadline, signature)` (packed signature variant)
   - `nonces(owner)` view function

3. **V2.2 Optimizations**:
   - Blacklist state stored in high bit of balance (gas optimization)
   - Dynamic domain separator calculation
   - Support for both EOA and contract wallet signatures

### Circle's USDC Version History

| Version | Key Features | `_initializedVersion` |
|---------|--------------|----------------------|
| V1 | Basic ERC-20 | 0 |
| V2 | EIP-3009 + EIP-2612 | 1 |
| V2.1 | Fund recovery mechanism | 2 |
| V2.2 | Blacklist optimization, dynamic domain separator | 3 |

### Upgrade Status

**No upgrade needed for EIP-3009**. The current implementation (`FiatTokenV2_2`) is Circle's latest version and already supports all EIP-3009 functionality.

---

## 5. Upgrade Scenarios

### Scenario A: Add EIP-3009 to Other Bridged Tokens (BridgedERC20V2)

For tokens using Taiko's `BridgedERC20V2`:

1. Deploy new `BridgedERC20V3` implementation with EIP-3009
2. For existing proxies: call `upgradeTo(newImplementation)` + `init3()`
3. For new tokens: deploy with `BridgedERC20V3` directly

### Scenario B: Upgrade Bridged USDC (Not Required)

The bridged USDC uses Circle's implementation, **not** Taiko's `BridgedERC20V2`. Options:

1. **Keep Current**: Already has EIP-3009 via `FiatTokenV2_2`
2. **Migrate to Taiko's System**: Would require:
   - Deploy new `BridgedERC20V3` proxy
   - Migrate balances (complex, requires user action or snapshot migration)
   - Update all integrations to new address
   - **Not recommended** unless there are specific requirements

### Scenario C: Verify EIP-3009 Is Working

To verify the bridged USDC supports EIP-3009:

```javascript
// Check if transferWithAuthorization exists
const usdc = new ethers.Contract(
  "0x07d83526730c7438048D55A4fc0b850e2aaB6f0b",
  ["function transferWithAuthorization(address,address,uint256,uint256,uint256,bytes32,bytes) external"],
  provider
);

// The function should exist and not revert on interface check
```

---

## 6. Test Modifications for BridgedERC20V3

### New Test File: `BridgedERC20V3.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "../../contracts/shared/vault/BridgedERC20V3.sol";

contract TestBridgedERC20V3 is CommonTest {
    address private vault = randAddress();
    BridgedERC20V3 private token;

    uint256 private alicePrivateKey = 0xa11ce;
    address private alice;

    function setUp() public override {
        super.setUp();
        alice = vm.addr(alicePrivateKey);
    }

    function setUpOnEthereum() internal override {
        register("erc20_vault", vault);
    }

    function deployToken() internal returns (BridgedERC20V3) {
        address srcToken = randAddress();
        return BridgedERC20V3(
            deploy({
                name: "TEST",
                impl: address(new BridgedERC20V3(vault)),
                data: abi.encodeCall(
                    BridgedERC20V3.init,
                    (deployer, srcToken, taikoChainId, 18, "Test Token", "TEST")
                )
            })
        );
    }

    function test_transferWithAuthorization() public {
        token = deployToken();

        // Mint tokens to alice
        vm.prank(vault);
        token.mint(alice, 1000 ether);

        // Prepare authorization
        bytes32 nonce = keccak256("unique-nonce");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;
        uint256 value = 100 ether;

        // Create signature
        bytes32 structHash = keccak256(abi.encode(
            token.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(),
            alice,
            Bob,
            value,
            validAfter,
            validBefore,
            nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Execute transfer (anyone can submit)
        vm.prank(Carol);
        token.transferWithAuthorization(
            alice,
            Bob,
            value,
            validAfter,
            validBefore,
            nonce,
            v, r, s
        );

        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(Bob), 100 ether);
        assertTrue(token.authorizationState(alice, nonce));
    }

    function test_receiveWithAuthorization() public {
        token = deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("receive-nonce");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(abi.encode(
            token.RECEIVE_WITH_AUTHORIZATION_TYPEHASH(),
            alice,
            Bob,
            value,
            validAfter,
            validBefore,
            nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Only Bob (the payee) can call receiveWithAuthorization
        vm.prank(Bob);
        token.receiveWithAuthorization(
            alice,
            Bob,
            value,
            validAfter,
            validBefore,
            nonce,
            v, r, s
        );

        assertEq(token.balanceOf(Bob), 100 ether);
    }

    function test_receiveWithAuthorization_RevertWhen_CallerNotPayee() public {
        token = deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("fail-nonce");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        bytes32 structHash = keccak256(abi.encode(
            token.RECEIVE_WITH_AUTHORIZATION_TYPEHASH(),
            alice,
            Bob,
            100 ether,
            validAfter,
            validBefore,
            nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Carol tries to call (not the payee)
        vm.prank(Carol);
        vm.expectRevert(BridgedERC20V3.BTOKEN_CALLER_NOT_PAYEE.selector);
        token.receiveWithAuthorization(
            alice,
            Bob,
            100 ether,
            validAfter,
            validBefore,
            nonce,
            v, r, s
        );
    }

    function test_cancelAuthorization() public {
        token = deployToken();

        bytes32 nonce = keccak256("cancel-nonce");

        bytes32 structHash = keccak256(abi.encode(
            token.CANCEL_AUTHORIZATION_TYPEHASH(),
            alice,
            nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        token.cancelAuthorization(alice, nonce, v, r, s);

        assertTrue(token.authorizationState(alice, nonce));
    }

    function test_transferWithAuthorization_RevertWhen_NonceUsed() public {
        token = deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("reuse-nonce");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        bytes32 structHash = keccak256(abi.encode(
            token.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(),
            alice,
            Bob,
            100 ether,
            validAfter,
            validBefore,
            nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // First transfer succeeds
        token.transferWithAuthorization(
            alice, Bob, 100 ether, validAfter, validBefore, nonce, v, r, s
        );

        // Second transfer with same nonce fails
        vm.expectRevert(BridgedERC20V3.BTOKEN_AUTHORIZATION_USED.selector);
        token.transferWithAuthorization(
            alice, Bob, 100 ether, validAfter, validBefore, nonce, v, r, s
        );
    }
}
```

---

## 7. Recommendations

### For Taiko Protocol Team

1. **No action needed for bridged USDC**: The current implementation already supports EIP-3009.

2. **For other bridged tokens**: Consider creating `BridgedERC20V3` with EIP-3009 support for tokens that would benefit from gasless transfers.

3. **Testing**: Add comprehensive tests for EIP-3009 functionality including:
   - Valid transfer authorizations
   - Expired/not-yet-valid authorizations
   - Nonce reuse prevention
   - Front-running protection via `receiveWithAuthorization`
   - Authorization cancellation

4. **Documentation**: Update bridge documentation to inform users about EIP-3009 support for USDC transfers.

### Security Considerations

1. **Front-running**: Use `receiveWithAuthorization` for smart contract integrations to prevent front-running attacks.

2. **Nonce management**: Nonces should be randomly generated 32-byte values, not sequential.

3. **Signature validation**: Always verify `ecrecover` doesn't return zero address.

4. **Time validation**: Ensure proper validation of `validAfter` and `validBefore` bounds.

---

## 8. References

- [EIP-3009: Transfer With Authorization](https://eips.ethereum.org/EIPS/eip-3009)
- [EIP-2612: Permit](https://eips.ethereum.org/EIPS/eip-2612)
- [EIP-712: Typed Data Signing](https://eips.ethereum.org/EIPS/eip-712)
- [Circle stablecoin-evm Repository](https://github.com/circlefin/stablecoin-evm)
- [Circle USDC Documentation](https://developers.circle.com/)
- [Extropy: Overview of EIP-3009](https://academy.extropy.io/pages/articles/review-eip-3009.html)

---

## Appendix: Circle FiatTokenV2_2 EIP-3009 Interface

For reference, here are the exact function signatures in Circle's implementation:

```solidity
// With standard (v, r, s) signature components
function transferWithAuthorization(
    address from,
    address to,
    uint256 value,
    uint256 validAfter,
    uint256 validBefore,
    bytes32 nonce,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;

// With packed signature bytes (for contract wallets)
function transferWithAuthorization(
    address from,
    address to,
    uint256 value,
    uint256 validAfter,
    uint256 validBefore,
    bytes32 nonce,
    bytes memory signature
) external;

// Similar overloads exist for receiveWithAuthorization and cancelAuthorization
```

The domain separator uses:
- `name`: Token name (e.g., "USD Coin")
- `version`: "2"
- `chainId`: Current chain ID
- `verifyingContract`: Token contract address
