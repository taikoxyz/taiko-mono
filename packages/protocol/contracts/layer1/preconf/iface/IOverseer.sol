// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";

/// @title IOverseer
/// @dev This interface inherits the URC's ISlasher interface containing the definition for
/// the `slash` function.
/// @custom:security-contact security@taiko.xyz
interface IOverseer is ISlasher {
    struct BlacklistedOperator {
        uint128 blacklistedAt;
        uint128 unBlacklistedAt;
    }

    struct Config {
        uint256 blacklistDelay;
        uint256 unblacklistDelay;
        uint256 slashingAmount;
    }

    // Blacklist events
    event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint256 timestamp);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint256 timestamp);

    // Slashing events
    event Slashed(address indexed committer, uint256 amount);

    // Signer events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SigningThresholdUpdated(uint64 newSigningThreshold);

    error BlacklistDelayNotMet();
    error CannotRemoveSignerWhenThresholdIsReached();
    error InsufficientSignatures();
    error InvalidSigningThreshold();
    error NotAnExistingSigner();
    error OperatorAlreadyBlacklisted();
    error OperatorNotBlacklisted();
    error SignerAlreadyExists();
    error SignerDoesNotExist();
    error SignersMustBeSortedInAscendingOrder();
    error UnblacklistDelayNotMet();

    /// @notice Blacklists a preconf operator for subjective faults
    /// @param _operatorRegistrationRoot The registration root of the operator to blacklist
    function blacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external;

    /// @notice Removes an operator from the blacklist
    /// @param _operatorRegistrationRoot The registration root of the operator to unblacklist
    function unblacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external;

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

    // Views
    // -----------------------------------------------------------------------------------

    /// @notice Returns the current configuration of the overseer
    /// @return The current configuration of the overseer
    function getConfig() external view returns (Config memory);
}
