// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../iface/IPreconfTaskManager.sol";
import "../iface/IPreconfServiceManager.sol";
import "../iface/IPreconfRegistry.sol";
import "./PreconfConstants.sol";

interface ILookaheadManager {
    struct LookaheadBufferEntry {
        // True when the preconfer is randomly selected
        bool isFallback;
        // Timestamp of the slot at which the provided preconfer is the L1 validator
        uint40 timestamp;
        // Timestamp of the last slot that had a valid preconfer
        uint40 prevTimestamp;
        // Address of the preconfer who is also the L1 validator
        // The preconfer will have rights to propose a block in the range (prevTimestamp, timestamp]
        address preconfer;
    }

        struct LookaheadSetParam {
        // The timestamp of the slot
        uint256 timestamp;
        // The AVS operator who is also the L1 validator for the slot and will preconf L2
        // transactions
        address preconfer;
    }

    struct LookaheadMetadata {
        // True if the lookahead was proved to be incorrect
        bool incorrect;
        // The poster of the lookahead
        address poster;
        // Fallback preconfer selected for the epoch in which the lookahead was posted
        // This is only set when the lookahead is proved to be incorrect
        address fallbackPreconfer;
    }

        struct PosterInfo {
        // Address of lookahead poster
        address poster;
        // Start timestamp of the epoch for which the lookahead was posted
        uint64 epochTimestamp;
    }

       event LookaheadUpdated(LookaheadSetParam[]);

    event ProvedIncorrectLookahead(
        address indexed poster, uint256 indexed timestamp, address indexed disputer
    );

}
contract LookaheadManager is ILookaheadManager, Initializable {
    // Cannot be kept in `PreconfConstants` file because solidity expects array sizes
    // to be stored in the main contract file itself.
    uint256 internal constant SLOTS_IN_EPOCH = 32;

    IPreconfServiceManager internal immutable preconfServiceManager;
    IPreconfRegistry internal immutable preconfRegistry;

    // EIP-4788
    uint256 internal immutable beaconGenesis;
    address internal immutable beaconBlockRootContract;

    // A ring buffer of upcoming preconfers (who are also the L1 validators)
    uint256 internal lookaheadTail;
    uint256 internal constant LOOKAHEAD_BUFFER_SIZE = 128;
    mapping(uint256 lookaheadIndex => LookaheadBufferEntry lookaheadBufferEntry) internal lookahead;

    // A ring buffer that maps beginning timestamp of an epoch to the lookahead poster for that
    // epoch
    // If the lookahead poster has been slashed or the lookahead is not yet posted, the poster is
    // the 0-address
    // Stores posters for 16 latest epochs
    uint256 internal constant LOOKAHEAD_POSTER_BUFFER_SIZE = PreconfConstants.SECONDS_IN_EPOCH * 16;
    mapping(uint256 epochTimestamp_mod_LOOKAHEAD_POSTER_BUFFER_SIZE => PosterInfo posterInfo)
        internal lookaheadPosters;

    uint256[47] private __gap; // = 50 - 3


    /// @dev The current (or provided) timestamp does not fall in the range provided by the
    /// lookahead pointer
    error InvalidLookaheadPointer();
    /// @dev The block proposer is not the assigned preconfer for the current slot/timestamp
    error SenderIsNotThePreconfer();
    /// @dev Preconfer is not present in the registry
    error PreconferNotRegistered();
    /// @dev  Epoch timestamp is incorrect
    error InvalidEpochTimestamp();
    /// @dev The timestamp in the lookahead is not of a valid future slot in the present epoch
    error InvalidSlotTimestamp();
    /// @dev The chain id on which the preconfirmation was signed is different from the current
    /// chain's id
    error PreconfirmationChainIdMismatch();
    /// @dev The dispute window for proving incorrectc lookahead or preconfirmation is over
    error MissedDisputeWindow();
    /// @dev The lookahead poster for the epoch has already been slashed or there is no lookahead
    /// for epoch
    error PosterAlreadySlashedOrLookaheadIsEmpty();
    /// @dev The lookahead preconfer matches the one the actual validator is proposing for
    error LookaheadEntryIsCorrect();
    /// @dev Cannot force push a lookahead since it is not lagging behind
    error LookaheadIsNotRequired();
    /// @dev The registry does not have a single registered preconfer
    error NoRegisteredPreconfer();


    constructor(
        IPreconfServiceManager _serviceManager,
        IPreconfRegistry _registry,
        uint256 _beaconGenesis,
        address _beaconBlockRootContract
    ) {
        preconfServiceManager = _serviceManager;
        preconfRegistry = _registry;
        beaconGenesis = _beaconGenesis;
        beaconBlockRootContract = _beaconBlockRootContract;
    }


    /**
     * @notice Proves that the lookahead for a specific slot was incorrect
     * @dev The logic in this function only works once the lookahead slot has passed. This is
     * because
     * we pull the proposer from a past beacon block and verify if it is associated with the
     * preconfer.
     * @param lookaheadPointer The pointer to the lookahead entry that represents the incorrect slot
     * @param slotTimestamp The timestamp of the slot for which the lookahead was incorrect
     * @param validatorBLSPubKey The BLS public key of the validator who is proposed the block in
     * the slot
     * @param validatorInclusionProof The inclusion proof of the above validator in the Beacon state
     */
    function proveIncorrectLookahead(
        uint256 lookaheadPointer,
        uint256 slotTimestamp,
        bytes memory validatorBLSPubKey,
        Lib4788.InclusionProof memory validatorInclusionProof
    )
        external
    {
        uint256 epochTimestamp = _getEpochTimestamp(slotTimestamp);

        address poster = getLookaheadPoster(epochTimestamp);

        // Poster must not have been slashed
        if (poster == address(0)) {
            revert PosterAlreadySlashedOrLookaheadIsEmpty();
        }

        // Must not have missed dispute period
        if (block.timestamp - slotTimestamp > PreconfConstants.DISPUTE_PERIOD) {
            revert MissedDisputeWindow();
        }

        // Verify that the sent validator is the one in Beacon state
        Lib4788.verifyValidator(
            validatorBLSPubKey, _getBeaconBlockRoot(slotTimestamp), validatorInclusionProof
        );

        LookaheadBufferEntry memory lookaheadEntry = _getLookaheadEntry(lookaheadPointer);

        // Validate lookahead pointer
        if (
            slotTimestamp > lookaheadEntry.timestamp
                || slotTimestamp <= lookaheadEntry.prevTimestamp
        ) {
            revert InvalidLookaheadPointer();
        }

        // We pull the preconfer present at the required slot timestamp in the lookahead.
        // If no preconfer is present for a slot, we simply use the 0-address to denote the
        // preconfer.
        address preconferInLookahead;
        if (lookaheadEntry.timestamp == slotTimestamp && !lookaheadEntry.isFallback) {
            // The slot was dedicated to a specific preconfer
            preconferInLookahead = lookaheadEntry.preconfer;
        }

        // Reduce validator's BLS pub key to the pub key hash expected by the registry
        bytes32 validatorPubKeyHash = _getValidatorPubKeyHash(validatorBLSPubKey);

        // Retrieve the validator object
        IPreconfRegistry.Validator memory validatorInRegistry =
            preconfRegistry.getValidator(validatorPubKeyHash);

        // Fetch the preconfer associated with the validator from the registry
        address preconferInRegistry = validatorInRegistry.preconfer;
        if (
            slotTimestamp < validatorInRegistry.startProposingAt
                || (
                    validatorInRegistry.stopProposingAt != 0
                        && slotTimestamp >= validatorInRegistry.stopProposingAt
                )
        ) {
            // The validator is no longer allowed to propose for the former preconfer
            preconferInRegistry = address(0);
        }

        // Revert if the lookahead preconfer matches the one that the validator pulled from beacon
        // state
        // is proposing for
        if (preconferInLookahead == preconferInRegistry) {
            revert LookaheadEntryIsCorrect();
        }

        uint256 epochEndTimestamp = epochTimestamp + PreconfConstants.SECONDS_IN_EPOCH;

        // If it is the current epoch's lookahead being proved incorrect then insert a fallback
        // preconfer
        if (block.timestamp < epochEndTimestamp) {
            uint256 _lookaheadTail = lookaheadTail;

            uint256 lastSlotTimestamp = epochEndTimestamp - PreconfConstants.SECONDS_IN_SLOT;

            // If the lookahead for next epoch is available
            if (_getLookaheadEntry(_lookaheadTail).timestamp >= epochEndTimestamp) {
                // Get to the entry in the next epoch that connects to a slot in the current epoch
                while (_getLookaheadEntry(_lookaheadTail).prevTimestamp >= epochEndTimestamp) {
                    _lookaheadTail -= 1;
                }

                // Switch the connection to the last slot of the current epoch
                lookahead[_lookaheadTail % LOOKAHEAD_BUFFER_SIZE].prevTimestamp =
                    uint40(lastSlotTimestamp);

                // Head to the last entry in current epoch
                _lookaheadTail -= 1;
            }

            _setLookaheadEntry(
                _lookaheadTail,
                LookaheadBufferEntry({
                    isFallback: true,
                    timestamp: uint40(lastSlotTimestamp),
                    prevTimestamp: uint40(epochTimestamp - PreconfConstants.SECONDS_IN_SLOT),
                    preconfer: getFallbackPreconfer(epochTimestamp)
                })
            );

            _lookaheadTail -= 1;

            // Nullify the rest of the lookahead entries for this epoch
            while (_getLookaheadEntry(_lookaheadTail).timestamp >= epochTimestamp) {
                _setLookaheadEntry(
                    _lookaheadTail,
                    LookaheadBufferEntry({
                        isFallback: false,
                        timestamp: 0,
                        prevTimestamp: 0,
                        preconfer: address(0)
                    })
                );
                _lookaheadTail -= 1;
            }
        }

        // Slash the poster
        lookaheadPosters[epochTimestamp % LOOKAHEAD_POSTER_BUFFER_SIZE].poster = address(0);
        preconfServiceManager.slashOperator(poster);

        emit ProvedIncorrectLookahead(poster, slotTimestamp, msg.sender);
    }

    /**
     * @notice Forces the lookahead to be set for the next epoch if it is not already set.
     * @dev This is called once when the system starts up to push the first lookahead, and later
     * anytime
     * when the lookahead is lagging due to missed proposals.
     * @param lookaheadSetParams Collection of timestamps and preconfer addresses to be inserted in
     * the lookahead
     */
    function forcePushLookahead(LookaheadSetParam[] calldata lookaheadSetParams) external {
        // Sender must be a preconfer
        if (preconfRegistry.getPreconferIndex(msg.sender) == 0) {
            revert PreconferNotRegistered();
        }

        // Lookahead must be missing
        uint256 epochTimestamp = _getEpochTimestamp(block.timestamp);
        uint256 nextEpochTimestamp = epochTimestamp + PreconfConstants.SECONDS_IN_EPOCH;
        if (!_isLookaheadRequired(epochTimestamp, nextEpochTimestamp)) {
            revert LookaheadIsNotRequired();
        }

        // Update the lookahead for next epoch
        _updateLookahead(nextEpochTimestamp, lookaheadSetParams);

        // Block the preconfer from withdrawing stake from Eigenlayer during the dispute window
        preconfServiceManager.lockStakeUntil(
            msg.sender, block.timestamp + PreconfConstants.DISPUTE_PERIOD
        );
    }

    //=========
    // Helpers
    //=========

    /// @dev Updates the lookahead for an epoch
    function _updateLookahead(
        uint256 epochTimestamp,
        LookaheadSetParam[] calldata lookaheadSetParams
    )
        private
    {
        uint256 epochEndTimestamp = epochTimestamp + PreconfConstants.SECONDS_IN_EPOCH;

        // The tail of the lookahead is tracked and connected to the first new lookahead entry so
        // that when no more preconfers are present in the remaining slots of the current epoch,
        // the next epoch's preconfer may start preconfing in advanced.
        //
        // --[]--[]--[p1]--[]--[]---|---[]--[]--[P2]--[]--[]
        //   1   2    3    4   5        6    7    8   9   10
        //         Epoch 1                     Epoch 2
        //
        // Here, P2 may start preconfing and proposing blocks from slot 4 itself
        //
        uint256 _lookaheadTail = lookaheadTail;
        uint256 prevSlotTimestamp = _getLookaheadEntry(_lookaheadTail).timestamp;

        if (lookaheadSetParams.length == 0) {
            // If no preconfers are present in the lookahead, we use the fallback preconfer for the
            // entire epoch
            address fallbackPreconfer = getFallbackPreconfer(epochTimestamp);
            _lookaheadTail += 1;

            // and, insert it in the last slot of the epoch so that it may start preconfing in
            // advanced
            _setLookaheadEntry(
                _lookaheadTail,
                LookaheadBufferEntry({
                    isFallback: true,
                    timestamp: uint40(epochEndTimestamp - PreconfConstants.SECONDS_IN_SLOT),
                    prevTimestamp: uint40(prevSlotTimestamp),
                    preconfer: fallbackPreconfer
                })
            );
        } else {
            for (uint256 i; i < lookaheadSetParams.length; ++i) {
                _lookaheadTail += 1;

                address preconfer = lookaheadSetParams[i].preconfer;
                uint256 slotTimestamp = lookaheadSetParams[i].timestamp;

                // Each entry must be registered in the preconf registry
                if (preconfRegistry.getPreconferIndex(preconfer) == 0) {
                    revert PreconferNotRegistered();
                }

                // Ensure that the timestamps belong to a valid slot in the epoch
                if (
                    (slotTimestamp - epochTimestamp) % 12 != 0 || slotTimestamp >= epochEndTimestamp
                        || slotTimestamp <= prevSlotTimestamp
                ) {
                    revert InvalidSlotTimestamp();
                }

                // Update the lookahead entry
                _setLookaheadEntry(
                    _lookaheadTail,
                    LookaheadBufferEntry({
                        isFallback: false,
                        timestamp: uint40(slotTimestamp),
                        prevTimestamp: uint40(prevSlotTimestamp),
                        preconfer: preconfer
                    })
                );
                prevSlotTimestamp = slotTimestamp;
            }
        }

        lookaheadTail = _lookaheadTail;
        lookaheadPosters[epochTimestamp % LOOKAHEAD_POSTER_BUFFER_SIZE] =
            PosterInfo({ poster: msg.sender, epochTimestamp: uint64(epochTimestamp) });

        // We directly use the lookahead set params even in the case of a fallback preconfer to
        // assist the nodes in identifying an incorrect lookahead. The contents of this event can be
        // matched against
        // the output of `getLookaheadParamsForEpoch` to verify the correctness of the lookahead.
        emit LookaheadUpdated(lookaheadSetParams);
    }

    /**
     * @notice Computes the timestamp of the epoch containing the provided slot timestamp
     */
    function _getEpochTimestamp(uint256 slotTimestamp) private view returns (uint256) {
        uint256 timePassedSinceGenesis = slotTimestamp - beaconGenesis;
        uint256 timeToCurrentEpochFromGenesis = (
            timePassedSinceGenesis / PreconfConstants.SECONDS_IN_EPOCH
        ) * PreconfConstants.SECONDS_IN_EPOCH;
        return beaconGenesis + timeToCurrentEpochFromGenesis;
    }

    /**
     * @notice Retrieves the beacon block root for the block at the specified timestamp
     */
    function _getBeaconBlockRoot(uint256 timestamp) private view returns (bytes32) {
        // At block N, we get the beacon block root for block N - 1. So, to get the block root of
        // the Nth block,
        // we query the root at block N + 1. If N + 1 is a missed slot, we keep querying until we
        // find a block N + x
        // that has the block root for Nth block.
        uint256 targetTimestamp = timestamp + PreconfConstants.SECONDS_IN_SLOT;
        while (true) {
            (bool success, bytes memory result) =
                beaconBlockRootContract.staticcall(abi.encode(targetTimestamp));
            if (success && result.length > 0) {
                return abi.decode(result, (bytes32));
            }

            unchecked {
                targetTimestamp += PreconfConstants.SECONDS_IN_SLOT;
            }
        }
        return bytes32(0);
    }

    function _getLookaheadEntry(uint256 index)
        internal
        view
        returns (LookaheadBufferEntry memory)
    {
        return lookahead[index % LOOKAHEAD_BUFFER_SIZE];
    }

    function _setLookaheadEntry(uint256 index, LookaheadBufferEntry memory entry) internal {
        lookahead[index % LOOKAHEAD_BUFFER_SIZE] = entry;
    }

    function _isLookaheadRequired(
        uint256 epochTimestamp,
        uint256 nextEpochTimestamp
    )
        internal
        view
        returns (bool)
    {
        // If it's the first slot of current epoch, we don't need the lookahead since the offchain
        // node may not have access to it yet.
        return block.timestamp != epochTimestamp
            && getLookaheadPoster(nextEpochTimestamp) == address(0);
    }

    /**
     * @dev Assumes that validatorBLSPubKey is 48 bytes long.
     * Puts 16 empty bytes infront to make it equivalent to 48-byte long pub key stored in
     * uint256[2]
     */
    function _getValidatorPubKeyHash(bytes memory validatorBLSPubKey)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(bytes16(0), validatorBLSPubKey));
    }

    function _validateEpochTimestamp(uint256 epochTimestamp) internal view {
        if (
            epochTimestamp < beaconGenesis
                || (epochTimestamp - beaconGenesis) % PreconfConstants.SECONDS_IN_EPOCH != 0
        ) {
            revert InvalidEpochTimestamp();
        }
    }

    //=======
    // Views
    //=======

    /// @dev We use the beacon block root at the first block in the last epoch as randomness to
    ///  decide on the preconfer for the given epoch
    function getFallbackPreconfer(uint256 epochTimestamp) public view returns (address) {
        _validateEpochTimestamp(epochTimestamp);

        uint256 nextPreconferIndex = preconfRegistry.getNextPreconferIndex();

        // Registry must have at least one preconfer
        if (nextPreconferIndex == 1) {
            revert NoRegisteredPreconfer();
        }

        // Start of the last epoch
        uint256 lastEpochTimestamp = epochTimestamp - PreconfConstants.SECONDS_IN_EPOCH;
        uint256 randomness = uint256(_getBeaconBlockRoot(lastEpochTimestamp));
        uint256 preconferIndex = randomness % (nextPreconferIndex - 1) + 1;

        return preconfRegistry.getPreconferAtIndex(preconferIndex);
    }

    /**
     * @notice Returns the full 32 slot preconfer lookahead for the epoch
     * @dev This function has been added as a helper for the node to get the full 32 slot lookahead
     * without
     * the need of deconstructing the contract storage. Due to the fact that we are deconstructing
     * an efficient
     * data structure to fill in all the slots, this is very heavy on gas, and onchain calls to it
     * should be avoided.
     * @param epochTimestamp The start timestamp of the epoch for which the lookahead is to be
     * generated
     */
    function getLookaheadForEpoch(uint256 epochTimestamp)
        external
        view
        returns (address[SLOTS_IN_EPOCH] memory)
    {
        _validateEpochTimestamp(epochTimestamp);

        address[SLOTS_IN_EPOCH] memory lookaheadForEpoch;

        uint256 _lookaheadTail = lookaheadTail;
        uint256 lastSlotTimestamp =
            epochTimestamp + PreconfConstants.SECONDS_IN_EPOCH - PreconfConstants.SECONDS_IN_SLOT;

        // Take the tail to the entry that fills the last slot of the epoch.
        // This may be an entry in the next epoch who starts preconfing in advanced.
        // This may also be an empty slot since the lookahead for next epoch is not yet posted.
        while (_getLookaheadEntry(_lookaheadTail).prevTimestamp >= lastSlotTimestamp) {
            _lookaheadTail -= 1;
        }

        LookaheadBufferEntry memory _entry = _getLookaheadEntry(_lookaheadTail);

        // Iterate backwards and fill in the slots
        for (uint256 i = SLOTS_IN_EPOCH; i > 0; --i) {
            if (_entry.timestamp >= lastSlotTimestamp) {
                lookaheadForEpoch[i - 1] = _entry.preconfer;
            }

            lastSlotTimestamp -= PreconfConstants.SECONDS_IN_SLOT;
            if (lastSlotTimestamp == _entry.prevTimestamp) {
                _lookaheadTail -= 1;
                // Reuse the memory space of _entry
                _entry.preconfer = _getLookaheadEntry(_lookaheadTail).preconfer;
                _entry.prevTimestamp = _getLookaheadEntry(_lookaheadTail).prevTimestamp;
            }
        }

        return lookaheadForEpoch;
    }

    /**
     * @notice Builds and returns lookahead set parameters for an epoch
     * @dev This function can be used by the offchain node to create the lookahead to be posted.
     * @param epochTimestamp The start timestamp of the epoch for which the lookahead is to be
     * generated
     * @param validatorBLSPubKeys The BLS public keys of the validators who are expected to propose
     * in the epoch
     * in the same sequence as they appear in the epoch. So at index n - 1, we have the validator
     * for slot n in that
     * epoch.
     */
    function getLookaheadParamsForEpoch(
        uint256 epochTimestamp,
        bytes[SLOTS_IN_EPOCH] memory validatorBLSPubKeys
    )
        external
        view
        returns (LookaheadSetParam[] memory)
    {
        _validateEpochTimestamp(epochTimestamp);

        uint256 index;
        LookaheadSetParam[32] memory lookaheadSetParamsTemp;

        for (uint256 i = 0; i < 32; ++i) {
            uint256 slotTimestamp = epochTimestamp + (i * PreconfConstants.SECONDS_IN_SLOT);

            // Fetch the validator object from the registry
            IPreconfRegistry.Validator memory validator =
                preconfRegistry.getValidator(_getValidatorPubKeyHash(validatorBLSPubKeys[i]));

            // Skip deregistered preconfers
            if (preconfRegistry.getPreconferIndex(validator.preconfer) == 0) {
                continue;
            }

            // If the validator is allowed to propose in the epoch, add the associated preconfer to
            // the lookahead
            if (
                validator.preconfer != address(0) && slotTimestamp >= validator.startProposingAt
                    && (validator.stopProposingAt == 0 || slotTimestamp < validator.stopProposingAt)
            ) {
                lookaheadSetParamsTemp[index] =
                    LookaheadSetParam({ timestamp: slotTimestamp, preconfer: validator.preconfer });
                ++index;
            }
        }

        // Not very gas efficient, but is okay for a view expected to be used offchain
        LookaheadSetParam[] memory lookaheadSetParams = new LookaheadSetParam[](index);
        for (uint256 i; i < index; ++i) {
            lookaheadSetParams[i] = lookaheadSetParamsTemp[i];
        }

        return lookaheadSetParams;
    }

    /// @dev Returns true if the contract is expecting a lookahead for the next epoch
    function isLookaheadRequired() external view returns (bool) {
        uint256 epochTimestamp = _getEpochTimestamp(block.timestamp);
        uint256 nextEpochTimestamp = epochTimestamp + PreconfConstants.SECONDS_IN_EPOCH;
        return _isLookaheadRequired(epochTimestamp, nextEpochTimestamp);
    }

    function getLookaheadBuffer()
        external
        view
        returns (LookaheadBufferEntry[LOOKAHEAD_BUFFER_SIZE] memory)
    {
        LookaheadBufferEntry[LOOKAHEAD_BUFFER_SIZE] memory _lookahead;
        for (uint256 i; i < LOOKAHEAD_BUFFER_SIZE; ++i) {
            _lookahead[i] = lookahead[i];
        }
        return _lookahead;
    }

    function getLookaheadPoster(uint256 epochTimestamp) public view returns (address) {
        _validateEpochTimestamp(epochTimestamp);
        PosterInfo memory posterInfo =
            lookaheadPosters[epochTimestamp % LOOKAHEAD_POSTER_BUFFER_SIZE];
        return posterInfo.epochTimestamp == epochTimestamp ? posterInfo.poster : address(0);
    }
}
