// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IRegistry } from "@eth-fabric/urc/IRegistry.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { MerkleTree } from "@eth-fabric/urc/lib/MerkleTree.sol";
import { BLS } from "@solady/src/utils/ext/ithaca/BLS.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LibBLSG1 } from "src/layer1/preconf/libs/LibBLSG1.sol";
import { LibEIP4788 } from "src/layer1/preconf/libs/LibEIP4788.sol";
import { LibLookaheadEncoder } from "src/layer1/preconf/libs/LibLookaheadEncoder.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { IPreconfSlasher } from "src/shared/preconf/IPreconfSlasher.sol";

/// @title PreconfSlasherL1
/// @notice This contract is the common entry point for slashing invalid lookahead and
/// preconfirmation faults.
/// @dev For slashing invalid lookahead, this contract is invoked by the URC.
/// @dev For slashing invalid preconfs, this contract is invoked by `PreconfSlasherL2` via the bridge.
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL1 is ISlasher, IMessageInvocable, EssentialContract {
    using LibBLSG1 for BLS.G1Point;

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
        IPreconfSlasher.SlashingPath path = IPreconfSlasher.SlashingPath(uint8(_evidence[0]));
        bytes calldata evidence = _evidence[1:];

        if (path == IPreconfSlasher.SlashingPath.Lookahead) {
            _validateLookaheadSlashingEvidence(_commitment, evidence);
            slashAmount_ = getSlashingAmounts().invalidLookahead;
        } else {
            // For preconf slashing, `onMessageInvocation` calls the URC, which further
            // calls this slashing function internally
            require(_challenger == address(this), ChallengerIsNotSelf());
            IPreconfSlasher.PreconfirmationFault fault =
                _classifyPreconfFault(_commitment, evidence);
            IPreconfSlasher.SlashingAmounts memory amounts = getSlashingAmounts();
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
                abi.encodePacked(uint8(IPreconfSlasher.SlashingPath.Preconfirmation), uint8(fault))
            );
    }

    // ---------------------------------------------------------------
    // Internal: Lookahead slashing evidence validation
    // ---------------------------------------------------------------

    /// @dev Bundled return data from `_validateLookaheadEvidence`
    struct ValidatedLookaheadEvidence {
        uint256 epochTimestamp;
        uint256 slotTimestamp;
        uint256 numSlots;
        uint256 referenceTimestamp;
        ILookaheadStore.LookaheadSlot lookaheadSlot;
    }

    /// @dev Validates evidence for slashing an invalid lookahead.
    /// @dev Evidence format: [LookaheadFault byte][evidence tuple (bytes, bytes, bytes)]
    /// @dev The evidence tuple contains:
    ///   - EvidenceLookahead (always required)
    ///   - EvidenceBeaconValidator (required for InvalidOperator and MissingOperator faults)
    ///   - EvidenceInvalidOperator or EvidenceMissingOperator (required for respective faults)
    function _validateLookaheadSlashingEvidence(
        Commitment calldata _commitment,
        bytes calldata _evidence
    )
        internal
        view
    {
        IPreconfSlasher.LookaheadFault fault = IPreconfSlasher.LookaheadFault(uint8(_evidence[0]));

        (
            bytes calldata evidenceLookahead,
            bytes calldata evidenceBeaconValidator,
            bytes calldata evidenceInvalidOrMissingOperator
        ) = _decodeEvidenceTuple(_evidence[1:]);

        ValidatedLookaheadEvidence memory evidence =
            _validateLookaheadEvidence(_commitment, evidenceLookahead);

        if (fault == IPreconfSlasher.LookaheadFault.InactiveOperator) {
            // Path 1: Operator in the lookahead was not active at reference timestamp
            require(evidence.numSlots != 0, EmptyLookahead());
            require(
                !ILookaheadStore(lookaheadStore)
                    .isOperatorActive(
                        evidence.lookaheadSlot.registrationRoot, evidence.referenceTimestamp
                    ),
                OperatorIsActive()
            );
        } else if (fault == IPreconfSlasher.LookaheadFault.InvalidValidatorLeafIndex) {
            // Path 2: Validator leaf index exceeds operator's registered key count
            require(evidence.numSlots != 0, EmptyLookahead());
            IRegistry.OperatorData memory opData =
                IRegistry(urc).getOperatorData(evidence.lookaheadSlot.registrationRoot);
            require(
                evidence.lookaheadSlot.validatorLeafIndex >= opData.numKeys,
                ValidValidatorLeafIndex()
            );
        } else {
            // Paths 3 & 4: Require beacon proofs
            uint256 previousEpochTimestamp =
                evidence.epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;

            BLS.G1Point calldata beaconValidatorPubKey = _validateBeaconValidatorEvidence(
                previousEpochTimestamp, evidence.slotTimestamp, evidenceBeaconValidator
            );

            if (fault == IPreconfSlasher.LookaheadFault.InvalidOperator) {
                // Path 3: Dedicated slot assigned to wrong operator
                require(
                    evidence.numSlots != 0
                        && evidence.lookaheadSlot.timestamp == evidence.slotTimestamp,
                    NotADedicatedSlot()
                );
                _validateInvalidOperatorEvidence(
                    evidence.lookaheadSlot, beaconValidatorPubKey, evidenceInvalidOrMissingOperator
                );
            } else {
                // Path 4: Slot unassigned but beacon proposer is valid opted-in operator
                require(
                    evidence.numSlots == 0
                        || evidence.lookaheadSlot.timestamp != evidence.slotTimestamp,
                    SlotHasAssignedOperator()
                );
                _validateMissingOperatorEvidence(
                    evidence.referenceTimestamp,
                    beaconValidatorPubKey,
                    evidenceInvalidOrMissingOperator
                );
            }
        }
    }

    /// @dev Validates the lookahead evidence:
    /// - Ensures that it matches the lookahead in the commitment
    /// - Ensures that the provided slot timestamp falls in the range of the indexed lookahead entry
    function _validateLookaheadEvidence(
        Commitment calldata _commitment,
        bytes calldata _evidenceLookaheadBytes
    )
        internal
        view
        returns (ValidatedLookaheadEvidence memory evidence_)
    {
        IPreconfSlasher.EvidenceLookahead calldata evidenceLookahead;
        assembly {
            evidenceLookahead := add(_evidenceLookaheadBytes.offset, 0x20)
        }

        evidence_.slotTimestamp = evidenceLookahead.slotTimestamp;
        evidence_.epochTimestamp = LibPreconfUtils.getEpochtimestampForSlot(evidence_.slotTimestamp);

        // Verify the encoded lookahead from the evidence matches the commitment
        bytes26 commitmentHash = abi.decode(_commitment.payload, (bytes26));
        bytes26 lookaheadHash = LibPreconfUtils.calculateLookaheadHash(
            evidence_.epochTimestamp, evidenceLookahead.encodedLookahead
        );
        require(lookaheadHash == commitmentHash, LookaheadHashMismatch());

        evidence_.numSlots = LibLookaheadEncoder.numSlots(evidenceLookahead.encodedLookahead);
        evidence_.referenceTimestamp =
            getOperatorValidityReferenceTimestamp(evidence_.epochTimestamp);

        if (evidence_.numSlots != 0) {
            uint256 index = evidenceLookahead.slotIndex;
            evidence_.lookaheadSlot =
                LibLookaheadEncoder.decodeIndex(evidenceLookahead.encodedLookahead, index);

            // Upper bounds check
            require(
                evidence_.slotTimestamp <= evidence_.lookaheadSlot.timestamp, InvalidSlotIndex()
            );

            if (index == 0) {
                // Lower bounds check for the first slot
                require(evidence_.slotTimestamp >= evidence_.epochTimestamp, InvalidSlotIndex());
            } else {
                ILookaheadStore.LookaheadSlot memory prevSlot = LibLookaheadEncoder.decodeIndex(
                    evidenceLookahead.encodedLookahead, index - 1
                );

                // Lower bounds check for later slots
                require(evidence_.slotTimestamp > prevSlot.timestamp, InvalidSlotIndex());
            }
        }
    }

    /// @dev Validates that the BLS public key provided in the evidence belongs to
    /// the validator of the beacon block at `_slotTimestamp`
    function _validateBeaconValidatorEvidence(
        uint256 _previousEpochTimestamp,
        uint256 _slotTimestamp,
        bytes calldata _evidenceBeaconValidatorBytes
    )
        internal
        view
        returns (BLS.G1Point calldata beaconValidatorPubKey_)
    {
        IPreconfSlasher.EvidenceBeaconValidator calldata evidenceBeaconValidator;
        assembly {
            evidenceBeaconValidator := add(_evidenceBeaconValidatorBytes.offset, 0x20)
        }

        // Verify proposer lookahead index matches the expected slot.
        // The beacon proposer lookahead at epoch E-1 covers slots starting from E-1,
        // so slots in epoch E have indices 32+.
        uint256 expectedProposerLookaheadIndex =
            (_slotTimestamp - _previousEpochTimestamp) / LibPreconfConstants.SECONDS_IN_SLOT;
        require(
            evidenceBeaconValidator.beaconProofs.proposerLookaheadProof.proposerLookaheadIndex
                == expectedProposerLookaheadIndex,
            ProposerLookaheadIndexMismatch()
        );

        // Fetch beacon block root via EIP-4788 for the previous epoch
        bytes32 beaconBlockRoot = LibPreconfUtils.getBeaconBlockRootAtOrAfter(
            _previousEpochTimestamp + LibPreconfConstants.SECONDS_IN_SLOT
        );
        require(beaconBlockRoot != bytes32(0), BeaconBlockRootNotAvailable());

        // Verify the proof's beacon block header root matches EIP-4788
        require(
            evidenceBeaconValidator.beaconProofs.beaconStateProof.beaconBlockHeaderRoot
                == beaconBlockRoot,
            BeaconBlockRootMismatch()
        );

        // Verify all beacon merkle proofs
        // (validator pubkey -> proposer lookahead -> beacon state -> block)
        LibEIP4788.verifyBeaconProofs(
            evidenceBeaconValidator.beaconValidatorPubKey, evidenceBeaconValidator.beaconProofs
        );

        beaconValidatorPubKey_ = evidenceBeaconValidator.beaconValidatorPubKey;
    }

    /// @dev Validates evidence for the InvalidOperator fault:
    /// - Ensures that the invalid operator's validator pub key does not match the beacon proposer's key
    /// - Ensures that the invalid operator's validator pub key is a part of the operator's registration
    ///   in the URC
    function _validateInvalidOperatorEvidence(
        ILookaheadStore.LookaheadSlot memory _lookaheadSlot,
        BLS.G1Point calldata _beaconValidatorPubKey,
        bytes calldata _evidenceInvalidOperatorBytes
    )
        internal
        view
    {
        IPreconfSlasher.EvidenceInvalidOperator calldata evidenceInvalidOperator;
        assembly {
            evidenceInvalidOperator := add(_evidenceInvalidOperatorBytes.offset, 0x20)
        }

        // Verify that the operator's validator key is a part of operator's registration
        // at the provided leaf index
        require(
            evidenceInvalidOperator.invalidOperatorValidatorPubKey
                .equals(
                    evidenceInvalidOperator.operatorRegistrations[_lookaheadSlot.validatorLeafIndex]
                    .pubkey
                ),
            PreconfValidatorIsNotRegistered()
        );

        // Verify that the operator's validator does not match the beacon proposer
        require(
            !evidenceInvalidOperator.invalidOperatorValidatorPubKey.equals(_beaconValidatorPubKey),
            PreconfValidatorIsSameAsBeaconValidator()
        );

        // Verify the correctness of `evidenceInvalidOperator.operatorRegistrations`
        IRegistry.OperatorData memory operatorData =
            IRegistry(urc).getOperatorData(_lookaheadSlot.registrationRoot);
        bytes32[] memory leaves = MerkleTree.hashToLeaves(
            evidenceInvalidOperator.operatorRegistrations, operatorData.owner
        );
        bytes32 registrationRoot = MerkleTree.generateTree(leaves);
        require(registrationRoot == _lookaheadSlot.registrationRoot, RegistrationRootMismatch());
    }

    /// @dev Validates evidence for the MissingOperator fault:
    /// - Ensures that the beacon proposer belongs to the operator provided in the evidence
    /// - Ensures that the operator was active at the reference timestamp
    function _validateMissingOperatorEvidence(
        uint256 _referenceTimestamp,
        BLS.G1Point calldata _beaconValidatorPubKey,
        bytes calldata _evidenceMissingOperatorBytes
    )
        internal
        view
    {
        IPreconfSlasher.EvidenceMissingOperator calldata evidenceMissingOperator;
        assembly {
            evidenceMissingOperator := add(_evidenceMissingOperatorBytes.offset, 0x20)
        }

        // Verify that the beacon validator belongs to an operator in the URC
        IRegistry.RegistrationProof calldata registrationProof =
        evidenceMissingOperator.operatorRegistrationProof;
        require(
            registrationProof.registration.pubkey.equals(_beaconValidatorPubKey),
            InvalidRegistrationProofValidator()
        );

        IRegistry(urc).verifyMerkleProof(registrationProof);

        // Verify the operator was active at the reference timestamp
        require(
            ILookaheadStore(lookaheadStore)
                .isOperatorActive(registrationProof.registrationRoot, _referenceTimestamp),
            OperatorNotActive()
        );
    }

    // ---------------------------------------------------------------
    // Internal: Preconfirmation slashing evidence processing
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

    /// @dev Returns the timestamp at which operator validity is checked.
    /// @dev The lookahead for epoch E is posted at the beginning of epoch E - 1.
    /// So, the reference timestamp is the beginning of epoch E - 2.
    /// @param _epochTimestamp The beginning timestamp of the lookahead's epoch.
    /// @return The reference timestamp for operator validity checks.
    function getOperatorValidityReferenceTimestamp(uint256 _epochTimestamp)
        public
        pure
        returns (uint256)
    {
        return _epochTimestamp - LibPreconfConstants.TWO_EPOCHS;
    }

    function getSlashingAmounts() public pure returns (IPreconfSlasher.SlashingAmounts memory) {
        // Note: These amounts will change
        return IPreconfSlasher.SlashingAmounts({
            invalidLookahead: 1 ether, preconfLivenessFault: 0.5 ether, preconfSafetyFault: 1 ether
        });
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

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

    error BeaconBlockRootMismatch();
    error BeaconBlockRootNotAvailable();
    error CallerIsNotPreconfSlasherL2();
    error ChallengerIsNotSelf();
    error EmptyLookahead();
    error InvalidSlotIndex();
    error InvalidRegistrationProofValidator();
    error LookaheadHashMismatch();
    error NotADedicatedSlot();
    error OperatorIsActive();
    error OperatorNotActive();
    error PreconfValidatorIsSameAsBeaconValidator();
    error PreconfValidatorIsNotRegistered();
    error ProposerLookaheadIndexMismatch();
    error RegistrationRootMismatch();
    error SlotHasAssignedOperator();
    error ValidValidatorLeafIndex();
}
