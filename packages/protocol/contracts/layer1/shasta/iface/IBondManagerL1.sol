// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";

/// @title IBondManagerL1
/// @notice Interface for L1-specific bond management functionality
/// @custom:security-contact security@taiko.xyz
interface IBondManagerL1 is IBondManager {
    /// @notice Emitted when a withdrawal is requested
    event WithdrawalRequested(address indexed account, uint256 withdrawableAt);

    /// @notice Emitted when a withdrawal request is cancelled
    event WithdrawalCancelled(address indexed account);

    /// @notice Checks if a proposer is active (has sufficient bond and hasn't requested withdrawal)
    /// @param proposer The proposer address to check
    /// @return True if the proposer can make proposals
    function isProposerActive(address proposer) external view returns (bool);

    /// @notice Request to start the withdrawal process
    /// @dev Proposer cannot make new proposals after requesting withdrawal
    function requestWithdrawal() external;

    /// @notice Reactivate as a proposer by cancelling withdrawal request
    /// @dev Can be called during or after the withdrawal delay period
    function reactivate() external;
}
