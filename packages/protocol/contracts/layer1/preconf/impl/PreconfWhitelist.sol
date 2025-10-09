// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfWhitelist.sol";
import "../libs/LibPreconfUtils.sol";
import "../libs/LibPreconfConstants.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/iface/IProposerChecker.sol";

/// @title PreconfWhitelist
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelist is EssentialContract, IPreconfWhitelist, IProposerChecker {
    struct OperatorInfo {
        uint32 activeSince; // Epoch when the operator becomes active.
        uint32 inactiveSince; // Epoch when the operator is no longer active.
        uint8 index; // Index in operatorMapping.
        address sequencerAddress; // Sequencer address for this operator (for off-chain use).
    }

    event Consolidated(uint8 previousCount, uint8 newCount, bool havingPerfectOperators);
    event OperatorChangeDelaySet(uint8 delay);
    event EjecterUpdated(address indexed ejecter, bool isEjecter);

    /// @dev An operator consists of a proposer address(the key to this mapping) and a sequencer
    /// address.
    ///     The proposer address is their main identifier and is used on-chain to identify the
    /// operator and decide if they are allowed to propose.
    ///     The sequencer address is used off-chain to to identify the address that is emitting
    /// preconfirmations.
    ///     NOTE: These two addresses may be the same, it is up to the operator to decide.
    mapping(address proposer => OperatorInfo info) public operators;
    mapping(uint256 index => address proposer) public operatorMapping;

    uint8 public operatorCount;
    /// @dev The number of epochs to delay for operator changes.
    uint8 public operatorChangeDelay;
    /// @dev The number of epochs to delay for randomness seed source.
    uint8 public randomnessDelay;
    /// @dev all operators in operatorMapping are active and none of them are to be deactivated.
    bool public havingPerfectOperators;
    /// @dev The addresses that can eject operators from the whitelist.
    mapping(address ejecter => bool isEjecter) public ejecters;

    uint256[45] private __gap;

    modifier onlyOwnerOrEjecter() {
        require(msg.sender == owner() || ejecters[msg.sender], NotOwnerOrEjecter());
        _;
    }

    function init(
        address _owner,
        uint8 _operatorChangeDelay,
        uint8 _randomnessDelay
    )
        external
        initializer
    {
        __Essential_init(_owner);
        operatorChangeDelay = _operatorChangeDelay;
        randomnessDelay = _randomnessDelay;
        havingPerfectOperators = true;
    }

    function setOperatorChangeDelay(uint8 _operatorChangeDelay) external onlyOwner {
        operatorChangeDelay = _operatorChangeDelay;
        emit OperatorChangeDelaySet(_operatorChangeDelay);
    }

    /// @inheritdoc IPreconfWhitelist
    function addOperator(address _proposer, address _sequencer) external onlyOwnerOrEjecter {
        _addOperator(_proposer, _sequencer, operatorChangeDelay);
    }

    /// @inheritdoc IPreconfWhitelist
    function removeOperator(uint256 _operatorIndex) external onlyOwnerOrEjecter {
        require(_operatorIndex < operatorCount, InvalidOperatorIndex());
        _removeOperator(operatorMapping[_operatorIndex], operatorChangeDelay);
    }

    /// @notice Removes an operator by address.
    /// @param _proposer The proposer address of the operator to remove.
    /// @param _effectiveImmediately True if the removal should be effective immediately, otherwise
    /// it will be effective in two epochs.
    function removeOperator(
        address _proposer,
        bool _effectiveImmediately
    )
        external
        onlyOwnerOrEjecter
    {
        _removeOperator(_proposer, _effectiveImmediately ? 0 : operatorChangeDelay);
    }

    /// @notice Allows the caller to remove themselves as an operator immediately.
    function removeSelf() external {
        _removeOperator(msg.sender, 0);
    }

    /// @notice Consolidates the operator mapping by removing operators whose removal epoch has
    /// passed, maintaining the order of active operators, and decrementing the operatorCount.
    function consolidate() external {
        uint32 currentEpoch = epochStartTimestamp(0);
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

    /// @notice Sets the ejecter address.
    /// @param _ejecter The new ejecter address.
    function setEjecter(address _ejecter, bool _isEjecter) external onlyOwner {
        ejecters[_ejecter] = _isEjecter;
        emit EjecterUpdated(_ejecter, _isEjecter);
    }

    /// @inheritdoc IProposerChecker
    function checkProposer(
        address _proposer,
        bytes calldata
    )
        external
        view
        override(IProposerChecker)
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        address operator = getOperatorForCurrentEpoch();
        require(operator != address(0), InvalidProposer());
        require(operator == _proposer, InvalidProposer());
        // Slashing is not enabled for whitelisted preconfers, so we return 0
        endOfSubmissionWindowTimestamp_ = 0;
    }

    /// @inheritdoc IPreconfWhitelist
    function getOperatorForCurrentEpoch() public view returns (address) {
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

    /// @notice Returns true if the operator is active in the given epoch.
    /// @param _proposer The proposer address of the operator to check.
    /// @param _epochTimestamp The timestamp of the epoch to check.
    /// @return _ True if the operator is active in the given epoch, false otherwise.
    function isOperatorActive(
        address _proposer,
        uint32 _epochTimestamp
    )
        public
        view
        returns (bool)
    {
        if (_proposer == address(0)) return false;
        OperatorInfo memory info = operators[_proposer];
        if (_epochTimestamp < info.activeSince) {
            return false;
        } else if (info.inactiveSince != 0 && _epochTimestamp >= info.inactiveSince) {
            return false;
        } else {
            return true;
        }
    }

    function epochStartTimestamp(uint256 _offset) public view returns (uint32) {
        return uint32(
            LibPreconfUtils.getEpochTimestamp() + _offset * LibPreconfConstants.SECONDS_IN_EPOCH
        );
    }

    function _addOperator(
        address _proposer,
        address _sequencer,
        uint8 _operatorChangeDelay
    )
        internal
    {
        require(_proposer != address(0), InvalidOperatorAddress());
        require(_sequencer != address(0), InvalidOperatorAddress());

        OperatorInfo storage info = operators[_proposer];

        // if they're already active, just revert
        if (info.activeSince != 0) {
            revert OperatorAlreadyExists();
        }

        // re-activating someone who was scheduled for removal,
        // but consolidate was not called.
        uint32 activeSince = epochStartTimestamp(_operatorChangeDelay);
        if (info.inactiveSince == 0) {
            // new operator
            uint8 idx = operatorCount;
            info.index = idx;
            operatorMapping[idx] = _proposer;

            unchecked {
                operatorCount = idx + 1;
            }
        }

        info.activeSince = activeSince;
        info.inactiveSince = 0;
        info.sequencerAddress = _sequencer;

        if (_operatorChangeDelay != 0) {
            havingPerfectOperators = false;
        }

        emit OperatorAdded(_proposer, _sequencer, activeSince);
    }

    function _removeOperator(address _proposer, uint8 _operatorChangeDelay) internal {
        require(operatorCount > 1, CannotRemoveLastOperator());
        require(_proposer != address(0), InvalidOperatorAddress());
        OperatorInfo memory info = operators[_proposer];
        require(info.inactiveSince == 0, OperatorAlreadyRemoved());
        require(info.activeSince != 0, InvalidOperatorAddress());

        address sequencer = info.sequencerAddress;

        uint8 _lastOperatorIndex = operatorCount - 1;
        if (_operatorChangeDelay == 0 && operators[_proposer].index == _lastOperatorIndex) {
            // If delay is 0 and operator is the last one, remove directly
            delete operators[_proposer];
            delete operatorMapping[_lastOperatorIndex];
            operatorCount = _lastOperatorIndex;
            emit OperatorRemoved(_proposer, sequencer, block.timestamp);
        } else {
            uint32 inactiveSince = epochStartTimestamp(_operatorChangeDelay);
            operators[_proposer].inactiveSince = inactiveSince;
            operators[_proposer].activeSince = 0;

            havingPerfectOperators = false;
            emit OperatorRemoved(_proposer, sequencer, inactiveSince);
        }
    }

    /// @dev The cost of this function is primarily linear with respect to operatorCount.
    function _getOperatorForEpoch(uint32 _epochTimestamp) internal view returns (address) {
        // Get epoch-stable randomness
        uint256 rand = _getRandomNumber(_epochTimestamp);

        uint256 _operatorCount = operatorCount;

        // If no operators, return address(0)
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

    function _getOperatorCandidatesForEpoch(uint32 _epochTimestamp)
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

    function _getRandomNumber(uint32 _epochTimestamp) internal view returns (uint256) {
        // Get the beacon root at the epoch start - this stays constant throughout the epoch
        bytes32 beaconRoot = LibPreconfUtils.getBeaconBlockRootAt(_epochTimestamp);

        return uint256(beaconRoot);
    }
}
