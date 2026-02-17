// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IRegistry } from "@eth-fabric/urc/IRegistry.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { MerkleTree } from "@eth-fabric/urc/lib/MerkleTree.sol";
import { BLS } from "@solady/src/utils/ext/ithaca/BLS.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LibEIP4788 } from "src/layer1/preconf/libs/LibEIP4788.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { IPreconfSlasher } from "src/shared/preconf/IPreconfSlasher.sol";

/// @title PreconfSlasherL1
/// @notice This contract is the common entry point for slashing invalid lookahead and
/// preconfirmation faults.
/// @dev For slashing invalid lookahead, this contract is invoked by the URC.
/// @dev For slashing invalid preconfs, this contract is invoked by `PreconfSlasherL2`
/// via the bridge.
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL1 is ISlasher, IMessageInvocable, EssentialContract {
    // ---------------------------------------------------------------
    // Enums
    // ---------------------------------------------------------------

    /// @dev Used as the first byte of the evidence to identify the slashing path
    enum SlashingPath {
        Lookahead,
        Preconfirmation
    }

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    struct SlashingAmounts {
        uint256 invalidLookahead;
        uint256 preconfLivenessFault;
        uint256 preconfSafetyFault;
    }

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

    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    address public immutable lookaheadStore;
    address public immutable urc;
    address public immutable preconfSlasherL2;
    address public immutable bridge;

    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor & Init
    // ---------------------------------------------------------------

    constructor(
        address _lookaheadStore,
        address _urc,
        address _preconfSlasherL2,
        address _bridge
    ) {
        lookaheadStore = _lookaheadStore;
        urc = _urc;
        preconfSlasherL2 = _preconfSlasherL2;
        bridge = _bridge;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // ISlasher implementation
    // ---------------------------------------------------------------

    /// @notice Called by the URC to slash a commitment
    /// @dev Routes between lookahead and preconfirmation slashing paths based on the
    /// first byte of evidence
    function slash(
        Delegation calldata, // delegation
        Commitment calldata _commitment,
        address, // committer
        bytes calldata _evidence,
        address _challenger
    )
        external
        view
        onlyFrom(urc)
        returns (uint256 slashAmount_)
    {
        SlashingPath path = SlashingPath(uint8(_evidence[0]));
        bytes calldata evidence = _evidence[1:];

        if (path == SlashingPath.Lookahead) {
            _validateLookaheadSlashingEvidence(urc, _commitment, evidence);
            slashAmount_ = getSlashingAmounts().invalidLookahead;
        } else {
            // For preconf slashing, `onMessageInvocation` calls the URC, which further
            // calls this slashing function internally
            require(_challenger == address(this), ChallengerIsNotSelf());
            IPreconfSlasher.PreconfirmationFault fault =
                _classifyPreconfFault(_commitment, evidence);
            SlashingAmounts memory amounts = getSlashingAmounts();
            slashAmount_ = fault == IPreconfSlasher.PreconfirmationFault.Liveness
                ? amounts.preconfLivenessFault
                : amounts.preconfSafetyFault;
        }
    }

    // ---------------------------------------------------------------
    // IMessageInvocable implementation
    // ---------------------------------------------------------------

    /// @notice Called by the bridge when PreconfSlasherL2 sends a slashing request
    function onMessageInvocation(bytes calldata _data) external payable onlyFrom(bridge) {
        IBridge.Context memory ctx = IBridge(bridge).context();
        require(ctx.from == preconfSlasherL2, CallerIsNotPreconfSlasherL2());

        (
            IPreconfSlasher.PreconfirmationFault fault,
            bytes32 registrationRoot,
            ISlasher.SignedCommitment memory signedCommitment
        ) = abi.decode(
            _data, (IPreconfSlasher.PreconfirmationFault, bytes32, ISlasher.SignedCommitment)
        );

        // Slash the operator via the URC
        IRegistry(urc)
            .slashCommitment(
                registrationRoot,
                signedCommitment,
                abi.encodePacked(uint8(SlashingPath.Preconfirmation), uint8(fault))
            );
    }

    // ---------------------------------------------------------------
    // Internal: Lookahead slashing validation
    // ---------------------------------------------------------------

    /// @dev Validates evidence for slashing an invalid lookahead
    function _validateLookaheadSlashingEvidence(
        address _urc,
        Commitment calldata _commitment,
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

    // ---------------------------------------------------------------
    // Internal: Evidence validation
    // ---------------------------------------------------------------

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
        // bytes26 lookaheadHash =
        //     ILookaheadStore(lookaheadStore).calculateLookaheadHash(epochTimestamp,
        //         _lookaheadSlots);
        // require(
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
    /// problematic slotTimestamp.
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

        // Verify that `preconfLookaheadValPubKey` is the validator present in the preconf
        // lookahead at the problematic slot
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

        // TODO: to be shifted to this contract
        // ILookaheadStore(lookaheadStore).isLookaheadOperatorValid(
        //     referenceTimestamp, registrationProof.registrationRoot
        // );
    }

    // ---------------------------------------------------------------
    // Internal: Preconf fault classification
    // ---------------------------------------------------------------

    /// @dev Classifies the preconf fault on L1. A liveness fault becomes a safety fault
    /// if the preconfer did not miss its L1 slot.
    function _classifyPreconfFault(
        Commitment calldata _commitment,
        bytes calldata _evidence
    )
        internal
        view
        returns (IPreconfSlasher.PreconfirmationFault)
    {
        IPreconfSlasher.PreconfirmationFault fault =
            IPreconfSlasher.PreconfirmationFault(uint8(_evidence[0]));

        if (fault == IPreconfSlasher.PreconfirmationFault.Liveness) {
            IPreconfSlasher.Preconfirmation memory preconfirmation =
                abi.decode(_commitment.payload, (IPreconfSlasher.Preconfirmation));
            // If the L1 slot had a block, the preconfer had the chance to submit
            if (
                LibPreconfUtils.getBeaconBlockRootAt(preconfirmation.submissionWindowEnd)
                    != bytes32(0)
            ) {
                return IPreconfSlasher.PreconfirmationFault.Safety;
            }
        }

        return fault;
    }

    // ---------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------

    function getSlashingAmounts() public pure returns (SlashingAmounts memory) {
        // Note: These amounts will change
        return SlashingAmounts({
            invalidLookahead: 1 ether, preconfLivenessFault: 0.5 ether, preconfSafetyFault: 1 ether
        });
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _isG1Equal(
        BLS.G1Point memory _a,
        BLS.G1Point memory _b
    )
        internal
        pure
        returns (bool)
    {
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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error CallerIsNotPreconfSlasherL2();
    error ChallengerIsNotSelf();
    error InvalidLookaheadSlotsIndex();
    error InvalidRegistrationProofValidator();
    error LookaheadHashMismatch();
    error PreconfValidatorIsSameAsBeaconValidator();
    error PreconfValidatorIsNotRegistered();
    error RegistrationRootMismatch();
}
