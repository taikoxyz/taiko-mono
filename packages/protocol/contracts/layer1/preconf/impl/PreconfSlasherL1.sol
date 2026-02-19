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
    // Types
    // ---------------------------------------------------------------

    /// @dev Used as the first byte of the evidence to identify the slashing path
    enum SlashingPath {
        Lookahead,
        Preconfirmation
    }

    /// @dev Slashing amounts for different fault types
    struct SlashingAmounts {
        // Amount slashed for an invalid lookahead
        uint256 invalidLookahead;
        // Amount slashed for a preconfirmation liveness fault
        uint256 preconfLivenessFault;
        // Amount slashed for a preconfirmation safety fault
        uint256 preconfSafetyFault;
    }

    /// @dev Used as the second byte of the lookahead evidence to identify the fault type
    enum LookaheadFault {
        InactiveOperator,
        InvalidValidatorLeafIndex,
        InvalidOperator,
        MissingOperator
    }

    /// @dev Evidence containing the invalid lookahead with the index and timestamp
    // of the invalid slot
    struct LookaheadEvidence {
        // Timestamp of the invalid slot
        uint256 slotTimestamp;
        // Index of the lookahead entry that covers the invalid slot
        uint256 slotIndex;
        // The encoded lookahead bytes (from LibLookaheadEncoder)
        bytes encodedLookahead;
    }

    /// @dev Evidence containing the proof of inclusion of the validator pub key at
    /// `LookaheadEvidence.slotTimestamp` in beacon lookahead.
    struct BeaconValidatorEvidence {
        // BLS pub key of the validator present within beacon lookahead
        // at `LookaheadEvidence.slotTimestamp`
        BLS.G1Point beaconValidatorPubKey;
        // Beacon chain merkle proofs for validator inclusion
        LibEIP4788.BeaconProofs beaconProofs;
    }

    /// @dev Evidence containing `invalidOperatorValidatorPubKey` that is a part of operator
    /// registrations in the URC, but does not match the beacon validator pub key at the
    /// invalid lookahead slot.
    struct InvalidOperatorEvidence {
        // BLS pub key of the validator registered to the operator in the URC and located at
        // `ILookaheadStore.LookaheadSlot.validatorLeafIndex` within `operatorRegistrations`
        BLS.G1Point invalidOperatorValidatorPubKey;
        // An array containing all validator registrations for the operator in the URC
        IRegistry.SignedRegistration[] operatorRegistrations;
    }

    /// @dev Evidence suggesting that `beaconValidatorPubKey` is registered to a valid
    /// opted-in operator in the URC
    struct MissingOperatorEvidence {
        // URC registration proof signifying that `BeaconValidatorEvidence.beaconValidatorPubKey`
        // belongs to a valid opted-in URC operator
        IRegistry.RegistrationProof operatorRegistrationProof;
    }

    /// @dev Bundled return data from `_validateLookaheadEvidence`
    struct ValidatedLookaheadEvidence {
        uint256 epochTimestamp;
        uint256 slotTimestamp;
        uint256 numSlots;
        uint256 referenceTimestamp;
        ILookaheadStore.LookaheadSlot lookaheadSlot;
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

    /// @inheritdoc ISlasher
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
            _validateLookaheadSlashingEvidence(_commitment, evidence);
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
    // Internal: Lookahead slashing evidence validation
    // ---------------------------------------------------------------

    /// @dev Validates evidence for slashing an invalid lookahead.
    /// @dev Evidence format: [LookaheadFault byte][evidence tuple (bytes, bytes, bytes)]
    /// @dev The evidence tuple contains:
    ///   - LookaheadEvidence (always required)
    ///   - BeaconValidatorEvidence (required for InvalidOperator and MissingOperator faults)
    ///   - InvalidOperatorEvidence or MissingOperatorEvidence (required for respective faults)
    function _validateLookaheadSlashingEvidence(
        Commitment calldata _commitment,
        bytes calldata _evidence
    )
        internal
        view
    {
        LookaheadFault fault = LookaheadFault(uint8(_evidence[0]));
        bytes calldata evidenceBody = _evidence[1:];

        ValidatedLookaheadEvidence memory validatedLookaheadEvidence =
            _validateLookaheadEvidence(_commitment, _extractLookaheadEvidence(evidenceBody));

        if (fault == LookaheadFault.InactiveOperator) {
            // Path 1: Operator in the lookahead was not active at reference timestamp
            require(validatedLookaheadEvidence.numSlots != 0, EmptyLookahead());
            require(
                !ILookaheadStore(lookaheadStore)
                    .isOperatorActive(
                        validatedLookaheadEvidence.lookaheadSlot.registrationRoot,
                        validatedLookaheadEvidence.referenceTimestamp
                    ),
                OperatorIsActive()
            );
        } else if (fault == LookaheadFault.InvalidValidatorLeafIndex) {
            // Path 2: Validator leaf index exceeds operator's registered key count
            require(validatedLookaheadEvidence.numSlots != 0, EmptyLookahead());
            IRegistry.OperatorData memory opData = IRegistry(urc)
                .getOperatorData(validatedLookaheadEvidence.lookaheadSlot.registrationRoot);
            require(
                validatedLookaheadEvidence.lookaheadSlot.validatorLeafIndex >= opData.numKeys,
                ValidValidatorLeafIndex()
            );
        } else {
            // Paths 3 & 4: Require beacon proofs
            uint256 previousEpochTimestamp =
                validatedLookaheadEvidence.epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;

            BLS.G1Point calldata beaconValidatorPubKey = _validateBeaconValidatorEvidence(
                previousEpochTimestamp,
                validatedLookaheadEvidence.slotTimestamp,
                _extractBeaconValidatorEvidence(evidenceBody)
            );

            if (fault == LookaheadFault.InvalidOperator) {
                // Path 3: Dedicated slot assigned to wrong operator
                require(
                    validatedLookaheadEvidence.numSlots != 0
                        && validatedLookaheadEvidence.lookaheadSlot.timestamp
                            == validatedLookaheadEvidence.slotTimestamp,
                    NotADedicatedSlot()
                );
                _validateInvalidOperatorEvidence(
                    validatedLookaheadEvidence.lookaheadSlot,
                    beaconValidatorPubKey,
                    _extractInvalidOperatorEvidence(evidenceBody)
                );
            } else {
                // Path 4: Slot unassigned but beacon proposer is valid opted-in operator
                require(
                    validatedLookaheadEvidence.numSlots == 0
                        || validatedLookaheadEvidence.lookaheadSlot.timestamp
                            != validatedLookaheadEvidence.slotTimestamp,
                    SlotHasAssignedOperator()
                );
                _validateMissingOperatorEvidence(
                    validatedLookaheadEvidence.referenceTimestamp,
                    beaconValidatorPubKey,
                    _extractMissingOperatorEvidence(evidenceBody)
                );
            }
        }
    }

    /// @dev Validates the lookahead evidence:
    /// - Ensures that it matches the lookahead in the commitment
    /// - Ensures that the provided slot timestamp falls in the range of the indexed lookahead entry
    function _validateLookaheadEvidence(
        Commitment calldata _commitment,
        LookaheadEvidence calldata _lookaheadEvidence
    )
        internal
        view
        returns (ValidatedLookaheadEvidence memory evidence_)
    {
        evidence_.slotTimestamp = _lookaheadEvidence.slotTimestamp;
        evidence_.epochTimestamp = LibPreconfUtils.getEpochtimestampForSlot(evidence_.slotTimestamp);

        // Verify the encoded lookahead from the evidence matches the commitment
        bytes26 commitmentHash = abi.decode(_commitment.payload, (bytes26));
        bytes26 lookaheadHash = LibPreconfUtils.calculateLookaheadHash(
            evidence_.epochTimestamp, _lookaheadEvidence.encodedLookahead
        );
        require(lookaheadHash == commitmentHash, LookaheadHashMismatch());

        evidence_.numSlots = LibLookaheadEncoder.numSlots(_lookaheadEvidence.encodedLookahead);
        evidence_.referenceTimestamp =
            getOperatorValidityReferenceTimestamp(evidence_.epochTimestamp);

        if (evidence_.numSlots != 0) {
            uint256 index = _lookaheadEvidence.slotIndex;
            evidence_.lookaheadSlot =
                LibLookaheadEncoder.decodeIndex(_lookaheadEvidence.encodedLookahead, index);

            // Upper bounds check
            require(
                evidence_.slotTimestamp <= evidence_.lookaheadSlot.timestamp, InvalidSlotIndex()
            );

            if (index == 0) {
                // Lower bounds check for the first slot
                require(evidence_.slotTimestamp >= evidence_.epochTimestamp, InvalidSlotIndex());
            } else {
                ILookaheadStore.LookaheadSlot memory prevSlot = LibLookaheadEncoder.decodeIndex(
                    _lookaheadEvidence.encodedLookahead, index - 1
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
        BeaconValidatorEvidence calldata _beaconValidatorEvidence
    )
        internal
        view
        returns (BLS.G1Point calldata beaconValidatorPubKey_)
    {
        // Verify proposer lookahead index matches the expected slot.
        // The beacon proposer lookahead at epoch E-1 covers slots starting from E-1,
        // so slots in epoch E have indices 32+.
        uint256 expectedProposerLookaheadIndex =
            (_slotTimestamp - _previousEpochTimestamp) / LibPreconfConstants.SECONDS_IN_SLOT;
        require(
            _beaconValidatorEvidence.beaconProofs.proposerLookaheadProof.proposerLookaheadIndex
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
            _beaconValidatorEvidence.beaconProofs.beaconStateProof.beaconBlockHeaderRoot
                == beaconBlockRoot,
            BeaconBlockRootMismatch()
        );

        // Verify all beacon merkle proofs
        // (validator pubkey -> proposer lookahead -> beacon state -> block)
        LibEIP4788.verifyBeaconProofs(
            _beaconValidatorEvidence.beaconValidatorPubKey, _beaconValidatorEvidence.beaconProofs
        );

        beaconValidatorPubKey_ = _beaconValidatorEvidence.beaconValidatorPubKey;
    }

    /// @dev Validates evidence for the InvalidOperator fault:
    /// - Ensures that the invalid operator's validator pub key does not match the beacon proposer's key
    /// - Ensures that the invalid operator's validator pub key is a part of the operator's registration
    ///   in the URC
    function _validateInvalidOperatorEvidence(
        ILookaheadStore.LookaheadSlot memory _lookaheadSlot,
        BLS.G1Point calldata _beaconValidatorPubKey,
        InvalidOperatorEvidence calldata _invalidOperatorEvidence
    )
        internal
        view
    {
        // Verify that the operator's validator key is a part of operator's registration
        // at the provided leaf index
        require(
            _invalidOperatorEvidence.invalidOperatorValidatorPubKey
                .equals(
                    _invalidOperatorEvidence.operatorRegistrations[
                        _lookaheadSlot.validatorLeafIndex
                    ].pubkey
                ),
            PreconfValidatorIsNotRegistered()
        );

        // Verify that the operator's validator does not match the beacon proposer
        require(
            !_invalidOperatorEvidence.invalidOperatorValidatorPubKey.equals(_beaconValidatorPubKey),
            PreconfValidatorIsSameAsBeaconValidator()
        );

        // Verify the correctness of `_invalidOperatorEvidence.operatorRegistrations`
        IRegistry.OperatorData memory operatorData =
            IRegistry(urc).getOperatorData(_lookaheadSlot.registrationRoot);
        bytes32[] memory leaves = MerkleTree.hashToLeaves(
            _invalidOperatorEvidence.operatorRegistrations, operatorData.owner
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
        MissingOperatorEvidence calldata _missingOperatorEvidence
    )
        internal
        view
    {
        // Verify that the beacon validator belongs to an operator in the URC
        IRegistry.RegistrationProof calldata registrationProof =
        _missingOperatorEvidence.operatorRegistrationProof;
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

    /// @dev Returns the slashing amounts for different types of faults
    /// @return SlashingAmounts struct containing the amounts for each fault type
    function getSlashingAmounts() public pure returns (SlashingAmounts memory) {
        return SlashingAmounts({
            invalidLookahead: 1 ether, preconfLivenessFault: 0.5 ether, preconfSafetyFault: 1 ether
        });
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Extracts LookaheadEvidence from the first slot of the evidence body
    ///      _evidenceBody: abi.encode((bytes, bytes, bytes))
    ///                                   ^ extract this
    function _extractLookaheadEvidence(bytes calldata _evidenceBody)
        internal
        pure
        returns (LookaheadEvidence calldata lookaheadEvidence_)
    {
        assembly {
            let outerOffset := calldataload(_evidenceBody.offset)
            outerOffset := add(_evidenceBody.offset, outerOffset)
            lookaheadEvidence_ := add(outerOffset, 0x40)
        }
    }

    /// @dev Extracts BeaconValidatorEvidence from the second slot of the evidence body
    ///      _evidenceBody: abi.encode((bytes, bytes, bytes))
    ///                                          ^ extract this
    function _extractBeaconValidatorEvidence(bytes calldata _evidenceBody)
        internal
        pure
        returns (BeaconValidatorEvidence calldata beaconValidatorEvidence_)
    {
        assembly {
            let outerOffset := calldataload(add(_evidenceBody.offset, 0x20))
            outerOffset := add(_evidenceBody.offset, outerOffset)
            beaconValidatorEvidence_ := add(outerOffset, 0x40)
        }
    }

    /// @dev Extracts InvalidOperatorEvidence from the third slot of the evidence body
    ///      _evidenceBody: abi.encode((bytes, bytes, bytes))
    ///                                                 ^ extract this
    function _extractInvalidOperatorEvidence(bytes calldata _evidenceBody)
        internal
        pure
        returns (InvalidOperatorEvidence calldata invalidOperatorEvidence_)
    {
        assembly {
            let outerOffset := calldataload(add(_evidenceBody.offset, 0x40))
            outerOffset := add(_evidenceBody.offset, outerOffset)
            invalidOperatorEvidence_ := add(outerOffset, 0x40)
        }
    }

    /// @dev Extracts MissingOperatorEvidence from the third slot of the evidence body
    ///      _evidenceBody: abi.encode((bytes, bytes, bytes))
    ///                                                 ^ extract this
    function _extractMissingOperatorEvidence(bytes calldata _evidenceBody)
        internal
        pure
        returns (MissingOperatorEvidence calldata missingOperatorEvidence_)
    {
        assembly {
            let outerOffset := calldataload(add(_evidenceBody.offset, 0x40))
            outerOffset := add(_evidenceBody.offset, outerOffset)
            missingOperatorEvidence_ := add(outerOffset, 0x40)
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
