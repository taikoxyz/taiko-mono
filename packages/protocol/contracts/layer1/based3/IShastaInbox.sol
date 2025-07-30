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
        // Slot 1: 160 + 48 = 208 bits (48 bits unused)
        address proposer;
        uint48 proposedAt;
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
        address designatedProver;
        address actualProver;
    }

    struct ClaimRecord {
        Claim claim;
        // 48 + 48 = 96 bits (160 bits unused)
        uint48 proposedAt;
        uint48 provedAt;
    }

    struct L2ProverBondPayment {
        // Slot 1: 160 + 48 + 48 = 256 bits
        address recipient;
        uint48 proposalId;
        uint48 refundAmount;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed
    event Proposed(uint48 indexed proposalId, Proposal proposal);

    /// @notice Emitted when a proof is submitted for a proposal
    event Proved(uint48 indexed proposalId, Proposal proposal, Claim claim);

    /// @notice Emitted when a proposal is finalized on L1
    event Finalized(uint48 indexed proposalId, Claim claim, L2ProverBondPayment bondRefund);

    // -------------------------------------------------------------------------
    // Public View Functions
    // -------------------------------------------------------------------------

    function nextProposalId() external view returns (uint48);

    function lastFinalizedProposalId() external view returns (uint48);

    function lastFinalizedClaimHash() external view returns (bytes32);

    function lastL2BlockNumber() external view returns (uint48);

    function lastL2BlockHash() external view returns (bytes32);

    function lastL2StateRoot() external view returns (bytes32);

    function bondRefundsHash() external view returns (bytes32);

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param blobIndex Index of the blob in the current transaction
    function propose(uint48 blobIndex) external;

    /// @notice Submits a proof for a proposal's state transition
    /// @param proposalId ID of the proposal being proven
    /// @param proposal Original proposal data
    /// @param claim State transition claim being proven
    /// @param proof Validity proof for the state transition
    function prove(
        uint48 proposalId,
        Proposal memory proposal,
        Claim memory claim,
        bytes calldata proof
    )
        external;

    /// @notice Finalizes a proven proposal and updates the L2 chain state
    /// @param claimRecord The proven claim to finalize
    function finalize(ClaimRecord memory claimRecord) external;
}
