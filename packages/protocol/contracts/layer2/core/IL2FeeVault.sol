// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IL2FeeVault
/// @notice Interface for the L2 fee vault that reimburses proposers for L1 costs.
/// @custom:security-contact security@taiko.xyz
interface IL2FeeVault {
    /// @notice Fee data for a single proposal, used to compute reimbursements.
    /// @dev All values must be validated by the validity proof before import:
    ///      - L1 fields (proposalId, proposer, l1GasUsed, numBlobs, l1Basefee, l1BlobBasefee)
    ///        come from the L1 Inbox's stored proposal data
    ///      - L2 field (l2BasefeeRevenue) is computed from L2 block execution
    struct ProposalFeeData {
        /// @dev Sequential proposal ID from L1 Inbox (must be imported in order, no gaps).
        uint48 proposalId;
        /// @dev Address that submitted the proposal on L1 (receives reimbursement).
        address proposer;
        /// @dev L1 execution gas consumed by the propose transaction.
        uint64 l1GasUsed;
        /// @dev Number of EIP-4844 blobs posted with the proposal.
        uint32 numBlobs;
        /// @dev L1 basefee at time of proposal (wei per gas).
        uint128 l1Basefee;
        /// @dev L1 blob basefee at time of proposal (wei per blob gas).
        uint128 l1BlobBasefee;
        /// @dev Total L2 basefee revenue collected from blocks in this proposal.
        uint256 l2BasefeeRevenue;
    }

    /// @notice Imports fee data for a single proposal to calculate reimbursements.
    /// @dev Must be called with proposalId = lastImportedProposalId + 1.
    ///      Triggers the fee adjustment mechanism after processing the proposal.
    /// @param _fee Proposal fee data to import.
    function importProposalFee(ProposalFeeData calldata _fee) external;
}
