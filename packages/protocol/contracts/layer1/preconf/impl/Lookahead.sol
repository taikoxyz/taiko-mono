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
    uint256 public immutable beaconGenesisTimestamp;
    uint256 public immutable disputePeriod;
    uint256 public immutable posterBufferSize;
    uint256 public immutable lookaheadBufferSize;

    struct Poster {
        address addr;
        uint40 epochTimestamp;
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
    error InvalidEpochTimestamp();
    error InvalidLookaheadPointer();
    error InvalidParam();
    error InvalidSlotTimestamp();
    error EntryIsCorrect();
    error LookaheadIsNotRequired();
    error MissedDisputeWindow();
    error NoPreconferAvailable();
    error PosterAlreadySlashedOrLookaheadIsEmpty();
    error PreconferNotRegistered();
    error SenderIsNotThePreconfer();

    modifier validEpochTimestamp(uint256 _epochTimestamp) {
        require(_epochTimestamp >= beaconGenesisTimestamp, InvalidEpochTimestamp());
        require(_epochTimestamp % LibEpoch.SECONDS_IN_EPOCH == 0, InvalidEpochTimestamp());
        _;
    }

    modifier onlyPreconfer() {
        uint256 preconferIndex = _preconfRegistry().getPreconferIndex(msg.sender);
        require(preconferIndex != 0, PreconferNotRegistered());
        _;
    }

    constructor(
        address _beaconBlockRootContract,
        uint256 _beaconGenesisTimestamp,
        uint256 _disputePeriod,
        uint256 _posterBufferSize,
        uint256 _lookaheadBufferSize
    ) {
        require(_beaconBlockRootContract != address(0), InvalidParam());
        require(_beaconGenesisTimestamp % LibEpoch.SECONDS_IN_SLOT == 0, InvalidParam());
        require(_disputePeriod != 0, InvalidParam());
        require(_posterBufferSize != 0, InvalidParam());
        require(_posterBufferSize % LibEpoch.SLOTS_IN_EPOCH == 0, InvalidParam());
        require(_lookaheadBufferSize != 0, InvalidParam());
        require(_lookaheadBufferSize % LibEpoch.SLOTS_IN_EPOCH == 0, InvalidParam());

        beaconBlockRootContract = _beaconBlockRootContract;
        beaconGenesisTimestamp = _beaconGenesisTimestamp;
        disputePeriod = _disputePeriod;
        posterBufferSize = _posterBufferSize;
        lookaheadBufferSize = _lookaheadBufferSize;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _preconfAddressManager) external initializer {
        __Essential_init(_owner, _preconfAddressManager);
    }

    /// @inheritdoc ILookahead
    function forcePostLookahead(EntryParam[] calldata _lookaheadParams)
        external
        onlyPreconfer
        nonReentrant
    {
        uint256 epochTimestamp = _toEpochTimestamp(block.timestamp);
        require(_isLookaheadRequired(epochTimestamp), LookaheadIsNotRequired());

        _postLookahead(epochTimestamp.nextEpoch(), _lookaheadParams);
    }

    /// @inheritdoc ILookahead
    function postLookahead(EntryParam[] calldata _lookaheadParams)
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
        uint256 _entryPointer,
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
        address poster = getPoster(epochTimestamp);
        require(poster != address(0), PosterAlreadySlashedOrLookaheadIsEmpty());

        // Validate lookahead pointer
        Entry memory entry = _entryAt(_entryPointer);
        require(_slotTimestamp > entry.validSince, InvalidLookaheadPointer());
        require(_slotTimestamp <= entry.validUntil, InvalidLookaheadPointer());

        // We pull the preconfer present at the required slot timestamp in the lookahead.
        // If no preconfer is present for a slot, we simply use the 0-address to denote the
        // preconfer.
        address preconferInLookahead;

        // checks if a slot is empty (has no dedicated preconfer)
        bool slotHasPreconfer = _slotTimestamp == entry.validUntil && !entry.isFallback;
        if (slotHasPreconfer) {
            preconferInLookahead = entry.preconfer;
        }

        bytes32 pubKeyHash = _hashBLSPubKey(_validatorBLSPubKey);
        address preconferInRegistry =
            _preconfRegistry().getPreconferForValidator(pubKeyHash, _slotTimestamp);

        require(preconferInRegistry != preconferInLookahead, EntryIsCorrect());

        LibEIP4788.verifyValidator(
            _validatorBLSPubKey, getBeaconBlockRoot(_slotTimestamp), _validatorInclusionProof
        );

        _enableFallbackPreconfer(epochTimestamp);
        _posterFor(epochTimestamp).addr = address(0);

        emit IncorrectLookaheadProved(_slotTimestamp, pubKeyHash, poster, entry);

        // Slash the poster
        _preconfServiceManager().slashOperator(poster);
    }

    /// @inheritdoc ILookahead
    function buildEntryParamsForEpoch(
        uint256 _epochTimestamp,
        bytes[32] calldata _validatorBLSPubKeys
    )
        external
        view
        validEpochTimestamp(_epochTimestamp)
        returns (EntryParam[] memory params_)
    {
        uint256 count;
        IPreconfRegistry.Validator memory validator;
        params_ = new EntryParam[](32);
        IPreconfRegistry preconfRegister = _preconfRegistry();

        for (uint256 i; i < 32; ++i) {
            uint256 slotTimestamp = _epochTimestamp + (i * LibEpoch.SECONDS_IN_SLOT);

            // Fetch the validator object from the registry
            validator = preconfRegister.getValidator(_hashBLSPubKey(_validatorBLSPubKeys[i]));

            // Skip deregistered preconfers
            if (preconfRegister.getPreconferIndex(validator.preconfer) == 0) {
                continue;
            }

            // If the validator is allowed to propose in the epoch, add the associated preconfer to
            // the lookahead
            if (
                validator.preconfer != address(0) && slotTimestamp >= validator.validSince
                    && (validator.validUntil == 0 || slotTimestamp < validator.validUntil)
            ) {
                params_[count++] = EntryParam(validator.preconfer, uint40(slotTimestamp));
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
        return _address == entry.preconfer && block.timestamp > entry.validSince
            && block.timestamp <= entry.validUntil;
    }

    /// @inheritdoc ILookahead
    function getLookaheadForEpoch(uint256 _epochTimestamp)
        external
        view
        validEpochTimestamp(_epochTimestamp)
        returns (address[32] memory entries_)
    {
        uint256 i = lookaheadTail;
        uint256 lastSlotTimestamp = _epochTimestamp.nextEpoch() - LibEpoch.SECONDS_IN_SLOT;

        // Take the tail to the entry that fills the last slot of the epoch.
        // This may be an entry in the next epoch who starts preconfing in advanced.
        // This may also be an empty slot since the lookahead for next epoch is not yet posted.
        while (_entryAt(i).validSince >= lastSlotTimestamp) {
            i -= 1;
        }

        Entry memory entry = _entryAt(i);
        address preconfer = entry.preconfer;
        uint256 validSince = entry.validSince;
        uint256 validUntil = entry.validUntil;

        // Iterate backwards and fill in the slots
        for (uint256 j = 32; j > 0; --j) {
            if (validUntil >= lastSlotTimestamp) {
                entries_[j - 1] = preconfer;
            }

            lastSlotTimestamp -= LibEpoch.SECONDS_IN_SLOT;

            if (lastSlotTimestamp == validSince) {
                entry = _entryAt(--i);
                preconfer = entry.preconfer;
                validSince = entry.validSince;
            }
        }
    }

    /// @inheritdoc ILookahead
    function getFallbackPreconfer(uint256 _epochTimestamp)
        external
        view
        validEpochTimestamp(_epochTimestamp)
        returns (address)
    {
        return _getFallbackPreconfer(_epochTimestamp);
    }

    /// @inheritdoc ILookahead
    function getPoster(uint256 _epochTimestamp) public view returns (address) {
        Poster memory poster = _posterFor(_epochTimestamp);
        return poster.epochTimestamp == _epochTimestamp ? poster.addr : address(0);
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
        uint40 previousValidUntil = _entryAt(i).validUntil;

        if (_lookaheadParams.length == 0) {
            // If no preconfers are present in the lookahead, we use the fallback preconfer for the
            // entire epoch and, insert it in the last slot of the epoch so that it may start
            // preconfing in advanced
            uint256 validUntil = _epochTimestamp - LibEpoch.SECONDS_IN_SLOT;
            require(validUntil > previousValidUntil, InvalidAssumption());

            Entry storage entry = _entryAt(++i);
            entry.preconfer = _getFallbackPreconfer(_epochTimestamp);
            entry.validSince = previousValidUntil;
            entry.validUntil = uint40(validUntil);
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
                uint40 validUntil = _lookaheadParams[j].validUntil;
                require(validUntil % LibEpoch.SECONDS_IN_SLOT == 0, InvalidSlotTimestamp());
                require(validUntil > previousValidUntil, InvalidSlotTimestamp());
                require(validUntil < _epochTimestamp.nextEpoch(), InvalidSlotTimestamp());

                Entry storage entry = _entryAt(++i);
                entry.preconfer = preconfer;
                entry.validSince = previousValidUntil;
                entry.validUntil = validUntil;
                entry.isFallback = false;
                emit EntryUpdated(i, entry);

                previousValidUntil = validUntil;
            }
        }

        unchecked {
            lookaheadTail = uint64(i);

            Poster storage poster = _posterFor(_epochTimestamp);
            poster.addr = msg.sender;
            poster.epochTimestamp = uint40(_epochTimestamp);

            _preconfServiceManager().lockStakeUntil(msg.sender, block.timestamp + disputePeriod);
        }
    }

    // TODO(dantaik): verify `--i` wont underflow
    function _enableFallbackPreconfer(uint256 _epochTimestamp) private {
        // If it is the current epoch's lookahead being proved incorrect then insert a fallback
        // preconfer for the next epoch.
        uint256 nextEpochTimestamp = _epochTimestamp.nextEpoch();
        if (block.timestamp < nextEpochTimestamp) return;

        uint256 lastSlotTimestampInCurrentEpoch = nextEpochTimestamp - LibEpoch.SECONDS_IN_SLOT;
        uint256 i = lookaheadTail;
        Entry storage entry = _entryAt(i);

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

        entry.preconfer = _getFallbackPreconfer(_epochTimestamp);
        entry.validSince = uint40(_epochTimestamp - LibEpoch.SECONDS_IN_SLOT);
        entry.validUntil = uint40(lastSlotTimestampInCurrentEpoch);
        entry.isFallback = true;
        emit EntryUpdated(i, entry);

        // Nullify the rest of the lookahead entries for this epoch
        for (entry = _entryAt(--i); entry.validUntil >= _epochTimestamp; entry = _entryAt(--i)) {
            // trick: keep entry.preconfer as-is to avoid setting the storage slot to zeros,
            // which saves gas for the next sstore operation at the same slot
            entry.validSince = 0;
            entry.validUntil = 0;
            entry.isFallback = false;

            emit EntryUpdated(i, entry);
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

    function _getFallbackPreconfer(uint256 _epochTimestamp) private view returns (address) {
        IPreconfRegistry preconfRegistry = _preconfRegistry();
        uint256 nextPreconfIndex = preconfRegistry.getNextPreconferIndex();
        require(nextPreconfIndex > 1, NoPreconferAvailable());

        // Use a random number that is constant for a given epoch
        uint256 random = uint256(getBeaconBlockRoot(_epochTimestamp.prevEpoch()));

        unchecked {
            uint256 preconferIndex = (random % (nextPreconfIndex - 1)) + 1;
            return preconfRegistry.getPreconferAtIndex(preconferIndex);
        }
    }

    function _entryAt(uint256 _entryPointer) private view returns (Entry storage) {
        return lookahead[_entryPointer % lookaheadBufferSize];
    }

    function _posterFor(uint256 _epochTimestamp) private view returns (Poster storage) {
        return posters[_epochTimestamp % posterBufferSize];
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
