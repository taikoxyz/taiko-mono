// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";

/// @title IProtector
/// @custom:security-contact security@taiko.xyz
interface IProtector is ISlasher {
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SigningThresholdUpdated(uint64 newSigningThreshold);

    error CannotRemoveSignerWhenThresholdIsReached();
    error InvalidSigningThreshold();
    error NotAnExistingSigner();
    error SignerAlreadyExists();
    error SignerDoesNotExist();
    error SignersMustBeSortedInAscendingOrder();

    /// @notice Adds a new signer to the set of authorized signers.
    /// @param _signer The address to add as a signer.
    /// @param _signatures Array of signatures from existing signers authorizing the addition.
    function addSigner(address _signer, bytes[] memory _signatures) external;

    /// @notice Removes a signer from the set of authorized signers.
    /// @param _signer The address to remove as a signer.
    /// @param _signatures Array of signatures from existing signers authorizing the removal.
    function removeSigner(address _signer, bytes[] memory _signatures) external;

    /// @notice Updates the signing threshold required for multi-signature operations.
    /// @param _signingThreshold The new threshold value.
    /// @param _signatures Array of signatures from existing signers authorizing the update.
    function updateSigningThreshold(
        uint64 _signingThreshold,
        bytes[] memory _signatures
    )
        external;
}
