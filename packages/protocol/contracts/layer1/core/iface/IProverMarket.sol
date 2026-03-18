// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverMarket
/// @notice Interface for the prover market that owns proving authorization and market lifecycle
/// hooks for Inbox
/// @custom:security-contact security@taiko.xyz
interface IProverMarket {
    /// @notice Places or updates a bid for a future proving epoch
    /// @param _feeInGwei The fee quote in gwei for each assigned proposal
    function bid(uint64 _feeInGwei) external;

    /// @notice Requests exit from the market for the caller's active or pending position
    function exit() external;

    /// @notice Deposits bond used to back proving obligations
    /// @param _amount The bond amount in gwei
    function depositBond(uint64 _amount) external;

    /// @notice Withdraws previously deposited bond
    /// @param _amount The bond amount in gwei
    function withdrawBond(uint64 _amount) external;

    /// @notice Withdraws accrued prover fees
    /// @param _amount The amount in wei to withdraw
    function withdrawFees(uint256 _amount) external;

    /// @notice Checks whether a caller is authorized to submit a proof for a given proposal.
    /// @dev Intended for off-chain use by provers before submitting a prove transaction.
    /// @param _caller The account that would submit the proof
    /// @param _firstNewProposalId The first proposal id that would be newly finalized
    /// @param _proposalAge The age in seconds of the first newly finalized proposal
    /// @return True if the caller is authorized to prove
    function canSubmitProof(
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        external
        view
        returns (bool);

    /// @notice Notifies the market that Inbox accepted a new proposal
    /// @dev Receives ETH from proposer via Inbox. Takes the active epoch fee and refunds
    ///      any excess directly to the proposer.
    /// @param _proposalId The accepted proposal id
    /// @param _proposer The proposer that created the proposal
    /// @param _proposalTimestamp The proposal timestamp
    function onProposalAccepted(
        uint48 _proposalId,
        address _proposer,
        uint48 _proposalTimestamp
    )
        external
        payable;

    /// @notice Notifies the market that Inbox finalized a new proof range.
    /// @dev Enforces prover authorization and handles slashing, bond release, and degraded mode.
    /// @param _caller The account that submitted the proof transaction
    /// @param _firstNewProposalId The first proposal id that was newly finalized
    /// @param _lastProposalId The last proposal id in the finalized range
    /// @param _proposalAge The age in seconds of the first newly finalized proposal
    function onProofAccepted(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint256 _proposalAge
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

    /// @notice Returns the bond balance for an account in gwei
    /// @param _account The account to query
    function bondBalances(address _account) external view returns (uint64);

    /// @notice Returns the accrued fee balance for an account in wei
    /// @param _account The account to query
    function feeBalances(address _account) external view returns (uint256);

    /// @notice Returns the bond token address used by this market
    function bondToken() external view returns (address);

    /// @notice Returns the exclusive proving window in seconds. Within this window only the
    /// assigned prover may prove; after it anyone may prove and the assigned prover is slashed.
    function provingWindow() external view returns (uint48);

    /// @notice Returns the fee in gwei that the next proposal will be charged
    /// @dev Accounts for pending epoch transitions. Useful for off-chain fee estimation.
    function activeFeeInGwei() external view returns (uint64);

    /// @notice Returns the minimum bond in gwei required to place a bid
    function minBond() external view returns (uint64);

    /// @notice Returns the minimum bid discount in basis points (e.g. 1000 = 10%)
    function bidDiscountBps() external view returns (uint16);

    /// @notice Returns the bond in gwei reserved per assigned proposal
    function bondPerProposal() external view returns (uint64);

    /// @notice Returns the slash amount in gwei per late proof
    function slashPerProof() external view returns (uint64);

    /// @notice Returns the reserved bond balance for an account in gwei
    /// @param _account The account to query
    function reservedBondGwei(address _account) external view returns (uint64);
}
