// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IProverAuction
/// @notice Interface for the ProverAuction contract that manages a continuous reverse auction
/// for prover services. Provers compete by offering the lowest proving fee per proposal.
/// @dev The auction follows these key rules:
///      - The prover offering the lowest fee wins immediately (no delay)
///      - Winner remains prover indefinitely until outbid, exited, or ejected
///      - Outbidding requires at least `minFeeReductionBps` lower fee (e.g., 5%)
///      - Current prover can lower their own fee without the reduction requirement
///      - Bond is required to participate; insufficient bond triggers ejection
/// @custom:security-contact security@taiko.xyz
interface IProverAuction {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Bond information for an account
    /// @param balance The current bond token balance
    /// @param withdrawableAt Timestamp when withdrawal is allowed
    /// (0 = no delay if not current prover)
    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when bond tokens are deposited
    /// @param account The account that deposited
    /// @param amount The amount deposited
    event Deposited(address indexed account, uint128 amount);

    /// @notice Emitted when bond tokens are withdrawn
    /// @param account The account that withdrew
    /// @param amount The amount withdrawn
    event Withdrawn(address indexed account, uint128 amount);

    /// @notice Emitted when a new bid is placed or current prover lowers their fee
    /// @param newProver The address of the new prover
    /// @param feeInGwei The new fee per proposal in Gwei
    /// @param oldProver The address of the previous prover (address(0) if none)
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);

    /// @notice Emitted when the current prover requests to exit
    /// @param prover The prover that requested exit
    /// @param withdrawableAt Timestamp when bond becomes withdrawable
    event ExitRequested(address indexed prover, uint48 withdrawableAt);

    /// @notice Emitted when a prover's bond is slashed
    /// @param prover The prover whose bond was slashed
    /// @param slashed The amount slashed
    /// @param recipient The recipient of the reward
    /// @param rewarded The amount rewarded to recipient
    event ProverSlashed(
        address indexed prover, uint128 slashed, address indexed recipient, uint128 rewarded
    );

    /// @notice Emitted when a prover is ejected due to insufficient bond
    /// @param prover The prover that was ejected
    event ProverEjected(address indexed prover);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Deposit bond tokens to caller's balance
    /// @param _amount Amount of bond tokens to deposit
    /// @dev Tokens are transferred from msg.sender to this contract
    /// @dev Can be called anytime, including after slashing to top up bond
    function deposit(uint128 _amount) external;

    /// @notice Withdraw bond tokens from caller's balance
    /// @param _amount Amount to withdraw
    /// @dev Reverts if caller is current prover
    /// @dev Reverts if withdrawal delay has not passed (when withdrawableAt > 0)
    function withdraw(uint128 _amount) external;

    /// @notice Submit a bid to become prover, or lower fee if already current prover
    /// @param _feeInGwei Fee per proposal in Gwei
    /// @dev Requirements:
    ///      - Caller must have sufficient bond balance (>= getRequiredBond())
    ///      - If caller is current prover: fee must be lower than current fee
    ///      - If caller is not current prover: fee must be <= getMaxBidFee()
    /// @dev Effects:
    ///      - If outbidding another prover, their withdrawableAt is set
    ///      - Moving average is updated with new fee
    ///      - Caller becomes the current prover
    function bid(uint32 _feeInGwei) external;

    /// @notice Request to exit as the current prover
    /// @dev Only callable by current prover
    /// @dev Sets exitTimestamp and starts withdrawal delay timer
    /// @dev After exit, slot becomes vacant and time-based fee cap applies
    function requestExit() external;

    /// @notice Slash a prover's bond for failing to prove within the time window
    /// @param _prover Address of the prover to slash
    /// @param _recipient Address to receive the reward (typically the actual prover)
    /// @dev Only callable by the Inbox contract
    /// @dev Best-effort slash: if balance < livenessBond, slashes entire balance
    /// @dev If bond falls below the ejection threshold, prover is automatically removed
    /// @dev Reward amount is computed from the actual slashed amount using a
    ///      contract-configured percentage. The difference (slashed - rewarded)
    ///      is tracked and locked forever in contract.
    function slashProver(address _prover, address _recipient) external;

    /// @notice Refresh the withdrawal delay timer for a prover with sufficient bond
    /// @param _prover Address of the prover to check
    /// @return success_ True if the prover has sufficient bond, false otherwise
    /// @dev Only callable by the Inbox contract
    /// @dev Used by Inbox to enable self-proving proposals even when an auction
    ///      prover exists; proposers may still choose to prove their own blocks.
    /// @dev Returns false if bond balance is below the ejection threshold
    /// @dev If prover is current, updates withdrawableAt only when already non-zero.
    /// @dev If prover is not current, always updates withdrawableAt.
    function checkBondDeferWithdrawal(address _prover) external returns (bool success_);

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Get the current active prover and their fee
    /// @return prover_ Current prover address (address(0) if none or exited)
    /// @return feeInGwei_ Fee per proposal in Gwei. Can be 0 for active provers.
    ///         Guaranteed to be 0 when prover_ is address(0).
    /// @dev Optimized for 1 SLOAD - called on every proposal by Inbox
    function getCurrentProver() external view returns (address prover_, uint32 feeInGwei_);

    /// @notice Get the maximum allowed bid fee at the current time
    /// @return maxFee_ Maximum fee in Gwei that a bid can specify
    /// @dev If active prover exists: returns fee * (10000 - minFeeReductionBps) / 10000
    /// @dev If slot is vacant: returns time-based cap (doubles every feeDoublingPeriod)
    function getMaxBidFee() external view returns (uint32 maxFee_);

    /// @notice Get bond information for an account
    /// @param _account The account to query
    /// @return bondInfo_ The bond information struct
    function getBondInfo(address _account) external view returns (BondInfo memory bondInfo_);

    /// @notice Get the required bond amount to become prover
    /// @return requiredBond_ The minimum bond required (ejectionThreshold * 2)
    function getRequiredBond() external view returns (uint128 requiredBond_);

    /// @notice Get the liveness bond amount slashed per failed proof
    /// @return livenessBond_ The liveness bond amount
    function getLivenessBond() external view returns (uint96 livenessBond_);

    /// @notice Get the bond threshold that triggers ejection
    /// @return threshold_ The ejection threshold (livenessBond * bondMultiplier)
    /// @dev Required bond = ejectionThreshold * 2
    function getEjectionThreshold() external view returns (uint128 threshold_);

    /// @notice Get the current moving average fee
    /// @return avgFee_ The exponential moving average of winning fees in Gwei
    function getMovingAverageFee() external view returns (uint32 avgFee_);

    /// @notice Get the total accumulated slashed amount (slashed - rewarded)
    /// @return totalSlashedAmount_ The total amount locked forever in the contract
    function getTotalSlashedAmount() external view returns (uint128 totalSlashedAmount_);
}
