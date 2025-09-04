// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOverseer
/// @custom:security-contact security@taiko.xyz
interface IOverseer {
    struct BlacklistTimestamps {
        uint48 blacklistedAt;
        uint48 unBlacklistedAt;
    }

    // Blacklist events
    event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);

    error BlacklistDelayNotMet();
    error NotOverseer();
    error OperatorAlreadyBlacklisted();
    error OperatorNotBlacklisted();
    error UnblacklistDelayNotMet();

    /// @notice Blacklists a preconf operator for subjective faults
    /// @param _operatorRegistrationRoot registration root of the operator being blacklisted
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external;

    /// @notice Removes an operator from the blacklist
    /// @param _operatorRegistrationRoot registration root of the operator to unblacklist
    function unblacklistOperator(bytes32 _operatorRegistrationRoot) external;

    // Views
    // -----------------------------------------------------------------------------------

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
