// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfWhitelist
/// @custom:security-contact security@taiko.xyz
interface IPreconfWhitelist {
    /// @notice Emitted when a new operator is added to the whitelist.
    /// @param operator The address of the operator that was added.
    event OperatorAdded(address indexed operator);

    /// @notice Emitted when an operator is removed from the whitelist.
    /// @param operator The address of the operator that was removed.
    event OperatorRemoved(address indexed operator);

    error InvalidOperatorIndex();
    error InvalidOperatorCount();
    error InvalidOperatorAddress();
    error OperatorAlreadyExists();
    error OperatorNotAvailableYet();

    /// @notice Adds a new operator to the whitelist.
    /// @param _operatorAddress The address of the operator to be added.
    /// @dev Only callable by the owner or an authorized address.
    function addOperator(address _operatorAddress) external;

    /// @notice Removes an operator from the whitelist.
    /// @param _operatorId The ID of the operator to be removed.
    /// @dev Only callable by the owner or an authorized address.
    /// @dev Reverts if the operator ID does not exist.
    function removeOperator(uint256 _operatorId) external;

    /// @notice Retrieves the address of the operator for the current epoch.
    /// @dev Uses the beacon block root of the first block in the last epoch as the source
    ///      of randomness.
    /// @return The address of the operator.
    function getOperatorForCurrentEpoch() external view returns (address);

    /// @notice Retrieves the address of the operator for the next epoch.
    /// @dev Uses the beacon block root of the first block in the current epoch as the source
    ///      of randomness.
    /// @return The address of the operator.
    function getOperatorForNextEpoch() external view returns (address);
}
