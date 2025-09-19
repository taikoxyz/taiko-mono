// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @title LibInboxValidation
/// @notice Library for common validation functions used by Inbox implementations
/// @custom:security-contact security@taiko.xyz
library LibInboxValidation {
    using LibInboxValidation for *;

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error ProposalHashMismatch();
    error ProposalHashMismatchWithTransition();

    // ---------------------------------------------------------------
    // Validation Functions
    // ---------------------------------------------------------------

    /// @dev Validates a transition for a given proposal.
    /// @param _proposal The proposal containing the transition.
    /// @param _transition The transition to validate.
    /// @param _proposalHashes Ring buffer mapping for proposal hashes.
    /// @param _ringBufferSize Size of the ring buffer.
    function validateTransition(
        IInbox.Proposal memory _proposal,
        IInbox.Transition memory _transition,
        mapping(uint256 => bytes32) storage _proposalHashes,
        uint256 _ringBufferSize
    )
        internal
        view
    {
        bytes32 proposalHash = checkProposalHash(_proposal, _proposalHashes, _ringBufferSize);
        require(proposalHash == _transition.proposalHash, ProposalHashMismatchWithTransition());
    }

    /// @dev Checks if a proposal hash matches the stored hash in the ring buffer.
    /// @param _proposal The proposal to check.
    /// @param _proposalHashes Ring buffer mapping for proposal hashes.
    /// @param _ringBufferSize Size of the ring buffer.
    /// @return proposalHash_ The computed proposal hash.
    function checkProposalHash(
        IInbox.Proposal memory _proposal,
        mapping(uint256 => bytes32) storage _proposalHashes,
        uint256 _ringBufferSize
    )
        internal
        view
        returns (bytes32 proposalHash_)
    {
        proposalHash_ = hashProposal(_proposal);
        bytes32 storedProposalHash = _proposalHashes[_proposal.id % _ringBufferSize];
        require(proposalHash_ == storedProposalHash, ProposalHashMismatch());
    }

    // ---------------------------------------------------------------
    // Pure Hash Functions
    // ---------------------------------------------------------------

    /// @dev Hashes a proposal.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @dev Hashes a transition.
    /// @param _transition The transition to hash.
    /// @return _ The hash of the transition.
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes32) {
        return keccak256(abi.encode(_transition));
    }

    /// @dev Hashes a checkpoint.
    /// @param _checkpoint The checkpoint to hash.
    /// @return _ The hash of the checkpoint.
    function hashCheckpoint(ICheckpointManager.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_checkpoint));
    }

    /// @dev Hashes the core state.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function hashCoreState(IInbox.CoreState memory _coreState) internal pure returns (bytes32) {
        return keccak256(abi.encode(_coreState));
    }

    /// @dev Hashes a derivation.
    /// @param _derivation The derivation to hash.
    /// @return _ The hash of the derivation.
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        return keccak256(abi.encode(_derivation));
    }

    /// @dev Hashes an array of Transitions.
    /// @param _transitions The transitions array to hash.
    /// @return _ The hash of the transitions array.
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_transitions));
    }

    // ---------------------------------------------------------------
    // Note: Unoptimized Reference Functions
    // ---------------------------------------------------------------
    // All functions in this library are intentionally unoptimized reference implementations
    // using standard keccak256(abi.encode(...)) for simplicity and compatibility.
    // For optimized versions, see LibHashing.sol which provides gas-efficient alternatives
    // using EfficientHashLib and custom packing strategies.
}
