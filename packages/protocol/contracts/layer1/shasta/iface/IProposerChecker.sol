// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProposerChecker
/// @notice Interface for checking if an address is authorized to propose blocks
/// @custom:security-contact security@taiko.xyz
interface IProposerChecker {
    error InvalidProposer();

    /// @notice Checks if an address is a valid proposer
    /// @param _proposer The address to check
    /// @return endOfSubmissionWindowTimestamp_ The timestamp of the last slot where the current
    /// preconfer
    /// can propose.
    /// @dev This function must revert if the address is not a valid proposer
    function checkProposer(address _proposer)
        external
        view
        returns (uint48 endOfSubmissionWindowTimestamp_);
}
