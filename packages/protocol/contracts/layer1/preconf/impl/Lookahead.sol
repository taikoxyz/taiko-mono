// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/ILookahead.sol";
import "../iface/IPreconfRegistry.sol";
import "../iface/IPreconfServiceManager.sol";
import "../libs/LibNames.sol";
import "../libs/LibEpoch.sol";
import "../libs/LibEIP4788.sol";

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
    mapping(uint256 epochTimestamp => Poster poster) internal posters;

    // Mapping from a pointer (representing a specific epoch timestamp) to a LookaheadEntry.
    // This stores the lookahead information for each epoch, allowing for efficient access and updates.
    mapping(uint256 pointer => LookaheadEntry) internal lookahead;
    
    // Pointer to the last entry in the lookahead mapping
    uint64 public lookaheadTail;

    uint256[47] private __gap;

    event EntryUpdated(uint256 indexed id, LookaheadEntry entry);

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
        // Lookahead must be missing
        require(_isLookaheadRequired(epochTimestamp), LookaheadIsNotRequired());
        _postLookahead(epochTimestamp.nextEpoch(), _lookaheadParams);
    }

    /// @inheritdoc ILookahead
    function postLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromNamed(LibNames.B_PRECONF_SERVICE_MANAGER)
        nonReentrant
    {
        uint256 epochTimestamp = _toEpochTimestamp(block.timestamp);
        if (_isLookaheadRequired(epochTimestamp)) {
            _postLookahead(epochTimestamp.nextEpoch(), _lookaheadParams);
        } else {
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
    {
        require(_slotTimestamp % LibEpoch.SECONDS_IN_SLOT == 0, InvalidSlotTimestamp());    
        require(block.timestamp < _slotTimestamp + disputePeriod, MissedDisputeWindow());

        uint256 epochTimestamp = _toEpochTimestamp(_slotTimestamp);
        Poster memory poster = _posterFor(epochTimestamp);
        require(poster.addr != address(0), PosterAlreadySlashedOrLookaheadIsEmpty());

        // Validate lookahead pointer
        LookaheadEntry memory entry = _entry(_lookaheadPointer);
        require(_slotTimestamp > entry.validSince, InvalidLookaheadPointer());
        require(_slotTimestamp <= entry.validUntil, InvalidLookaheadPointer());

        // We pull the preconfer present at the required slot timestamp in the lookahead.
        // If no preconfer is present for a slot, we simply use the 0-address to denote the
        // preconfer.
        address preconferInLookahead;

        // TODO? Fiture out the following logic
        if (_slotTimestamp == entry.validUntil && !entry.isFallback) {
            // The slot was dedicated to a specific preconfer
            preconferInLookahead = entry.preconfer;
        }

        address preconferInRegistry = _preconfRegistry().getPreconferForValidator(
            _hashBLSPubKey(_validatorBLSPubKey), _slotTimestamp
        );

        require(preconferInRegistry != preconferInLookahead, LookaheadEntryIsCorrect());

        LibEIP4788.verifyValidator(
            _validatorBLSPubKey, _getBeaconBlockRoot(_slotTimestamp), _validatorInclusionProof
        );

        _enableFallbackPreconfer(epochTimestamp);

        // Slash the poster
        _posterFor(epochTimestamp).addr = address(0);
        _preconfServiceManager().slashOperator(poster.addr);
    }

    /// @inheritdoc ILookahead
    function isCurrentPreconfer(address addr) external view returns (bool) {
        //
    }

    function getPoster(uint256 _epochTimestamp) public view returns (address) { }

    /// @dev Returns the fallback preconfer
    function getFallbackPreconfer() public view returns (address) {
        IPreconfRegistry preconfRegistry =
            IPreconfRegistry(resolve(LibNames.B_PRECONF_REGISTRY, false));

        uint256 nextPreconfIndex = preconfRegistry.getNextPreconferIndex();
        require(nextPreconfIndex > 1, NoPreconferAvailable());

        unchecked {
            uint256 preconferIndex = (block.prevrandao % (nextPreconfIndex - 1)) + 1;
            return preconfRegistry.getPreconferAtIndex(preconferIndex);
        }
    }

    function _postLookahead(
        uint256 _epochTimestamp,
        LookaheadParam[] calldata _lookaheadParams
    )
        internal
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
        uint40 previousValidUntil = _entry(i).validUntil;

        if (_lookaheadParams.length == 0) {
            // If no preconfers are present in the lookahead, we use the fallback preconfer for the
            // entire epoch and, insert it in the last slot of the epoch so that it may start
            // preconfing in advanced
            uint256 validUntil = _epochTimestamp - LibEpoch.SECONDS_IN_SLOT;
            require(validUntil > previousValidUntil, InvalidAssumption());

            LookaheadEntry storage entry = _entry(++i);
            entry.isFallback = true;
            entry.validSince = previousValidUntil;
            entry.validUntil = uint40(validUntil);
            entry.preconfer = getFallbackPreconfer();
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

                LookaheadEntry storage entry = _entry(++i);
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

    /// @notice Retrieves the beacon block root for the block at the specified timestamp
    function _getBeaconBlockRoot(uint256 timestamp) private view returns (bytes32) {
        // At block N, we get the beacon block root for block N - 1. So, to get the block root of
        // the Nth block,
        // we query the root at block N + 1. If N + 1 is a missed slot, we keep querying until we
        // find a block N + x
        // that has the block root for Nth block.
        uint256 targetTimestamp = timestamp + LibEpoch.SECONDS_IN_SLOT;
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

    function _isLookaheadRequired(uint256 _epochTimestamp) private view returns (bool) {
        // If it's the first slot of current epoch, we don't need the lookahead since the offchain
        // node may not have access to it yet.
        unchecked {
            return block.timestamp != _epochTimestamp
                && _posterFor(_epochTimestamp.nextEpoch()).addr == address(0);
        }
    }

    function _entry(uint256 _pointer) private view returns (LookaheadEntry storage) {
        return lookahead[_pointer]; // TODO
    }

    function _posterFor(uint256 _epochTimestamp) private view returns (Poster storage) {
        return posters[_epochTimestamp];
    }

    // TODO: verify `--i` wont underflow
    function _enableFallbackPreconfer(uint256 _epochTimestamp) private {
        // If it is the current epoch's lookahead being proved incorrect then insert a fallback
        // preconfer for the next epoch.
        uint256 nextEpochTimestamp = _epochTimestamp.nextEpoch();
        if (block.timestamp < nextEpochTimestamp) return;

        unchecked {
            uint256 lastSlotTimestampInCurrentEpoch = nextEpochTimestamp - LibEpoch.SECONDS_IN_SLOT;
            uint256 i = lookaheadTail;
            LookaheadEntry storage entry = _entry(i);

            // If the lookahead for next epoch is available
            if (entry.validUntil >= nextEpochTimestamp) {
                // Get to the first entry that connects to a slot in the current epoch
                while (entry.validSince >= nextEpochTimestamp) {
                    entry = _entry(--i);
                }

                // Switch the connection to the last slot of the current epoch
                entry.validSince = uint40(lastSlotTimestampInCurrentEpoch);

                emit EntryUpdated(i, entry);

                // Head to the last entry in current epoch
                entry = _entry(--i);
            }

            entry.isFallback = true;
            entry.validSince = uint40(_epochTimestamp - LibEpoch.SECONDS_IN_SLOT);
            entry.validUntil = uint40(lastSlotTimestampInCurrentEpoch);
            entry.preconfer = getFallbackPreconfer();

            emit EntryUpdated(i, entry);

            // Nullify the rest of the lookahead entries for this epoch
            for (entry = _entry(--i); entry.validUntil >= _epochTimestamp; entry = _entry(--i)) {
                // trick: keep entry.preconfer as-is to avoid setting the storage slot to zeros,
                // which saves gas for the next sstore operation at the same slot
                entry.isFallback = false;
                entry.validSince = 0;
                entry.validUntil = 0;

                emit EntryUpdated(i, entry);
            }
        }
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

    function _toEpochTimestamp(uint256 _timestamp) private view returns (uint256) {
        return LibEpoch.toEpochTimestamp(_timestamp, beaconGenesisTimestamp);
    }
}
