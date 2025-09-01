// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOverseer
/// @custom:security-contact security@taiko.xyz
interface IOverseer {
    struct BlacklistTimestamps {
        uint48 blacklistedAt;
        uint48 unBlacklistedAt;
    }

    /// @dev These delays prevent the lookahead from being messed up mid-epoch
    struct Config {
        // Delay after which a formerly unblacklisted operator can be blacklisted again
        uint256 blacklistDelay;
        // Delay after which a formerly blacklisted operator can be unblacklisted again
        uint256 unblacklistDelay;
    }

    // Blacklist events
    event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);

    error BlacklistDelayNotMet();
    error OperatorAlreadyBlacklisted();
    error OperatorNotBlacklisted();
    error UnblacklistDelayNotMet();

    /// @notice Blacklists a preconf operator for subjective faults
    /// @param _operatorRegistrationRoot registration root of the operator being blacklisted
    /// @param _signatures signatures of the overseer signers
    function blacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external;

    /// @notice Removes an operator from the blacklist
    /// @param _operatorRegistrationRoot registration root of the operator to unblacklist
    /// @param _signatures signatures of the overseer signers
    function unblacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external;

    // Views
    // -----------------------------------------------------------------------------------

    /// @notice Returns the current configuration of the overseer
    /// @return The current configuration of the overseer
    function getConfig() external view returns (Config memory);

    /// @notice Returns the blacklist timestamps for all operators
    /// @param _operatorRegistrationRoot registration root of the operator
    /// @return BlacklistTimestamps struct containing global blacklist state
    function getBlacklist(bytes32 _operatorRegistrationRoot)
        external
        view
        returns (BlacklistTimestamps memory);

    /// @notice Returns whether an operator is blacklisted
    /// @param operatorRegistrationRoot registration root of the operator
    /// @return Whether the operator is blacklisted
    function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) external view returns (bool);
}
