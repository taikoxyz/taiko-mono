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
    /// If an operator is just added, activeSince != 0, inactiveSince == 0.
    /// If an operator is just removed, activeSince != 0, inactiveSince != 0.
    struct OperatorInfo {
        uint64 activeSince; // Epoch when the operator becomes active.
        uint64 inactiveSince; // Epoch when the operator is no longer active.
        uint8 index; // Index in operatorMapping.
    }

    event Consolidated(uint8 previousCount, uint8 newCount, bool havingPerfectOperators);

    uint256 public immutable selectorEpochOffset; // in epochs
    uint256 public immutable operatorChangeDelay; // in epochs

    // Slot 1
    mapping(address operator => OperatorInfo info) public operators;

    // Slot 2
    mapping(uint256 index => address operator) public operatorMapping;

    // Slot 3
    uint8 public operatorCount;

    // all operators in operatorMapping are active and none of them is to be deactivated.
    bool public havingPerfectOperators;

    uint256[47] private __gap;

    constructor(
        uint256 _operatorChangeDelay,
        uint256 _selectorEpochOffset
    )
        EssentialContract(address(0))
    {
        require(_selectorEpochOffset > 1, SelectorEpochOffsetTooSmall());
        require(_operatorChangeDelay > 0, InvalidOperatorChangeDelay());
        selectorEpochOffset = _selectorEpochOffset;
        operatorChangeDelay = _operatorChangeDelay;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
        havingPerfectOperators = true;
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
    /// @param _effectiveImmediately True if the removal should be effective immediately.
    function removeOperator(address _operator, bool _effectiveImmediately) external onlyOwner {
        _removeOperator(_operator, _effectiveImmediately ? 0 : operatorChangeDelay);
    }

    /// @notice Removes an operator by address who will become inactive in two epochs.
    /// @param _operator The address of the operator to remove.
    function removeOperator(address _operator) external onlyOwner {
        _removeOperator(_operator, operatorChangeDelay);
    }

    /// @notice Allows the caller to remove themselves as an operator immediately.
    function removeSelf() external {
        _removeOperator(msg.sender, 0);
    }

    /// @notice Consolidates the operator mapping by removing operators whose removal epoch has
    /// passed, maintaining the order of active operators, and decrementing the operatorCount.
    function consolidate() external {
        if (havingPerfectOperators) return;

        bool _havingPerfectOperators = true;
        uint8 _operatorCount = operatorCount;
        uint256 _epochTimestamp = epochStartTimestamp(0);

        for (uint256 i; i < _operatorCount;) {
            address operator = operatorMapping[i];
            OperatorInfo memory info = operators[operator];
            if (_epochTimestamp < info.activeSince) {
                // this validator is pending activation
                _havingPerfectOperators = false;
                i++;
                continue;
            }

            if (info.inactiveSince == 0) {
                // this validator is active and not pending deactivation 
                i++;
                continue;
            }

            if (_epochTimestamp < info.inactiveSince) {
                // this validator is pending deactivation
                _havingPerfectOperators = false;
                i++;
                continue;
            }

            if (_operatorCount - 1 != i) {
                // swap the last validator with this one.
                address lastOperator = operatorMapping[_operatorCount - 1];
                operatorMapping[i] = lastOperator;
                operators[lastOperator].index = uint8(i);
                delete operators[operator];
                delete operatorMapping[_operatorCount - 1];
            }

            _operatorCount--;
        }

        havingPerfectOperators = _havingPerfectOperators;
        operatorCount = _operatorCount;
        // emit Consolidated(_previousCount, _operatorCount, _havingPerfectOperators);
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForCurrentEpoch() external view returns (address) {
        return _getOperatorForEpoch(epochStartTimestamp(0));
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForNextEpoch() external view returns (address) {
        return _getOperatorForEpoch(epochStartTimestamp(1));
    }

    /// @notice Returns the operator candidates for the current epoch.
    /// @return An array of addresses representing the operator candidates.
    function getActiveOperatorsForCurrentEpoch() external view returns (address[] memory) {
        return _getActiveOperatorsForEpoch(epochStartTimestamp(0));
    }

    /// @notice Returns the operator candidates for the next epoch.
    /// @return An array of addresses representing the operator candidates.
    function getActiveOperatorsForNextEpoch() external view returns (address[] memory) {
        return _getActiveOperatorsForEpoch(epochStartTimestamp(1));
    }

    function epochStartTimestamp(uint256 _offset) public view returns (uint64) {
        unchecked {
            return uint64(
                LibPreconfUtils.getEpochTimestamp() + _offset * LibPreconfConstants.SECONDS_IN_EPOCH
            );
        }
    }

    function _addOperator(
        address _operator,
        uint256 _operatorChangeDelay
    )
        internal
        nonZeroAddr(_operator)
    {
        require(operators[_operator].activeSince == 0, OperatorAlreadyExists());

        uint8 _operatorCount = operatorCount;
        uint64 activeSince = epochStartTimestamp(_operatorChangeDelay);
        operators[_operator] = OperatorInfo({
            activeSince: activeSince,
            inactiveSince: 0, // no removal scheduled.
            index: _operatorCount
        });
        operatorMapping[_operatorCount] = _operator;
        unchecked {
            operatorCount = _operatorCount + 1;
        }

        havingPerfectOperators = false;
        emit OperatorAdded(_operator, activeSince);
    }

    function _removeOperator(
        address _operator,
        uint256 _operatorChangeDelay
    )
        internal
        nonZeroAddr(_operator)
    {
        OperatorInfo memory info = operators[_operator];
        require(info.activeSince != 0, InvalidOperatorAddress());
        require(info.inactiveSince == 0, OperatorAlreadyRemoved());

        uint64 inactiveSince = epochStartTimestamp(_operatorChangeDelay);
        operators[_operator].inactiveSince = inactiveSince;

        havingPerfectOperators = false;
        emit OperatorRemoved(_operator, inactiveSince);
    }

    /// @dev The cost of this function is primarily linear with respect to operatorCount.
    function _getOperatorForEpoch(uint64 _epochTimestamp) internal view returns (address) {
        // We use the beacon root at or after ` _epochTimestamp - timeShift` as the random number to
        // select an operator.
        // selectorEpochOffset must be big enough to ensure a non-zero beacon root is
        // available and immutable.
        uint256 timeShift = selectorEpochOffset * LibPreconfConstants.SECONDS_IN_EPOCH;
        if (_epochTimestamp < timeShift) return address(0);

        uint256 rand;
        unchecked {
            rand = uint256(LibPreconfUtils.getBeaconBlockRoot(_epochTimestamp - timeShift));
        }

        if (rand == 0) return address(0);

        uint256 _operatorCount = operatorCount;
        if (_operatorCount == 0) return address(0);

        if (havingPerfectOperators) {
            return operatorMapping[rand % _operatorCount];
        }

        address[] memory activeOperators = _getActiveOperatorsForEpoch(_epochTimestamp);
        if (activeOperators.length == 0) return address(0);

        return activeOperators[rand % activeOperators.length];
    }

    function _getActiveOperatorsForEpoch(uint64 _epochTimestamp)
        internal
        view
        returns (address[] memory operators_)
    {
        uint256 _operatorCount = operatorCount;
        operators_ = new address[](_operatorCount);
        uint256 count;
        for (uint256 i; i < _operatorCount; ++i) {
            address operator = operatorMapping[i];
            OperatorInfo memory info = operators[operator];

            if (
                _epochTimestamp >= info.activeSince
                    && (info.inactiveSince == 0 || _epochTimestamp < info.inactiveSince)
            ) {
                operators_[count++] = operator;
            }
        }

        assembly {
            mstore(operators_, count)
        }
    }
}
