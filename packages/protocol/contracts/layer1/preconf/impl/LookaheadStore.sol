// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPreconfConstants as LPC } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils as LPU } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/shared/common/EssentialContract.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, EssentialContract {
    IRegistry public immutable urc;
    address public immutable guardian;
    address public immutable preconfSlasher;

    // Lookahead buffer that stores the hashed lookahead entries for an epoch
    mapping(uint256 epochTimestamp_mod_lookaheadBufferSize => LookaheadHash lookaheadHash) public
        lookahead;

    uint256[49] private __gap;

    constructor(
        address _resolver,
        address _urc,
        address _guardian,
        address _preconfSlasher
    )
        EssentialContract(_resolver)
    {
        urc = IRegistry(_urc);
        guardian = _guardian;
        preconfSlasher = _preconfSlasher;
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
    {
        bool isPostedByGuardian = msg.sender == guardian;
        LookaheadPayload[] memory lookaheadPayloads;

        if (isPostedByGuardian) {
            lookaheadPayloads = abi.decode(_data, (LookaheadPayload[]));
        } else if (isLookaheadRequired()) {
            // Validate the lookahead poster's operator status within the URC
            lookaheadPayloads = _validateLookaheadPoster(
                _registrationRoot, abi.decode(_data, (ISlasher.SignedCommitment))
            );
        } else {
            revert LookaheadNotRequired();
        }

        _updateLookahead(LPU.getEpochTimestamp(0), lookaheadPayloads, isPostedByGuardian);
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
        return LPU.calculateLookaheadHash(_epochTimestamp, _lookaheadSlots);
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
        uint256 nextEpochTimestamp = LPU.getEpochTimestamp(1);

        return _getLookaheadHash(nextEpochTimestamp).epochTimestamp != nextEpochTimestamp;
    }

    /// @inheritdoc ILookaheadStore
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26) {
        LookaheadHash memory lookaheadHash = _getLookaheadHash(_epochTimestamp);
        require(lookaheadHash.epochTimestamp == _epochTimestamp, LookaheadHashNotFound());
        return lookaheadHash.lookaheadHash;
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
        uint256 _currentEpochTimestamp,
        LookaheadPayload[] memory _lookaheadPayloads,
        bool _isPostedByGuardian
    )
        internal
    {
        unchecked {
            LookaheadSlot[] memory lookaheadSlots = new LookaheadSlot[](_lookaheadPayloads.length);

            // Set this value to the last slot timestamp of the previous epoch
            uint256 nextEpochTimestamp = _currentEpochTimestamp + LPC.SECONDS_IN_EPOCH;
            uint256 prevSlotTimestamp = nextEpochTimestamp - LPC.SECONDS_IN_SLOT;
            uint256 minCollateralForPreconfing = getConfig().minCollateralForPreconfing;

            for (uint256 i; i < _lookaheadPayloads.length; ++i) {
                LookaheadPayload memory lookaheadPayload = _lookaheadPayloads[i];

                require(
                    lookaheadPayload.slotTimestamp > prevSlotTimestamp,
                    SlotTimestampIsNotIncrementing()
                );
                require(
                    (lookaheadPayload.slotTimestamp - nextEpochTimestamp) % LPC.SECONDS_IN_EPOCH
                        == 0,
                    InvalidSlotTimestamp()
                );

                prevSlotTimestamp = lookaheadPayload.slotTimestamp;

                // Validate the operator in the lookahead payload with the current epoch as
                // reference.
                // We use the current epoch's start timestamp `_currentEpochTimestamp` as the
                // reference time instead of the preconferrer's slot timestamp. This approach
                // prevents the poster from being unfairly slashed due to increasing collateral
                // balance between the time of posting this lookahead and the slot timestamp. If
                // the preconferrer's slot timestamp were used and their collateral balance
                // increased during this period, the poster could be unjustly penalized.
                //
                // It's important to note that a preconfer's collateral balance might decrease
                // during this period, leading to their removal from the URC. Consequently, when
                // verifying preconfer permissions, we must ensure not only that they are the
                // designated preconfer for a specific slot in the lookahead but also that they
                // remain a registered operator in the URC at the time of their proposal.
                (
                    IRegistry.OperatorData memory operatorData,
                    IRegistry.SlasherCommitment memory slasherCommitment
                ) = _validateOperator(
                    lookaheadPayload.registrationRoot,
                    lookaheadPayload.slotTimestamp,
                    _currentEpochTimestamp,
                    minCollateralForPreconfing,
                    preconfSlasher
                );

                require(
                    lookaheadPayload.validatorLeafIndex < operatorData.numKeys,
                    InvalidValidatorLeafIndex()
                );

                lookaheadSlots[i] = LookaheadSlot({
                    committer: slasherCommitment.committer,
                    slotTimestamp: lookaheadPayload.slotTimestamp,
                    registrationRoot: lookaheadPayload.registrationRoot,
                    validatorLeafIndex: lookaheadPayload.validatorLeafIndex
                });
            }

            // Validate that the last slot timestamp is within the next epoch
            require(
                prevSlotTimestamp < nextEpochTimestamp + LPC.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );

            // Hash the lookahead slots and update the lookahead hash for next epoch
            bytes26 lookaheadHash = LPU.calculateLookaheadHash(nextEpochTimestamp, lookaheadSlots);
            _setLookaheadHash(nextEpochTimestamp, lookaheadHash);

            emit LookaheadPosted(
                _isPostedByGuardian, nextEpochTimestamp, lookaheadHash, lookaheadSlots
            );
        }
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
        returns (LookaheadPayload[] memory)
    {
        require(_signedCommitment.commitment.slasher == guardian, SlasherIsNotGuardian());

        uint256 currentTimestamp = block.timestamp;
        (, IRegistry.SlasherCommitment memory slasherCommitment) = _validateOperator(
            _registrationRoot,
            currentTimestamp,
            currentTimestamp,
            getConfig().minCollateralForPosting,
            guardian
        );

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(
            keccak256(abi.encode(_signedCommitment.commitment)), _signedCommitment.signature
        );
        require(committer == slasherCommitment.committer, CommitmentSignerMismatch());
        require(_signedCommitment.commitment.slasher == guardian, SlasherIsNotGuardian());

        return abi.decode(_signedCommitment.commitment.payload, (LookaheadPayload[]));
    }

    /// @dev Validates if the operator is registered and has not been slashed at the given epoch
    /// timestamp. We use the epoch timestamp of the epoch in which the lookahead is posted to
    /// validate the registration and sloashing status.
    /// @param _registrationRoot The registration root of the operator
    /// @param _operationTimestamp The timestamp of the operation (posting or preconfing)
    /// @param _collateralTimestamp The timestamp for querying the collateral balance
    /// @param _minCollateral The minimum collateral required for the operation
    /// @param _slasher The slasher address
    function _validateOperator(
        bytes32 _registrationRoot,
        uint256 _operationTimestamp,
        uint256 _collateralTimestamp,
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
        require(
            operatorData_.registeredAt != 0 && operatorData_.registeredAt <= _operationTimestamp,
            OperatorHasNotRegistered()
        );
        require(
            operatorData_.unregisteredAt == 0 || operatorData_.unregisteredAt > _operationTimestamp,
            OperatorHasUnregistered()
        );
        require(
            operatorData_.slashedAt == 0 || operatorData_.slashedAt > _operationTimestamp,
            OperatorHasBeenSlashed()
        );

        uint256 collateralWei = _collateralTimestamp >= block.timestamp
            ? operatorData_.collateralWei
            : urc.getHistoricalCollateral(_registrationRoot, _collateralTimestamp);

        require(collateralWei >= _minCollateral, OperatorHasInsufficientCollateral());

        // Validate the operator's slashing commitment
        slasherCommitment_ = urc.getSlasherCommitment(_registrationRoot, _slasher);
        require(
            slasherCommitment_.optedInAt != 0 && slasherCommitment_.optedInAt <= _operationTimestamp,
            OperatorHasNotOptedIn()
        );
        require(
            slasherCommitment_.optedOutAt == 0
                || slasherCommitment_.optedOutAt > _operationTimestamp,
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
