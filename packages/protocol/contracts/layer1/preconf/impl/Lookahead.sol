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

    address public immutable beaconBlockRootContract;
    uint256 public immutable beaconGenesisSlot;
    uint256 public immutable disputePeriod;
    uint256 public immutable posterBufferSize;
    uint256 public immutable lookaheadBufferSize;

    struct Poster {
        address addr;
        uint40 slot;
    }

    // A ring buffer from the epoch timestamp to its poster.
    // If the lookahead poster has been slashed, it maps to the 0-address.
    mapping(uint256 epochTimestamp => Poster poster) internal posters;

    // A ring-buffer of Entries.
    mapping(uint256 entryPointer => Entry) internal lookahead;

    // Pointer to the last entry in the lookahead mapping
    uint64 public lookaheadTail;

    uint256[47] private __gap;

    error InvalidAssumption();
    error InvalidDisputePeriod();
    error InvalidLookaheadPointer();
    error InvalidParam();
    error InvalidSlot();
    error InvalidEpochFirstSlot();
    error EntryIsCorrect();
    error LookaheadIsNotRequired();
    error MissedDisputeWindow();
    error NoPreconferAvailable();
    error PosterAlreadySlashedOrLookaheadIsEmpty();
    error PreconferNotRegistered();
    error SenderIsNotThePreconfer();

    modifier validEpochFirstSlot(uint256 _epochFirstSlot) {
        require(_epochFirstSlot % LibEpoch.SLOTS_IN_EPOCH == 0, InvalidEpochFirstSlot());
        _;
    }

    modifier onlyPreconfer() {
        uint256 preconferIndex = _preconfRegistry().getPreconferIndex(msg.sender);
        require(preconferIndex != 0, PreconferNotRegistered());
        _;
    }

    constructor(
        address _beaconBlockRootContract,
        uint256 _beaconGenesisSlot,
        uint256 _disputePeriod,
        uint256 _posterBufferSize,
        uint256 _lookaheadBufferSize
    ) {
        require(_beaconBlockRootContract != address(0), InvalidParam());
        require(_disputePeriod != 0, InvalidParam());
        require(_posterBufferSize != 0, InvalidParam());
        require(_posterBufferSize % LibEpoch.SLOTS_IN_EPOCH == 0, InvalidParam());
        require(_lookaheadBufferSize != 0, InvalidParam());
        require(_lookaheadBufferSize % LibEpoch.SLOTS_IN_EPOCH == 0, InvalidParam());

        beaconBlockRootContract = _beaconBlockRootContract;
        beaconGenesisSlot = _beaconGenesisSlot;
        disputePeriod = _disputePeriod;
        posterBufferSize = _posterBufferSize;
        lookaheadBufferSize = _lookaheadBufferSize;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc ILookahead
    function forcePostLookahead(EntryParam[] calldata _lookaheadParams)
        external
        onlyPreconfer
        nonReentrant
    {
        uint256 epochFirstSlot = block.number.toEpochFirstSlot();
        require(_isLookaheadRequired(epochFirstSlot), LookaheadIsNotRequired());

        _postLookahead(epochFirstSlot.nextEpoch(), _lookaheadParams);
    }

    /// @inheritdoc ILookahead
    function postLookahead(EntryParam[] calldata _lookaheadParams)
        external
        onlyFromNamed(LibNames.B_PRECONF_TASK_MANAGER)
        nonReentrant
    {
        uint256 epochFirstSlot = block.number.toEpochFirstSlot();
        if (_isLookaheadRequired(epochFirstSlot)) {
            _postLookahead(epochFirstSlot.nextEpoch(), _lookaheadParams);
        } else {
            // Do not allow non-empty _lookaheadParams that will not be used
            require(_lookaheadParams.length == 0, LookaheadIsNotRequired());
        }
    }

    /// @inheritdoc ILookahead
    function proveIncorrectLookahead(
        uint256 _entryPointer,
        uint256 _slot,
        bytes calldata _validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata _validatorInclusionProof
    )
        external
        nonReentrant
    {
        require(block.number < _slot + disputePeriod, MissedDisputeWindow());

        uint256 epochFirstSlot = _slot.toEpochFirstSlot();
        address poster = getPoster(epochFirstSlot);
        require(poster != address(0), PosterAlreadySlashedOrLookaheadIsEmpty());

        // Validate lookahead pointer
        Entry memory entry = _entryAt(_entryPointer);
        require(_slot > entry.startSlot, InvalidLookaheadPointer());
        require(_slot <= entry.endSlot, InvalidLookaheadPointer());

        // We pull the preconfer present at the required slot timestamp in the lookahead.
        // If no preconfer is present for a slot, we simply use the 0-address to denote the
        // preconfer.
        address preconferInLookahead;

        // checks if a slot is empty (has no dedicated preconfer)
        bool slotHasPreconfer = _slot == entry.endSlot && !entry.isFallback;
        if (slotHasPreconfer) {
            preconferInLookahead = entry.preconfer;
        }

        bytes32 pubKeyHash = _hashBLSPubKey(_validatorBLSPubKey);
        address preconferInRegistry = _preconfRegistry().getPreconferForValidator(pubKeyHash, _slot);

        require(preconferInRegistry != preconferInLookahead, EntryIsCorrect());

        LibEIP4788.verifyValidator(
            _validatorBLSPubKey, getBeaconBlockRoot(_slot), _validatorInclusionProof
        );

        _enableFallbackPreconfer(epochFirstSlot);
        _posterFor(epochFirstSlot).addr = address(0);

        emit IncorrectLookaheadProved(_slot, pubKeyHash, poster, entry);

        // Slash the poster
        _preconfServiceManager().slashOperator(poster);
    }

    /// @inheritdoc ILookahead
    function buildEntryParamsForEpoch(
        uint256 _slot,
        bytes[32] calldata _validatorBLSPubKeys
    )
        external
        view
        returns (EntryParam[] memory params_)
    {
        uint256 count;
        IPreconfRegistry.Validator memory validator;
        params_ = new EntryParam[](32);
        IPreconfRegistry preconfRegister = _preconfRegistry();

        for (uint256 i; i < 32; ++i) {
            uint256 slot = _slot + i;

            // Fetch the validator object from the registry
            validator = preconfRegister.getValidator(_hashBLSPubKey(_validatorBLSPubKeys[i]));

            // Skip deregistered preconfers
            if (preconfRegister.getPreconferIndex(validator.preconfer) == 0) {
                continue;
            }

            // If the validator is allowed to propose in the epoch, add the associated preconfer to
            // the lookahead
            if (
                validator.preconfer != address(0) && slot >= validator.startSlot
                    && (validator.endSlot == 0 || slot < validator.endSlot)
            ) {
                params_[count++] = EntryParam(validator.preconfer, uint40(slot));
            }
        }

        // resize the array
        assembly {
            mstore(params_, count)
        }
    }

    /// @inheritdoc ILookahead
    function isCurrentPreconfer(
        uint256 _entryPointer,
        address _address
    )
        external
        view
        returns (bool)
    {
        Entry memory entry = _entryAt(_entryPointer);
        return _address == entry.preconfer && block.number > entry.startSlot
            && block.timestamp <= entry.endSlot;
    }

    /// @inheritdoc ILookahead
    function getLookaheadForEpoch(uint256 _epochFirstSlot)
        external
        view
        returns (address[32] memory entries_)
    {
        uint256 i = lookaheadTail;
        uint256 lastSlot = _epochFirstSlot.nextEpoch() - 1;

        // Take the tail to the entry that fills the last slot of the epoch.
        // This may be an entry in the next epoch who starts preconfing in advanced.
        // This may also be an empty slot since the lookahead for next epoch is not yet posted.
        while (_entryAt(i).startSlot >= lastSlot) {
            i -= 1;
        }

        Entry memory entry = _entryAt(i);
        address preconfer = entry.preconfer;
        uint256 startSlot = entry.startSlot;
        uint256 endSlot = entry.endSlot;

        // Iterate backwards and fill in the slots
        for (uint256 j = 32; j > 0; --j) {
            if (endSlot >= lastSlot) {
                entries_[j - 1] = preconfer;
            }

            lastSlot -= LibEpoch.SECONDS_IN_SLOT;

            if (lastSlot == startSlot) {
                entry = _entryAt(--i);
                preconfer = entry.preconfer;
                startSlot = entry.startSlot;
            }
        }
    }

    /// @inheritdoc ILookahead
    function getFallbackPreconfer(uint256 _epochFirstSlot)
        public
        view
        validEpochFirstSlot(_epochFirstSlot)
        returns (address)
    {
        return _getFallbackPreconfer(_epochFirstSlot);
    }

    /// @inheritdoc ILookahead
    function getPoster(uint256 _epochFirstSlot)
        public
        view
        validEpochFirstSlot(_epochFirstSlot)
        returns (address)
    {
        Poster memory poster = _posterFor(_epochFirstSlot);
        return poster.slot == _epochFirstSlot ? poster.addr : address(0);
    }

    /// @notice Retrieves the beacon block root for the block at the specified timestamp
    function getBeaconBlockRoot(uint256 _slot) public view returns (bytes32) {
        // At block N, we get the beacon block root for block N - 1. So, to get the block root of
        // the Nth block, we query the root at block N + 1. If N + 1 is a missed slot, we keep
        // querying until we find a block N + x that has the block root for Nth block.
        uint256 targetTimestamp = _slot.slotToTimestamp() + LibEpoch.SECONDS_IN_SLOT;
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
        uint256 _epochFirstSlot,
        EntryParam[] calldata _lookaheadParams
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
        uint40 previousEndSlot = _entryAt(i).endSlot;

        if (_lookaheadParams.length == 0) {
            // If no preconfers are present in the lookahead, we use the fallback preconfer for the
            // entire epoch and, insert it in the last slot of the epoch so that it may start
            // preconfing in advanced
            uint256 endSlot = _epochFirstSlot - 1;
            require(endSlot > previousEndSlot, InvalidAssumption());

            Entry storage entry = _entryAt(++i);
            entry.preconfer = _getFallbackPreconfer(_epochFirstSlot);
            entry.startSlot = previousEndSlot;
            entry.endSlot = uint40(endSlot);
            entry.isFallback = true;
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
                uint40 endSlot = _lookaheadParams[j].endSlot;
                require(endSlot > previousEndSlot, InvalidSlot());
                require(endSlot < _epochFirstSlot.nextEpoch(), InvalidSlot());

                Entry storage entry = _entryAt(++i);
                entry.preconfer = preconfer;
                entry.startSlot = previousEndSlot;
                entry.endSlot = endSlot;
                entry.isFallback = false;
                emit EntryUpdated(i, entry);

                previousEndSlot = endSlot;
            }
        }

        unchecked {
            lookaheadTail = uint64(i);

            Poster storage poster = _posterFor(_epochFirstSlot);
            poster.addr = msg.sender;
            poster.slot = uint40(_epochFirstSlot);

            _preconfServiceManager().lockStakeUntil(msg.sender, block.number + disputePeriod);
        }
    }

    // TODO(dantaik): verify `--i` wont underflow
    function _enableFallbackPreconfer(uint256 _epochFirstSlot) private {
        // If it is the current epoch's lookahead being proved incorrect then insert a fallback
        // preconfer for the next epoch.
        uint256 nextEpochFirstSlot = _epochFirstSlot.nextEpoch();
        if (block.number < nextEpochFirstSlot) return;

        uint256 epochLastSlot = nextEpochFirstSlot - 1;
        uint256 i = lookaheadTail;
        Entry storage entry = _entryAt(i);

        // If the lookahead for next epoch is available
        if (entry.endSlot >= nextEpochFirstSlot) {
            // Get to the first entry that connects to a slot in the current epoch
            while (entry.startSlot >= nextEpochFirstSlot) {
                entry = _entryAt(--i);
            }

            // Switch the connection to the last slot of the current epoch
            entry.startSlot = uint40(epochLastSlot);

            emit EntryUpdated(i, entry);

            // Head to the last entry in current epoch
            entry = _entryAt(--i);
        }

        entry.preconfer = _getFallbackPreconfer(_epochFirstSlot);
        entry.startSlot = uint40(_epochFirstSlot - 1);
        entry.endSlot = uint40(epochLastSlot);
        entry.isFallback = true;
        emit EntryUpdated(i, entry);

        // Nullify the rest of the lookahead entries for this epoch
        for (entry = _entryAt(--i); entry.endSlot >= _epochFirstSlot; entry = _entryAt(--i)) {
            // trick: keep entry.preconfer as-is to avoid setting the storage slot to zeros,
            // which saves gas for the next sstore operation at the same slot
            entry.startSlot = 0;
            entry.endSlot = 0;
            entry.isFallback = false;

            emit EntryUpdated(i, entry);
        }
    }

    function _isLookaheadRequired(uint256 _epochFirstSlot) private view returns (bool) {
        // If it's the first slot of current epoch, we don't need the lookahead since the offchain
        // node may not have access to it yet.
        unchecked {
            return block.number != _epochFirstSlot
                && _posterFor(_epochFirstSlot.nextEpoch()).addr == address(0);
        }
    }

    function _getFallbackPreconfer(uint256 _epochFirstSlot) private view returns (address) {
        IPreconfRegistry preconfRegistry = _preconfRegistry();
        uint256 nextPreconfIndex = preconfRegistry.getNextPreconferIndex();
        require(nextPreconfIndex > 1, NoPreconferAvailable());

        // Use a random number that is constant for a given epoch
        uint256 random = uint256(getBeaconBlockRoot(_epochFirstSlot.prevEpoch()));

        unchecked {
            uint256 preconferIndex = (random % (nextPreconfIndex - 1)) + 1;
            return preconfRegistry.getPreconferAtIndex(preconferIndex);
        }
    }

    function _entryAt(uint256 _entryPointer) private view returns (Entry storage) {
        return lookahead[_entryPointer % lookaheadBufferSize];
    }

    function _posterFor(uint256 _epochFirstSlot) private view returns (Poster storage) {
        return posters[_epochFirstSlot % posterBufferSize];
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
