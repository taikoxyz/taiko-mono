// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/ILookaheadSlasher.sol";
import "src/layer1/preconf/iface/IOverseer.sol";
import "src/layer1/preconf/libs/LibEIP4788.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/shared/common/EssentialContract.sol";
import "@eth-fabric/urc/lib/MerkleTree.sol";

/// @title LookaheadSlasher
/// @dev The lookahead contained within the beacon state is referred to
/// as the "beacon lookahead"
/// whereas, the lookahead maintained by the preconfing protocol is referred to
/// as the "preconf lookahead"
/// @custom:security-contact security@taiko.xyz
contract LookaheadSlasher is ILookaheadSlasher, EssentialContract {
    address public immutable urc;
    address public immutable lookaheadStore;
    address public immutable preconfSlasher;
    address public immutable overseer;
    uint256 public immutable slashAmount;

    uint256[50] private __gap;

    constructor(
        address _urc,
        address _lookaheadStore,
        address _preconfSlasher,
        address _overseer,
        uint256 _slashAmount
    )
        EssentialContract()
    {
        urc = _urc;
        lookaheadStore = _lookaheadStore;
        preconfSlasher = _preconfSlasher;
        overseer = _overseer;
        slashAmount = _slashAmount;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata, /*_delegation*/
        Commitment calldata _commitment,
        address, /*_committer*/
        bytes calldata _evidence,
        address /*_challenger*/
    )
        external
        nonReentrant
        onlyFrom(urc)
        returns (uint256)
    {
        // Todo: move to calldata
        ILookaheadStore.LookaheadSlot[] memory lookaheadSlots =
            abi.decode(_commitment.payload, (ILookaheadStore.LookaheadSlot[]));

        // (EvidenceLookahead, EvidenceBeaconValidator, EvidenceInvalidOperator ||
        // EvidenceMissingOperator)
        (bytes calldata evidenceX, bytes calldata evidenceY, bytes calldata evidenceZ) =
            _decodeEvidenceTuple(_evidence);

        (
            // Timestamp of the epoch preceding the one containing the problematic slot
            uint256 previousEpochTimestamp,
            // Timestamp of the problematic slot
            uint256 slotTimestamp,
            ILookaheadStore.LookaheadSlot memory lookaheadSlot
        ) = _validateLookaheadEvidence(evidenceX, lookaheadSlots);

        BLS.G1Point calldata beaconValidatorPubKey =
            _validateBeaconValidatorEvidence(previousEpochTimestamp, slotTimestamp, evidenceY);

        if (lookaheadSlots.length != 0 && lookaheadSlot.slotTimestamp == slotTimestamp) {
            // This condition is executed when the problematic slot is a dedicated slot of an
            // operator, but is assigned to the wrong operator i.e the beacon validator does
            // not belong to the operator
            _validateInvalidOperatorEvidence(lookaheadSlot, beaconValidatorPubKey, evidenceZ);
        } else {
            // This condition is executed when the problematic slot has no assigned operator i.e
            // when it is an advanced proposal slot, or when the lookahead is empty .
            _validateMissingOperatorEvidence(
                previousEpochTimestamp, beaconValidatorPubKey, evidenceZ
            );
        }

        return slashAmount;
    }

    // Evidence validation
    // --------------------------------------------------------------------------

    function _validateLookaheadEvidence(
        bytes calldata _evidenceLookaheadBytes,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        internal
        view
        returns (
            uint256 previousEpochTimestamp_,
            uint256 slotTimestamp_,
            ILookaheadStore.LookaheadSlot memory lookaheadSlot_
        )
    {
        EvidenceLookahead calldata evidenceLookahead;
        assembly {
            evidenceLookahead := _evidenceLookaheadBytes.offset
        }

        slotTimestamp_ = evidenceLookahead.slotTimestamp;
        uint256 epochTimestamp = _getEpochtimestamp(slotTimestamp_);

        bytes26 lookaheadHash =
            ILookaheadStore(lookaheadStore).calculateLookaheadHash(epochTimestamp, _lookaheadSlots);
        require(
            lookaheadHash == ILookaheadStore(lookaheadStore).getLookaheadHash(epochTimestamp),
            LookaheadHashMismatch()
        );

        // Timestamp of the epoch preceding the one containing `slotTimestamp_`.
        // This is used to validate the beacon validator evidence and also serves as the reference
        // timestamp for the missing operator evidence.
        previousEpochTimestamp_ = epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;

        if (_lookaheadSlots.length != 0) {
            lookaheadSlot_ = _lookaheadSlots[evidenceLookahead.lookaheadSlotsIndex];

            // Verify that `slotTimestamp_` is within the range of the timestamp contained in the
            // provided lookahead slot entry.
            if (slotTimestamp_ > lookaheadSlot_.slotTimestamp || slotTimestamp_ < epochTimestamp) {
                revert InvalidLookaheadSlotsIndex();
            }
        }
    }

    function _validateBeaconValidatorEvidence(
        uint256 _previousEpochTimestamp,
        uint256 _slotTimestamp,
        bytes calldata _evidenceBeaconValidatorBytes
    )
        internal
        view
        returns (BLS.G1Point calldata)
    {
        EvidenceBeaconValidator calldata evidenceBeaconValidator;
        assembly {
            evidenceBeaconValidator := add(_evidenceBeaconValidatorBytes.offset, 0x20)
        }

        // The index of the beacon lookahead slot containing our beacon validator.
        // Given the `_previousEpochTimestamp` is the timestamp of the epoch preceding the one
        // containing `_slotTimestamp`, the `expectedproposerLookaheadIndex` is always > 31 when
        // using the beacon state at `_previousEpochTimestamp`.
        uint256 expectedproposerLookaheadIndex = (_slotTimestamp - _previousEpochTimestamp) / 12;

        bytes32 beaconBlockRoot = LibPreconfUtils.getBeaconBlockRootAtOrAfter(
            _previousEpochTimestamp + LibPreconfConstants.SECONDS_IN_SLOT
        );

        LibEIP4788.verifyValidator(
            expectedproposerLookaheadIndex,
            evidenceBeaconValidator.beaconValidatorPubKey,
            beaconBlockRoot,
            evidenceBeaconValidator.beaconValidatorInclusionProof
        );

        return evidenceBeaconValidator.beaconValidatorPubKey;
    }

    function _validateInvalidOperatorEvidence(
        ILookaheadStore.LookaheadSlot memory _lookaheadSlot,
        BLS.G1Point calldata _beaconValidatorPubKey,
        bytes calldata _evidenceInvalidOperatorBytes
    )
        internal
        view
    {
        EvidenceInvalidOperator calldata evidenceInvalidOperator;
        assembly {
            evidenceInvalidOperator := add(_evidenceInvalidOperatorBytes.offset, 0x20)
        }

        // Validator referenced in the preconf lookahead must not match the beacon validator.
        require(
            !_isEqual(evidenceInvalidOperator.preconfValidatorPubKey, _beaconValidatorPubKey),
            PreconfValidatorIsSameAsBeaconValidator()
        );

        // Verify that `preconfValidatorPubKey` is indeed the validator referenced in the
        // problematic slot of the preconf lookahead.
        require(
            _isEqual(
                evidenceInvalidOperator.preconfValidatorPubKey,
                evidenceInvalidOperator.operatorRegistrations[_lookaheadSlot.validatorLeafIndex]
                    .pubkey
            ),
            PreconfValidatorIsNotRegistered()
        );

        IRegistry.OperatorData memory operatorData =
            IRegistry(urc).getOperatorData(_lookaheadSlot.registrationRoot);
        bytes32[] memory leaves = MerkleTree.hashToLeaves(
            evidenceInvalidOperator.operatorRegistrations, operatorData.owner
        );
        bytes32 registrationRoot = MerkleTree.generateTree(leaves);

        require(registrationRoot == _lookaheadSlot.registrationRoot, RegistrationRootMismatch());
    }

    function _validateMissingOperatorEvidence(
        uint256 _previousEpochTimestamp,
        BLS.G1Point calldata _beaconValidatorPubKey,
        bytes calldata _evidenceMissingOperatorBytes
    )
        internal
        view
    {
        EvidenceMissingOperator calldata evidenceMissingOperator;
        assembly {
            evidenceMissingOperator := add(_evidenceMissingOperatorBytes.offset, 0x20)
        }

        // Verify that `_beaconValidatorPubKey` belongs to an operator in the URC.
        IRegistry.RegistrationProof calldata registrationProof =
            evidenceMissingOperator.operatorRegistrationProof;
        require(
            _isEqual(registrationProof.registration.pubkey, _beaconValidatorPubKey),
            InvalidRegistrationProofValidator()
        );

        IRegistry(urc).verifyMerkleProof(registrationProof);

        IRegistry.OperatorData memory operatorData =
            IRegistry(urc).getOperatorData(registrationProof.registrationRoot);

        uint256 referenceTimestamp = _previousEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that the operator was valid at the reference timestamp.
        require(
            operatorData.registeredAt != 0 && operatorData.registeredAt < referenceTimestamp,
            OperatorHasNotRegistered()
        );
        require(
            operatorData.unregisteredAt == type(uint48).max
                || operatorData.unregisteredAt > referenceTimestamp,
            OperatorHasUnregistered()
        );
        require(
            operatorData.slashedAt == 0 || operatorData.slashedAt > referenceTimestamp,
            OperatorHasBeenSlashed()
        );

        // Verify that the operator was opted in at the reference timestamp.
        IRegistry.SlasherCommitment memory slasherCommitment =
            IRegistry(urc).getSlasherCommitment(registrationProof.registrationRoot, preconfSlasher);

        require(
            slasherCommitment.optedInAt != 0 && slasherCommitment.optedInAt < referenceTimestamp,
            OperatorHasNotOptedIn()
        );
        require(
            slasherCommitment.optedOutAt == 0 || slasherCommitment.optedOutAt > referenceTimestamp,
            OperatorHasNotOptedIn()
        );

        // Verify that the operator had sufficient collateral at the reference timestamp.
        uint256 collateral = IRegistry(urc).getHistoricalCollateral(
            registrationProof.registrationRoot, referenceTimestamp
        );

        require(
            collateral > ILookaheadStore(lookaheadStore).getConfig().minCollateralForPreconfing,
            OperatorHasInsufficientCollateral()
        );

        IOverseer.BlacklistTimestamps memory blacklistTimestamps =
            IOverseer(overseer).getBlacklist(registrationProof.registrationRoot);

        // Verify that the operator was not blacklisted at the reference timestamp
        bool notBlacklisted = blacklistTimestamps.blacklistedAt == 0
            || blacklistTimestamps.blacklistedAt > referenceTimestamp;
        bool unblacklisted = blacklistTimestamps.unBlacklistedAt != 0
            && blacklistTimestamps.unBlacklistedAt < referenceTimestamp;
        require(notBlacklisted || unblacklisted, OperatorHasBeenBlacklisted());
    }

    // Internal helpers
    // --------------------------------------------------------------------------

    /// @dev Returns the epoch timestamp of the epoch containing the slot timestamp.
    /// This could be an epoch in the past, present or future.
    function _getEpochtimestamp(uint256 _slotTimestamp) internal view returns (uint256) {
        uint256 genesisTimestamp = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 timePassed = _slotTimestamp - genesisTimestamp;
        uint256 timePassedUptoEpoch = (timePassed / LibPreconfConstants.SECONDS_IN_EPOCH)
            * LibPreconfConstants.SECONDS_IN_EPOCH;
        return genesisTimestamp + timePassedUptoEpoch;
    }

    function _isEqual(BLS.G1Point memory _a, BLS.G1Point memory _b) internal pure returns (bool) {
        return _a.x_a == _b.x_a && _a.x_b == _b.x_b && _a.y_a == _b.y_a && _a.y_b == _b.y_b;
    }

    function _decodeEvidenceTuple(bytes calldata _evidence)
        internal
        pure
        returns (bytes calldata x, bytes calldata y, bytes calldata z)
    {
        assembly {
            let xOuterOffset := calldataload(_evidence.offset)
            xOuterOffset := add(_evidence.offset, xOuterOffset)
            x.length := calldataload(xOuterOffset)
            x.offset := add(xOuterOffset, 0x20)

            let yOuterOffset := calldataload(add(_evidence.offset, 0x20))
            yOuterOffset := add(_evidence.offset, yOuterOffset)
            y.length := calldataload(yOuterOffset)
            y.offset := add(yOuterOffset, 0x20)

            let zOuterOffset := calldataload(add(_evidence.offset, 0x40))
            zOuterOffset := add(_evidence.offset, zOuterOffset)
            z.length := calldataload(zOuterOffset)
            z.offset := add(zOuterOffset, 0x20)
        }
    }
}
