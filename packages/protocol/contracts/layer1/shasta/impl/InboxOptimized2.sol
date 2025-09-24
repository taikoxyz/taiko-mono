// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { InboxOptimized1 } from "./InboxOptimized1.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibHashingOptimized } from "../libs/LibHashingOptimized.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

/// @title InboxOptimized2
/// @notice Second optimization layer with merged event, calldata, and hashing optimizations
/// @dev Key optimizations:
///      - Custom event encoding using LibProposedEventEncoder and LibProvedEventEncoder
///      - Compact binary representation for event data
///      - Reduced calldata size for events
///      - Custom calldata encoding for propose and prove inputs
///      - Compact binary representation using LibProposeInputDecoder and LibProveInputDecoder
///      - Reduced transaction costs through efficient data packing
///      - Uses LibHashing library for optimized struct hashing operations
///      - Maintains all optimizations from InboxOptimized1
/// @dev Gas savings: ~40% reduction in calldata costs for propose/prove operations
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized2 is InboxOptimized1 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) InboxOptimized1(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    function _encodeProposedEventData(ProposedEventPayload memory _payload)
        internal
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @inheritdoc Inbox
    function _encodeProvedEventData(ProvedEventPayload memory _payload)
        internal
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    /// @inheritdoc Inbox
    function _decodeProposeInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProposeInput memory)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    /// @inheritdoc Inbox
    function _decodeProveInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProveInput memory)
    {
        return LibProveInputDecoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // LibHashing Optimizations
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @return bytes32 The composite key for storage mapping
    function _composeTransitionKey(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashingOptimized.composeTransitionKey(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc Inbox
    function _hashBlobHashesArray(bytes32[] memory _blobHashes)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashingOptimized.hashBlobHashesArray(_blobHashes);
    }

    /// @inheritdoc Inbox
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashingOptimized.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc Inbox
    function _hashCoreState(CoreState memory _coreState) internal pure override returns (bytes32) {
        return LibHashingOptimized.hashCoreState(_coreState);
    }

    /// @inheritdoc Inbox
    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashingOptimized.hashDerivation(_derivation);
    }

    /// @inheritdoc Inbox
    function _hashProposal(Proposal memory _proposal) internal pure override returns (bytes32) {
        return LibHashingOptimized.hashProposal(_proposal);
    }

    /// @inheritdoc Inbox
    function _hashTransition(Transition memory _transition)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashingOptimized.hashTransition(_transition);
    }

    /// @inheritdoc Inbox
    function _hashTransitionRecord(TransitionRecord memory _transitionRecord)
        internal
        pure
        override
        returns (bytes26)
    {
        return LibHashingOptimized.hashTransitionRecord(_transitionRecord);
    }

    /// @inheritdoc Inbox
    function _hashTransitionsWithMetadata(
        Transition[] memory _transitions,
        TransitionMetadata[] memory _metadatas
    )
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashingOptimized.hashTransitionsWithMetadata(_transitions, _metadatas);
    }
}
