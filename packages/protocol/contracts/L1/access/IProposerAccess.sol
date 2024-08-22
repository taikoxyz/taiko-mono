// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IProposerAccess
/// @notice An interface to check if a proposer is eligible to propose blocks in a specific Ethereum
/// block.
/// @custom:security-contact security@taiko.xyz
interface IProposerAccess {
    /// @notice Checks if a proposer can propose a block in the current Ethereum block.
    /// @param _proposer The address of the proposer.
    /// @return eligible_ true if the proposer can propose blocks, false otherwise.
    function isProposerEligible(address _proposer) external view returns (bool eligible_);
}
