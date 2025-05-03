// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverBlacklist
/// @custom:security-contact security@taiko.xyz
interface IProverBlacklist {
    /// @notice Emitted when a proposer is blacklisted by a prover.
    /// @param proposer The address of the proposer.
    /// @param byProver The address of the prover who blacklisted the proposer.
    /// @param blacklisted True if the proposer is blacklisted, false otherwise.
    event ProposerBlacklisted(address indexed proposer, address indexed byProver, bool blacklisted);

    /// @notice Emitted when proposer is blacklisted by msg.sender.
    /// @param _proposer The address of the proposer.
    function addToBlackList(address _proposer) external;

    /// @notice Emitted when proposer is removed from blacklist by msg.sender.
    /// @param _proposer The address of the proposer.
    function removeFromBlackList(address _proposer) external;

    /// @notice Check if a proposer is blacklisted by a prover.
    /// @param _proposer The address of the proposer.
    /// @param _prover The address of the prover.
    /// @return True if the proposer is blacklisted by the prover, false otherwise.
    function isBlacklistedBy(address _proposer, address _prover) external view returns (bool);
}
