// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfSlasherL2
/// @custom:security-contact security@taiko.xyz
interface IPreconfSlasherL2 {
    // The object that is preconfirmed
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

    // The slashing reason forwarded to the L1 preconfirmation slasher
    enum Fault {
        // Every "liveness fault" computed on L2 is a "potential" liveness fault.
        // It is the L1 contract that further confirms it.
        PotentialLiveness,
        Liveness,
        Safety
    }

    // Note: `Commitment` and `SignedCommitment` are extracted here from URC's ISlasher,
    // since Cancun specific opcodes in ISlasher are not allowing compilation to Shanghai.

    /// @notice A Commitment message binding an opaque payload to a slasher contract
    struct Commitment {
        /// The type of commitment
        uint64 commitmentType;
        /// The payload of the commitment
        bytes payload;
        /// The address of the slasher contract
        address slasher;
    }

    /// @notice A commitment message signed by a delegate's ECDSA key
    struct SignedCommitment {
        /// The commitment message
        Commitment commitment;
        /// The signature of the commitment message
        bytes signature;
    }

    error InvalidEOPFlag();
    error NotALivenessFault();
    error NotASafetyFault();
    error ParentRawTxListHashMismatch();
    error ParentSubmissionWindowEndMismatch();
    error UnexpectedExtraProposalsInPreviousWindow();

    /// @notice Validates if a preconfirmation is slashable and forwards the fault to the
    /// L1 preconfirmation slasher.
    /// @param _fault The fault that needs to be checked
    /// @param _registrationRoot The urc registration root of the operator being slashed
    /// @param _signedCommitment The signed preconfirmation commitment to slash
    function slash(
        Fault _fault,
        bytes32 _registrationRoot,
        SignedCommitment calldata _signedCommitment
    )
        external;
}
