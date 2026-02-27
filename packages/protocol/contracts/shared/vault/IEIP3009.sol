// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEIP3009
/// @notice Interface for EIP-3009: Transfer With Authorization
/// @dev See https://eips.ethereum.org/EIPS/eip-3009
/// @custom:security-contact security@taiko.xyz
interface IEIP3009 {
    /// @notice Emitted when an authorization is used
    /// @param authorizer The address of the authorizer
    /// @param nonce The nonce of the authorization
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    /// @notice Emitted when an authorization is canceled
    /// @param authorizer The address of the authorizer
    /// @param nonce The nonce of the authorization
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);

    /// @notice Execute a transfer with a signed authorization (EOA signature)
    /// @param _from Payer's address (Authorizer)
    /// @param _to Payee's address
    /// @param _value Amount to be transferred
    /// @param _validAfter The time after which this is valid (unix time)
    /// @param _validBefore The time before which this is valid (unix time)
    /// @param _nonce Unique nonce
    /// @param _v v of the signature
    /// @param _r r of the signature
    /// @param _s s of the signature
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
        external;

    /// @notice Execute a transfer with a signed authorization (EIP-1271 compatible)
    /// @param _from Payer's address (Authorizer)
    /// @param _to Payee's address
    /// @param _value Amount to be transferred
    /// @param _validAfter The time after which this is valid (unix time)
    /// @param _validBefore The time before which this is valid (unix time)
    /// @param _nonce Unique nonce
    /// @param _signature Signature bytes (ECDSA or EIP-1271 contract signature)
    function transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    )
        external;

    /// @notice Receive a transfer with a signed authorization from the payer (EOA signature)
    /// @dev This has an additional check to ensure that the payee's address
    /// matches the caller of this function to prevent front-running attacks.
    /// @param _from Payer's address (Authorizer)
    /// @param _to Payee's address
    /// @param _value Amount to be transferred
    /// @param _validAfter The time after which this is valid (unix time)
    /// @param _validBefore The time before which this is valid (unix time)
    /// @param _nonce Unique nonce
    /// @param _v v of the signature
    /// @param _r r of the signature
    /// @param _s s of the signature
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
        external;

    /// @notice Receive a transfer with a signed authorization from the payer (EIP-1271 compatible)
    /// @dev This has an additional check to ensure that the payee's address
    /// matches the caller of this function to prevent front-running attacks.
    /// @param _from Payer's address (Authorizer)
    /// @param _to Payee's address
    /// @param _value Amount to be transferred
    /// @param _validAfter The time after which this is valid (unix time)
    /// @param _validBefore The time before which this is valid (unix time)
    /// @param _nonce Unique nonce
    /// @param _signature Signature bytes (ECDSA or EIP-1271 contract signature)
    function receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    )
        external;

    /// @notice Attempt to cancel an authorization (EOA signature)
    /// @dev Works only if the authorization is not yet used.
    /// @param _authorizer Authorizer's address
    /// @param _nonce Nonce of the authorization
    /// @param _v v of the signature
    /// @param _r r of the signature
    /// @param _s s of the signature
    function cancelAuthorization(
        address _authorizer,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external;

    /// @notice Attempt to cancel an authorization (EIP-1271 compatible)
    /// @dev Works only if the authorization is not yet used.
    /// @param _authorizer Authorizer's address
    /// @param _nonce Nonce of the authorization
    /// @param _signature Signature bytes (ECDSA or EIP-1271 contract signature)
    function cancelAuthorization(
        address _authorizer,
        bytes32 _nonce,
        bytes memory _signature
    )
        external;

    /// @notice Returns the state of an authorization
    /// @dev Nonces are randomly generated 32-byte data unique to the authorizer's address
    /// @param _authorizer Authorizer's address
    /// @param _nonce Nonce of the authorization
    /// @return used_ True if the nonce is used
    function authorizationState(
        address _authorizer,
        bytes32 _nonce
    )
        external
        view
        returns (bool used_);
}
