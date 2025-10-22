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
        // The preconfer did not submit a preconfed block
        // (If the submission slot on L1 is a missed slot, it's a liveness fault, else a safety
        // fault)
        MissedSubmission,
        // The last preconfirmation in an assigned window does not have the eop flag set to `true`
        // (If the submission slot on L1 is a missed slot, it's a liveness fault, else a safety
        // fault)
        MissingEOP,
        // The preconfirmed raw transaction list hash or anchor block value do not match the
        // submitted value.
        // (Safety fault)
        RawTxListHashOrAnchorBlockMismatch,
        // A non-terminal preconfirmation has its eop flag set to `true`
        // (Safety fault)
        InvalidEOP
    }

    /// @notice A Commitment message binding an opaque payload to a slasher contract
    /// @dev This is extracted from URC's `ISlasher` to enable compilation to Shanghai.
    struct Commitment {
        /// The type of commitment
        uint64 commitmentType;
        /// The payload of the commitment
        bytes payload;
        /// The address of the slasher contract
        address slasher;
    }

    /// @notice A commitment message signed by a delegate's ECDSA key
    /// @dev This is extracted from URC's `ISlasher` to enable compilation to Shanghai.
    struct SignedCommitment {
        /// The commitment message
        Commitment commitment;
        /// The signature of the commitment message
        bytes signature;
    }

    error EOPOnlyPreconfirmationDoesNotRequireSubmission();
    error InvalidEOPFlag();
    error NotALivenessFault();
    error NotAMissedSubmission();
    error NotAnInvalidEOP();
    error NotARawTxListHashOrAnchorBlockMismatch();
    error ParentRawTxListHashMismatch();
    error ParentSubmissionWindowEndMismatch();
    error SubmissionWindowMismatch();
    error UnexpectedExtraProposalsInPreviousWindow();

    /// @notice Validates if a preconfirmation is slashable and forwards the fault to the
    /// L1 preconfirmation slasher.
    /// @param _fault The fault that needs to be checked
    /// @param _evidenceBlockNumber An "evidence" height to fetch the `PreconfMeta` for an EOP-only
    /// preconfirmation
    /// @param _registrationRoot The urc registration root of the operator being
    /// slashed
    /// @param _signedCommitment The signed preconfirmation commitment to slash
    function slash(
        Fault _fault,
        uint256 _evidenceBlockNumber,
        bytes32 _registrationRoot,
        SignedCommitment calldata _signedCommitment
    )
        external;
}
