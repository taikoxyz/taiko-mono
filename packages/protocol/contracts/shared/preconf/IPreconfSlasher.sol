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
    enum PreconfirmationFault {
        // A liveness fault: the preconfer missed a submission or missed the EOP flag.
        // On L1, this is further classified: if the L1 slot had a block, it becomes a Safety fault.
        Liveness,
        // A safety fault: the preconfirmed data does not match the submitted data,
        // or an invalid EOP flag was set.
        Safety
    }
}
