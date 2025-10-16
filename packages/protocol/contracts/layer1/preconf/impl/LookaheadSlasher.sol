// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/libs/LibEIP4788.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "@eth-fabric/urc/lib/MerkleTree.sol";
import "@eth-fabric/urc/ISlasher.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@solady/src/utils/ext/ithaca/BLS.sol";

/// @title LookaheadSlasher
/// @dev This contract is inherited by the `UnifiedSlasher`
/// @dev The lookahead contained within the beacon state is referred to
/// as the "beacon lookahead"
/// whereas, the lookahead maintained by the preconfing protocol is referred to
/// as the "preconf lookahead"
/// @custom:security-contact security@taiko.xyz
abstract contract LookaheadSlasher {
    /// @dev Evidence for the problematic slot in the preconfer lookahead.
    struct EvidenceLookahead {
        // Timestamp of the problematic slot
        uint256 slotTimestamp;
        // Index of the associated entry in the `lookaheadSlots` array
        uint256 lookaheadSlotsIndex;
    }

    /// @dev Evidence containing the proof of inclusion of `beaconLookaheadValPubKey` at the
    /// problematic slot in beacon lookahead.
    struct EvidenceBeaconValidator {
        // BLS pub key of the validator present within beacon lookahead
        // at `EvidenceLookahead.slotTimestamp`
        BLS.G1Point beaconLookaheadValPubKey;
        // Inclusion proof for the beacon validator pub key in the beacon lookahead
        LibEIP4788.InclusionProof beaconValidatorInclusionProof;
    }

    /// @dev Evidence suggesting that `preconfLookaheadValPubKey` was inserted into the
    /// preconf lookahead at the problematic slot.
    struct EvidenceInvalidOperator {
        // BLS pub key of the validator present within preconfer lookahead
        // at `EvidenceLookahead.slotTimestamp`
        BLS.G1Point preconfLookaheadValPubKey;
        // Used to build the merkle proof to verify that preconf validator belongs to the operator
        // within the preconf lookahead
        IRegistry.SignedRegistration[] operatorRegistrations;
    }

    /// @dev Evidence suggesting that `beaconLookaheadValPubKey` is registered to a valid
    /// opted-in operator in the URC
    struct EvidenceMissingOperator {
        // URC registration proof signifying that `EvidenceBeaconValidator.beaconLookaheadValPubKey`
        // belongs to a valid opted-in URC operator
        IRegistry.RegistrationProof operatorRegistrationProof;
    }

    error InvalidLookaheadSlotsIndex();
    error InvalidRegistrationProofValidator();
    error LookaheadHashMismatch();
    error PreconfValidatorIsSameAsBeaconValidator();
    error PreconfValidatorIsNotRegistered();
    error RegistrationRootMismatch();

    address internal immutable lookaheadStore;

    constructor(address _lookaheadStore) {
        lookaheadStore = _lookaheadStore;
    }

    // Slashing logic
    // --------------------------------------------------------------------------

    /// @dev This is invoked internally by the `UnifiedSlasher` contract
    function _validateLookaheadSlashingEvidence(
        address _urc,
        ISlasher.Commitment calldata _commitment,
        bytes calldata _evidence
    )
        internal
        view
    {
        ILookaheadStore.LookaheadSlot[] memory lookaheadSlots =
            abi.decode(_commitment.payload, (ILookaheadStore.LookaheadSlot[]));

        // (EvidenceLookahead, EvidenceBeaconValidator, EvidenceInvalidOperator ||
        // EvidenceMissingOperator)
        (
            bytes calldata evidenceLookahead,
            bytes calldata evidenceBeaconValidator,
            bytes calldata evidenceInvalidOrMissingOperator
        ) = _decodeEvidenceTuple(_evidence);

        (
            // Timestamp of the epoch preceding the one containing the problematic slot
            uint256 previousEpochTimestamp,
            // Timestamp of the problematic slot
            uint256 slotTimestamp,
            // Problematic slot
            ILookaheadStore.LookaheadSlot memory lookaheadSlot
        ) = _validateLookaheadEvidence(evidenceLookahead, lookaheadSlots);

        BLS.G1Point calldata beaconLookaheadValPubKey = _validateBeaconValidatorEvidence(
            previousEpochTimestamp, slotTimestamp, evidenceBeaconValidator
        );

        if (lookaheadSlots.length != 0 && lookaheadSlot.timestamp == slotTimestamp) {
            // This condition is executed when the problematic slot is a dedicated slot of an
            // operator, but is assigned to the wrong operator i.e the beacon validator is
            // not registered to the operator in the URC.
            _validateInvalidOperatorEvidence(
                _urc, lookaheadSlot, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        } else {
            // This condition is executed when the problematic slot has no assigned operator i.e
            // when it is an advanced proposal slot, or when the lookahead is empty.
            _validateMissingOperatorEvidence(
                _urc,
                previousEpochTimestamp,
                beaconLookaheadValPubKey,
                evidenceInvalidOrMissingOperator
            );
        }
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
        uint256 epochTimestamp = LibPreconfUtils.getEpochtimestampForSlot(slotTimestamp_);

        // Note: Commented to prevent compilation errors with the new LookaheadStore changes
        // Verify that the commitment was accepted by the lookahead store
        // bytes26 lookaheadHash =
        //     ILookaheadStore(lookaheadStore).calculateLookaheadHash(epochTimestamp,
        // _lookaheadSlots); require(
        //     lookaheadHash == ILookaheadStore(lookaheadStore).getLookaheadHash(epochTimestamp),
        //     LookaheadHashMismatch()
        // );

        // Timestamp of the epoch preceding the one containing `slotTimestamp_`.
        // This is used to validate the beacon validator evidence and also serves as the reference
        // timestamp for the missing operator evidence.
        previousEpochTimestamp_ = epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;

        if (_lookaheadSlots.length != 0) {
            lookaheadSlot_ = _lookaheadSlots[evidenceLookahead.lookaheadSlotsIndex];

            // Verify that `slotTimestamp_` is within the range of the timestamp contained in the
            // provided lookahead slot entry.
            if (slotTimestamp_ > lookaheadSlot_.timestamp || slotTimestamp_ < epochTimestamp) {
                revert InvalidLookaheadSlotsIndex();
            }
        }
    }

    /// @dev Verifies that validator public key provided in the evidence is present at the
    /// problematic
    /// slotTimestamp.
    function _validateBeaconValidatorEvidence(
        uint256 _previousEpochTimestamp,
        uint256 _slotTimestamp,
        bytes calldata _evidenceBeaconValidatorBytes
    )
        internal
        view
        returns (BLS.G1Point calldata beaconLookaheadValPubKey_)
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
            evidenceBeaconValidator.beaconLookaheadValPubKey,
            beaconBlockRoot,
            evidenceBeaconValidator.beaconValidatorInclusionProof
        );

        beaconLookaheadValPubKey_ = evidenceBeaconValidator.beaconLookaheadValPubKey;
    }

    function _validateInvalidOperatorEvidence(
        address _urc,
        ILookaheadStore.LookaheadSlot memory _lookaheadSlot,
        BLS.G1Point calldata _beaconLookaheadValPubKey,
        bytes calldata _evidenceInvalidOperatorBytes
    )
        internal
        view
    {
        EvidenceInvalidOperator calldata evidenceInvalidOperator;
        assembly {
            evidenceInvalidOperator := add(_evidenceInvalidOperatorBytes.offset, 0x20)
        }

        // Verify that `preconfLookaheadValPubKey` is the validator present in the preconf lookahead
        // at the problematic slot
        require(
            _isG1Equal(
                evidenceInvalidOperator.preconfLookaheadValPubKey,
                evidenceInvalidOperator.operatorRegistrations[_lookaheadSlot.validatorLeafIndex]
                .pubkey
            ),
            PreconfValidatorIsNotRegistered()
        );

        // Verify that this preconf lookahead validator does not match the beacon lookahead
        // validator
        require(
            !_isG1Equal(
                evidenceInvalidOperator.preconfLookaheadValPubKey, _beaconLookaheadValPubKey
            ),
            PreconfValidatorIsSameAsBeaconValidator()
        );

        // Verify the correctness of `evidenceInvalidOperator.operatorRegistrations`
        IRegistry.OperatorData memory operatorData =
            IRegistry(_urc).getOperatorData(_lookaheadSlot.registrationRoot);
        bytes32[] memory leaves = MerkleTree.hashToLeaves(
            evidenceInvalidOperator.operatorRegistrations, operatorData.owner
        );
        bytes32 registrationRoot = MerkleTree.generateTree(leaves);

        require(registrationRoot == _lookaheadSlot.registrationRoot, RegistrationRootMismatch());
    }

    function _validateMissingOperatorEvidence(
        address _urc,
        uint256 _previousEpochTimestamp,
        BLS.G1Point calldata _beaconLookaheadValPubKey,
        bytes calldata _evidenceMissingOperatorBytes
    )
        internal
        view
    {
        EvidenceMissingOperator calldata evidenceMissingOperator;
        assembly {
            evidenceMissingOperator := add(_evidenceMissingOperatorBytes.offset, 0x20)
        }

        // Verify that `_beaconLookaheadValPubKey` belongs to an operator in the URC.
        IRegistry.RegistrationProof calldata registrationProof =
        evidenceMissingOperator.operatorRegistrationProof;
        require(
            _isG1Equal(registrationProof.registration.pubkey, _beaconLookaheadValPubKey),
            InvalidRegistrationProofValidator()
        );

        IRegistry(_urc).verifyMerkleProof(registrationProof);

        // This is the same reference timestamp that is used in the lookahead store
        uint256 referenceTimestamp =
            _previousEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that this operator was valid at the reference timestamp.
        // This reverts if the operator is not valid at the reference timestamp.
        // TODO: to be shifted to this contract
        // ILookaheadStore(lookaheadStore).isLookaheadOperatorValid(
        //     referenceTimestamp, registrationProof.registrationRoot
        // );
    }

    // Helpers
    // --------------------------------------------------------------------------

    function _isG1Equal(BLS.G1Point memory _a, BLS.G1Point memory _b) internal pure returns (bool) {
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
