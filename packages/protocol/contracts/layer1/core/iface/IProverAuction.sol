// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IProverAuction
/// @notice Minimal interface for prover auction contracts used by the Inbox.
/// @custom:security-contact security@taiko.xyz
interface IProverAuction {
    /// @notice Emitted when a prover's bond is slashed.
    /// @param prover The prover whose bond was slashed.
    /// @param slashed The amount slashed.
    /// @param recipient The recipient of the reward.
    /// @param rewarded The amount rewarded to recipient.
    event ProverSlashed(
        address indexed prover, uint128 slashed, address indexed recipient, uint128 rewarded
    );

    /// @notice Slash a prover for liveness failure.
    /// @param _proverAddr The prover to slash.
    /// @param _recipient The recipient of the slashed reward.
    function slashProver(address _proverAddr, address _recipient) external;

    /// @notice Check whether a prover has sufficient bond and defer withdrawals.
    /// @dev When this function succeeds it (re)sets the withdrawal delay timer. This is used by
    /// the Inbox to prevent proposers acting as a self-prover from withdrawing their bond while
    /// they may still be slashable.
    /// @param _prover Address of the prover to check.
    /// @return success_ True if the prover has sufficient bond, false otherwise.
    function checkBondDeferWithdrawal(address _prover) external returns (bool success_);

    /// @notice Get the current designated prover and their fee.
    /// @param _maxFeeInGwei Maximum acceptable fee in Gwei. If the current prover's fee exceeds
    /// this value, returns (address(0), 0). Pass type(uint32).max to always get the prover.
    /// @return prover_ Current prover address (address(0) if none or fee too high).
    /// @return feeInGwei_ Fee per proposal in Gwei (0 if no prover or fee too high).
    function getProver(uint32 _maxFeeInGwei)
        external
        view
        returns (address prover_, uint32 feeInGwei_);
}
