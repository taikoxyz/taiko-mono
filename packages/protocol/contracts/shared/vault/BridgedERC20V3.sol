// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgedERC20V2.sol";
import "./IEIP3009.sol";

import "./BridgedERC20V3_Layout.sol"; // DO NOT DELETE

/// @title BridgedERC20V3
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain. This implementation adds EIP-3009 (Transfer With Authorization)
/// support to BridgedERC20V2, enabling gasless transfers via signed authorizations.
///
/// EIP-2612 (Permit) support is inherited from BridgedERC20V2.
///
/// @custom:security-contact security@taiko.xyz
contract BridgedERC20V3 is BridgedERC20V2, IEIP3009 {
    // keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256
    // validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
        0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

    // keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256
    // validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

    // keccak256("CancelAuthorization(address authorizer,bytes32 nonce)")
    bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH =
        0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;

    /// @dev Mapping of authorizer address => nonce => whether it has been used
    mapping(address authorizer => mapping(bytes32 nonce => bool used)) private _authorizationStates;

    uint256[48] private __gap;

    error BTOKEN_AUTHORIZATION_NOT_YET_VALID();
    error BTOKEN_AUTHORIZATION_EXPIRED();
    error BTOKEN_AUTHORIZATION_USED();
    error BTOKEN_CALLER_NOT_PAYEE();

    constructor(address _erc20Vault) BridgedERC20V2(_erc20Vault) { }

    /// @inheritdoc IBridgedERC20Initializable
    /// @dev This function is called when the bridge deploys a new bridged ERC20 token.
    /// We use `reinitializer(3)` to support direct deployment as V3.
    function init(
        address _owner,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string calldata _symbol,
        string calldata _name
    )
        external
        override
        reinitializer(3)
    {
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId);
        __Essential_init(_owner);
        __ERC20_init(_name, _symbol);
        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        __srcDecimals = _decimals;

        // Initialize EIP-712 (from V2)
        __EIP712_init_unchained(_name, "1");
    }

    /// @notice Initialize V3 for contracts upgrading from V2
    /// @dev This function should be called when upgrading an existing V2 proxy to V3.
    function init3() external reinitializer(3) {
        // No additional initialization needed for EIP-3009
        // Domain separator is already set up by V2
    }

    /// @inheritdoc IEIP3009
    function transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        whenNotPaused
        nonReentrant
    {
        _requireValidAuthorization(_from, _nonce, _validAfter, _validBefore);

        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
                _from,
                _to,
                _value,
                _validAfter,
                _validBefore,
                _nonce
            )
        );

        _validateSignature(_from, structHash, _v, _r, _s);
        _markAuthorizationAsUsed(_from, _nonce);
        _transfer(_from, _to, _value);
    }

    /// @inheritdoc IEIP3009
    function receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (_to != msg.sender) revert BTOKEN_CALLER_NOT_PAYEE();

        _requireValidAuthorization(_from, _nonce, _validAfter, _validBefore);

        bytes32 structHash = keccak256(
            abi.encode(
                RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
                _from,
                _to,
                _value,
                _validAfter,
                _validBefore,
                _nonce
            )
        );

        _validateSignature(_from, structHash, _v, _r, _s);
        _markAuthorizationAsUsed(_from, _nonce);
        _transfer(_from, _to, _value);
    }

    /// @inheritdoc IEIP3009
    function cancelAuthorization(
        address _authorizer,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (_authorizationStates[_authorizer][_nonce]) revert BTOKEN_AUTHORIZATION_USED();

        bytes32 structHash =
            keccak256(abi.encode(CANCEL_AUTHORIZATION_TYPEHASH, _authorizer, _nonce));

        _validateSignature(_authorizer, structHash, _v, _r, _s);
        _authorizationStates[_authorizer][_nonce] = true;
        emit AuthorizationCanceled(_authorizer, _nonce);
    }

    /// @inheritdoc IEIP3009
    function authorizationState(
        address _authorizer,
        bytes32 _nonce
    )
        external
        view
        returns (bool used_)
    {
        return _authorizationStates[_authorizer][_nonce];
    }

    /// @inheritdoc BridgedERC20V2
    function supportsInterface(bytes4 _interfaceId) public pure override returns (bool) {
        return _interfaceId == type(IEIP3009).interfaceId || super.supportsInterface(_interfaceId);
    }

    /// @dev Validates authorization parameters
    /// @param _authorizer The authorizer's address
    /// @param _nonce The nonce to check
    /// @param _validAfter The time after which authorization is valid
    /// @param _validBefore The time before which authorization is valid
    function _requireValidAuthorization(
        address _authorizer,
        bytes32 _nonce,
        uint256 _validAfter,
        uint256 _validBefore
    )
        private
        view
    {
        if (block.timestamp <= _validAfter) revert BTOKEN_AUTHORIZATION_NOT_YET_VALID();
        if (block.timestamp >= _validBefore) revert BTOKEN_AUTHORIZATION_EXPIRED();
        if (_authorizationStates[_authorizer][_nonce]) revert BTOKEN_AUTHORIZATION_USED();
    }

    /// @dev Validates signature against the signer
    /// @param _signer Expected signer address
    /// @param _structHash EIP-712 struct hash
    /// @param _v v component of signature
    /// @param _r r component of signature
    /// @param _s s component of signature
    function _validateSignature(
        address _signer,
        bytes32 _structHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        private
        view
    {
        bytes32 hash = _hashTypedDataV4(_structHash);
        address recovered = ECDSAUpgradeable.recover(hash, _v, _r, _s);
        if (recovered != _signer) revert BTOKEN_INVALID_SIG();
    }

    /// @dev Marks an authorization as used
    /// @param _authorizer The authorizer's address
    /// @param _nonce The nonce to mark as used
    function _markAuthorizationAsUsed(address _authorizer, bytes32 _nonce) private {
        _authorizationStates[_authorizer][_nonce] = true;
        emit AuthorizationUsed(_authorizer, _nonce);
    }
}
