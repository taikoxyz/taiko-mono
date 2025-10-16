// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBlacklist
/// @notice Interface for the Blacklist contract
/// @custom:security-contact security@taiko.xyz
interface IBlacklist {
    struct BlacklistTimestamps {
        uint48 blacklistedAt;
        uint48 unBlacklistedAt;
    }

    /// @dev These delays prevent lookahead state from changing mid-epoch.
    /// We do not store historical blacklist data. If an operator is blacklisted,
    /// then unblacklisted, and blacklisted again within a single lookahead window,
    /// we cannot determine when the first blacklist occurred (without storing full
    /// history). Therefore, we cannot slash a lookahead poster for failing to include
    /// a non-blacklisted preconfer.
    struct BlacklistConfig {
        // Delay after which a formerly unblacklisted operator can be blacklisted again
        uint256 blacklistDelay;
        // Delay after which a formerly blacklisted operator can be unblacklisted again
        uint256 unblacklistDelay;
    }

    event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event OverseersAdded(address[] overseers);
    event OverseersRemoved(address[] overseers);

    error BlacklistDelayNotMet();
    error NotOverseer();
    error NotOwnerOrOverseer();
    error OperatorAlreadyBlacklisted();
    error OperatorNotBlacklisted();
    error UnblacklistDelayNotMet();
    error OverseerAlreadyExists();
    error OverseerDoesNotExist();

    /// @notice Blacklists a preconf operator for subjective faults
    /// @param _operatorRegistrationRoot registration root of the operator being blacklisted
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external;

    /// @notice Removes an operator from the blacklist
    /// @param _operatorRegistrationRoot registration root of the operator to unblacklist
    function unblacklistOperator(bytes32 _operatorRegistrationRoot) external;

    /// @notice Adds multiple overseers to the blacklist
    /// @param _overseers array of addresses to add as overseers
    function addOverseers(address[] calldata _overseers) external;

    /// @notice Removes multiple overseers from the blacklist
    /// @param _overseers array of addresses to remove as overseers
    function removeOverseers(address[] calldata _overseers) external;

    /// @notice Returns the blacklist configuration
    /// @return BlacklistConfig struct containing delay parameters
    function getBlacklistConfig() external pure returns (BlacklistConfig memory);

    /// @notice Returns the blacklist timestamps for an operator
    /// @param operatorRegistrationRoot registration root of the operator
    /// @return BlacklistTimestamps struct containing blacklist and unblacklist timestamps
    function getBlacklist(bytes32 operatorRegistrationRoot)
        external
        view
        returns (BlacklistTimestamps memory);

    /// @notice Checks if an operator is currently blacklisted
    /// @param operatorRegistrationRoot registration root of the operator
    /// @return true if the operator is blacklisted, false otherwise
    function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) external view returns (bool);
}
