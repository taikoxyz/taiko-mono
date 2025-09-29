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
        bytes32 anchorBlockNumber;
        // Keccak256 hash of the raw list of transactions included in the parent block
        bytes32 parentRawTxListHash;
        // Keccak256 hash of the raw list of transactions included in the block
        bytes32 rawTxListHash;
        // The timestamp of the preconfer's slot in the lookahead
        uint256 submissionWindowEnd;
    }

    // The slashing reason forwarded to the L1 preconfirmation slasher
    enum Fault {
        Liveness,
        Safety
    }

    error InvalidEOPFlag();
    error NotALivenessFault();
    error NotASafetyFault();
    error ParentRawTxListHashMismatch();
    error UnexpectedExtraProposalsInPreviousWindow();

    /// @notice Validates if a preconfirmation is slashable and forwards the fault to the
    /// L1 preconfirmation slasher.
    /// @param _fault The fault that needs to be checked
    /// @param _preconfirmation The preconfirmation object to slash
    function slash(Fault _fault, Preconfirmation calldata _preconfirmation) external;
}
