// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IPreconfWhitelist } from "../iface/IPreconfWhitelist.sol";
import { LibPreconfConstants } from "../libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "../libs/LibPreconfUtils.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";

/// @title PreconfWhitelist
/// @notice Non-upgradeable operator whitelist for proposer authorization.
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelist is Ownable2Step, IPreconfWhitelist, IProposerChecker {
    struct OperatorInfo {
        uint32 activeSince; // Epoch when the operator becomes active.
        uint32 deprecatedInactiveSince; // Deprecated. Kept for ABI compatibility with Go bindings.
        uint8 index; // Index in operatorMapping.
        address sequencerAddress; // Sequencer address for this operator (for off-chain use).
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    /// @dev The number of epochs before a newly added operator becomes active.
    uint8 public constant OPERATOR_CHANGE_DELAY = 2;
    /// @dev The number of epochs to use as delay when selecting an operator.
    ///      This needs to be 2 epochs or more to ensure the randomness seed source is stable
    ///      across epochs.
    uint8 public constant RANDOMNESS_DELAY = 2;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------
    mapping(address proposer => OperatorInfo info) public operators;
    mapping(uint256 index => address proposer) public operatorMapping;

    uint8 public operatorCount;
    uint32 public latestActivationEpoch;

    mapping(address ejecter => bool isEjecter) public ejecters;

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyOwnerOrEjecter() {
        require(msg.sender == owner() || ejecters[msg.sender], NotOwnerOrEjecter());
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address _owner) {
        require(_owner != address(0), ZeroAddress());
        _transferOwnership(_owner);
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IPreconfWhitelist
    /// @dev The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
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
    /// @dev Gas-optimized: inlines epochStartTimestamp, _getOperatorForEpoch, _getRandomNumber,
    ///      and getBeaconBlockRootAtOrAfter to eliminate redundant getGenesisTimestamp calls,
    ///      SafeCast overhead, and internal function JUMP costs.
    function checkProposer(
        address _proposer,
        bytes calldata
    )
        external
        view
        override(IProposerChecker)
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        // --- Inline epochStartTimestamp(0) → getEpochTimestamp(0) ---
        // Original: epochStartTimestamp(0) → LibPreconfUtils.getEpochTimestamp()
        //   → getGenesisTimestamp(block.chainid) + epoch floor calculation + SafeCast.toUint48
        uint256 genesisTimestamp = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 epochTs;
        // forge-lint: disable-start(divide-before-multiply)
        unchecked {
            uint256 timePassed = block.timestamp - genesisTimestamp;
            epochTs = genesisTimestamp + (timePassed / LibPreconfConstants.SECONDS_IN_EPOCH)
                * LibPreconfConstants.SECONDS_IN_EPOCH;
        }
        // forge-lint: disable-end

        // --- Inline _getOperatorForEpoch(uint32(epochTs)) ---
        // Original: computes delaySeconds, reads operatorCount + latestActivationEpoch,
        //   calls _getRandomNumber → getBeaconBlockRootAtOrAfter (which calls
        //   getGenesisTimestamp AGAIN). By inlining we skip the second genesis lookup.
        unchecked {
            // RANDOMNESS_DELAY (2) * SECONDS_IN_EPOCH (384) = 768, constant-folded
            uint256 randomnessTs = epochTs >= LibPreconfConstants.TWO_EPOCHS
                ? epochTs - LibPreconfConstants.TWO_EPOCHS
                : epochTs;

            // 1 SLOAD: operatorCount + latestActivationEpoch packed in same slot
            uint256 count = operatorCount;
            require(count != 0, InvalidProposer());

            // --- Inline _getRandomNumber → getBeaconBlockRootAtOrAfter ---
            // Skip genesis check: randomnessTs is derived from block.timestamp ≥ genesis,
            // so randomnessTs ≥ 0 (genesis=0 for unknown chains) is always true.
            bytes32 beaconRoot;
            {
                address beacon = LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT;
                uint256 slotDuration = LibPreconfConstants.SECONDS_IN_SLOT;
                assembly {
                    let ts := add(randomnessTs, slotDuration)
                    let current := timestamp()
                    // Use scratch space at 0x00 (safe in view context, avoids
                    // free-memory-pointer concerns across compiler versions).
                    for {
                        let i := 0
                    } and(lt(i, 32), iszero(gt(ts, current))) { i := add(i, 1) } {
                        mstore(0x00, ts)
                        let success := staticcall(gas(), beacon, 0x00, 32, 0x00, 32)
                        if and(success, gt(returndatasize(), 0)) {
                            let root := mload(0x00)
                            if root {
                                beaconRoot := root
                                break
                            }
                        }
                        ts := add(ts, slotDuration)
                    }
                }
            }

            // Note: if beaconRoot == 0 (no root found), operator selection defaults to index 0.
            // This matches the behavior of the original getBeaconBlockRootAtOrAfter.
            uint32 _latestActivationEpoch = latestActivationEpoch;

            address operator;
            if (uint32(epochTs) >= _latestActivationEpoch) {
                // Fast path: all operators active
                operator = operatorMapping[uint256(beaconRoot) % count];
            } else {
                // Slow path: check which operators are active
                uint32 epochTs32 = uint32(epochTs);
                address[] memory candidates = new address[](count);
                uint256 activeCount;
                for (uint256 i; i < count; ++i) {
                    address op = operatorMapping[i];
                    uint32 activeSince = operators[op].activeSince;
                    if (activeSince != 0 && epochTs32 >= activeSince) {
                        candidates[activeCount++] = op;
                    }
                }
                if (activeCount != 0) {
                    operator = candidates[uint256(beaconRoot) % activeCount];
                }
            }

            require(operator == _proposer, InvalidProposer());
        }

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

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

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

        latestActivationEpoch = activeSince;

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
        require(info.sequencerAddress != address(0), InvalidOperatorAddress());

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

    /// @dev Returns the operator for the given epoch
    /// This function is not affected by operators that are added mid-epoch, since it filters
    /// active ones.
    /// NOTE: We optimize for the common case where all operators are active.
    /// In that case we don't scan the entire operator set or check if the operator is active.
    /// @param _epochTimestamp The timestamp of the epoch to get the operator for.
    /// @return The operator for the given epoch.
    function _getOperatorForEpoch(uint32 _epochTimestamp) internal view returns (address) {
        unchecked {
            uint256 delaySeconds = RANDOMNESS_DELAY * LibPreconfConstants.SECONDS_IN_EPOCH;
            uint256 ts = uint256(_epochTimestamp);
            uint32 randomnessTs = uint32(ts >= delaySeconds ? ts - delaySeconds : ts);

            uint256 _operatorCount = operatorCount;
            uint32 _latestActivationEpoch = latestActivationEpoch;

            if (_operatorCount == 0) return address(0);
            uint256 randomNumber =
                uint256(LibPreconfUtils.getBeaconBlockRootAtOrAfter(randomnessTs));
            if (_epochTimestamp >= _latestActivationEpoch) {
                return operatorMapping[randomNumber % _operatorCount];
            }

            address[] memory candidates = new address[](_operatorCount);
            uint256 count;
            for (uint256 i; i < _operatorCount; ++i) {
                address operator = operatorMapping[i];
                if (isOperatorActive(operator, _epochTimestamp)) {
                    candidates[count++] = operator;
                }
            }
            if (count == 0) return address(0);
            return candidates[randomNumber % count];
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error CannotRemoveLastOperator();
    error InvalidOperatorIndex();
    error InvalidOperatorAddress();
    error OperatorAlreadyExists();
    error NoActiveOperatorRemaining();
    error NotOwnerOrEjecter();
    error ZeroAddress();
}
