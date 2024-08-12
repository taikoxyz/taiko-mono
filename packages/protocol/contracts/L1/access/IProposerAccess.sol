// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IProposerAccess
/// @dev An interface to check if a proposer is eligible to propose blocks in a specific Ethereum
/// block.
/// @custom:security-contact security@taiko.xyz
interface IProposerAccess {
    /// @notice Checks if a proposer can propose block in the current Ethereum block.
    /// @param _proposer The proposer.
    /// @param _blockHeight Ethereum block height.
    /// @return true if the proposer can propose blocks, false otherwise.
    function isProposerEligible(
        address _proposer,
        uint256 _blockHeight
    )
        external
        view
        returns (bool);
}
