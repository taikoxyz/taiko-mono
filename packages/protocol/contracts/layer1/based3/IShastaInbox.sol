// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IShastaInbox
/// @notice Interface for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
interface IShastaInbox {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Proposal {
        // Slot 1: 160 + 48 + 48 = 256 bits
        address proposer;
        address prover;
        uint48 livenessBond;
        uint48 proposedAt;
        uint48 id;
        // Slot 2
        bytes32 latestL1BlockHash;
        // Slot 3
        bytes32 blobDataHash;
    }

    struct Claim {
        // Slot 1
        bytes32 proposalHash;
        // Slot 2
        bytes32 parentClaimHash;
        // Slot 3
        bytes32 endL2BlockHash;
        // Slot 4
        bytes32 endL2StateRoot;
        // Slot 5: 160 + 48 + 48 = 256 bits
        address proposer;
        uint48 endL2BlockNumber;
        uint48 proverBond;
        // Slot 6: 160 + 160 = 320 bits (96 bits would be wasted)
        address prover;
    }

    struct ClaimRecord {
        Claim claim;
        // 48 + 48 = 96 bits (160 bits unused)
        uint48 proposedAt;
        uint48 provedAt;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed
    event Proposed(uint48 indexed proposalId, Proposal proposal);

    /// @notice Emitted when a proof is submitted for a proposal
    event Proved(uint48 indexed proposalId, Proposal proposal, Claim claim);

    /// @notice Emitted when a proposal is finalized on L1
    event Finalized(uint48 indexed proposalId, Claim claim);

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _blobIndex Index of the blob in the current transaction
    function propose(uint48 _blobIndex) external;

    /// @notice Submits a proof for a proposal's state transition
    /// @param _proposalId ID of the proposal being proven
    /// @param _proposal Original proposal data
    /// @param _claim State transition claim being proven
    /// @param _proof Validity proof for the state transition
    function prove(
        uint48 _proposalId,
        Proposal memory _proposal,
        Claim memory _claim,
        bytes calldata _proof
    )
        external;

    /// @notice Finalizes a proven proposal and updates the L2 chain state
    /// @param _record The proven claim record to be used to finalize the next proposal
    function finalize(ClaimRecord memory _record) external;

    // -------------------------------------------------------------------------
    // External View Functions
    // -------------------------------------------------------------------------

    function provingWindow() external view returns (uint48 provingWindow_);
}
