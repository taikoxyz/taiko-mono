// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgedERC20.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC5267Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

/// @title BridgedERC20V2
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain. This implementation adds ERC20Permit support to BridgedERC20.
///
/// Most of the code were copied from OZ's ERC20PermitUpgradeable.sol contract.
///
/// @custom:security-contact security@taiko.xyz
contract BridgedERC20V2 is BridgedERC20, IERC20PermitUpgradeable, EIP712Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    mapping(address account => CountersUpgradeable.Counter counter) private _nonces;
    uint256[49] private __gap;

    error BTOKEN_DEADLINE_EXPIRED();
    error BTOKEN_INVALID_SIG();

    constructor(address _erc20Vault) BridgedERC20(_erc20Vault) { }

    /// @inheritdoc IBridgedERC20Initializable
    /// @dev This function is called when the bridge deploys a new bridged ERC20 token, so this
    /// function must also cover the logic in init2(), we use
    /// `reinitializer(2)` instead of `initializer`.
    function init(
        address _owner,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string calldata _symbol,
        string calldata _name
    )
        external
        virtual
        override
        reinitializer(2)
    {
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId);
        __Essential_init(_owner);
        __ERC20_init(_name, _symbol);
        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        __srcDecimals = _decimals;

        // Cover logics from `init2()`
        __EIP712_init_unchained(_name, "1");
    }

    /// @notice This function shall be called by previously deployed contracts.
    function init2() external reinitializer(2) {
        __EIP712_init_unchained(name(), "1");
    }

    /// @inheritdoc IERC20PermitUpgradeable
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @inheritdoc IERC20PermitUpgradeable
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        virtual
        override
    {
        if (block.timestamp > deadline) revert BTOKEN_DEADLINE_EXPIRED();

        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline)
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        if (signer != owner) revert BTOKEN_INVALID_SIG();

        _approve(owner, spender, value);
    }

    /// @inheritdoc IERC20PermitUpgradeable
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner].current();
    }

    function supportsInterface(bytes4 _interfaceId) public pure virtual override returns (bool) {
        return _interfaceId == type(IERC20PermitUpgradeable).interfaceId
            || _interfaceId == type(IERC5267Upgradeable).interfaceId
            || super.supportsInterface(_interfaceId);
    }

    /// @dev "Consume a nonce": return the current value and increment.
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        CountersUpgradeable.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
}

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _balances                      | mapping(address => uint256)                        | Slot: 251  | Offset: 0    | Bytes: 32
//   _allowances                    | mapping(address => mapping(address => uint256))    | Slot: 252  | Offset: 0    | Bytes: 32
//   _totalSupply                   | uint256                                            | Slot: 253  | Offset: 0    | Bytes: 32
//   _name                          | string                                             | Slot: 254  | Offset: 0    | Bytes: 32
//   _symbol                        | string                                             | Slot: 255  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[45]                                        | Slot: 256  | Offset: 0    | Bytes: 1440
//   srcToken                       | address                                            | Slot: 301  | Offset: 0    | Bytes: 20
//   __srcDecimals                  | uint8                                              | Slot: 301  | Offset: 20   | Bytes: 1
//   srcChainId                     | uint256                                            | Slot: 302  | Offset: 0    | Bytes: 32
//   migratingAddress               | address                                            | Slot: 303  | Offset: 0    | Bytes: 20
//   migratingInbound               | bool                                               | Slot: 303  | Offset: 20   | Bytes: 1
//   __gap                          | uint256[47]                                        | Slot: 304  | Offset: 0    | Bytes: 1504
//   _hashedName                    | bytes32                                            | Slot: 351  | Offset: 0    | Bytes: 32
//   _hashedVersion                 | bytes32                                            | Slot: 352  | Offset: 0    | Bytes: 32
//   _name                          | string                                             | Slot: 353  | Offset: 0    | Bytes: 32
//   _version                       | string                                             | Slot: 354  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[48]                                        | Slot: 355  | Offset: 0    | Bytes: 1536
//   _nonces                        | mapping(address => struct CountersUpgradeable.Counter) | Slot: 403  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 404  | Offset: 0    | Bytes: 1568
// solhint-enable max-line-length

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1   
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1   
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20  
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20  
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1   
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1   
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _balances                      | mapping(address => uint256)                        | Slot: 251  | Offset: 0    | Bytes: 32  
//   _allowances                    | mapping(address => mapping(address => uint256))    | Slot: 252  | Offset: 0    | Bytes: 32  
//   _totalSupply                   | uint256                                            | Slot: 253  | Offset: 0    | Bytes: 32  
//   _name                          | string                                             | Slot: 254  | Offset: 0    | Bytes: 32  
//   _symbol                        | string                                             | Slot: 255  | Offset: 0    | Bytes: 32  
//   __gap                          | uint256[45]                                        | Slot: 256  | Offset: 0    | Bytes: 1440
//   srcToken                       | address                                            | Slot: 301  | Offset: 0    | Bytes: 20  
//   __srcDecimals                  | uint8                                              | Slot: 301  | Offset: 20   | Bytes: 1   
//   srcChainId                     | uint256                                            | Slot: 302  | Offset: 0    | Bytes: 32  
//   migratingAddress               | address                                            | Slot: 303  | Offset: 0    | Bytes: 20  
//   migratingInbound               | bool                                               | Slot: 303  | Offset: 20   | Bytes: 1   
//   __gap                          | uint256[47]                                        | Slot: 304  | Offset: 0    | Bytes: 1504
//   _hashedName                    | bytes32                                            | Slot: 351  | Offset: 0    | Bytes: 32  
//   _hashedVersion                 | bytes32                                            | Slot: 352  | Offset: 0    | Bytes: 32  
//   _name                          | string                                             | Slot: 353  | Offset: 0    | Bytes: 32  
//   _version                       | string                                             | Slot: 354  | Offset: 0    | Bytes: 32  
//   __gap                          | uint256[48]                                        | Slot: 355  | Offset: 0    | Bytes: 1536
//   _nonces                        | mapping(address => struct CountersUpgradeable.Counter) | Slot: 403  | Offset: 0    | Bytes: 32  
//   __gap                          | uint256[49]                                        | Slot: 404  | Offset: 0    | Bytes: 1568
// solhint-enable max-line-length
