// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eth-fabric/urc/IRegistry.sol";
import "@eth-fabric/urc/ISlasher.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/layer1/core/iface/IProposerChecker.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/preconf/impl/Blacklist.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/shared/common/EssentialContract.sol";

import "./LookaheadStore_Layout.sol"; // DO NOT DELETE

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, IProposerChecker, Blacklist, EssentialContract {
    IRegistry public immutable urc;
    address public immutable lookaheadSlasher;
    address public immutable preconfSlasher;
    address public immutable inbox;
    address public immutable preconfWhitelist;

    // Lookahead buffer that stores the hashed lookahead entries for an epoch
    mapping(uint256 epochTimestamp_mod_lookaheadBufferSize => LookaheadHash lookaheadHash) public
        lookahead;

    uint256[49] private __gap;

    constructor(
        address _urc,
        address _lookaheadSlasher,
        address _preconfSlasher,
        address _inbox,
        address _preconfWhitelist,
        address[] memory _overseers
    )
        Blacklist(_overseers)
    {
        urc = IRegistry(_urc);
        lookaheadSlasher = _lookaheadSlasher;
        preconfSlasher = _preconfSlasher;
        inbox = _inbox;
        preconfWhitelist = _preconfWhitelist;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposerChecker
    /// @dev Checks if a proposer is eligible to propose for the current slot and conditionally
    ///         updates the lookahead for the next epoch.
    /// @dev IMPORTANT: The first preconfer of each epoch must submit the lookahead for the next
    /// epoch. The contract enforces this by trying to update the lookahead for next epoch if none
    /// is
    /// stored.
    function checkProposer(
        address _proposer,
        bytes calldata _lookaheadData
    )
        external
        returns (uint48)
    {
        require(msg.sender == inbox, NotInbox());

        LookaheadData memory data = abi.decode(_lookaheadData, (LookaheadData));
        _validateSlotIndex(data);

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Determine the proposer context from supplied evidence
        ProposerContext memory context =
            _determineProposerContext(data, epochTimestamp, nextEpochTimestamp);

        // Verify that the sender is the expected proposer
        require(_proposer == context.proposer, ProposerIsNotPreconfer());

        // Verify that the proposer is in the preconfing window
        require(
            block.timestamp > context.submissionWindowStart
                && block.timestamp <= context.submissionWindowEnd,
            InvalidLookaheadTimestamp()
        );

        // Validate the current lookahead evidence
        _validateCurrentEpochLookahead(epochTimestamp, data.currLookahead);

        // Validate the next lookahead evidence and update the store if required
        _handleNextEpochLookahead(nextEpochTimestamp, context, data);

        return uint48(context.submissionWindowEnd);
    }

    /// @dev Validates that the slot index is valid.
    /// If the proposer is from the current epoch, it must be less than the size of the
    /// lookahead(32).
    /// If it is from the next epoch, it must be set to type(uint256).max.
    function _validateSlotIndex(LookaheadData memory _data) private pure {
        require(
            _data.slotIndex == type(uint256).max || _data.slotIndex < _data.currLookahead.length,
            InvalidSlotIndex()
        );
    }

    /// @dev Ensures the provided current epoch lookahead matches the stored hash.
    /// Empty lookahead is valid only when no hash exists for the epoch.
    function _validateCurrentEpochLookahead(
        uint256 _epochTimestamp,
        LookaheadSlot[] memory _currLookahead
    )
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
    function _handleNextEpochLookahead(
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
        } else {
            // Lookahead not posted yet - must post it now
            _updateLookaheadForNextEpoch(_nextEpochTimestamp, _context, _data);
        }
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
            _updateLookahead(_nextEpochTimestamp, _data.nextLookahead);
        } else {
            // Opted-in Operator case
            ISlasher.Commitment memory commitment = _buildLookaheadCommitment(_data.nextLookahead);
            _validateLookaheadPoster(
                _nextEpochTimestamp, _data.registrationRoot, commitment, _data.commitmentSignature
            );
            _updateLookahead(_nextEpochTimestamp, _data.nextLookahead);
        }
    }

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
            } else {
                context_.proposer = context_.lookaheadSlot.committer;
            }
        }
    }

    /// @dev Returns proposer context for when current epoch has no lookahead (fallback preconfer).
    function _handleEmptyCurrentLookahead(
        uint256 _epochTimestamp,
        uint256 _nextEpochTimestamp
    )
        private
        pure
        returns (ProposerContext memory context_)
    {
        context_.isFallback = true;
        context_.submissionWindowStart = _epochTimestamp;
        context_.submissionWindowEnd = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
    }

    /// @dev Returns proposer context for when no more opted in preconfers are remaining for the
    /// current
    /// epoch.
    function _handleCrossEpochProposer(
        LookaheadData memory _data,
        uint256 _nextEpochTimestamp
    )
        private
        pure
        returns (ProposerContext memory context_)
    {
        context_.submissionWindowStart =
        _data.currLookahead[_data.currLookahead.length - 1].timestamp;

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
            context_.isFallback = false;
            context_.submissionWindowEnd = _data.nextLookahead[0].timestamp;
            context_.lookaheadSlot = _data.nextLookahead[0];
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
    function _handleSameEpochProposer(
        LookaheadData memory _data,
        uint256 _epochTimestamp
    )
        private
        pure
        returns (ProposerContext memory context_)
    {
        context_.isFallback = false;
        context_.lookaheadSlot = _data.currLookahead[_data.slotIndex];
        context_.submissionWindowEnd = context_.lookaheadSlot.timestamp;

        // Determine start of window
        if (_data.slotIndex == 0) {
            context_.submissionWindowStart = _epochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        } else {
            context_.submissionWindowStart = _data.currLookahead[_data.slotIndex - 1].timestamp;
        }
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
    function getProposerContext(
        LookaheadData memory _data,
        uint256 _epochTimestamp
    )
        external
        view
        returns (ProposerContext memory context_)
    {
        uint256 nextEpochTimestamp = _epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
        context_ = _determineProposerContext(_data, _epochTimestamp, nextEpochTimestamp);
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadOperatorValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool)
    {
        uint256 referenceTimestamp = _epochTimestamp;

        _validateLookaheadOperator(
            referenceTimestamp,
            _registrationRoot,
            getLookaheadStoreConfig().minCollateralForPreconfing,
            preconfSlasher
        );

        return true;
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadPosterValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool)
    {
        uint256 referenceTimestamp = _epochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_EPOCH;

        _validateOperator(
            referenceTimestamp,
            _registrationRoot,
            getLookaheadStoreConfig().minCollateralForPosting,
            lookaheadSlasher
        );

        return true;
    }

    /// @inheritdoc ILookaheadStore
    function calculateLookaheadHash(
        uint256 _epochTimestamp,
        LookaheadSlot[] memory _lookaheadSlots
    )
        external
        pure
        returns (bytes26)
    {
        return LibPreconfUtils.calculateLookaheadHash(_epochTimestamp, _lookaheadSlots);
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
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

    /// @inheritdoc ILookaheadStore
    function getLookaheadStoreConfig() public pure virtual returns (LookaheadStoreConfig memory) {
        return LookaheadStoreConfig({
            // We use a prime number to allow for the entire buffer to fillup without conflicts
            lookaheadBufferSize: 503,
            minCollateralForPosting: 1 ether,
            minCollateralForPreconfing: 1 ether
        });
    }

    // Internal functions
    // --------------------------------------------------------------------

    function _updateLookahead(
        uint256 _nextEpochTimestamp,
        LookaheadSlot[] memory _lookaheadSlots
    )
        internal
        returns (bytes26 lookaheadHash_)
    {
        require(isLookaheadRequired(), LookaheadNotRequired());

        unchecked {
            // Set this value to the last slot timestamp of the previous epoch
            uint256 prevSlotTimestamp = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;

            uint256 minCollateralForPreconfing =
                getLookaheadStoreConfig().minCollateralForPreconfing;

            for (uint256 i; i < _lookaheadSlots.length; ++i) {
                LookaheadSlot memory lookaheadSlot = _lookaheadSlots[i];

                require(
                    lookaheadSlot.timestamp > prevSlotTimestamp, SlotTimestampIsNotIncrementing()
                );
                require(
                    (lookaheadSlot.timestamp - _nextEpochTimestamp)
                            % LibPreconfConstants.SECONDS_IN_SLOT == 0,
                    InvalidSlotTimestamp()
                );

                prevSlotTimestamp = lookaheadSlot.timestamp;

                // Validate the operator in the lookahead payload with the current epoch as
                // reference
                (
                    IRegistry.OperatorData memory operatorData,
                    IRegistry.SlasherCommitment memory slasherCommitment
                ) = _validateLookaheadOperator(
                    _nextEpochTimestamp,
                    lookaheadSlot.registrationRoot,
                    minCollateralForPreconfing,
                    preconfSlasher
                );

                require(
                    lookaheadSlot.validatorLeafIndex < operatorData.numKeys,
                    InvalidValidatorLeafIndex()
                );
                require(lookaheadSlot.committer == slasherCommitment.committer, CommitterMismatch());
            }

            // Validate that the last slot timestamp is within the next epoch
            require(
                prevSlotTimestamp < _nextEpochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );
        }

        // Hash the lookahead slots and update the lookahead hash for next epoch
        lookaheadHash_ =
            LibPreconfUtils.calculateLookaheadHash(_nextEpochTimestamp, _lookaheadSlots);
        _setLookaheadHash(_nextEpochTimestamp, lookaheadHash_);

        emit LookaheadPosted(_nextEpochTimestamp, lookaheadHash_, _lookaheadSlots);
    }

    function _setLookaheadHash(uint256 _epochTimestamp, bytes26 _hash) internal {
        LookaheadHash storage lookaheadHash = _getLookaheadHash(_epochTimestamp);
        lookaheadHash.epochTimestamp = uint48(_epochTimestamp);
        lookaheadHash.lookaheadHash = _hash;
    }

    function _validateLookaheadOperator(
        uint256 _nextEpochTimestamp,
        bytes32 _registrationRoot,
        uint256 _minCollateral,
        address _slasher
    )
        internal
        view
        returns (
            IRegistry.OperatorData memory operatorData_,
            IRegistry.SlasherCommitment memory slasherCommitment_
        )
    {
        uint256 prevEpochTimestamp =
            _nextEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_EPOCH;

        // Use the general operator validation first
        (operatorData_, slasherCommitment_) =
            _validateOperator(prevEpochTimestamp, _registrationRoot, _minCollateral, _slasher);

        // Apply lookahead-specific blacklist validation

        BlacklistTimestamps memory blacklistTimestamps = blacklist[_registrationRoot];

        // To make it into the lookahead, either the operator is not blacklisted, or blacklisted
        // in the previous or the current epoch.
        bool notBlacklisted = blacklistTimestamps.blacklistedAt == 0
            || blacklistTimestamps.blacklistedAt > prevEpochTimestamp;
        // If unblacklisted, the operator must have been unblacklisted before the start of the
        // previous epoch
        // in order to make it into the lookahead.
        bool unblacklisted = blacklistTimestamps.unBlacklistedAt != 0
            && blacklistTimestamps.unBlacklistedAt < prevEpochTimestamp;
        require(notBlacklisted || unblacklisted, OperatorHasBeenBlacklisted());
    }

    function _validateLookaheadPoster(
        uint256 _nextEpochTimestamp,
        bytes32 _registrationRoot,
        ISlasher.Commitment memory _commitment,
        bytes memory _commitmentSignature
    )
        internal
        view
    {
        uint256 prevEpochTimestamp = _nextEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_EPOCH;

        (, IRegistry.SlasherCommitment memory slasherCommitment) = _validateOperator(
            prevEpochTimestamp,
            _registrationRoot,
            getLookaheadStoreConfig().minCollateralForPosting,
            lookaheadSlasher
        );

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(keccak256(abi.encode(_commitment)), _commitmentSignature);
        require(committer == slasherCommitment.committer, CommitmentSignerMismatch());
    }

    /// @dev Validates if the operator is allowed to post a lookahead, or be present within a
    /// lookahead as
    // a preconfer.
    // It uses the starting timestamp of the previous epoch as the reference timestamp for checking
    // the
    // validity conditions.
    function _validateOperator(
        uint256 _prevEpochTimestamp,
        bytes32 _registrationRoot,
        uint256 _minCollateral,
        address _slasher
    )
        internal
        view
        returns (
            IRegistry.OperatorData memory operatorData_,
            IRegistry.SlasherCommitment memory slasherCommitment_
        )
    {
        operatorData_ = urc.getOperatorData(_registrationRoot);

        // Operator must be registered before the start of the previous epoch
        require(
            operatorData_.registeredAt != 0 && operatorData_.registeredAt < _prevEpochTimestamp,
            OperatorHasNotRegistered()
        );

        // If unregistered, the operator must have unregistered within the previous or current epoch
        require(
            operatorData_.unregisteredAt == type(uint48).max
                || operatorData_.unregisteredAt > _prevEpochTimestamp,
            OperatorHasUnregistered()
        );

        // If slashed, the operator must have been slashed within the previous or current epoch
        require(
            operatorData_.slashedAt == 0 || operatorData_.slashedAt > _prevEpochTimestamp,
            OperatorHasBeenSlashed()
        );

        // Operator must have enough collateral at the beginning of the previous epoch
        uint256 collateralWei = urc.getHistoricalCollateral(_registrationRoot, _prevEpochTimestamp);
        require(collateralWei >= _minCollateral, OperatorHasInsufficientCollateral());

        slasherCommitment_ = urc.getSlasherCommitment(_registrationRoot, _slasher);

        // Operator must have opted into the slasher before the start of the previous epoch
        require(
            slasherCommitment_.optedInAt != 0 && slasherCommitment_.optedInAt < _prevEpochTimestamp,
            OperatorHasNotOptedIn()
        );

        // If opted out, the operator must have opted out within the previous or current epoch
        require(
            slasherCommitment_.optedOutAt == 0
                || slasherCommitment_.optedOutAt > _prevEpochTimestamp,
            OperatorHasNotOptedIn()
        );
    }

    function _getLookaheadHash(uint256 _epochTimestamp)
        internal
        view
        returns (LookaheadHash storage)
    {
        return lookahead[_epochTimestamp % getLookaheadStoreConfig().lookaheadBufferSize];
    }

    function _validateLookahead(
        uint256 _epochTimestamp,
        LookaheadSlot[] memory _lookahead,
        bytes26 _lookaheadHash
    )
        internal
        pure
    {
        bytes26 actualHash = LibPreconfUtils.calculateLookaheadHash(_epochTimestamp, _lookahead);
        require(_lookaheadHash == actualHash, InvalidLookahead());
    }

    function _buildLookaheadCommitment(LookaheadSlot[] memory _lookahead)
        internal
        view
        returns (ISlasher.Commitment memory)
    {
        return ISlasher.Commitment({
            commitmentType: 0, payload: abi.encode(_lookahead), slasher: lookaheadSlasher
        });
    }
}
