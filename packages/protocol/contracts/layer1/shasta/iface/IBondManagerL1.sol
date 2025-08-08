// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";

/// @title IBondManagerL1
/// @notice Interface for L1-specific bond management functionality
/// @custom:security-contact security@taiko.xyz
interface IBondManagerL1 is IBondManager {
    /// @notice Notifies the bond manager that a proposal was created by a proposer and checks that
    /// the proposer has enough balance.
    /// @dev Called only by the authorized inbox contract on L1.
    /// @param proposer The proposer address.
    /// @param proposalId The proposal id.
    function notifyProposed(address proposer, uint48 proposalId) external;
}
