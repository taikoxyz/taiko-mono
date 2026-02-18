// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRegistry } from "@eth-fabric/urc/IRegistry.sol";
import { BLS } from "@solady/src/utils/ext/ithaca/BLS.sol";
import { LibEIP4788 } from "src/layer1/preconf/libs/LibEIP4788.sol";

/// @title IPreconfSlasher
/// @dev Contains entities that are shared by both PreconfSlasherL1 and PreconfSlasherL2
/// @custom:security-contact security@taiko.xyz
interface IPreconfSlasher {
    // ---------------------------------------------------------------
    // Common
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

    // ---------------------------------------------------------------
    // Lookahead fault
    // ---------------------------------------------------------------

    /// @dev Used as the second byte of the lookahead evidence to identify the fault type
    enum LookaheadFault {
        InactiveOperator,
        InvalidValidatorLeafIndex,
        InvalidOperator,
        MissingOperator
    }

    /// @dev Evidence containing the invalid lookahead with the index and timestamp
    // of the invalid slot
    struct EvidenceLookahead {
        // Timestamp of the invalid slot
        uint256 slotTimestamp;
        // Index of the lookahead entry that covers the invalid slot
        uint256 slotIndex;
        // The encoded lookahead bytes (from LibLookaheadEncoder)
        bytes encodedLookahead;
    }

    /// @dev Evidence containing the proof of inclusion of the validator pub key at
    /// `EvidenceLookahead.slotTimestamp` in beacon lookahead.
    struct EvidenceBeaconValidator {
        // BLS pub key of the validator present within beacon lookahead
        // at `EvidenceLookahead.slotTimestamp`
        BLS.G1Point beaconValidatorPubKey;
        // Beacon chain merkle proofs for validator inclusion
        LibEIP4788.BeaconProofs beaconProofs;
    }

    /// @dev Evidence containing `invalidOperatorValidatorPubKey` that is a part of operator
    /// registrations in the URC, but does not match the beacon validator pub key at the
    /// invalid lookahead slot.
    struct EvidenceInvalidOperator {
        // BLS pub key of the validator registered to the operator in the URC and located at
        // `ILookaheadStore.LookaheadSlot.validatorLeafIndex` within `operatorRegistrations`
        BLS.G1Point invalidOperatorValidatorPubKey;
        // An array containing all validator registrations for the operator in the URC
        IRegistry.SignedRegistration[] operatorRegistrations;
    }

    /// @dev Evidence suggesting that `beaconValidatorPubKey` is registered to a valid
    /// opted-in operator in the URC
    struct EvidenceMissingOperator {
        // URC registration proof signifying that `EvidenceBeaconValidator.beaconValidatorPubKey`
        // belongs to a valid opted-in URC operator
        IRegistry.RegistrationProof operatorRegistrationProof;
    }

    // ---------------------------------------------------------------
    // Preconfirmation fault
    // ---------------------------------------------------------------

    /// @dev The slashing reason forwarded to the L1 preconfirmation slasher
    enum PreconfirmationFault {
        // A liveness fault: the preconfer missed a submission or missed the EOP flag.
        // On L1, this is further classified: if the L1 slot had a block, it becomes a Safety fault.
        Liveness,
        // A safety fault: the preconfirmed data does not match the submitted data,
        // or an invalid EOP flag was set.
        Safety
    }

    /// @dev The object that is preconfirmed
    struct Preconfirmation {
        // End of preconfirmation flag
        bool eop;
        // Height of the preconfirmed block
        uint256 blockNumber;
        // Height of the L1 block chosen as anchor for the preconfirmed block
        uint256 anchorBlockNumber;
        // Keccak256 hash of the raw list of transactions included in the parent block
        bytes32 parentRawTxListHash;
        // Keccak256 hash of the raw list of transactions included in the block
        bytes32 rawTxListHash;
        // The expected submission window of the parent block
        uint256 parentSubmissionWindowEnd;
        // The timestamp of the preconfer's slot in the lookahead
        uint256 submissionWindowEnd;
    }
}
