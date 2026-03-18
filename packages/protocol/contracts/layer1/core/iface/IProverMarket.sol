// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverMarket
/// @notice Interface for the prover market that owns proving authorization and market lifecycle
/// hooks for Inbox
/// @custom:security-contact security@taiko.xyz
interface IProverMarket {
    /// @notice Places or updates a bid for a future proving epoch
    /// @param _feeRecipient The address that should receive proving fees for the bid
    /// @param _feeInGwei The fee quote in gwei for each assigned proposal
    function bid(address _feeRecipient, uint64 _feeInGwei) external;

    /// @notice Requests exit from the market for the caller's active or pending position
    function exit() external;

    /// @notice Deposits bond used to back proving obligations
    /// @param _amount The bond amount in gwei
    function depositBond(uint64 _amount) external;

    /// @notice Withdraws previously deposited bond
    /// @param _amount The bond amount in gwei
    function withdrawBond(uint64 _amount) external;

    /// @notice Deposits proposer fee credit for future proposal reservations
    function depositFeeCredit() external payable;

    /// @notice Withdraws unused proposer fee credit or accrued prover fees
    /// @param _amount The amount in wei to withdraw
    function withdrawFeeCredit(uint256 _amount) external;

    /// @notice Checks whether a proof submission is authorized under the current market state
    /// @param _caller The account submitting the proof transaction
    /// @param _firstNewProposalId The first proposal id that would be newly finalized
    /// @param _proposalTimestamp The timestamp of the first newly finalized proposal
    /// @param _proposalAge The age in seconds of the first newly finalized proposal
    function beforeProofSubmission(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _proposalTimestamp,
        uint256 _proposalAge
    )
        external
        view;

    /// @notice Notifies the market that Inbox accepted a new proposal
    /// @param _proposalId The accepted proposal id
    /// @param _proposer The proposer that created the proposal
    /// @param _proposalTimestamp The proposal timestamp
    function onProposalAccepted(
        uint48 _proposalId,
        address _proposer,
        uint48 _proposalTimestamp
    )
        external;

    /// @notice Notifies the market that Inbox finalized a new proof range
    /// @param _caller The account that submitted the proof transaction
    /// @param _actualProver The prover recorded in the commitment
    /// @param _firstNewProposalId The first proposal id that was newly finalized
    /// @param _lastProposalId The last proposal id in the finalized range
    /// @param _proposalAge The age in seconds of the first newly finalized proposal
    /// @param _finalizedAt The timestamp when finalization occurred
    function onProofAccepted(
        address _caller,
        address _actualProver,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint256 _proposalAge,
        uint48 _finalizedAt
    )
        external;

    /// @notice Enables or disables emergency permissionless proving mode
    /// @param _enabled True to force permissionless proving, false to restore market enforcement
    function forcePermissionlessMode(bool _enabled) external;

    /// @notice Credits migrated bond from Inbox to a user's balance
    /// @dev Only callable by the Inbox contract during bond migration
    /// @param _account The account to credit the bond to
    /// @param _amount The bond amount in gwei
    function creditMigratedBond(address _account, uint64 _amount) external;
}
