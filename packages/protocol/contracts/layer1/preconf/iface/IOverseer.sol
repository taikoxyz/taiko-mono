// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@solady/src/utils/ext/ithaca/BLS.sol";

/// @title IOverseer
/// @custom:security-contact security@taiko.xyz
interface IOverseer {
    struct BlacklistTimestamps {
        uint128 blacklistedAt;
        uint128 unBlacklistedAt;
    }

    /// @dev These delays prevent the lookahead from being messed up mid-epoch 
    struct Config {
        // Delay after which a formerly unblacklisted validator can be blacklisted again
        uint256 blacklistDelay;
        // Delay after which a formerly blacklisted validator can be unblacklisted again
        uint256 unblacklistDelay;
    }

    // Blacklist events
    event Blacklisted(bytes32 indexed validatorsRoot, uint256 timestamp);
    event Unblacklisted(bytes32 indexed validatorsRoot, uint256 timestamp);

    // Signer events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SigningThresholdUpdated(uint64 newSigningThreshold);

    error BlacklistDelayNotMet();
    error CannotRemoveSignerWhenThresholdIsReached();
    error InsufficientSignatures();
    error InvalidSigningThreshold();
    error NotAnExistingSigner();
    error ValidatorsAlreadyBlacklisted();
    error ValidatorsNotBlacklisted();
    error SignerAlreadyExists();
    error SignerDoesNotExist();
    error SignersMustBeSortedInAscendingOrder();
    error UnblacklistDelayNotMet();

    /// @notice Blacklists the validators of a preconf operator for subjective faults
    /// @param _validatorPubKeys consensus layer public keys of the validators being blacklisted
    /// @param _signatures signatures of the overseer signers
    function blacklistValidators(
        BLS.G1Point[] calldata _validatorPubKeys,
        bytes[] memory _signatures
    )
        external;

    /// @notice Removes a validator set from the blacklist
    /// @param _validatorsRoot merkle root of the validator set to unblacklist
    /// @param _signatures signatures of the overseer signers
    function unblacklistValidators(bytes32 _validatorsRoot, bytes[] memory _signatures) external;

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

    /// @notice Returns the proof of inclusion of a validator in the blacklist
    /// @param _validatorPubKeys consensus layer public keys of the validators
    /// @param _validatorIndex index of the validator in the validator set
    /// @return The proof of inclusion of the validator in the blacklist
    function getValidatorBlacklistInclusionProof(
        BLS.G1Point[] calldata _validatorPubKeys,
        uint256 _validatorIndex
    )
        external
        pure
        returns (bytes32[] memory);

    /// @notice Returns whether a validator is blacklisted
    /// @param _validatorPubKey consensus layer public key of the validator
    /// @param _validatorsRoot merkle root of the validator set
    /// @param _proof merkle proof of the validator's inclusion in the validator set
    /// @return Whether the validator is blacklisted
    function isValidatorBlacklisted(
        BLS.G1Point memory _validatorPubKey,
        bytes32 _validatorsRoot,
        bytes32[] calldata _proof
    )
        external
        pure
        returns (bool);
}
