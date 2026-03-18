// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfSlasher
/// @dev Contains entities that are shared by both PreconfSlasherL1 and PreconfSlasherL2
/// @custom:security-contact security@taiko.xyz
interface IPreconfSlasher {
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
        // The preconfer did not submit a preconfed block to the L1 inbox
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
}
