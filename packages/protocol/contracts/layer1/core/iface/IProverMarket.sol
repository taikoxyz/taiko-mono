// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverMarket
/// @notice Interface for the prover market, exposing only the hooks called by Inbox.
/// @custom:security-contact security@taiko.xyz
interface IProverMarket {
    /// @notice Notifies the market that Inbox accepted a new proposal.
    /// @param _proposalId The accepted proposal id.
    /// @param _proposer The proposer that created the proposal.
    /// @param _proposalTimestamp The proposal timestamp.
    function onProposalAccepted(uint48 _proposalId, address _proposer, uint48 _proposalTimestamp) external payable;

    /// @notice Notifies the market that Inbox finalized a new proof range.
    /// @dev Validates prover authorization, then handles payout accounting, bond release,
    /// and slashing for the newly finalized range.
    /// @param _caller The account that submitted the proof transaction.
    /// @param _firstNewProposalId The first proposal id that was newly finalized.
    /// @param _lastProposalId The last proposal id in the finalized range.
    function onProofAccepted(address _caller, uint48 _firstNewProposalId, uint48 _lastProposalId) external;

    /// @notice Returns the bond token address used by this market.
    function bondToken() external view returns (address);

    /// @notice Credits migrated bond from Inbox to a user's balance.
    /// @dev Only callable by the Inbox contract during bond migration.
    /// @param _account The account to credit the bond to.
    /// @param _amount The bond amount in gwei.
    function creditMigratedBond(address _account, uint64 _amount) external;
}
