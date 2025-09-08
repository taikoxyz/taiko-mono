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
    IRegistry public immutable urc;
    address public immutable lookaheadSlasher;
    address public immutable preconfSlasher;
    address public immutable inbox;
    address public immutable preconfWhitelist;
    address public immutable fallbackPreconfer;

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
        address _fallbackPreconfer,
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
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    modifier onlyOwnerOrOverseer() {
        require(msg.sender == owner() || overseers[msg.sender], NotOwnerOrOverseer());
        _;
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

        require(
            data.slotIndex == type(uint256).max || data.slotIndex < data.currLookahead.length,
            InvalidSlotIndex()
        );

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();

        // Validate `currLookahead`
        {
            bytes26 currLookaheadHash = getLookaheadHash(epochTimestamp);
            if (currLookaheadHash != 0) {
                _validateLookahead(epochTimestamp, data.currLookahead, currLookaheadHash);
            } else {
                require(data.currLookahead.length == 0, InvalidLookahead());
            }
        }

        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
        bytes26 nextLookaheadHash = getLookaheadHash(nextEpochTimestamp);
        bool validateNextLookahead;
        bool validateWhitelistPreconfer;

        // Update the next epoch's lookahead if needed
        {
            if (nextLookaheadHash == 0) {
                if (data.commitmentSignature.length == 0) {
                    // A whitelist preconfer is expected since a commitment signature is not
                    // provided.

                    validateWhitelistPreconfer = true;
                    nextLookaheadHash =
                        _updateLookahead(LibPreconfUtils.getEpochTimestamp(1), data.nextLookahead);
                } else {
                    // A URC registered operator who has opted into the lookahead slasher is
                    // expected.

                    // Validate the lookahead poster's operator status within the URC
                    ISlasher.Commitment memory commitment =
                        _buildLookaheadCommitment(data.nextLookahead);
                    _validateLookaheadPoster(
                        data.registrationRoot, commitment, data.commitmentSignature
                    );

                    nextLookaheadHash =
                        _updateLookahead(LibPreconfUtils.getEpochTimestamp(1), data.nextLookahead);
                }
            } else {
                validateNextLookahead = true;
            }
        }

        LookaheadSlot memory _lookaheadSlot;
        uint256 endOfSubmissionWindowTimestamp; // Upper boundary of preconfing period

        if (data.currLookahead.length == 0) {
            // The current lookahead is empty, so we use a whitelisted preconfer
            validateWhitelistPreconfer = true;

            // The last slot of the current epoch is the submission timestamp
            // of the whitelisted preconfer
            endOfSubmissionWindowTimestamp = nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
        } else {
            uint256 prevEndOfSubmissionWindowTimestamp; // Lower boundary of preconfing period

            if (data.slotIndex == type(uint256).max) {
                if (validateNextLookahead) {
                    _validateLookahead(nextEpochTimestamp, data.nextLookahead, nextLookaheadHash);
                }

                if (data.nextLookahead.length == 0) {
                    // This is the case when the next lookahead is empty
                    // Eg: [x x x Pa y y y] [     empty    ]
                    //     [  curr epoch  ] [  next epoch  ]
                    //
                    // The empty slots y will be taken over by the whitelist preconfer
                    // for the current epoch.
                    // The upper boundary of the preconfing period is the last slot of the
                    // current epoch.
                    //
                    endOfSubmissionWindowTimestamp =
                        nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
                    validateWhitelistPreconfer = true;
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
                    endOfSubmissionWindowTimestamp = data.nextLookahead[0].timestamp;
                    _lookaheadSlot = data.nextLookahead[0];
                }

                prevEndOfSubmissionWindowTimestamp =
                    data.currLookahead[data.currLookahead.length - 1].timestamp;
            } else {
                // This is the case when the preconfer is proposing in the same epoch in which
                // it has its lookahead slot.
                //
                // Eg: [x x x Pa y y y]
                //     [  curr epoch  ]
                // - Pa is our preconfer.
                // - x and y represent empty slots with no opted in preconfer.
                // - Pa intends to propose at any slot x
                //
                // OR
                //
                // Eg: [x x x Pa y y y Pb z z z]
                //     [      curr epoch       ]
                // - Pb is our preconfer.
                // - x, y and z represent empty slots with no opted in preconfer.
                // - Pb intends to propose at any slot y
                //
                endOfSubmissionWindowTimestamp = data.currLookahead[data.slotIndex].timestamp;
                prevEndOfSubmissionWindowTimestamp = data.slotIndex == 0
                    ? epochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT
                    : data.currLookahead[data.slotIndex - 1].timestamp;
                _lookaheadSlot = data.currLookahead[data.slotIndex];
            }

            // Validate the preconfing period
            require(
                block.timestamp > prevEndOfSubmissionWindowTimestamp
                    && block.timestamp <= endOfSubmissionWindowTimestamp,
                InvalidLookaheadTimestamp()
            );
        }

        if (validateWhitelistPreconfer) {
            _validateWhitelistPreconfer(_proposer);
        } else {
            _validateOptedInPreconfer(_proposer, _lookaheadSlot);
        }

        return uint64(endOfSubmissionWindowTimestamp);
    }

    // Blacklist functions
    // --------------------------------------------------------------------------

    /// @inheritdoc IBlacklist
    function addOverseers(address[] calldata _overseers) external override onlyOwnerOrOverseer {
        for (uint256 i = 0; i < _overseers.length; ++i) {
            address overseer = _overseers[i];
            require(!overseers[overseer], OverseerAlreadyExists());
            overseers[overseer] = true;
        }
        emit OverseersAdded(_overseers);
    }

    /// @inheritdoc IBlacklist
    function removeOverseers(address[] calldata _overseers) external override onlyOwnerOrOverseer {
        for (uint256 i = 0; i < _overseers.length; ++i) {
            address overseer = _overseers[i];
            require(overseers[overseer], OverseerDoesNotExist());
            overseers[overseer] = false;
        }
        emit OverseersRemoved(_overseers);
    }

    // View and Pure functions
    // --------------------------------------------------------------------------

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
    // --------------------------------------------------------------------------

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
            uint256 currentEpochTimestamp =
                _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;

            uint256 minCollateralForPreconfing =
                getLookaheadStoreConfig().minCollateralForPreconfing;

            for (uint256 i; i < _lookaheadSlots.length; ++i) {
                LookaheadSlot memory lookaheadSlot = _lookaheadSlots[i];

                require(
                    lookaheadSlot.timestamp > prevSlotTimestamp,
                    SlotTimestampIsNotIncrementing()
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
                ) = _validateOperator(
                    lookaheadSlot.registrationRoot,
                    currentEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT,
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

    function _validateLookaheadPoster(
        bytes32 _registrationRoot,
        ISlasher.Commitment memory _commitment,
        bytes memory _commitmentSignature
    )
        internal
        view
    {
        (, IRegistry.SlasherCommitment memory slasherCommitment) = _validateOperator(
            _registrationRoot,
            block.timestamp,
            getLookaheadStoreConfig().minCollateralForPosting,
            lookaheadSlasher
        );

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(keccak256(abi.encode(_commitment)), _commitmentSignature);
        require(committer == slasherCommitment.committer, CommitmentSignerMismatch());
    }

    /// @dev Validates if the operator is registered and has not been slashed at the given epoch
    /// timestamp. We use the epoch timestamp of the epoch in which the lookahead is posted to
    /// validate the registration and slashing status.
    function _validateOperator(
        bytes32 _registrationRoot,
        uint256 _timestamp,
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
        // The lookahead poster must be registered at least one slot in advanced from posting slot.
        // The operators within lookahead must be registered at least two slots in advanced from the
        // current epoch.
        require(
            operatorData_.registeredAt != 0 && operatorData_.registeredAt < _timestamp,
            OperatorHasNotRegistered()
        );

        // The poster must not have unregistered or been slashed.
        // The operators within lookahead may have unregistered or been slashed in the
        // current epoch.
        require(
            operatorData_.unregisteredAt == type(uint48).max
                || operatorData_.unregisteredAt > _timestamp,
            OperatorHasUnregistered()
        );
        require(
            operatorData_.slashedAt == 0 || operatorData_.slashedAt > _timestamp,
            OperatorHasBeenSlashed()
        );

        // For the poster, we consider the latest collateral value.
        // For the operators within lookahead, we consider the collateral value at the start of
        // the current epoch.
        uint256 collateralWei = _slasher == lookaheadSlasher
            ? operatorData_.collateralWei
            : urc.getHistoricalCollateral(_registrationRoot, _timestamp);
        require(collateralWei >= _minCollateral, OperatorHasInsufficientCollateral());

        BlacklistTimestamps memory blacklistTimestamps = blacklist[_registrationRoot];

        // Todo: extract this to a lookahead specific operators function
        // The operators within lookahead must not be blacklisted, or may have been blacklist in the
        // current epoch.
        bool notBlacklisted =
            blacklistTimestamps.blacklistedAt == 0 || blacklistTimestamps.blacklistedAt > _timestamp;
        // If unblacklisted, the operators within lookahead must have been unblacklisted at least
        // two slots in advanced from the current epoch.
        bool unblacklisted = blacklistTimestamps.unBlacklistedAt != 0
            && blacklistTimestamps.unBlacklistedAt < _timestamp;
        require(notBlacklisted || unblacklisted, OperatorHasBeenBlacklisted());

        slasherCommitment_ = urc.getSlasherCommitment(_registrationRoot, _slasher);

        // The lookahead poster must have opted in at least one slot in advanced from posting slot.
        // The operators within lookahead must have opted in at least two slots in advanced from
        // the current epoch.
        require(
            slasherCommitment_.optedInAt != 0 && slasherCommitment_.optedInAt < _timestamp,
            OperatorHasNotOptedIn()
        );

        // The lookahead poster must not have opted out.
        // The operators within lookahead may have opted out in the current epoch.
        require(
            slasherCommitment_.optedOutAt == 0 || slasherCommitment_.optedOutAt > _timestamp,
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
            _proposer == fallbackPreconfer
                || _proposer == IPreconfWhitelist(preconfWhitelist).getOperatorForCurrentEpoch(),
            NotWhitelistedOrFallbackPreconfer()
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
