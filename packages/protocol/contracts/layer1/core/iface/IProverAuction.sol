// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IProverAuction
/// @notice Minimal interface for ProverAuction used by Inbox.
/// @custom:security-contact security@taiko.xyz
interface IProverAuction {
    /// @notice Emitted when a prover's bond is slashed
    /// @param prover The prover whose bond was slashed
    /// @param slashed The amount slashed
    /// @param recipient The recipient of the reward
    /// @param rewarded The amount rewarded to recipient
    event ProverSlashed(
        address indexed prover, uint128 slashed, address indexed recipient, uint128 rewarded
    );

    /// @notice Slash a prover's bond for failing to prove within the time window
    /// @param _prover Address of the prover to slash
    /// @param _recipient Address to receive the reward (typically the actual prover)
    /// @dev Only callable by the Inbox contract
    function slashProver(address _prover, address _recipient) external;

    /// @notice Refresh the withdrawal delay timer for a prover with sufficient bond
    /// @param _prover Address of the prover to check
    /// @return success_ True if the prover has sufficient bond, false otherwise
    /// @dev Only callable by the Inbox contract
    function checkBondDeferWithdrawal(address _prover) external returns (bool success_);

    /// @notice Get the current active prover and their fee
    /// @return prover_ Current prover address (address(0) if none or exited)
    /// @return feeInGwei_ Fee per proposal in Gwei
    /// @dev WARNING: This function can be expensive (O(n) in ProverAuction2). It is intended
    ///      for off-chain use only. On-chain code (e.g., Inbox) should use isCurrentProver()
    ///      for O(1) validation after obtaining the prover address off-chain.
    function getCurrentProver() external view returns (address prover_, uint32 feeInGwei_);

    /// @notice Check if an address is currently an active prover
    /// @param _prover The address to check
    /// @return isActive_ True if the address is an active prover
    /// @return feeInGwei_ The prover's fee in Gwei (0 if not active)
    /// @dev O(1) operation - use this for on-chain validation instead of getCurrentProver()
    function isCurrentProver(address _prover)
        external
        view
        returns (bool isActive_, uint32 feeInGwei_);
}
