// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";

/// @title LibCoreState
/// @notice Library for CoreState operations in the Taiko protocol
/// @custom:security-contact security@taiko.xyz
library LibCoreState {
    using LibCoreState for IInbox.CoreState;

    /// @notice Returns the count of unfinalized proposals
    /// @param _coreState The core state
    /// @return count_ The number of unfinalized proposals
    function getUnfinalizedCount(IInbox.CoreState memory _coreState)
        internal
        pure
        returns (uint256 count_)
    {
        return _coreState.nextProposalId - _coreState.lastFinalizedProposalId;
    }

    /// @notice Validates that unfinalized capacity isn't exceeded
    /// @param _coreState The core state
    /// @param _capacity The maximum unfinalized proposal capacity
    function checkUnfinalizedCapacity(
        IInbox.CoreState memory _coreState,
        uint256 _capacity
    )
        internal
        pure
    {
        if (_coreState.getUnfinalizedCount() > _capacity) {
            revert ExceedsUnfinalizedProposalCapacity();
        }
    }

    /// @notice Checks if there are unfinalized proposals
    /// @param _coreState The core state
    /// @return hasUnfinalized_ True if there are unfinalized proposals
    function hasUnfinalizedProposals(IInbox.CoreState memory _coreState)
        internal
        pure
        returns (bool hasUnfinalized_)
    {
        return _coreState.nextProposalId > _coreState.lastFinalizedProposalId;
    }

    /// @notice Gets the next proposal ID to finalize
    /// @param _coreState The core state
    /// @return proposalId_ The next proposal ID to finalize, or 0 if none
    function getNextProposalToFinalize(IInbox.CoreState memory _coreState)
        internal
        pure
        returns (uint48 proposalId_)
    {
        if (_coreState.hasUnfinalizedProposals()) {
            return _coreState.lastFinalizedProposalId + 1;
        }
        return 0;
    }

    /// @notice Updates finalization state for a proposal
    /// @param _coreState The core state to update
    /// @param _proposalId The proposal ID being finalized
    /// @param _claimHash The claim hash for the finalized proposal
    /// @param _bondOperationsHash The updated bond operations hash
    function finalizeProposal(
        IInbox.CoreState memory _coreState,
        uint48 _proposalId,
        bytes32 _claimHash,
        bytes32 _bondOperationsHash
    )
        internal
        pure
    {
        _coreState.lastFinalizedProposalId = _proposalId;
        _coreState.lastFinalizedClaimHash = _claimHash;
        _coreState.bondOperationsHash = _bondOperationsHash;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ExceedsUnfinalizedProposalCapacity();
}
