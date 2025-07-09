// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfWhitelist
/// @custom:security-contact security@taiko.xyz
interface IPreconfWhitelist {
    /// @notice Emitted when a new operator is added to the whitelist.
    /// @param operator The address of the operator that was added.
    /// @param multiAddr The multiaddr of the operator driver p2p node.
    /// @param activeSince The timestamp when the operator became active.
    event OperatorAdded(address indexed operator, string multiAddr, uint256 activeSince);

    /// @notice Emitted when an operator is removed from the whitelist.
    /// @param operator The address of the operator that was removed.
    /// @param inactiveSince The timestamp when the operator became inactive.
    event OperatorRemoved(address indexed operator, uint256 inactiveSince);

    /// @notice Emitted when an operator is updated.
    /// @param operator The address of the operator.
    /// @param multiAddr The new multiaddr.
    event OperatorUpdated(address indexed operator, string multiAddr);

    error InvalidOperatorIndex();
    error InvalidOperatorCount();
    error InvalidOperatorAddress();
    error OperatorAlreadyExists();
    error OperatorAlreadyRemoved();
    error OperatorNotAvailableYet();

    /// @notice Initializes the whitelist contract.
    /// @param _owner The address that will own the contract.
    /// @param _operatorChangeDelay The number of epochs to delay operator changes.
    /// @param _randomnessDelayEpochs The number of epochs to delay randomness for operator
    /// selection.
    /// @dev Configuration note: If you want to ensure operator changes don't affect whitelist
    /// lookahead,
    ///      set _operatorChangeDelay >= _randomnessDelayEpochs. If you want to allow lookahead
    ///      to be affected by operator changes (e.g., for emergency evictions), set
    /// _operatorChangeDelay = 0.
    function init(
        address _owner,
        uint8 _operatorChangeDelay,
        uint8 _randomnessDelayEpochs
    )
        external;

    /// @notice Adds a new operator to the whitelist.
    /// @param _operatorAddress The address of the operator to be added.
    /// @dev Only callable by the owner or an authorized address.
    function addOperator(address _operatorAddress, string calldata multiAddr) external;

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

    /// @notice Updates the multiaddr for a specific operator.
    function changeMultiAddrForOperator(address _operator, string calldata multiAddr) external;
}
