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
    uint256 public lastRecordedSlotTimestamp;

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
        bytes32 registrationRoot,
        ISlasher.SignedCommitment memory signedCommitment
    )
        external
    {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Only proceed if lookahead is required
        require(isLookaheadRequired(), LookaheadNotRequired());

        // Validate the lookahead poster's operator status within the URC
        _validateLookaheadPoster(registrationRoot, signedCommitment);

        LookaheadPayload[] memory lookaheadPayloads =
            abi.decode(signedCommitment.commitment.payload, (LookaheadPayload[]));

        if (lookaheadPayloads.length == 0) {
            // The poster claims that the lookahead for the next epoch has no preconfers
            bytes32 emptyLookaheadRoot = keccak256(abi.encode(nextEpochTimestamp));
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
                    timestamp: lookaheadPayload.slotTimestamp,
                    prevTimestamp: _lastRecordedSlotTimestamp,
                    committer: committer,
                    operatorRegistrationRoot: lookaheadPayload.registrationRoot,
                    validatorLeafIndex: lookaheadPayload.validatorLeafIndex
                });

                emit LookaheadLeafPosted(
                    lookaheadPayload.slotTimestamp,
                    _lastRecordedSlotTimestamp,
                    committer,
                    lookaheadPayload.validatorLeafIndex
                );

                _lastRecordedSlotTimestamp = lookaheadPayload.slotTimestamp;
                leaves[i] = keccak256(abi.encode(lookaheadLeaf));
            }

            // Validate that the last recorded slot timestamp is within the next epoch
            require(
                _lastRecordedSlotTimestamp
                    <= nextEpochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH,
                InvalidLookaheadEpoch()
            );

            lastRecordedSlotTimestamp = _lastRecordedSlotTimestamp;

            // Merkleize the lookahead buffer entries and update the lookahead root for next epoch
            bytes32 root = LibMerkleTree.generateTree(leaves);
            _setLookaheadRoot(nextEpochTimestamp, root);

            emit LookaheadRootUpdated(nextEpochTimestamp, root);
        }
    }

    /// @inheritdoc ILookaheadStore
    function overwriteLookahead(uint256 epochTimestamp, bytes32 lookaheadRoot) external {
        require(msg.sender == guardian, SenderIsNotGuardian());
        _setLookaheadRoot(epochTimestamp, lookaheadRoot);
    }

    // View functions --------------------------------------------------------------------------

    /// @inheritdoc ILookaheadStore
    function isLookaheadRequired() public view returns (bool) {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        // no-proposer-preconfer slots && no-claim-of-empty-lookahead
        return lastRecordedSlotTimestamp < nextEpochTimestamp
            && _getLookaheadRoot(nextEpochTimestamp).root != keccak256(abi.encode(nextEpochTimestamp));
    }

    /// @inheritdoc ILookaheadStore
    function getLookaheadRoot(uint256 epochTimestamp) external view returns (bytes32) {
        LookaheadRoot memory lookaheadRoot = _getLookaheadRoot(epochTimestamp);
        require(lookaheadRoot.epochTimestamp == epochTimestamp, LookaheadRootNotFound());
        return lookaheadRoot.root;
    }

    /// @inheritdoc ILookaheadStore
    function lookaheadStoreConfig() public pure returns (Config memory) {
        return Config({
            // We use a prime number to allow for the entire buffer to fillup without conflicts
            lookaheadBufferSize: 503,
            minCollateralForPosting: 1 ether,
            minCollateralForPreconfing: 1 ether
        });
    }

    // Internal functions ----------------------------------------------------------------------

    function _validateLookaheadPoster(
        bytes32 registrationRoot,
        ISlasher.SignedCommitment memory signedCommitment
    )
        internal
        view
    {
        // Validate the lookahead poster's operator status within the URC
        IRegistry.OperatorData memory operatorData = urc.getOperatorData(registrationRoot);
        require(operatorData.unregisteredAt == 0, PosterHasUnregistered());
        require(operatorData.slashedAt == 0, PosterHasBeenSlashed());
        require(
            operatorData.collateralWei >= lookaheadStoreConfig().minCollateralForPosting,
            PosterHasInsufficientCollateral()
        );

        // Validate the slashing commitment of the lookahead poster
        IRegistry.SlasherCommitment memory slashingCommitment =
            urc.getSlasherCommitment(registrationRoot, guardian);
        require(slashingCommitment.optedOutAt < slashingCommitment.optedInAt, PosterHasNotOptedIn());

        // Validate the lookahead poster's signed commitment
        address committer = ECDSA.recover(
            keccak256(abi.encode(signedCommitment.commitment)), signedCommitment.signature
        );
        require(committer == slashingCommitment.committer, CommittmentSignerMismatch());
        require(signedCommitment.commitment.slasher == guardian, SlasherIsNotGuardian());
    }

    /// @dev Validates if the timestamp belongs to a valid slot in the next epoch
    function _validateSlotTimestamp(
        LookaheadPayload memory lookaheadPayload,
        uint256 previousSlotTimestamp,
        uint256 nextEpochTimestamp
    )
        internal
        pure
    {
        if (previousSlotTimestamp == 0) {
            require(lookaheadPayload.slotTimestamp >= nextEpochTimestamp, InvalidLookaheadEpoch());
        } else {
            require(
                lookaheadPayload.slotTimestamp > previousSlotTimestamp,
                SlotTimestampIsNotIncrementing()
            );
        }

        require(
            (lookaheadPayload.slotTimestamp - nextEpochTimestamp) % 12 == 0, InvalidSlotTimestamp()
        );
    }

    /// @dev Validates if the operator is registered and has not been slashed at the given epoch
    /// timestamp. We use the epoch timestamp of the epoch in which the lookahead is posted to
    /// validate the registration and slashing status.
    function _validateOperatorInLookaheadPayload(
        LookaheadPayload memory lookaheadPayload,
        uint256 epochTimestamp
    )
        internal
        view
        returns (address committer)
    {
        IRegistry.OperatorData memory OperatorData =
            urc.getOperatorData(lookaheadPayload.registrationRoot);
        require(
            OperatorData.unregisteredAt == 0 || OperatorData.unregisteredAt >= epochTimestamp,
            OperatorHasUnregistered()
        );
        require(
            OperatorData.slashedAt == 0 || OperatorData.slashedAt >= epochTimestamp,
            OperatorHasBeenSlashed()
        );
        require(
            lookaheadPayload.validatorLeafIndex < OperatorData.numKeys, InvalidValidatorLeafIndex()
        );

        uint256 collateralAtEpochTimestamp =
            urc.getHistoricalCollateral(lookaheadPayload.registrationRoot, epochTimestamp);
        require(
            collateralAtEpochTimestamp >= lookaheadStoreConfig().minCollateralForPreconfing,
            OperatorHasInsufficientCollateral()
        );

        // Validate the operator's slashing commitment
        IRegistry.SlasherCommitment memory slashingCommitment =
            urc.getSlasherCommitment(lookaheadPayload.registrationRoot, preconfSlasher);
        require(
            slashingCommitment.optedInAt < epochTimestamp
                && (
                    slashingCommitment.optedOutAt == 0
                        || slashingCommitment.optedOutAt >= epochTimestamp
                ),
            OperatorHasNotOptedIntoPreconfSlasher()
        );

        return slashingCommitment.committer;
    }

    function _setLookaheadRoot(uint256 epochTimestamp, bytes32 root) internal {
        lookahead[epochTimestamp % lookaheadStoreConfig().lookaheadBufferSize] =
            LookaheadRoot({ epochTimestamp: epochTimestamp, root: root });
    }

    function _getLookaheadRoot(uint256 epochTimestamp)
        internal
        view
        returns (LookaheadRoot memory)
    {
        return lookahead[epochTimestamp % lookaheadStoreConfig().lookaheadBufferSize];
    }
}
