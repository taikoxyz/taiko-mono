// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/preconf/libs/LibEIP4788.sol";
import "@eth-fabric/urc/ISlasher.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@solady/src/utils/ext/ithaca/BLS.sol";

/// @title ILookaheadSlasher
/// @dev The lookahead contained within the beacon state is referred to
/// as the "beacon lookahead"
/// whereas, the lookahead maintained by the preconfing protocol is referred to
/// as the "preconf lookahead"
/// @dev The contract inherits from the `ISlasher` interface containing the `slash` function
/// required by the URC.
/// @custom:security-contact security@taiko.xyz
interface ILookaheadSlasher is ISlasher {
    /// @dev Evidence for the problematic slot in the preconfer lookahead.
    struct EvidenceLookahead {
        // Timestamp of the problematic slot
        uint256 slotTimestamp;
        // Index of the problematic slot in the lookahead slots array
        uint256 lookaheadSlotsIndex;
    }

    /// @dev Evidence for validator pub key and its inclusion proof within the beacon lookahead at
    /// the problematic slot.
    struct EvidenceBeaconValidator {
        // BLS pub key of the validator present within beacon lookahead
        // at `EvidenceLookahead.slotTimestamp`
        BLS.G1Point beaconValidatorPubKey;
        // Inclusion proof for the beacon validator pub key in the beacon lookahead
        LibEIP4788.InclusionProof beaconValidatorInclusionProof;
    }

    /// @dev Evidence for when an invalid operator is inserted at a specific preconfer
    /// lookahead slot
    struct EvidenceInvalidOperator {
        // BLS pub key of the validator present within preconfer lookahead
        // at `EvidenceLookahead.slotTimestamp`
        BLS.G1Point preconfValidatorPubKey;
        // Used to build the merkle proof to verify that preconf validator belongs to the operator
        // within the preconf lookahead
        IRegistry.SignedRegistration[] operatorRegistrations;
    }

    /// @dev Evidence for when an operator is missing from the preconfer lookahead.
    struct EvidenceMissingOperator {
        // URC registration proof signifying that `EvidenceBeaconValidator.beaconValidatorPubKey`
        // belongs to a valid opted-in URC operator
        IRegistry.RegistrationProof operatorRegistrationProof;
    }

    error InvalidLookaheadSlotsIndex();
    error InvalidRegistrationProofValidator();
    error LookaheadHashMismatch();
    error OperatorHasBeenBlacklisted();
    error OperatorHasBeenSlashed();
    error OperatorHasInsufficientCollateral();
    error OperatorHasNotOptedIn();
    error OperatorHasNotOptedOut();
    error OperatorHasNotRegistered();
    error OperatorHasUnregistered();
    error PreconfValidatorIsSameAsBeaconValidator();
    error PreconfValidatorIsNotRegistered();
    error RegistrationRootMismatch();
}
