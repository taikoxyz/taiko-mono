// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
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
    function updateLookahead(bytes32 _registrationRoot, bytes calldata _payload) external {
        bool isPostedByGuardian = msg.sender == guardian;
        LookaheadPayload[] memory lookaheadPayloads;

        if (isPostedByGuardian) {
            lookaheadPayloads = abi.decode(_payload, (LookaheadPayload[]));
        } else if (isLookaheadRequired()) {
            ISlasher.SignedCommitment memory signedCommitment =
                abi.decode(_payload, (ISlasher.SignedCommitment));

            // Validate the lookahead poster's operator status within the URC
            _validateLookaheadPoster(_registrationRoot, signedCommitment);

            lookaheadPayloads =
                abi.decode(signedCommitment.commitment.payload, (LookaheadPayload[]));
        } else {
            revert LookaheadNotRequired();
        }

        uint256 nextEpochTimestamp = LibPreconfUtils.getEpochTimestamp(1);

        (bytes32 lookaheadHash, LookaheadSlot[] memory lookaheadSlots) =
            _updateLookahead(nextEpochTimestamp, lookaheadPayloads);

        emit LookaheadPosted(isPostedByGuardian, nextEpochTimestamp, lookaheadHash, lookaheadSlots);
    }

    // View functions --------------------------------------------------------------------------

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
        uint256 nextEpochTimestamp = LibPreconfUtils.getEpochTimestamp(1);

        return _getLookaheadHash(nextEpochTimestamp).epochTimestamp != nextEpochTimestamp;
    }

    /// @inheritdoc ILookaheadStore
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes32) {
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

    // Internal functions ----------------------------------------------------------------------

    function _updateLookahead(
        uint256 _nextEpochTimestamp,
        LookaheadPayload[] memory _lookaheadPayloads
    )
        internal
        returns (bytes32, LookaheadSlot[] memory)
    {
        if (_lookaheadPayloads.length == 0) {
            // The poster claims that the lookahead for the next epoch has no preconfers
            bytes32 emptyLookaheadHash = _calculateEmptyLookaheadHash(_nextEpochTimestamp);
            _setLookaheadHash(_nextEpochTimestamp, emptyLookaheadHash);

            return (emptyLookaheadHash, new LookaheadSlot[](0));
        } else {
            LookaheadSlot[] memory lookaheadSlots = new LookaheadSlot[](_lookaheadPayloads.length);

            for (uint256 i; i < _lookaheadPayloads.length; ++i) {
                LookaheadPayload memory lookaheadPayload = _lookaheadPayloads[i];

                _validateSlotTimestamp(
                    lookaheadPayload,
                    i > 0 ? _lookaheadPayloads[i - 1].slotTimestamp : 0,
                    _nextEpochTimestamp
                );

                // Validate the operator in the lookahead payload with the current epoch as
                // reference
                uint256 epochTimestamp = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;
                address committer =
                    _validateOperatorInLookaheadPayload(lookaheadPayload, epochTimestamp);

                LookaheadSlot memory lookaheadSlot = LookaheadSlot({
                    timestamp: lookaheadPayload.slotTimestamp,
                    committer: committer,
                    operatorRegistrationRoot: lookaheadPayload.registrationRoot,
                    validatorLeafIndex: lookaheadPayload.validatorLeafIndex
                });

                lookaheadSlots[i] = lookaheadSlot;
            }

            // Validate that the last slot timestamp is within the next epoch
            require(
                lookaheadSlots[lookaheadSlots.length - 1].timestamp
                    <= _nextEpochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );

            // Hash the lookahead slots and update the lookahead hash for next epoch
            bytes32 lookaheadHash = _calculateLookaheadHash(lookaheadSlots);
            _setLookaheadHash(_nextEpochTimestamp, lookaheadHash);

            return (lookaheadHash, lookaheadSlots);
        }
    }

    function _validateLookaheadPoster(
        bytes32 _registrationRoot,
        ISlasher.SignedCommitment memory _signedCommitment
    )
        internal
        view
    {
        // Validate the lookahead poster's operator status within the URC
        IRegistry.OperatorData memory operatorData = urc.getOperatorData(_registrationRoot);
        require(operatorData.unregisteredAt == 0, PosterHasUnregistered());
        require(operatorData.slashedAt == 0, PosterHasBeenSlashed());
        require(
            operatorData.collateralWei >= getConfig().minCollateralForPosting,
            PosterHasInsufficientCollateral()
        );

        // Validate the slashing commitment of the lookahead poster
        IRegistry.SlasherCommitment memory slashingCommitment =
            urc.getSlasherCommitment(_registrationRoot, guardian);
        require(slashingCommitment.optedOutAt < slashingCommitment.optedInAt, PosterHasNotOptedIn());

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(
            keccak256(abi.encode(_signedCommitment.commitment)), _signedCommitment.signature
        );
        require(committer == slashingCommitment.committer, CommittmentSignerMismatch());
        require(_signedCommitment.commitment.slasher == guardian, SlasherIsNotGuardian());
    }

    /// @dev Validates if the timestamp belongs to a valid slot in the next epoch
    function _validateSlotTimestamp(
        LookaheadPayload memory _lookaheadPayload,
        uint256 _previousSlotTimestamp,
        uint256 _nextEpochTimestamp
    )
        internal
        pure
    {
        if (_previousSlotTimestamp == 0) {
            require(_lookaheadPayload.slotTimestamp >= _nextEpochTimestamp, InvalidLookaheadEpoch());
        } else {
            require(
                _lookaheadPayload.slotTimestamp > _previousSlotTimestamp,
                SlotTimestampIsNotIncrementing()
            );
        }

        require(
            (_lookaheadPayload.slotTimestamp - _nextEpochTimestamp) % 12 == 0,
            InvalidSlotTimestamp()
        );
    }

    /// @dev Validates if the operator is registered and has not been slashed at the given epoch
    /// timestamp. We use the epoch timestamp of the epoch in which the lookahead is posted to
    /// validate the registration and slashing status.
    function _validateOperatorInLookaheadPayload(
        LookaheadPayload memory _lookaheadPayload,
        uint256 _epochTimestamp
    )
        internal
        view
        returns (address committer)
    {
        uint256 blockHeightAtEpochTimestamp =
            LibPreconfUtils.getBlockHeightAtTimestamp(_epochTimestamp);

        IRegistry.OperatorData memory operatorData =
            urc.getOperatorData(_lookaheadPayload.registrationRoot);
        require(
            operatorData.unregisteredAt == 0
                || operatorData.unregisteredAt >= blockHeightAtEpochTimestamp,
            OperatorHasUnregistered()
        );
        require(
            operatorData.slashedAt == 0 || operatorData.slashedAt >= blockHeightAtEpochTimestamp,
            OperatorHasBeenSlashed()
        );
        require(
            _lookaheadPayload.validatorLeafIndex < operatorData.numKeys, InvalidValidatorLeafIndex()
        );

        uint256 collateralAtEpochTimestamp =
            urc.getHistoricalCollateral(_lookaheadPayload.registrationRoot, _epochTimestamp);
        require(
            collateralAtEpochTimestamp >= getConfig().minCollateralForPreconfing,
            OperatorHasInsufficientCollateral()
        );

        // Validate the operator's slashing commitment
        IRegistry.SlasherCommitment memory slashingCommitment =
            urc.getSlasherCommitment(_lookaheadPayload.registrationRoot, preconfSlasher);
        require(
            slashingCommitment.optedInAt < blockHeightAtEpochTimestamp
                && (
                    slashingCommitment.optedOutAt == 0
                        || slashingCommitment.optedOutAt >= blockHeightAtEpochTimestamp
                ),
            OperatorHasNotOptedIntoPreconfSlasher()
        );

        return slashingCommitment.committer;
    }

    function _setLookaheadHash(uint256 _epochTimestamp, bytes32 _hash) internal {
        LookaheadHash storage lookaheadHash = _getLookaheadHash(_epochTimestamp);
        lookaheadHash.epochTimestamp = _epochTimestamp;
        lookaheadHash.lookaheadHash = _hash;
    }

    function _getLookaheadHash(uint256 _epochTimestamp)
        internal
        view
        returns (LookaheadHash storage)
    {
        return lookahead[_epochTimestamp % getConfig().lookaheadBufferSize];
    }

    function _calculateLookaheadHash(LookaheadSlot[] memory _lookaheadSlots)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_lookaheadSlots));
    }

    function _calculateEmptyLookaheadHash(uint256 _epochTimestamp)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_epochTimestamp));
    }
}
