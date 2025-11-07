// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfWhitelist.sol";
import "../libs/LibPreconfConstants.sol";
import "../libs/LibPreconfUtils.sol";
import "src/layer1/core/iface/IProposerChecker.sol";
import "src/shared/common/EssentialContract.sol";

import "./PreconfWhitelist_Layout.sol"; // DO NOT DELETE

/// @title PreconfWhitelist
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelist is EssentialContract, IPreconfWhitelist, IProposerChecker {
    struct OperatorInfo {
        uint32 activeSince; // Epoch when the operator becomes active.
        uint32 deprecatedInactiveSince; // Deprecated. Kept for storage compatibility.
        uint8 index; // Index in operatorMapping.
        address sequencerAddress; // Sequencer address for this operator (for off-chain use).
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    /// @dev The number of epochs before a newly added operator becomes active.
    uint8 public constant OPERATOR_CHANGE_DELAY = 2;
    /// @dev The number of epochs to use as delay when selecting an operator.
    ///      This needs to be 2 epochs or more to ensure the randomness seed source is stable across epochs.
    uint8 public constant RANDOMNESS_DELAY = 2;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------
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
    /// @dev Deprecated variable. Kept here for storage compatibility.
    uint8 private deprecated1;
    /// @dev Deprecated variable. Kept here for storage compatibility.
    uint8 private deprecated2;
    /// @dev Deprecated variable. Kept here for storage compatibility.
    bool private deprecated3;
    /// @dev The addresses that can eject operators from the whitelist.
    mapping(address ejecter => bool isEjecter) public ejecters;

    uint256[45] private __gap;

    modifier onlyOwnerOrEjecter() {
        require(msg.sender == owner() || ejecters[msg.sender], NotOwnerOrEjecter());
        _;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IPreconfWhitelist
    /// @dev NOTE: The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
    function addOperator(address _proposer, address _sequencer) external onlyOwnerOrEjecter {
        _addOperator(_proposer, _sequencer);
    }

    /// @inheritdoc IPreconfWhitelist
    /// @dev IMPORTANT: The operator is removed immediately
    function removeOperator(uint256 _operatorIndex) external onlyOwnerOrEjecter {
        require(_operatorIndex < operatorCount, InvalidOperatorIndex());
        _removeOperator(operatorMapping[_operatorIndex]);
    }

    /// @notice Removes an operator by proposer address, keeping the index mapping densely packed.
    /// IMPORTANT: The operator is removed immediately
    /// @param _proposer The proposer address of the operator to remove.
    function removeOperatorByAddress(address _proposer) external onlyOwnerOrEjecter {
        _removeOperator(_proposer);
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
        address operator = _getOperatorForEpoch(epochStartTimestamp(0));
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
        unchecked {
            OperatorInfo storage info = operators[_proposer];

            uint32 activeSince = info.activeSince;
            return activeSince != 0 && _epochTimestamp >= activeSince;
        }
    }

    /// @notice Returns the timestamp of the epoch start with the given offset
    /// @param _offset The offset from the current epoch start.
    /// @return The timestamp of the epoch start with the given offset.
    function epochStartTimestamp(uint256 _offset) public view returns (uint32) {
        return uint32(
            LibPreconfUtils.getEpochTimestamp() + _offset * LibPreconfConstants.SECONDS_IN_EPOCH
        );
    }

    /// @dev Checks if there is another active operator excluding the given operator
    /// @param _excluded The proposer address of the operator to exclude.
    /// @param _epochTimestamp The timestamp of the epoch to check.
    /// @return True if there is another active operator, false otherwise.
    function _hasAnotherActiveOperator(
        address _excluded,
        uint32 _epochTimestamp
    )
        internal
        view
        returns (bool)
    {
        uint8 _operatorCount = operatorCount;
        for (uint8 i; i < _operatorCount; ++i) {
            address operator = operatorMapping[i];
            if (operator == _excluded) continue;
            if (isOperatorActive(operator, _epochTimestamp)) return true;
        }
        return false;
    }

    /// @dev Adds an operator to the whitelist.
    /// NOTE: The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
    /// @param _proposer The proposer address of the operator to add.
    /// @param _sequencer The sequencer address of the operator to add.
    function _addOperator(address _proposer, address _sequencer) internal {
        require(_proposer != address(0), InvalidOperatorAddress());
        require(_sequencer != address(0), InvalidOperatorAddress());

        OperatorInfo storage info = operators[_proposer];

        // if they're already active, just revert
        if (info.activeSince != 0) {
            revert OperatorAlreadyExists();
        }

        uint32 activeSince = epochStartTimestamp(OPERATOR_CHANGE_DELAY);
        uint8 idx = operatorCount;
        info.index = idx;
        operatorMapping[idx] = _proposer;

        operatorCount = idx + 1;

        info.activeSince = activeSince;
        info.sequencerAddress = _sequencer;

        emit OperatorAdded(_proposer, _sequencer, activeSince);
    }

    /// @dev Removes an operator immediately and backfills its slot with the last proposer so
    ///      operatorMapping stays packed from 0..operatorCount-1.
    /// IMPORTANT: Reverts if no other operator is active.
    /// @param _proposer The proposer address of the operator to remove.
    function _removeOperator(address _proposer) internal {
        require(operatorCount > 1, CannotRemoveLastOperator());
        require(_proposer != address(0), InvalidOperatorAddress());
        OperatorInfo storage info = operators[_proposer];
        require(info.activeSince != 0, InvalidOperatorAddress());

        uint32 currentEpochTs = epochStartTimestamp(0);
        if (isOperatorActive(_proposer, currentEpochTs)) {
            require(
                _hasAnotherActiveOperator(_proposer, currentEpochTs), NoActiveOperatorRemaining()
            );
        }

        address sequencer = info.sequencerAddress;
        uint8 index = info.index;
        uint8 lastIndex = operatorCount - 1;

        if (index != lastIndex) {
            address lastProposer = operatorMapping[lastIndex];
            operatorMapping[index] = lastProposer;
            operators[lastProposer].index = index;
        }

        delete operatorMapping[lastIndex];
        delete operators[_proposer];

        operatorCount = lastIndex;

        emit OperatorRemoved(_proposer, sequencer, block.timestamp);
    }

    function _getOperatorForEpoch(uint32 _epochTimestamp) internal view returns (address) {
        unchecked {
            // Get epoch-stable randomness with a delayed applied. This avoids querying future beacon roots.
            uint256 delaySeconds = RANDOMNESS_DELAY * LibPreconfConstants.SECONDS_IN_EPOCH;
            uint256 ts = uint256(_epochTimestamp);
            uint32 randomnessTs = uint32(ts >= delaySeconds ? ts - delaySeconds : ts);
            uint256 _operatorCount = operatorCount;

            uint256 target = _getRandomNumber(randomnessTs) % _operatorCount;

            for (uint256 i; i < _operatorCount; ++i) {
                address operator = operatorMapping[target];
                if (isOperatorActive(operator, _epochTimestamp)) {
                    // In most cases, we just return the operator at the target index.
                    // This allows us to do a single SLOAD.
                    return operator;
                }
                // If the operator is not active, we need to find the next active operator.
                target = target == 0 ? _operatorCount - 1 : target - 1;
            }

            // If no active operators, return address(0). This should never happen.
            return address(0);
        }
    }

    function _getRandomNumber(uint32 _epochTimestamp) internal view returns (uint256) {
        // Get the beacon root at the epoch start - this stays constant throughout the epoch
        bytes32 beaconRoot = LibPreconfUtils.getBeaconBlockRootAt(_epochTimestamp);

        return uint256(beaconRoot);
    }
}
