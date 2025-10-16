// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import { LibLookaheadEncoder as Encoder } from "src/layer1/preconf/libs/LibLookaheadEncoder.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { IPreconfWhitelist } from "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import { IBlacklist, Blacklist } from "src/layer1/preconf/impl/Blacklist.sol";
import { IProposerChecker } from "src/layer1/shasta/iface/IProposerChecker.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, IProposerChecker, Blacklist, EssentialContract {
    address public immutable inbox;
    address public immutable unifiedSlasher;
    address public immutable preconfWhitelist;

    uint256 public constant LOOKAHEAD_BUFFER_SIZE = 503;

    // Lookahead buffer that stores the hashed lookahead entries for an epoch
    mapping(uint256 epochTimestamp_mod_lookaheadBufferSize => LookaheadHash lookaheadHash) public
        lookahead;

    uint256[49] private __gap;

    constructor(address _inbox, address _unifiedSlasher, address _preconfWhitelist) {
        inbox = _inbox;
        unifiedSlasher = _unifiedSlasher;
        preconfWhitelist = _preconfWhitelist;
    }

    function init(address _owner, address[] memory _overseers) external initializer {
        __Essential_init(_owner);
        __Blacklist_init(_overseers);
    }

    /// @inheritdoc IProposerChecker
    /// @dev Checks if a proposer is eligible to propose for the current slot and conditionally
    /// updates the lookahead for the next epoch.
    /// @dev IMPORTANT: The first preconfer of each epoch must submit the lookahead for the next
    /// epoch. The contract enforces this by trying to update the lookahead for next epoch if none
    /// is stored.
    function checkProposer(address _proposer, bytes calldata _lookaheadData)
        external
        returns (uint48)
    {
        // Must only be called the inbox
        // The inbox should set `_proposer` to the current L2 batch proposer's address
        require(msg.sender == inbox, NotInbox());

        LookaheadData memory data = abi.decode(_lookaheadData, (LookaheadData));

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Determine the proposer context from supplied evidence
        ProposerContext memory context =
            _determineProposerContext(data, epochTimestamp, nextEpochTimestamp);

        // Verify that the sender is the expected proposer
        require(_proposer == context.proposer, ProposerIsNotPreconfer());

        // Verify that the proposer is in the preconfing window
        require(
            block.timestamp >= context.submissionWindowStart
                && block.timestamp <= context.submissionWindowEnd,
            InvalidLookaheadTimestamp()
        );

        // Validate the current lookahead evidence
        _validateCurrentEpochLookahead(epochTimestamp, data.currLookahead);

        // Validate the next lookahead evidence and update the store if required
        _handleNextEpochLookahead(epochTimestamp, nextEpochTimestamp, context, data);

        return uint48(context.submissionWindowEnd);
    }

    // Blacklist functions
    // --------------------------------------------------------------------------

    /// @inheritdoc IBlacklist
    function addOverseers(address[] calldata _overseers) external override onlyOwner {
        for (uint256 i = 0; i < _overseers.length; ++i) {
            address overseer = _overseers[i];
            require(!overseers[overseer], OverseerAlreadyExists());
            overseers[overseer] = true;
        }
        emit OverseersAdded(_overseers);
    }

    /// @inheritdoc IBlacklist
    function removeOverseers(address[] calldata _overseers) external override onlyOwner {
        for (uint256 i = 0; i < _overseers.length; ++i) {
            address overseer = _overseers[i];
            require(overseers[overseer], OverseerDoesNotExist());
            overseers[overseer] = false;
        }
        emit OverseersRemoved(_overseers);
    }

    // View and Pure functions
    // --------------------------------------------------------------------

    /// @inheritdoc ILookaheadStore
    function getProposerContext(LookaheadData memory _data, uint256 _epochTimestamp)
        external
        view
        returns (ProposerContext memory context_)
    {
        uint256 nextEpochTimestamp = _epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
        context_ = _determineProposerContext(_data, _epochTimestamp, nextEpochTimestamp);
    }

    /// @inheritdoc ILookaheadStore
    function calculateLookaheadHash(uint256 _epochTimestamp, bytes memory _encodedLookahead)
        external
        pure
        returns (bytes26)
    {
        return LibPreconfUtils.calculateLookaheadHash(_epochTimestamp, _encodedLookahead);
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() external view returns (bool) {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp(0);
        if (block.timestamp == epochTimestamp) {
            // Lookahead for the next epoch is not required to be posted in the first slot
            // of the current epoch because the offchain node may not have sufficient time
            // to build the lookahead.
            return false;
        }
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
        return _getLookaheadHash(nextEpochTimestamp).epochTimestamp != nextEpochTimestamp;
    }

    /// @inheritdoc ILookaheadStore
    function getLookaheadHash(uint256 _epochTimestamp) public view returns (bytes26 hash_) {
        LookaheadHash memory lookaheadHash = _getLookaheadHash(_epochTimestamp);
        if (lookaheadHash.epochTimestamp == _epochTimestamp) {
            hash_ = lookaheadHash.lookaheadHash;
        }
    }

    // Internal functions
    // --------------------------------------------------------------------

    /// @dev Determines the proposer's slot and submission window based on lookahead state.
    /// Handles empty lookahead, cross-epoch, and same-epoch scenarios.
    function _determineProposerContext(
        LookaheadData memory _data,
        uint256 _epochTimestamp,
        uint256 _nextEpochTimestamp
    )
        private
        view
        returns (ProposerContext memory context_)
    {
        if (_data.currLookahead.length == 0) {
            context_ = _handleEmptyCurrentLookahead(_epochTimestamp, _nextEpochTimestamp);
        } else if (_data.slotIndex == type(uint256).max) {
            context_ = _handleCrossEpochProposer(_data, _nextEpochTimestamp);
        } else {
            context_ = _handleSameEpochProposer(_data, _epochTimestamp);
        }

        // Use fallback preconfer if no opted-in slot, otherwise use lookahead committer
        // All operators are validated when lookahead is posted, so no need to re-validate
        if (context_.isFallback) {
            context_.proposer = IPreconfWhitelist(preconfWhitelist).getOperatorForCurrentEpoch();
        } else {
            if (isOperatorBlacklisted(context_.lookaheadSlot.registrationRoot)) {
                context_.isFallback = true;
                context_.proposer = IPreconfWhitelist(preconfWhitelist).getOperatorForCurrentEpoch();
                if (_data.slotIndex == type(uint256).max) {
                    // For a cross epoch proposal, the current epoch's preconfer must submit by the
                    // end of the current epoch.
                    context_.submissionWindowEnd =
                        _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
                }
            } else {
                context_.proposer = context_.lookaheadSlot.committer;
            }
        }
    }

    /// @dev Returns proposer context for when current epoch has no lookahead (fallback preconfer).
    function _handleEmptyCurrentLookahead(uint256 _epochTimestamp, uint256 _nextEpochTimestamp)
        private
        pure
        returns (ProposerContext memory context_)
    {
        context_.isFallback = true;
        context_.submissionWindowStart = _epochTimestamp;
        context_.submissionWindowEnd = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
    }

    /// @dev Returns proposer context for when no more opted in preconfers are remaining for the
    /// current epoch.
    function _handleCrossEpochProposer(LookaheadData memory _data, uint256 _nextEpochTimestamp)
        private
        pure
        returns (ProposerContext memory context_)
    {
        LookaheadSlot memory lastSlot =
            Encoder.decodeIndex(_data.currLookahead, Encoder.numSlots(_data.currLookahead) - 1);
        context_.submissionWindowStart = lastSlot.timestamp - LibPreconfConstants.SECONDS_IN_SLOT;

        if (_data.nextLookahead.length == 0) {
            // This is the case when the next lookahead is empty
            // Eg: [x x x Pa y y y] [     empty    ]
            //     [  curr epoch  ] [  next epoch  ]
            //
            // The empty slots y will be taken over by the fallback preconfer
            // for the current epoch.
            // The upper boundary of the preconfing period is the last slot of the
            // current epoch.
            //
            context_.isFallback = true;
            context_.submissionWindowEnd = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        } else {
            // This is the case when the first preconfer from the next epoch is proposing in
            // advanced in the current epoch.
            //
            // Eg: [x x x Pa y y y] [z z z Pb v v v]
            //     [  curr epoch  ] [  next epoch  ]
            // - Pb is our preconfer.
            // - x, y, z and v represent empty slots with no opted in preconfer.
            // - Pb intends to propose at any slot y
            //
            LookaheadSlot memory proposerSlot = Encoder.decodeIndex(_data.nextLookahead, 0);
            context_.isFallback = false;
            context_.submissionWindowEnd = proposerSlot.timestamp;
            context_.lookaheadSlot = proposerSlot;
        }
    }

    /// @dev This handles the case when the preconfer is proposing in the same epoch in which
    /// it has its lookahead slot.
    ///
    /// Eg: [x x x Pa y y y]
    ///     [  curr epoch  ]
    /// - Pa is our preconfer.
    /// - x and y represent empty slots with no opted in preconfer.
    /// - Pa intends to propose at any slot x
    ///
    /// OR
    ///
    /// Eg: [x x x Pa y y y Pb z z z]
    ///     [      curr epoch       ]
    /// - Pb is our preconfer.
    /// - x, y and z represent empty slots with no opted in preconfer.
    /// - Pb intends to propose at any slot y
    function _handleSameEpochProposer(LookaheadData memory _data, uint256 _epochTimestamp)
        private
        pure
        returns (ProposerContext memory context_)
    {
        LookaheadSlot memory proposerSlot =
            Encoder.decodeIndex(_data.currLookahead, _data.slotIndex);

        context_.isFallback = false;
        context_.lookaheadSlot = proposerSlot;
        context_.submissionWindowEnd = context_.lookaheadSlot.timestamp;

        // Determine start of window
        if (_data.slotIndex == 0) {
            context_.submissionWindowStart = _epochTimestamp;
        } else {
            // `slotIndex` must be within bounds
            require(_data.slotIndex < Encoder.numSlots(_data.currLookahead), InvalidSlotIndex());

            LookaheadSlot memory lastSlot =
                Encoder.decodeIndex(_data.currLookahead, _data.slotIndex - 1);
            context_.submissionWindowStart =
                lastSlot.timestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        }
    }

    /// @dev Ensures the provided current epoch lookahead matches the stored hash.
    /// Empty lookahead is valid only when no hash exists for the epoch.
    function _validateCurrentEpochLookahead(uint256 _epochTimestamp, bytes memory _currLookahead)
        private
        view
    {
        bytes26 currLookaheadHash = getLookaheadHash(_epochTimestamp);

        if (currLookaheadHash != 0) {
            _validateLookahead(_epochTimestamp, _currLookahead, currLookaheadHash);
        } else {
            require(_currLookahead.length == 0, InvalidLookahead());
        }
    }

    /// @dev Processes next epoch's lookahead: validates existing or stores new lookahead.
    /// Optimization: same-epoch proposers can skip this entirely when lookahead already exists.
    /// @dev Lookahead for the next epoch is only expected from slot 1 onwards.
    function _handleNextEpochLookahead(
        uint256 _epochTimestamp,
        uint256 _nextEpochTimestamp,
        ProposerContext memory _context,
        LookaheadData memory _data
    )
        private
    {
        bytes26 nextLookaheadHash = getLookaheadHash(_nextEpochTimestamp);

        // Check if next epoch lookahead already exists
        if (nextLookaheadHash != 0) {
            if (_data.slotIndex != type(uint256).max) {
                // Same-epoch proposers don't need nextLookahead - skip validation
                return;
            }

            // Cross-epoch or fallback proposers must provide correct nextLookahead
            _validateLookahead(_nextEpochTimestamp, _data.nextLookahead, nextLookaheadHash);
        } else if (block.timestamp != _epochTimestamp) {
            // Lookahead not posted yet - must post it now
            _updateLookaheadForNextEpoch(_nextEpochTimestamp, _context, _data);
        }
    }

    function _validateLookahead(
        uint256 _epochTimestamp,
        bytes memory _encodedLookahead,
        bytes26 _lookaheadHash
    )
        internal
        pure
    {
        bytes26 actualHash = LibPreconfUtils.calculateLookaheadHash(
            _epochTimestamp, _encodedLookahead
        );
        require(_lookaheadHash == actualHash, InvalidLookahead());
    }

    /// @dev Stores new lookahead when none exists for next epoch.
    /// fallback preconfers provide no signature; URC operators must sign their commitment.
    function _updateLookaheadForNextEpoch(
        uint256 _nextEpochTimestamp,
        ProposerContext memory _context,
        LookaheadData memory _data
    )
        private
    {
        if (_data.commitmentSignature.length == 0) {
            // Fallback preconfer case
            require(_context.isFallback, ProposerIsNotFallbackPreconfer());
        } else {
            // Opted-in Operator case
            ISlasher.Commitment memory commitment = _buildLookaheadCommitment(_data.nextLookahead);
            address committer =
                ECDSA.recover(keccak256(abi.encode(commitment)), _data.commitmentSignature);
            require(committer == _context.proposer, CommitmentSignerMismatch());
        }

        _updateLookahead(_nextEpochTimestamp, _data.nextLookahead);
    }

    function _buildLookaheadCommitment(bytes memory _encodedLookahead)
        internal
        view
        returns (ISlasher.Commitment memory)
    {
        return ISlasher.Commitment({
            commitmentType: 0,
            payload: abi.encode(keccak256(_encodedLookahead)),
            slasher: unifiedSlasher
        });
    }

    function _updateLookahead(uint256 _nextEpochTimestamp, bytes memory _encodedLookahead)
        internal
        returns (bytes26 lookaheadHash_)
    {
        unchecked {
            // Set this value to the last slot timestamp of the previous epoch
            uint256 prevSlotTimestamp = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
            uint256 lookaheadLength = Encoder.numSlots(_encodedLookahead);

            for (uint256 i; i < lookaheadLength; ++i) {
                LookaheadSlot memory lookaheadSlot = Encoder.decodeIndex(_encodedLookahead, i);

                require(
                    lookaheadSlot.timestamp > prevSlotTimestamp, SlotTimestampIsNotIncrementing()
                );
                require(
                    (lookaheadSlot.timestamp - _nextEpochTimestamp)
                            % LibPreconfConstants.SECONDS_IN_SLOT == 0,
                    InvalidSlotTimestamp()
                );

                prevSlotTimestamp = lookaheadSlot.timestamp;
            }

            // Validate that the last slot timestamp is within the next epoch
            require(
                prevSlotTimestamp < _nextEpochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );
        }

        // Hash the lookahead slots and update the lookahead hash for next epoch
        lookaheadHash_ =
            LibPreconfUtils.calculateLookaheadHash(_nextEpochTimestamp, _encodedLookahead);
        _setLookaheadHash(_nextEpochTimestamp, lookaheadHash_);

        emit LookaheadPosted(_nextEpochTimestamp, lookaheadHash_);
    }

    function _setLookaheadHash(uint256 _epochTimestamp, bytes26 _hash) internal {
        LookaheadHash storage lookaheadHash = _getLookaheadHash(_epochTimestamp);
        lookaheadHash.epochTimestamp = uint48(_epochTimestamp);
        lookaheadHash.lookaheadHash = _hash;
    }

    function _getLookaheadHash(uint256 _epochTimestamp)
        internal
        view
        returns (LookaheadHash storage)
    {
        return lookahead[_epochTimestamp % LOOKAHEAD_BUFFER_SIZE];
    }
}
