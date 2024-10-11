// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IAVSDirectory {
    struct SignatureWithSaltAndExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the salt used to generate the signature
        bytes32 salt;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /// @dev This function will be left without implementation in the MVP
    function registerOperatorToAVS(address operator, SignatureWithSaltAndExpiry memory operatorSignature) external;

    /// @dev This function will be left without implementation in the MVP
    function deregisterOperatorFromAVS(address operator) external;

    /// @dev This function will have the implementation in the MVP so that the node can pull the message
    ///    to be signed
    function calculateOperatorAVSRegistrationDigestHash(address operator, address avs, bytes32 salt, uint256 expiry)
        external
        view
        returns (bytes32);
}
