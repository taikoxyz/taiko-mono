// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IUnzenProposeCutoff
/// @notice The propose cutoff the upgraded Unzen Inbox exposes on a network that switches to Etna
/// (START-10-5d). `EtnaInbox.setOrigin` reads it to require that proposals are closed.
/// @custom:security-contact security@taiko.xyz
interface IUnzenProposeCutoff {
    /// @notice Returns the L1 timestamp from which `propose` reverts.
    /// @dev The same value the current `propose` implementation enforces: a proposal reverts once
    /// `block.timestamp >= proposeCutoff()`. Zero means no cutoff is installed.
    /// @return The propose cutoff in L1 Unix seconds.
    function proposeCutoff() external view returns (uint48);
}
