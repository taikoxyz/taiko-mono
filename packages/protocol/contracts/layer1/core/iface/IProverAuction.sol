// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IProverAuction
/// @notice Minimal interface for prover auction contracts used by the Inbox.
/// @custom:security-contact security@taiko.xyz
interface IProverAuction {
    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a prover's bond is slashed.
    /// @param prover The prover whose bond was slashed.
    /// @param slashed The amount slashed.
    /// @param recipient The recipient of the reward.
    /// @param rewarded The amount rewarded to recipient.
    event ProverSlashed(
        address indexed prover, uint128 slashed, address indexed recipient, uint128 rewarded
    );

    /// @notice Emitted when a prover is ejected due to insufficient bond.
    /// @param prover The prover that was ejected.
    event ProverEjected(address indexed prover);

    /// @notice Emitted when bond tokens are deposited.
    /// @param account The account that deposited.
    /// @param amount The amount deposited.
    event Deposited(address indexed account, uint128 amount);

    /// @notice Emitted when bond tokens are withdrawn.
    /// @param account The account that withdrew.
    /// @param amount The amount withdrawn.
    event Withdrawn(address indexed account, uint128 amount);

    /// @notice Emitted when the current prover requests to exit.
    /// @param prover The prover that requested exit.
    /// @param withdrawableAt Timestamp when bond becomes withdrawable.
    event ExitRequested(address indexed prover, uint48 withdrawableAt);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Submit a bid to become the designated prover.
    /// @dev A bid is a fee offer (in Gwei) paid per proposal. Lower fees are better.
    ///
    /// If the prover slot is vacant, the bid must be below the dynamically computed maximum.
    /// If a prover is already active, the bid must undercut the current fee by at least the
    /// configured minimum reduction.
    ///
    /// A current prover may also rebid to lower their own fee.
    /// @param _feeInGwei Fee per proposal in Gwei.
    function bid(uint32 _feeInGwei) external;

    /// @notice Deposit bond tokens to caller's balance.
    /// @param _amount Amount of bond tokens to deposit.
    function deposit(uint128 _amount) external;

    /// @notice Withdraw the caller's entire bond balance.
    function withdraw() external;

    /// @notice Request to exit as a current prover.
    function requestExit() external;

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

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Get the current designated prover and their fee.
    /// @return prover_ Current prover address (address(0) if none).
    /// @return feeInGwei_ Fee per proposal in Gwei.
    function getProver() external view returns (address prover_, uint32 feeInGwei_);

    /// @notice Get the required bond amount to become prover.
    /// @return requiredBond_ The minimum bond required.
    function getRequiredBond() external view returns (uint128 requiredBond_);

    /// @notice Get the liveness bond amount slashed per failed proof.
    /// @return livenessBond_ The liveness bond amount.
    function getLivenessBond() external view returns (uint96 livenessBond_);

    /// @notice Get the bond threshold that triggers ejection.
    /// @return threshold_ The ejection threshold.
    function getEjectionThreshold() external view returns (uint128 threshold_);

    /// @notice Get the total accumulated slashed amount (slashed - rewarded).
    /// @return totalSlashedAmount_ The total amount locked forever in the contract.
    function getTotalSlashedAmount() external view returns (uint128 totalSlashedAmount_);
}
