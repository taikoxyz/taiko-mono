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
    struct OperatorInfo {
        uint64 activeSince; // Epoch when the operator becomes active.
        uint64 inactiveSince; // Epoch when the operator is no longer active.
        uint8 index; // Index in operatorMapping.
    }

    event Consolidated(uint8 previousCount, uint8 newCount, bool havingPerfectOperators);
    event OperatorChangeDelaySet(uint8 delay);

    mapping(address operator => OperatorInfo info) public operators;
    mapping(uint256 index => address operator) public operatorMapping;
    uint8 public operatorCount;
    uint8 public operatorChangeDelay; // in epochs

    // all operators in operatorMapping are active and none of them is to be deactivated.
    bool public havingPerfectOperators;

    uint256[47] private __gap;

    constructor() EssentialContract(address(0)) { }

    function init(address _owner, uint8 _operatorChangeDelay) external initializer {
        __Essential_init(_owner);
        operatorChangeDelay = _operatorChangeDelay;
        havingPerfectOperators = true;
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
        uint64 currentEpoch = epochStartTimestamp(0);
        uint8 i;
        uint8 _previousCount = operatorCount;
        uint8 _operatorCount = _previousCount;

        bool _havingPerfectOperators = true;

        while (i < _operatorCount) {
            address operator = operatorMapping[i];
            OperatorInfo memory info = operators[operator];

            // Check if the operator is scheduled for removal and the removal epoch has passed
            if (info.inactiveSince != 0 && info.inactiveSince <= currentEpoch) {
                // Shift all subsequent operators one position to the left
                for (uint8 j = i; j < _operatorCount - 1; j++) {
                    address nextOperator = operatorMapping[j + 1];
                    operators[nextOperator].index = j;
                    operatorMapping[j] = nextOperator;
                }
                // Remove the last operator as it has been shifted
                delete operators[operator];
                delete operatorMapping[--_operatorCount];
                // Do not increment i to check the new entry at position i
            } else {
                if (_havingPerfectOperators) {
                    if (info.activeSince == 0 || info.activeSince > currentEpoch) {
                        _havingPerfectOperators = false;
                    }
                }

                ++i;
            }
        }

        operatorCount = _operatorCount;
        havingPerfectOperators = _havingPerfectOperators;
        emit Consolidated(_previousCount, _operatorCount, _havingPerfectOperators);
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
    function getOperatorCandidatesForCurrentEpoch() external view returns (address[] memory) {
        return _getOperatorCandidatesForEpoch(epochStartTimestamp(0));
    }

    /// @notice Returns the operator candidates for the next epoch.
    /// @return An array of addresses representing the operator candidates.
    function getOperatorCandidatesForNextEpoch() external view returns (address[] memory) {
        return _getOperatorCandidatesForEpoch(epochStartTimestamp(1));
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

        if (_operatorChangeDelay != 0) {
            havingPerfectOperators = false;
        }

        emit OperatorAdded(_operator, activeSince);
    }

    function _removeOperator(address _operator, uint8 _operatorChangeDelay) internal {
        require(_operator != address(0), InvalidOperatorAddress());
        OperatorInfo memory info = operators[_operator];
        require(info.inactiveSince == 0, OperatorAlreadyRemoved());
        require(info.activeSince != 0, InvalidOperatorAddress());

        uint8 _lastOperatorIndex = operatorCount - 1;
        if (_operatorChangeDelay == 0 && operators[_operator].index == _lastOperatorIndex) {
            // If delay is 0 and operator is the last one, remove directly
            delete operators[_operator];
            delete operatorMapping[_lastOperatorIndex];
            operatorCount = _lastOperatorIndex;
            emit OperatorRemoved(_operator, block.timestamp);
        } else {
            uint64 inactiveSince = epochStartTimestamp(_operatorChangeDelay);
            operators[_operator].inactiveSince = inactiveSince;
            operators[_operator].activeSince = 0;

            havingPerfectOperators = false;
            emit OperatorRemoved(_operator, inactiveSince);
        }
    }

    /// @dev The cost of this function is primarily linear with respect to operatorCount.
    function _getOperatorForEpoch(uint64 _epochTimestamp) internal view returns (address) {
        if (_epochTimestamp < LibPreconfConstants.SECONDS_IN_EPOCH) {
            return address(0);
        }

        // Use the previous epoch's start timestamp as the random number, if it is not available
        // (zero), return address(0) directly.
        uint256 rand = uint256(
            LibPreconfUtils.getBeaconBlockRoot(
                _epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH
            )
        );

        if (rand == 0) return address(0);

        uint256 _operatorCount = operatorCount;
        if (_operatorCount == 0) return address(0);

        if (havingPerfectOperators) {
            return operatorMapping[rand % _operatorCount];
        } else {
            address[] memory candidates = new address[](_operatorCount);
            uint256 count;
            for (uint256 i; i < _operatorCount; ++i) {
                address operator = operatorMapping[i];
                if (isOperatorActive(operator, _epochTimestamp)) {
                    candidates[count++] = operator;
                }
            }
            if (count == 0) return address(0);
            return candidates[rand % count];
        }
    }

    function _getOperatorCandidatesForEpoch(uint64 _epochTimestamp)
        internal
        view
        returns (address[] memory operators_)
    {
        operators_ = new address[](operatorCount);
        uint256 count;
        for (uint256 i; i < operatorCount; ++i) {
            if (isOperatorActive(operatorMapping[i], _epochTimestamp)) {
                operators_[count++] = operatorMapping[i];
            }
        }

        assembly {
            mstore(operators_, count)
        }
    }
}
