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
    function updateLookahead(bytes32 _registrationRoot, bytes calldata _data) external {
        bool isPostedByGuardian = msg.sender == guardian;
        LookaheadPayload[] memory lookaheadPayloads;

        if (isPostedByGuardian) {
            lookaheadPayloads = abi.decode(_data, (LookaheadPayload[]));
        } else if (isLookaheadRequired()) {
            ISlasher.SignedCommitment memory signedCommitment =
                abi.decode(_data, (ISlasher.SignedCommitment));

            // Validate the lookahead poster's operator status within the URC
            _validateLookaheadPoster(_registrationRoot, signedCommitment);

            lookaheadPayloads =
                abi.decode(signedCommitment.commitment.payload, (LookaheadPayload[]));
        } else {
            revert LookaheadNotRequired();
        }

        _updateLookahead(
            LibPreconfUtils.getEpochTimestamp(1), lookaheadPayloads, isPostedByGuardian
        );
    }

    // View and Pure functions
    // --------------------------------------------------------------------------

    /// @inheritdoc ILookaheadStore
    function calculateLookaheadHash(
        uint256 _epochTimestamp,
        LookaheadSlot[] memory _lookaheadSlots
    )
        public
        pure
        returns (bytes26)
    {
        return bytes26(keccak256(abi.encode(_epochTimestamp, _lookaheadSlots)));
    }

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
        uint256 nextEpochTimestamp = LibPreconfUtils.getEpochTimestamp(1);

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
        uint256 _nextEpochTimestamp,
        LookaheadPayload[] memory _lookaheadPayloads,
        bool _isPostedByGuardian
    )
        internal
    {
        LookaheadSlot[] memory lookaheadSlots = new LookaheadSlot[](_lookaheadPayloads.length);

        unchecked {
            // Set this value to the last slot timestamp of the previous epoch
            uint256 prevSlotTimestamp = _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;

            for (uint256 i; i < _lookaheadPayloads.length; ++i) {
                LookaheadPayload memory lookaheadPayload = _lookaheadPayloads[i];

                require(
                    lookaheadPayload.slotTimestamp > prevSlotTimestamp,
                    SlotTimestampIsNotIncrementing()
                );

                require(
                    (lookaheadPayload.slotTimestamp - _nextEpochTimestamp)
                        % LibPreconfConstants.SECONDS_IN_EPOCH == 0,
                    InvalidSlotTimestamp()
                );

                prevSlotTimestamp = lookaheadPayload.slotTimestamp;

                // Validate the operator in the lookahead payload with the current epoch as
                // reference
                address committer = _validateOperatorInLookaheadPayload(
                    lookaheadPayload, _nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH
                );

                lookaheadSlots[i] = LookaheadSlot({
                    committer: committer,
                    slotTimestamp: lookaheadPayload.slotTimestamp,
                    registrationRoot: lookaheadPayload.registrationRoot,
                    validatorLeafIndex: lookaheadPayload.validatorLeafIndex
                });
            }

            // Validate that the last slot timestamp is within the next epoch
            require(
                prevSlotTimestamp <= _nextEpochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );
        }

        // Hash the lookahead slots and update the lookahead hash for next epoch
        bytes26 lookaheadHash = calculateLookaheadHash(_nextEpochTimestamp, lookaheadSlots);

        _setLookaheadHash(_nextEpochTimestamp, lookaheadHash);
        
        emit LookaheadPosted(
            _isPostedByGuardian, _nextEpochTimestamp, lookaheadHash, lookaheadSlots
        );
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
        require(committer == slashingCommitment.committer, CommitmentSignerMismatch());
        require(_signedCommitment.commitment.slasher == guardian, SlasherIsNotGuardian());
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
        IRegistry.OperatorData memory operatorData =
            urc.getOperatorData(_lookaheadPayload.registrationRoot);
        require(
            operatorData.unregisteredAt == 0 || operatorData.unregisteredAt >= _epochTimestamp,
            OperatorHasUnregistered()
        );
        require(
            operatorData.slashedAt == 0 || operatorData.slashedAt >= _epochTimestamp,
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
            slashingCommitment.optedInAt < _epochTimestamp
                && (
                    slashingCommitment.optedOutAt == 0
                        || slashingCommitment.optedOutAt >= _epochTimestamp
                ),
            OperatorHasNotOptedIntoPreconfSlasher()
        );

        return slashingCommitment.committer;
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
        return lookahead[_epochTimestamp % getConfig().lookaheadBufferSize];
    }
}
