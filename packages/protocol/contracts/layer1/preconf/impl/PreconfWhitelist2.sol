// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfWhitelist.sol";
import "../libs/LibPreconfUtils.sol";
import "../libs/LibPreconfConstants.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/common/EssentialContract.sol";

import "forge-std/src/console2.sol";

/// @title PreconfWhitelist2
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelist2 is EssentialContract, IPreconfWhitelist {
    struct OperatorInfo {
        uint64 activeSince; // Epoch when the operator becomes active.
        uint64 inactiveSince; // Epoch when the operator is no longer active.
        uint8 index; // Index in operatorMapping.
    }

    mapping(address operator => OperatorInfo info) public operators;
    mapping(uint256 index => address operator) public operatorMapping;
    uint8 public operatorCount;

    uint256[47] private __gap;

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    constructor(address _resolver) EssentialContract(_resolver) { }

    /// @notice Add a new operator who will become effective in two epochs.
    /// @param _operator The operator to add.
    function addOperator(address _operator) external onlyOwner {
        require(_operator != address(0), InvalidOperatorAddress());
        require(operators[_operator].activeSince == 0, OperatorAlreadyExists());

        uint8 _operatorCount = operatorCount;
        operators[_operator] = OperatorInfo({
            activeSince: epochTimestamp(2),
            inactiveSince: 0, // 0 indicates no removal scheduled.
            index: _operatorCount
        });
        operatorMapping[_operatorCount] = _operator;
        unchecked {
            operatorCount = _operatorCount + 1;
        }

        emit OperatorAdded(_operator);
    }

    /// @notice Removes an operator by address who will become inactive in two epochs.
    /// @param _operator The address of the operator to remove.
    function removeOperator(address _operator) external onlyOwner {
        _removeOperator(_operator);
    }

    /// @notice Removes an operator by index.
    /// @param _operatorIndex The index of the operator to remove.
    function removeOperator(uint256 _operatorIndex) external onlyOwner {
        require(_operatorIndex < operatorCount, InvalidOperatorIndex());
        _removeOperator(operatorMapping[_operatorIndex]);
    }

    // Consolidate cleans up the operator mapping by removing operators whose removal epoch has
    // passed.
    // It swaps removed operators with the last entry and decrements the operatorCount.
    function consolidate() external {
        uint64 currentEpoch = epochTimestamp(0);
        uint8 i;
        uint8 _operatorCount = operatorCount;

        while (i < _operatorCount) {
            address operator = operatorMapping[i];
            OperatorInfo memory info = operators[operator];
            // Check if the operator is scheduled for removal and the removal epoch has passed
            if (info.inactiveSince != 0 && info.inactiveSince <= currentEpoch) {
                uint8 lastIndex = _operatorCount - 1;
                // Only perform swap if not the last element
                if (i != lastIndex) {
                    address lastOperator = operatorMapping[lastIndex];
                    operators[lastOperator].index = i;
                    operatorMapping[i] = lastOperator;
                }
                // Remove the operator from the mapping
                delete operators[operator];
                delete operatorMapping[lastIndex];
                _operatorCount--;
                // Do not increment i to check the swapped entry
            } else {
                ++i;
            }
        }

        operatorCount = _operatorCount;
    }

    // Returns the list of operators active in the current epoch.
    function getOperatorForCurrentEpoch() external view returns (address) {
        return _getOperatorForEpoch(epochTimestamp(0) - uint64(LibPreconfConstants.SECONDS_IN_EPOCH));
    }

    // Returns the list of operators active in the next epoch.
    function getOperatorForNextEpoch() external view returns (address) {
        return _getOperatorForEpoch(epochTimestamp(0));
    }

    // Returns true if the operator is active in the given epoch.
    function isOperatorActive(address _operator, uint64 _epoch) public view returns (bool) {
        if (_operator == address(0)) return false;
        OperatorInfo memory info = operators[_operator];
        if (_epoch < info.activeSince) return false;
        if (info.inactiveSince != 0 && _epoch >= info.inactiveSince) return false;
        return true;
    }

    function epochTimestamp(uint256 offset) public view returns (uint64) {
        return uint64(
            LibPreconfUtils.getEpochTimestamp() + offset * LibPreconfConstants.SECONDS_IN_EPOCH
        );
    }

    function _getOperatorForEpoch(uint64 _epoch) internal view returns (address) {
        if (block.timestamp <= _epoch) return address(0);

        // Only allocate what we need - operatorCount is the maximum we could have
        address[] memory activeOperators = new address[](operatorCount);
        uint8 count;
        for (uint8 i; i < operatorCount; ++i) {
            address operator = operatorMapping[i];
            if (isOperatorActive(operator, _epoch)) {
                activeOperators[count++] = operator;
            }
        }

        if (count == 0) return address(0);

        bytes32 randomness = LibPreconfUtils.getBeaconBlockRoot(
            _epoch - uint64(LibPreconfConstants.SECONDS_IN_EPOCH)
        );
        uint256 index = uint256(randomness) % count;
        return activeOperators[index];
    }

    /// @notice Remove an operator.
    /// @dev Normally, removal is scheduled for current + 2 epochs.
    /// If the operator has not yet become active, it will be active for one epoch and removed in
    /// activeSince + 1 epoch.
    function _removeOperator(address operator) internal {
        require(operator != address(0), InvalidOperatorAddress());
        OperatorInfo storage info = operators[operator];
        require(info.activeSince != 0, InvalidOperatorAddress());

        uint64 inactiveSince = epochTimestamp(2);
        if (inactiveSince <= info.activeSince) {
            inactiveSince = info.activeSince + uint64(LibPreconfConstants.SECONDS_IN_EPOCH);
        }
        info.inactiveSince = inactiveSince;

        emit OperatorRemoved(operator);
    }
}
