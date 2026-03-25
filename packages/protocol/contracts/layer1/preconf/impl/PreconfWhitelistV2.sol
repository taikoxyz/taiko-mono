// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPreconfWhitelist } from "../iface/IPreconfWhitelist.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { LibPreconfConstants } from "../libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "../libs/LibPreconfUtils.sol";

/// @title PreconfWhitelistV2
/// @notice Non-upgradeable PreconfWhitelist — eliminates ERC1967 proxy overhead on checkProposer.
/// @custom:security-contact security@taiko.xyz
contract PreconfWhitelistV2 is Ownable, IPreconfWhitelist, IProposerChecker {
    struct OperatorInfo {
        uint32 activeSince; // Epoch when the operator becomes active.
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
        _transferOwnership(_owner);
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IPreconfWhitelist
    function addOperator(address _proposer, address _sequencer) external onlyOwnerOrEjecter {
        _addOperator(_proposer, _sequencer);
    }

    /// @inheritdoc IPreconfWhitelist
    function removeOperator(uint256 _operatorIndex) external onlyOwnerOrEjecter {
        require(_operatorIndex < operatorCount, InvalidOperatorIndex());
        _removeOperator(operatorMapping[_operatorIndex]);
    }

    /// @notice Removes an operator by proposer address.
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
    /// @dev Gas-optimized: inlines full call chain and eliminates proxy overhead.
    function checkProposer(
        address _proposer,
        bytes calldata
    )
        external
        view
        override(IProposerChecker)
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        // Inline epochStartTimestamp(0) → getEpochTimestamp(0)
        uint256 genesisTimestamp = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 epochTs;
        unchecked {
            uint256 timePassed = block.timestamp - genesisTimestamp;
            epochTs = genesisTimestamp
                + (timePassed / LibPreconfConstants.SECONDS_IN_EPOCH)
                    * LibPreconfConstants.SECONDS_IN_EPOCH;
        }

        // Inline _getOperatorForEpoch
        unchecked {
            uint256 randomnessTs =
                epochTs >= LibPreconfConstants.TWO_EPOCHS ? epochTs - LibPreconfConstants.TWO_EPOCHS : epochTs;

            // 1 SLOAD: operatorCount + latestActivationEpoch packed in same slot
            uint256 count = operatorCount;
            require(count != 0, InvalidProposer());

            // Inline beacon root query
            bytes32 beaconRoot;
            {
                address beacon = LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT;
                uint256 slotDuration = LibPreconfConstants.SECONDS_IN_SLOT;
                assembly {
                    let ts := add(randomnessTs, slotDuration)
                    let current := timestamp()
                    let ptr := mload(0x40)
                    for {
                        let i := 0
                    } and(lt(i, 32), iszero(gt(ts, current))) { i := add(i, 1) } {
                        mstore(ptr, ts)
                        let success := staticcall(gas(), beacon, ptr, 32, ptr, 32)
                        if and(success, gt(returndatasize(), 0)) {
                            let root := mload(ptr)
                            if root {
                                beaconRoot := root
                                break
                            }
                        }
                        ts := add(ts, slotDuration)
                    }
                }
            }

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

    /// @notice Returns the timestamp of the epoch start with the given offset.
    function epochStartTimestamp(uint256 _offset) public view returns (uint32) {
        return uint32(
            LibPreconfUtils.getEpochTimestamp() + _offset * LibPreconfConstants.SECONDS_IN_EPOCH
        );
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Checks if there is another active operator excluding the given operator.
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

    /// @dev Removes an operator immediately and backfills its slot.
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

    /// @dev Returns the operator for the given epoch.
    function _getOperatorForEpoch(uint32 _epochTimestamp) internal view returns (address) {
        unchecked {
            uint256 delaySeconds = RANDOMNESS_DELAY * LibPreconfConstants.SECONDS_IN_EPOCH;
            uint256 ts = uint256(_epochTimestamp);
            uint32 randomnessTs = uint32(ts >= delaySeconds ? ts - delaySeconds : ts);

            uint256 _operatorCount = operatorCount;
            uint32 _latestActivationEpoch = latestActivationEpoch;

            if (_operatorCount == 0) return address(0);
            uint256 randomNumber = uint256(LibPreconfUtils.getBeaconBlockRootAtOrAfter(randomnessTs));
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
}
