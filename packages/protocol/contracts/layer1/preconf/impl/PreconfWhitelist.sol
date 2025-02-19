// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfWhitelist.sol";
import "../libs/LibPreconfUtils.sol";
import "../libs/LibPreconfConstants.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/common/EssentialContract.sol";

/// @title PreconfWhitelist
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelist is EssentialContract, IPreconfWhitelist {
    // Tracks the total number of operators in the whitelist
    uint256 public operatorCount;

    // Tracks whether an address is an operator
    mapping(address operator => bool isOperator) public isOperator;

    // Maps operator index to their corresponding operator addresses
    mapping(uint256 operatorIndex => address operator) public operatorIndexToOperator;

    uint256[47] private __gap;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IPreconfWhitelist
    function addOperator(address _operatorAddress)
        external
        onlyFromOwnerOrNamed(LibStrings.B_PRECONF_WHITELIST_OWNER)
    {
        require(_operatorAddress != address(0), InvalidOperatorAddress());
        require(!isOperator[_operatorAddress], OperatorAlreadyExists());

        operatorIndexToOperator[operatorCount++] = _operatorAddress;

        isOperator[_operatorAddress] = true;

        emit OperatorAdded(_operatorAddress);
    }

    /// @inheritdoc IPreconfWhitelist
    function removeOperator(uint256 _operatorIndex)
        external
        onlyFromOwnerOrNamed(LibStrings.B_PRECONF_WHITELIST_OWNER)
    {
        uint256 _operatorCount = operatorCount;
        require(_operatorIndex < _operatorCount, InvalidOperatorIndex());

        address removedOperator = operatorIndexToOperator[_operatorIndex];

        unchecked {
            // Bring the last operator to this operator's index
            address lastOperator = operatorIndexToOperator[_operatorCount - 1];
            operatorIndexToOperator[_operatorIndex] = lastOperator;

            --operatorCount;
        }

        isOperator[removedOperator] = false;

        emit OperatorRemoved(removedOperator);
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForCurrentEpoch() external view returns (address) {
        uint256 _operatorCount = operatorCount;
        require(_operatorCount != 0, InvalidOperatorCount());

        // Timestamp at which the last epoch started
        uint256 timestampOfLastEpoch =
            LibPreconfUtils.getEpochTimestamp() - LibPreconfConstants.SECONDS_IN_EPOCH;
        // Use the beacon block root at the first block of the last epoch as the
        // source of randomness
        bytes32 randomness = LibPreconfUtils.getBeaconBlockRoot(timestampOfLastEpoch);
        uint256 index = uint256(randomness) % _operatorCount;
        return operatorIndexToOperator[index];
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForNextEpoch() external view returns (address) {
        uint256 _operatorCount = operatorCount;
        require(_operatorCount != 0, InvalidOperatorCount());

        // Timestamp at which the current epoch started
        uint256 timestampOfCurrentEpoch = LibPreconfUtils.getEpochTimestamp();

        // We can only get the beacon block root of the first block in the current
        // epoch from the second block onward.
        require(block.timestamp > timestampOfCurrentEpoch, OperatorNotAvailableYet());

        // Use the beacon block root at the first block of the current epoch as the
        // source of randomness
        bytes32 randomness = LibPreconfUtils.getBeaconBlockRoot(timestampOfCurrentEpoch);
        uint256 index = uint256(randomness) % _operatorCount;
        return operatorIndexToOperator[index];
    }
}
