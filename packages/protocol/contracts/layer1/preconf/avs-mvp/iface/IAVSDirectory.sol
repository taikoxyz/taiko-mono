// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAVSDirectory {
    struct SignatureWithSaltAndExpiry {
        /// @notice The signature itself, formatted as a single bytes object
        bytes signature;
        /// @notice The salt used to generate the signature
        bytes32 salt;
        /// @notice The expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /// @notice Registers an operator to AVS
    /// @param operator The address of the operator to register
    /// @param operatorSignature The signature, salt, and expiry of the operator
    function registerOperatorToAVS(
        address operator,
        SignatureWithSaltAndExpiry memory operatorSignature
    )
        external;

    /// @notice Deregisters an operator from AVS
    /// @param operator The address of the operator to deregister
    function deregisterOperatorFromAVS(address operator) external;

    /// @notice Calculates the digest hash for operator AVS registration
    /// @param operator The address of the operator
    /// @param avs The address of the AVS
    /// @param salt The salt used to generate the signature
    /// @param expiry The expiration timestamp (UTC) of the signature
    /// @return The digest hash for operator AVS registration
    function calculateOperatorAVSRegistrationDigestHash(
        address operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    )
        external
        view
        returns (bytes32);
}
