// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/ILookahead.sol";
import "../iface/IPreconfRegistry.sol";
import "../iface/IPreconfServiceManager.sol";
import "../libs/LibNames.sol";
import "../libs/LibEpoch.sol";

/// @title Lookahead
/// @custom:security-contact security@taiko.xyz
contract Lookahead is ILookahead, EssentialContract {
    using LibEpoch for uint256;

    uint256 public immutable disputePeriod;
    uint256 public immutable beaconGenesisTimestamp;
    address public immutable beaconBlockRootContract;

    struct Poster {
        address addr;
    }

    // Maps the epoch timestamp to the lookahead poster.
    // If the lookahead poster has been slashed, it maps to the 0-address.
    // Note: This may be optimised to re-use existing slots and reduce gas cost.
    // TODO(dantaik): convert into a ring buffer
    mapping(uint256 epochTimestamp => Poster poster) internal posters;

    // Mapping from a pointer (representing a specific epoch timestamp) to a LookaheadEntry.
    // This stores the lookahead information for each epoch, allowing for efficient access and
    // updates.
    // TODO(dantaik): convert into a ring buffer
    mapping(uint256 pointer => LookaheadEntry) internal lookahead;

    // Pointer to the last entry in the lookahead mapping
    uint64 public lookaheadTail;

    uint256[47] private __gap;

    error InvalidAssumption();
    error InvalidDisputePeriod();
    error InvalidGenesisTimestamp();
    error InvalidLookaheadPointer();
    error InvalidSlotTimestamp();
    error LookaheadEntryIsCorrect();
    error LookaheadIsNotRequired();
    error MissedDisputeWindow();
    error NoPreconferAvailable();
    error PosterAlreadySlashedOrLookaheadIsEmpty();
    error PreconferNotRegistered();
    error SenderIsNotThePreconfer();

    modifier onlyFromPreconfer() {
        uint256 preconferIndex = _preconfRegistry().getPreconferIndex(msg.sender);
        require(preconferIndex != 0, PreconferNotRegistered());
        _;
    }

    constructor(
        uint256 _beaconGenesisTimestamp,
        address _beaconBlockRootContract,
        uint256 _disputePeriod
    ) {
        require(_beaconGenesisTimestamp % LibEpoch.SECONDS_IN_SLOT == 0, InvalidGenesisTimestamp());
        require(_disputePeriod != 0, InvalidDisputePeriod());

        beaconGenesisTimestamp = _beaconGenesisTimestamp;
        beaconBlockRootContract = _beaconBlockRootContract;
        disputePeriod = _disputePeriod;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc ILookahead
    function forcePostLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromPreconfer
        nonReentrant
    {
        uint256 epochTimestamp = _toEpochTimestamp(block.timestamp);
        require(_isLookaheadRequired(epochTimestamp), LookaheadIsNotRequired());

        _postLookahead(epochTimestamp.nextEpoch(), _lookaheadParams);
    }

    /// @inheritdoc ILookahead
    function postLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromNamed(LibNames.B_PRECONF_TASK_MANAGER)
        nonReentrant
    {
        uint256 epochTimestamp = _toEpochTimestamp(block.timestamp);
        if (_isLookaheadRequired(epochTimestamp)) {
            _postLookahead(epochTimestamp.nextEpoch(), _lookaheadParams);
        } else {
            // Do not allow non-empty _lookaheadParams that will not be used
            require(_lookaheadParams.length == 0, LookaheadIsNotRequired());
        }
    }

    /// @inheritdoc ILookahead
    function proveIncorrectLookahead(
        uint256 _lookaheadPointer,
        uint256 _slotTimestamp,
        bytes calldata _validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata _validatorInclusionProof
    )
        external
        nonReentrant
    {
        require(_slotTimestamp % LibEpoch.SECONDS_IN_SLOT == 0, InvalidSlotTimestamp());
        require(block.timestamp < _slotTimestamp + disputePeriod, MissedDisputeWindow());

        uint256 epochTimestamp = _toEpochTimestamp(_slotTimestamp);
        Poster memory poster = _posterFor(epochTimestamp);
        require(poster.addr != address(0), PosterAlreadySlashedOrLookaheadIsEmpty());

        // Validate lookahead pointer
        LookaheadEntry memory entry = _entryAt(_lookaheadPointer);
        require(_slotTimestamp > entry.validSince, InvalidLookaheadPointer());
        require(_slotTimestamp <= entry.validUntil, InvalidLookaheadPointer());

        // We pull the preconfer present at the required slot timestamp in the lookahead.
        // If no preconfer is present for a slot, we simply use the 0-address to denote the
        // preconfer.
        address preconferInLookahead;

        // TODO(dantaik):Fiture out the following logic
        if (_slotTimestamp == entry.validUntil && !entry.isFallback) {
            // The slot was dedicated to a specific preconfer
            preconferInLookahead = entry.preconfer;
        }

        bytes32 pubKeyHash = _hashBLSPubKey(_validatorBLSPubKey);
        address preconferInRegistry =
            _preconfRegistry().getPreconferForValidator(pubKeyHash, _slotTimestamp);

        require(preconferInRegistry != preconferInLookahead, LookaheadEntryIsCorrect());

        LibEIP4788.verifyValidator(
            _validatorBLSPubKey, getBeaconBlockRoot(_slotTimestamp), _validatorInclusionProof
        );

        _enableFallbackPreconfer(epochTimestamp);
        _posterFor(epochTimestamp).addr = address(0);

        emit IncorrectLookaheadProved(_slotTimestamp, pubKeyHash, poster.addr, entry);

        // Slash the poster
        _preconfServiceManager().slashOperator(poster.addr);
    }

    /// @inheritdoc ILookahead
    function isCurrentPreconfer(
        uint256 _lookaheadPointer,
        address _address
    )
        external
        view
        returns (bool)
    {
        LookaheadEntry memory entry = _entryAt(_lookaheadPointer);
        return _address == entry.preconfer && block.timestamp > entry.validSince
            && block.timestamp <= entry.validUntil;
    }
    

     /// @dev Returns the full 32 slot preconfer lookahead for the epoch
    function getLookaheadForEpoch(uint256 epochTimestamp) external view returns (address[32] memory entries_) {
        // uint256 i = lookaheadTail;
        // uint256 lastSlotTimestamp = epochTimestamp.nextEpoch() - LibEpoch.SECONDS_IN_SLOT;

        // // Take the tail to the entry that fills the last slot of the epoch.
        // // This may be an entry in the next epoch who starts preconfing in advanced.
        // // This may also be an empty slot since the lookahead for next epoch is not yet posted.
        // while (_entryAt(i).validSince >= lastSlotTimestamp) {
        //    i-=1;
        // }

        // LookaheadEntry memory entry = _entryAt(i);
        // address preconfer = entry.preconfer;
        // uint256 validSince = entry.validSince;
        // uint256 validUntil =entry.validUntil;

        // // Iterate backwards and fill in the slots
        // for (uint256 i = 32; i > 0; --i) {
        //     if ( _entryAt(i).validUntil >= lastSlotTimestamp) {
        //         entries_[i - 1] = preconfer;
        //     }

        //     lastSlotTimestamp -= LibEpoch.SECONDS_IN_SLOT;

        //     if (lastSlotTimestamp == validSince) {
        //         LookaheadEntry memory entry = _entryAt(--i);
        //         preconfer = entry.preconfer;
        //         validSince = entry.validSince;
        //     }
        // }
    }

    /// @inheritdoc ILookahead
    function getPoster(uint256 _epochTimestamp) external view returns (address) {
        return _posterFor(_epochTimestamp).addr;
    }

    /// @notice Retrieves the beacon block root for the block at the specified timestamp
    function getBeaconBlockRoot(uint256 _timestamp) public view returns (bytes32) {
        // At block N, we get the beacon block root for block N - 1. So, to get the block root of
        // the Nth block, we query the root at block N + 1. If N + 1 is a missed slot, we keep
        // querying until we find a block N + x that has the block root for Nth block.
        uint256 targetTimestamp = _timestamp + LibEpoch.SECONDS_IN_SLOT;
        while (true) {
            (bool success, bytes memory result) =
                beaconBlockRootContract.staticcall(abi.encode(targetTimestamp));
            if (success && result.length > 0) {
                return abi.decode(result, (bytes32));
            }

            unchecked {
                targetTimestamp += LibEpoch.SECONDS_IN_SLOT;
            }
        }
        return bytes32(0);
    }

    // --- internal/private helper functions
    // ----------------------------------------------------------

    function _postLookahead(
        uint256 _epochTimestamp,
        LookaheadParam[] calldata _lookaheadParams
    )
        private
    {
        // The tail of the lookahead is tracked and connected to the first new lookahead entry so
        // that when no more preconfers are present in the remaining slots of the current epoch,
        // the next epoch's preconfer may start preconfing in advanced.
        //
        // --[]--[]--[P1]--[]--[]---|---[]--[]--[P2]--[]--[]
        //   1   2    3    4   5        6    7    8   9   10
        //         Epoch 1                     Epoch 2
        //
        // Here, P2 may start preconfing and proposing blocks from slot 4 itself
        //
        uint256 i = lookaheadTail;
        uint40 previousValidUntil = _entryAt(i).validUntil;

        if (_lookaheadParams.length == 0) {
            // If no preconfers are present in the lookahead, we use the fallback preconfer for the
            // entire epoch and, insert it in the last slot of the epoch so that it may start
            // preconfing in advanced
            uint256 validUntil = _epochTimestamp - LibEpoch.SECONDS_IN_SLOT;
            require(validUntil > previousValidUntil, InvalidAssumption());

            LookaheadEntry storage entry = _entryAt(++i);
            entry.isFallback = true;
            entry.validSince = previousValidUntil;
            entry.validUntil = uint40(validUntil);
            entry.preconfer = _getFallbackPreconfer();
            emit EntryUpdated(i, entry);
        } else {
            for (uint256 j; j < _lookaheadParams.length; j++) {
                // Each entry must be registered in the preconf registry
                address preconfer = _lookaheadParams[j].preconfer;
                require(
                    preconfer != address(0) && _preconfRegistry().getPreconferIndex(preconfer) != 0,
                    PreconferNotRegistered()
                );

                // Ensure that the timestamps belong to a valid slot in the epoch
                uint40 validUntil = _lookaheadParams[j].validUntil;
                require(validUntil % LibEpoch.SECONDS_IN_SLOT == 0, InvalidSlotTimestamp());
                require(validUntil > previousValidUntil, InvalidSlotTimestamp());
                require(validUntil < _epochTimestamp.nextEpoch(), InvalidSlotTimestamp());

                LookaheadEntry storage entry = _entryAt(++i);
                entry.isFallback = false;
                entry.validSince = previousValidUntil;
                entry.validUntil = validUntil;
                entry.preconfer = preconfer;
                emit EntryUpdated(i, entry);

                previousValidUntil = validUntil;
            }
        }

        unchecked {
            lookaheadTail = uint64(i);
            _posterFor(_epochTimestamp).addr = msg.sender;
            _preconfServiceManager().lockStakeUntil(msg.sender, block.timestamp + disputePeriod);
        }
    }

    // TODO(dantaik): verify `--i` wont underflow
    function _enableFallbackPreconfer(uint256 _epochTimestamp) private {
        // If it is the current epoch's lookahead being proved incorrect then insert a fallback
        // preconfer for the next epoch.
        uint256 nextEpochTimestamp = _epochTimestamp.nextEpoch();
        if (block.timestamp < nextEpochTimestamp) return;

        unchecked {
            uint256 lastSlotTimestampInCurrentEpoch = nextEpochTimestamp - LibEpoch.SECONDS_IN_SLOT;
            uint256 i = lookaheadTail;
            LookaheadEntry storage entry = _entryAt(i);

            // If the lookahead for next epoch is available
            if (entry.validUntil >= nextEpochTimestamp) {
                // Get to the first entry that connects to a slot in the current epoch
                while (entry.validSince >= nextEpochTimestamp) {
                    entry = _entryAt(--i);
                }

                // Switch the connection to the last slot of the current epoch
                entry.validSince = uint40(lastSlotTimestampInCurrentEpoch);

                emit EntryUpdated(i, entry);

                // Head to the last entry in current epoch
                entry = _entryAt(--i);
            }

            entry.isFallback = true;
            entry.validSince = uint40(_epochTimestamp - LibEpoch.SECONDS_IN_SLOT);
            entry.validUntil = uint40(lastSlotTimestampInCurrentEpoch);
            entry.preconfer = _getFallbackPreconfer();

            emit EntryUpdated(i, entry);

            // Nullify the rest of the lookahead entries for this epoch
            for (entry = _entryAt(--i); entry.validUntil >= _epochTimestamp; entry = _entryAt(--i))
            {
                // trick: keep entry.preconfer as-is to avoid setting the storage slot to zeros,
                // which saves gas for the next sstore operation at the same slot
                entry.isFallback = false;
                entry.validSince = 0;
                entry.validUntil = 0;

                emit EntryUpdated(i, entry);
            }
        }
    }

    function _isLookaheadRequired(uint256 _epochTimestamp) private view returns (bool) {
        // If it's the first slot of current epoch, we don't need the lookahead since the offchain
        // node may not have access to it yet.
        unchecked {
            return block.timestamp != _epochTimestamp
                && _posterFor(_epochTimestamp.nextEpoch()).addr == address(0);
        }
    }

    function _getFallbackPreconfer() private view returns (address) {
        IPreconfRegistry preconfRegistry = _preconfRegistry();
        uint256 nextPreconfIndex = preconfRegistry.getNextPreconferIndex();
        require(nextPreconfIndex > 1, NoPreconferAvailable());

        unchecked {
            uint256 preconferIndex = (block.prevrandao % (nextPreconfIndex - 1)) + 1;
            return preconfRegistry.getPreconferAtIndex(preconferIndex);
        }
    }

    function _entryAt(uint256 _pointer) private view returns (LookaheadEntry storage) {
        return lookahead[_pointer];
    }

    function _posterFor(uint256 _epochTimestamp) private view returns (Poster storage) {
        return posters[_epochTimestamp];
    }

    function _toEpochTimestamp(uint256 _timestamp) private view returns (uint256) {
        return LibEpoch.toEpochTimestamp(_timestamp, beaconGenesisTimestamp);
    }

    function _preconfRegistry() private view returns (IPreconfRegistry) {
        return IPreconfRegistry(resolve(LibNames.B_PRECONF_REGISTRY, false));
    }

    function _preconfServiceManager() private view returns (IPreconfServiceManager) {
        return IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false));
    }

    function _hashBLSPubKey(bytes calldata _BLSPubKey) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes16(0), _BLSPubKey));
    }
}
