// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfWhitelist.sol";
import "../libs/LibPreconfUtils.sol";
import "../libs/LibPreconfConstants.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/common/EssentialContract.sol";

/// @title PreconfWhitelist2
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelist2 is EssentialContract, IPreconfWhitelist {
    struct OperatorInfo {
        uint64 activeSince; // Epoch when the operator becomes active.
        uint64 inactiveSince; // Epoch when the operator is no longer active.
        uint8 index; // Index in operatorMapping.
    }

    event Consolidated();
    event OperatorChangeDelaySet(uint8 delay);

    mapping(address operator => OperatorInfo info) public operators;
    mapping(uint256 index => address operator) public operatorMapping;
    uint8 public operatorCount;
    uint8 public operatorChangeDelay; // in epochs

    uint256[47] private __gap;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner, uint8 _operatorChangeDelay) external initializer {
        __Essential_init(_owner);
        operatorChangeDelay = _operatorChangeDelay;
    }

    function setOperatorChangeDelay(uint8 _operatorChangeDelay) external onlyOwner {
        operatorChangeDelay = _operatorChangeDelay;
        emit OperatorChangeDelaySet(_operatorChangeDelay);
    }

    /// @inheritdoc IPreconfWhitelist
    function addOperator(address _operator) external onlyOwner {
        _addOperator(_operator, operatorChangeDelay);
    }

    /// @inheritdoc IPreconfWhitelist
    function removeOperator(uint256 _operatorIndex) external onlyOwner {
        require(_operatorIndex < operatorCount, InvalidOperatorIndex());
        _removeOperator(operatorMapping[_operatorIndex], operatorChangeDelay);
    }

    /// @notice Removes an operator by address who will become inactive in two epochs.
    /// @param _operator The address of the operator to remove.
    function removeOperator(address _operator) external onlyOwner {
        _removeOperator(_operator, operatorChangeDelay);
    }

    //// @notice Allows the caller to remove themselves as an operator immediately.
    function removeSelf() external {
        _removeOperator(msg.sender, 0);
    }

    /// @notice Consolidates the operator mapping by removing operators whose removal epoch has
    /// passed, swapping removed operators with the last entry, and decrementing the operatorCount.
    function consolidate() external {
        uint64 currentEpoch = epochStartTimestamp(0);
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
        emit Consolidated();
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForCurrentEpoch() external view returns (address) {
        return _getOperatorForEpoch(epochStartTimestamp(0));
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForNextEpoch() external view returns (address) {
        return _getOperatorForEpoch(epochStartTimestamp(1));
    }

    // Returns true if the operator is active in the given epoch.
    function isOperatorActive(
        address _operator,
        uint64 _epochTimestamp
    )
        public
        view
        returns (bool)
    {
        if (_operator == address(0)) return false;
        OperatorInfo memory info = operators[_operator];
        if (_epochTimestamp < info.activeSince) {
            return false;
        } else if (info.inactiveSince != 0 && _epochTimestamp >= info.inactiveSince) {
            return false;
        } else {
            return true;
        }
    }

    function epochStartTimestamp(uint256 _offset) public view returns (uint64) {
        return uint64(
            LibPreconfUtils.getEpochTimestamp() + _offset * LibPreconfConstants.SECONDS_IN_EPOCH
        );
    }

    function _addOperator(address _operator, uint8 _operatorChangeDelay) internal {
        require(_operator != address(0), InvalidOperatorAddress());
        require(operators[_operator].activeSince == 0, OperatorAlreadyExists());

        uint8 _operatorCount = operatorCount;
        operators[_operator] = OperatorInfo({
            activeSince: epochStartTimestamp(_operatorChangeDelay),
            inactiveSince: 0, // no removal scheduled.
            index: _operatorCount
        });
        operatorMapping[_operatorCount] = _operator;
        unchecked {
            operatorCount = _operatorCount + 1;
        }

        emit OperatorAdded(_operator);
    }

    function _removeOperator(address _operator, uint8 _operatorChangeDelay) internal {
        require(_operator != address(0), InvalidOperatorAddress());
        OperatorInfo memory info = operators[_operator];
        require(info.activeSince != 0, InvalidOperatorAddress());
        require(info.inactiveSince == 0, OperatorAlreadyRemoved());

        operators[_operator].inactiveSince = epochStartTimestamp(_operatorChangeDelay);

        emit OperatorRemoved(_operator);
    }

    function _getOperatorForEpoch(uint64 _epochTimestamp) internal view returns (address) {
        if (_epochTimestamp < LibPreconfConstants.SECONDS_IN_EPOCH) {
            return address(0);
        }

        // Use the previous epoch's start timestamp as the random number, if it is not available
        // (zero), return address(0) directly.
        bytes32 root = LibPreconfUtils.getBeaconBlockRoot(
            _epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH
        );

        if (root == 0) return address(0);

        address[] memory activeOperators = new address[](operatorCount);
        uint8 count;
        for (uint8 i; i < operatorCount; ++i) {
            address operator = operatorMapping[i];
            if (isOperatorActive(operator, _epochTimestamp)) {
                activeOperators[count++] = operator;
            }
        }

        if (count == 0) return address(0);
        return activeOperators[uint256(root) % count];
    }
}
