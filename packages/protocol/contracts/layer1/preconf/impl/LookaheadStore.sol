// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/preconf/impl/Blacklist.sol";
import "src/shared/common/EssentialContract.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@eth-fabric/urc/ISlasher.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, Blacklist, EssentialContract {
    struct NextEpochResult {
        bytes26 lookaheadHash;
        bool isLookaheadValidationRequired;
        bool isWhitelistRequired;
    }

    struct ProposerContext {
        uint256 submissionWindowEnd;
        uint256 submissionWindowStart;
        LookaheadSlot lookaheadSlot;
        bool useWhitelistPreconfer;
    }

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
        EssentialContract()
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

    /// @inheritdoc ILookaheadStore
    function checkProposer(
        address _proposer,
        bytes calldata _lookaheadData
    )
        external
        returns (uint64)
    {
        require(msg.sender == inbox, NotInbox());

        LookaheadData memory data = abi.decode(_lookaheadData, (LookaheadData));
        _validateSlotIndex(data);

        // Step 1: Validate current epoch lookahead
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        _validateCurrentEpochLookahead(epochTimestamp, data.currLookahead);

        // Step 2: Handle next epoch lookahead
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
        NextEpochResult memory nextEpochResult = _handleNextEpochLookahead(nextEpochTimestamp, data);

        // Step 3: Determine proposer context
        ProposerContext memory context =
            _determineProposerContext(data, epochTimestamp, nextEpochTimestamp, nextEpochResult);

        // Step 4: Validate the actual proposer
        _validateProposer(_proposer, context);

        return uint64(context.submissionWindowEnd);
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
    /// Returns lookahead hash and if whitelist is required.
    function _handleNextEpochLookahead(
        uint256 _nextEpochTimestamp,
        LookaheadData memory _data
    )
        private
        returns (NextEpochResult memory result)
    {
        result.lookaheadHash = getLookaheadHash(_nextEpochTimestamp);

        if (result.lookaheadHash == 0) {
            result = _updateLookaheadForNextEpoch(_nextEpochTimestamp, _data);
        } else {
            // Since the lookahead was not updated in the same transaction, we need to validate
            // the slot supplied as evidence
            result.isLookaheadValidationRequired = true;
        }

        return result;
    }

    /// @dev Stores new lookahead when none exists for next epoch.
    /// Whitelist preconfers provide no signature; URC operators must sign their commitment.
    function _updateLookaheadForNextEpoch(
        uint256 _nextEpochTimestamp,
        LookaheadData memory _data
    )
        private
        returns (NextEpochResult memory result)
    {
        if (_data.commitmentSignature.length == 0) {
            // Whitelist preconfer case
            result.isWhitelistRequired = true;
            result.lookaheadHash = _updateLookahead(_nextEpochTimestamp, _data.nextLookahead);
        } else {
            // URC Operator case
            ISlasher.Commitment memory commitment = _buildLookaheadCommitment(_data.nextLookahead);
            _validateLookaheadPoster(
                _nextEpochTimestamp, _data.registrationRoot, commitment, _data.commitmentSignature
            );
            result.lookaheadHash = _updateLookahead(_nextEpochTimestamp, _data.nextLookahead);
        }
        return result;
    }

    /// @dev Determines the proposer's slot and submission window based on lookahead state.
    /// Handles empty lookahead, cross-epoch, and same-epoch scenarios.
    function _determineProposerContext(
        LookaheadData memory _data,
        uint256 _epochTimestamp,
        uint256 _nextEpochTimestamp,
        NextEpochResult memory _nextResult
    )
        private
        pure
        returns (ProposerContext memory context)
    {
        if (_data.currLookahead.length == 0) {
            return _handleEmptyCurrentLookahead(_nextEpochTimestamp);
        } else if (_data.slotIndex == type(uint256).max) {
            return _handleCrossEpochProposer(_data, _nextEpochTimestamp, _nextResult);
        } else {
            return _handleSameEpochProposer(_data, _epochTimestamp);
        }
    }

    /// @dev Returns context for when current epoch has no lookahead (whitelist fallback).
    function _handleEmptyCurrentLookahead(uint256 _nextEpochTimestamp)
        private
        pure
        returns (ProposerContext memory context)
    {
        context.useWhitelistPreconfer = true;
        context.submissionWindowEnd = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        return context;
    }

    /// @dev Handles proposer from last slot of current epoch proposing early into next epoch.
    /// Falls back to whitelist if next epoch is empty.
    function _handleCrossEpochProposer(
        LookaheadData memory _data,
        uint256 _nextEpochTimestamp,
        NextEpochResult memory _nextResult
    )
        private
        pure
        returns (ProposerContext memory context)
    {
        // Validate next lookahead if required
        if (_nextResult.isLookaheadValidationRequired) {
            _validateLookahead(_nextEpochTimestamp, _data.nextLookahead, _nextResult.lookaheadHash);
        }

        context.submissionWindowStart =
            _data.currLookahead[_data.currLookahead.length - 1].timestamp;

        if (_data.nextLookahead.length == 0) {
            // This is the case when the next lookahead is empty
            // Eg: [x x x Pa y y y] [     empty    ]
            //     [  curr epoch  ] [  next epoch  ]
            //
            // The empty slots y will be taken over by the whitelist preconfer
            // for the current epoch.
            // The upper boundary of the preconfing period is the last slot of the
            // current epoch.
            //
            context.submissionWindowEnd = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
            context.useWhitelistPreconfer = true;
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
            context.submissionWindowEnd = _data.nextLookahead[0].timestamp;
            context.lookaheadSlot = _data.nextLookahead[0];
            context.useWhitelistPreconfer = false;
        }

        return context;
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
        returns (ProposerContext memory context)
    {
        context.lookaheadSlot = _data.currLookahead[_data.slotIndex];
        context.submissionWindowEnd = context.lookaheadSlot.timestamp;
        context.useWhitelistPreconfer = false;

        // Determine start of window
        if (_data.slotIndex == 0) {
            context.submissionWindowStart = _epochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        } else {
            context.submissionWindowStart = _data.currLookahead[_data.slotIndex - 1].timestamp;
        }

        return context;
    }

    /// @dev Validates proposer is within their time window and has proper authorization.
    /// Checks whitelist for fallback scenarios or validates opted-in preconfer.
    function _validateProposer(address _proposer, ProposerContext memory _context) private view {
        // Validate timing window (only for non-empty current lookahead)
        if (!_context.useWhitelistPreconfer || _context.submissionWindowStart > 0) {
            require(
                block.timestamp > _context.submissionWindowStart
                    && block.timestamp <= _context.submissionWindowEnd,
                InvalidLookaheadTimestamp()
            );
        }

        // Validate proposer identity
        if (_context.useWhitelistPreconfer) {
            _validateWhitelistPreconfer(_proposer);
        } else {
            _validateOptedInPreconfer(_proposer, _context.lookaheadSlot);
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
        uint256 nextEpochTimestamp = LibPreconfUtils.getEpochTimestamp(1);

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

        LookaheadSlot[] memory lookaheadSlots = new LookaheadSlot[](_lookaheadSlots.length);

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
        lookaheadHash_ = LibPreconfUtils.calculateLookaheadHash(_nextEpochTimestamp, lookaheadSlots);
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
        uint256 prevEpochTimestamp = _nextEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_EPOCH;

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

    function _validateWhitelistPreconfer(address _proposer) internal view {
        require(
            _proposer == IPreconfWhitelist(preconfWhitelist).getOperatorForCurrentEpoch(),
            NotWhitelistedPreconfer()
        );
    }

    /// @dev Validates if the proposer has proposing rights for the current slot
    function _validateOptedInPreconfer(
        address _proposer,
        LookaheadSlot memory _lookaheadSlot
    )
        internal
        view
    {
        IRegistry.OperatorData memory operatorData =
            urc.getOperatorData(_lookaheadSlot.registrationRoot);
        bool isOptedIn = urc.isOptedIntoSlasher(_lookaheadSlot.registrationRoot, preconfSlasher);

        // If the operator is slashed, unregistered, not opted in, or blacklisted, we use the
        // fallback or whitelist preconfer
        if (
            operatorData.unregisteredAt != type(uint48).max || operatorData.slashedAt != 0
                || !isOptedIn || isOperatorBlacklisted(_lookaheadSlot.registrationRoot)
        ) {
            _validateWhitelistPreconfer(_proposer);
        } else {
            // Proposer must be the expected committer (i.e the opted in preconfer) for
            // the current preconfing period
            require(_proposer == _lookaheadSlot.committer, ProposerIsNotPreconfer());
        }
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
            commitmentType: 0,
            payload: abi.encode(_lookahead),
            slasher: lookaheadSlasher
        });
    }
}
