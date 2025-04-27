// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/libs/LibMerkleTree.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LookaheadStore
/// @custom:security-contact security@taiko.xyz
contract LookaheadStore is ILookaheadStore, EssentialContract {
    IRegistry public immutable urc;
    address public immutable guardian;
    address public immutable preconfSlasher;

    // The timestamp of the last recorded lookahead slot.
    uint64 public lastRecordedSlotTimestamp;
    uint64 private _reserved1;
    uint128 private _reserved2;

    // Lookahead buffer that stores the merkle root of the merkleized lookahead entries for an epoch
    mapping(uint256 epochTimestamp_mod_lookaheadBufferSize => LookaheadRoot lookaheadRoot) public
        lookahead;

    uint256[48] private __gap;

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
        ISlasher.SignedCommitment memory _signedCommitment
    )
        external
    {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Only proceed if lookahead is required
        require(isLookaheadRequired(), LookaheadNotRequired());

        // Validate the lookahead poster's operator status within the URC
        _validateLookaheadPoster(_registrationRoot, _signedCommitment);

        LookaheadPayload[] memory lookaheadPayloads =
            abi.decode(_signedCommitment.commitment.payload, (LookaheadPayload[]));

        if (lookaheadPayloads.length == 0) {
            // The poster claims that the lookahead for the next epoch has no preconfers
            bytes32 emptyLookaheadRoot = _calculateEmptyLookaheadRoot(nextEpochTimestamp);
            _setLookaheadRoot(nextEpochTimestamp, emptyLookaheadRoot);

            emit LookaheadRootUpdated(nextEpochTimestamp, emptyLookaheadRoot);
        } else {
            bytes32[] memory leaves = new bytes32[](lookaheadPayloads.length);

            uint256 _lastRecordedSlotTimestamp = lastRecordedSlotTimestamp;
            for (uint256 i; i < lookaheadPayloads.length; ++i) {
                LookaheadPayload memory lookaheadPayload = lookaheadPayloads[i];

                _validateSlotTimestamp(
                    lookaheadPayload,
                    i > 0 ? lookaheadPayloads[i - 1].slotTimestamp : 0,
                    nextEpochTimestamp
                );

                address committer =
                    _validateOperatorInLookaheadPayload(lookaheadPayload, epochTimestamp);

                LookaheadLeaf memory lookaheadLeaf = LookaheadLeaf({
                    index: i,
                    timestamp: lookaheadPayload.slotTimestamp,
                    prevTimestamp: _lastRecordedSlotTimestamp,
                    committer: committer,
                    operatorRegistrationRoot: lookaheadPayload.registrationRoot,
                    validatorLeafIndex: lookaheadPayload.validatorLeafIndex
                });

                emit LookaheadLeafPosted(lookaheadPayload.slotTimestamp, lookaheadLeaf);

                _lastRecordedSlotTimestamp = lookaheadPayload.slotTimestamp;
                leaves[i] = keccak256(abi.encode(lookaheadLeaf));
            }

            // Validate that the last recorded slot timestamp is within the next epoch
            require(
                _lastRecordedSlotTimestamp
                    <= nextEpochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );

            lastRecordedSlotTimestamp = uint64(_lastRecordedSlotTimestamp);

            // Merkleize the lookahead buffer entries and update the lookahead root for next epoch
            bytes32 root = LibMerkleTree.generateTree(leaves);
            _setLookaheadRoot(nextEpochTimestamp, root);

            emit LookaheadRootUpdated(nextEpochTimestamp, root);
        }
    }

    /// @inheritdoc ILookaheadStore
    function overwriteLookahead(
        uint256 _epochTimestamp,
        bytes32 _lookaheadRoot
    )
        external
        onlyFrom(guardian)
    {
        _setLookaheadRoot(_epochTimestamp, _lookaheadRoot);
    }

    // View functions --------------------------------------------------------------------------

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        // no-proposer-preconfer slots && no-claim-of-empty-lookahead
        return lastRecordedSlotTimestamp < nextEpochTimestamp
            && _getLookaheadRoot(nextEpochTimestamp).root
                != _calculateEmptyLookaheadRoot(nextEpochTimestamp);
    }

    /// @inheritdoc ILookaheadStore
    function getLookaheadRoot(uint256 _epochTimestamp) external view returns (bytes32) {
        LookaheadRoot memory lookaheadRoot = _getLookaheadRoot(_epochTimestamp);
        require(lookaheadRoot.epochTimestamp == _epochTimestamp, LookaheadRootNotFound());
        return lookaheadRoot.root;
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
        IRegistry.OperatorData memory OperatorData =
            urc.getOperatorData(_lookaheadPayload.registrationRoot);
        require(
            OperatorData.unregisteredAt == 0 || OperatorData.unregisteredAt >= _epochTimestamp,
            OperatorHasUnregistered()
        );
        require(
            OperatorData.slashedAt == 0 || OperatorData.slashedAt >= _epochTimestamp,
            OperatorHasBeenSlashed()
        );
        require(
            _lookaheadPayload.validatorLeafIndex < OperatorData.numKeys, InvalidValidatorLeafIndex()
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

    function _setLookaheadRoot(uint256 _epochTimestamp, bytes32 _root) internal {
        LookaheadRoot storage lookaheadRoot = _getLookaheadRoot(_epochTimestamp);
        lookaheadRoot.epochTimestamp = _epochTimestamp;
        lookaheadRoot.root = _root;
    }

    function _getLookaheadRoot(uint256 _epochTimestamp)
        internal
        view
        returns (LookaheadRoot storage)
    {
        return lookahead[_epochTimestamp % getConfig().lookaheadBufferSize];
    }

    function _calculateEmptyLookaheadRoot(uint256 _epochTimestamp)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_epochTimestamp));
    }
}
