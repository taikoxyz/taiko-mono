// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/iface/IOverseer.sol";
import "src/shared/common/EssentialContract.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, IOverseer, EssentialContract {
    // State variables
    // -------------------------------------------------------------------------

    IRegistry public immutable urc;
    address public immutable protector;
    address public immutable lookaheadSlasher;
    address public immutable preconfSlasher;
    address public immutable preconfRouter;

    /// @notice Lookahead buffer that stores the hashed lookahead entries for an epoch
    /// @dev Once the lookahead for an epoch is posted and validated, it becomes FIXED, even if
    /// operators within that epoch are blacklisted, unblacklisted or slashed.
    mapping(uint256 epochTimestamp_mod_lookaheadBufferSize => LookaheadHash lookaheadHash) public
        lookahead;

    /// @notice Maps operator registration roots to their blacklist timestamps
    mapping(bytes32 operatorRegistrationRoot => BlacklistTimestamps blacklistTimestamps) public
        blacklist;

    /// @notice Maps addresses to their overseer role status
    mapping(address => bool) public overseers;

    uint256[47] private __gap;

    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOverseer() {
        require(overseers[msg.sender], NotOverseer());
        _;
    }

    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        address _urc,
        address _protector,
        address _lookaheadSlasher,
        address _preconfSlasher,
        address _preconfRouter
    )
        EssentialContract()
    {
        urc = IRegistry(_urc);
        protector = _protector;
        lookaheadSlasher = _lookaheadSlasher;
        preconfSlasher = _preconfSlasher;
        preconfRouter = _preconfRouter;
    }

    // External & Public
    // -------------------------------------------------------------------------

    function init(address _owner, address _initialOverseer) external initializer {
        __Essential_init(_owner);
        if (_initialOverseer != address(0)) {
            overseers[_initialOverseer] = true;
            emit OverseerUpdated(_initialOverseer, true);
        }
    }

    /// @inheritdoc ILookaheadStore
    function updateLookahead(
        bytes32 _registrationRoot,
        bytes calldata _data
    )
        external
        nonReentrant
        returns (bytes26 lookaheadHash_)
    {
        LookaheadSlot[] memory lookaheadSlots;

        bool isLookaheadRequired_ = isLookaheadRequired();

        if (_registrationRoot == bytes32(0)) {
            // If the registration root is 0, the lookahead is posted by a whitelist preconfer
            // (via preconf router) or it is posted the lookahead slasher.
            if (msg.sender == preconfRouter) {
                require(isLookaheadRequired_, LookaheadNotRequired());
            } else {
                require(msg.sender == protector, NotProtectorOrPreconfRouter());
            }
            lookaheadSlots = abi.decode(_data, (LookaheadSlot[]));
        } else {
            require(isLookaheadRequired_, LookaheadNotRequired());

            // Validate the lookahead poster's operator status within the URC
            lookaheadSlots = _validateLookaheadPoster(
                _registrationRoot, abi.decode(_data, (ISlasher.SignedCommitment))
            );
        }

        return _updateLookahead(LibPreconfUtils.getEpochTimestamp(1), lookaheadSlots);
    }

    /// @inheritdoc IOverseer
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external onlyOverseer {
        BlacklistTimestamps storage blacklistTimestamps = blacklist[_operatorRegistrationRoot];

        // The operator must not be already blacklisted
        require(
            blacklistTimestamps.blacklistedAt <= blacklistTimestamps.unBlacklistedAt,
            OperatorAlreadyBlacklisted()
        );

        // If the operator was unblacklisted, the overseer must wait for a delay before
        // blacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.unBlacklistedAt + getConfig().blacklistDelay,
            BlacklistDelayNotMet()
        );

        blacklist[_operatorRegistrationRoot].blacklistedAt = uint48(block.timestamp);

        emit Blacklisted(_operatorRegistrationRoot, uint48(block.timestamp));
    }

    /// @inheritdoc IOverseer
    function unblacklistOperator(bytes32 _operatorRegistrationRoot) external onlyOverseer {
        BlacklistTimestamps storage blacklistTimestamps = blacklist[_operatorRegistrationRoot];

        // The operator must be blacklisted
        require(
            blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt,
            OperatorNotBlacklisted()
        );

        // If the operator was blacklisted, the overseer must wait for a delay before
        // unblacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.blacklistedAt + getConfig().unblacklistDelay,
            UnblacklistDelayNotMet()
        );

        blacklist[_operatorRegistrationRoot].unBlacklistedAt = uint48(block.timestamp);

        emit Unblacklisted(_operatorRegistrationRoot, uint48(block.timestamp));
    }

    /// @inheritdoc IOverseer
    function setOverseer(address _overseer, bool _enabled) external onlyOwner {
        overseers[_overseer] = _enabled;
        emit OverseerUpdated(_overseer, _enabled);
    }

    /// @notice Test-only function to set blacklist timestamps directly (bypasses delay validation)
    /// @dev This function should NEVER be deployed to mainnet - it's only for testing
    /// @param _operatorRegistrationRoot The operator registration root
    /// @param _blacklistedAt Timestamp when blacklisted
    /// @param _unblacklistedAt Timestamp when unblacklisted
    function setBlacklistTimestamps(
        bytes32 _operatorRegistrationRoot,
        uint48 _blacklistedAt,
        uint48 _unblacklistedAt
    )
        external
    {
        blacklist[_operatorRegistrationRoot] = BlacklistTimestamps({
            blacklistedAt: _blacklistedAt,
            unBlacklistedAt: _unblacklistedAt
        });
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
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26 hash_) {
        LookaheadHash memory lookaheadHash = _getLookaheadHash(_epochTimestamp);
        if (lookaheadHash.epochTimestamp == _epochTimestamp) {
            hash_ = lookaheadHash.lookaheadHash;
        }
    }

    /// @inheritdoc IOverseer
    function getBlacklist(bytes32 _operatorRegistrationRoot)
        external
        view
        returns (BlacklistTimestamps memory)
    {
        return blacklist[_operatorRegistrationRoot];
    }

    /// @inheritdoc IOverseer
    function isOperatorBlacklisted(bytes32 _operatorRegistrationRoot)
        external
        view
        returns (bool)
    {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_operatorRegistrationRoot];
        return blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt;
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
        uint256 nextEpochTimestamp = LibPreconfUtils.getEpochTimestamp(1);

        return _getLookaheadHash(nextEpochTimestamp).epochTimestamp != nextEpochTimestamp;
    }

    /// @inheritdoc ILookaheadStore
    function getConfig() public pure virtual returns (Config memory) {
        return Config({
            // We use a prime number to allow for the entire buffer to fillup without conflicts
            lookaheadBufferSize: 503,
            minCollateralForPosting: 1 ether,
            minCollateralForPreconfing: 1 ether,
            blacklistDelay: 1 days,
            unblacklistDelay: 1 days
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
        LookaheadSlot[] memory lookaheadSlots = new LookaheadSlot[](_lookaheadSlots.length);

        unchecked {
            // Set this value to the last slot timestamp of the previous epoch
            uint256 prevSlotTimestamp = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
            uint256 currentEpochTimestamp =
                _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;

            uint256 minCollateralForPreconfing = getConfig().minCollateralForPreconfing;

            for (uint256 i; i < _lookaheadSlots.length; ++i) {
                LookaheadSlot memory lookaheadSlot = _lookaheadSlots[i];

                require(
                    lookaheadSlot.slotTimestamp > prevSlotTimestamp,
                    SlotTimestampIsNotIncrementing()
                );
                require(
                    (lookaheadSlot.slotTimestamp - _nextEpochTimestamp)
                        % LibPreconfConstants.SECONDS_IN_SLOT == 0,
                    InvalidSlotTimestamp()
                );

                prevSlotTimestamp = lookaheadSlot.slotTimestamp;

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

                lookaheadSlots[i] = LookaheadSlot({
                    committer: slasherCommitment.committer,
                    slotTimestamp: lookaheadSlot.slotTimestamp,
                    registrationRoot: lookaheadSlot.registrationRoot,
                    validatorLeafIndex: lookaheadSlot.validatorLeafIndex
                });
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

        emit LookaheadPosted(_nextEpochTimestamp, lookaheadHash_, lookaheadSlots);
    }

    function _setLookaheadHash(uint256 _epochTimestamp, bytes26 _hash) internal {
        LookaheadHash storage lookaheadHash = _getLookaheadHash(_epochTimestamp);
        lookaheadHash.epochTimestamp = uint48(_epochTimestamp);
        lookaheadHash.lookaheadHash = _hash;
    }

    function _validateLookaheadPoster(
        bytes32 _registrationRoot,
        ISlasher.SignedCommitment memory _signedCommitment
    )
        internal
        view
        returns (LookaheadSlot[] memory)
    {
        require(
            _signedCommitment.commitment.slasher == lookaheadSlasher, SlasherIsNotLookaheadSlasher()
        );

        (, IRegistry.SlasherCommitment memory slasherCommitment) = _validateOperator(
            _registrationRoot,
            block.timestamp,
            getConfig().minCollateralForPosting,
            lookaheadSlasher
        );

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(
            keccak256(abi.encode(_signedCommitment.commitment)), _signedCommitment.signature
        );
        require(committer == slasherCommitment.committer, CommitmentSignerMismatch());

        return abi.decode(_signedCommitment.commitment.payload, (LookaheadSlot[]));
    }

    /// @dev Validates if the operator is registered and has not been slashed or blacklistedat the
    /// given epoch
    /// timestamp. We use the epoch timestamp of the epoch in which the lookahead is posted to
    /// validate the registration and slashing status.
    /// @dev For blaclisting, an operator is conisdered valid if they're either:
    /// 1. Never been blacklisted
    /// 2. Were blacklisted but it happened after the reference point (future blacklisting doesn't
    /// affect current validity)
    /// 3. Were unblacklisted before the reference point
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
        return lookahead[_epochTimestamp % getConfig().lookaheadBufferSize];
    }
}
