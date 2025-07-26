// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/shared/common/EssentialContract.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, EssentialContract {
    IRegistry public immutable urc;
    address public immutable protector;
    address public immutable preconfSlasher;
    address public immutable preconfRouter;

    // Lookahead buffer that stores the hashed lookahead entries for an epoch
    mapping(uint256 epochTimestamp_mod_lookaheadBufferSize => LookaheadHash lookaheadHash) public
        lookahead;

    uint256[49] private __gap;

    constructor(
        address _urc,
        address _protector,
        address _preconfSlasher,
        address _preconfRouter
    )
        EssentialContract()
    {
        urc = IRegistry(_urc);
        protector = _protector;
        preconfSlasher = _preconfSlasher;
        preconfRouter = _preconfRouter;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
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
            // (via preconf router) or it is posted the protector.
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
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26 hash_) {
        LookaheadHash memory lookaheadHash = _getLookaheadHash(_epochTimestamp);
        if (lookaheadHash.epochTimestamp == _epochTimestamp) {
            hash_ = lookaheadHash.lookaheadHash;
        }
    }

    /// @inheritdoc ILookaheadStore
    function getConfig() public pure virtual returns (Config memory) {
        return Config({
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
        require(_signedCommitment.commitment.slasher == protector, SlasherIsNotProtector());

        (, IRegistry.SlasherCommitment memory slasherCommitment) = _validateOperator(
            _registrationRoot, block.timestamp, getConfig().minCollateralForPosting, protector
        );

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(
            keccak256(abi.encode(_signedCommitment.commitment)), _signedCommitment.signature
        );
        require(committer == slasherCommitment.committer, CommitmentSignerMismatch());

        return abi.decode(_signedCommitment.commitment.payload, (LookaheadSlot[]));
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
        uint256 collateralWei = _slasher == protector
            ? operatorData_.collateralWei
            : urc.getHistoricalCollateral(_registrationRoot, _timestamp);
        require(collateralWei >= _minCollateral, OperatorHasInsufficientCollateral());

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
