// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { InboxOptimized1 } from "./InboxOptimized1.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibHashing } from "../libs/LibHashing.sol";
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
    // Public Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The InboxHelper contract address for utility functions
    /// @dev This helper provides external access to encoding/decoding and hashing functions
    address public immutable helper;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config, address _helper) InboxOptimized1(_config) {
        helper = _helper;
    }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @notice Encodes proposed event data using optimized format
    /// @dev Overrides base implementation to use custom encoding
    /// @param _payload The ProposedEventPayload to encode
    /// @return Custom-encoded bytes with reduced size
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
    /// @notice Encodes proved event data using optimized format
    /// @dev Overrides base implementation to use custom encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return Custom-encoded bytes with reduced size
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
    /// @notice Decodes custom-encoded proposal input data
    /// @dev Overrides base implementation to use LibProposeInputDecoder
    /// @param _data The custom-encoded propose input data
    /// @return _ The decoded ProposeInput struct
    function _decodeProposeInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProposeInput memory)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    /// @inheritdoc Inbox
    /// @notice Decodes custom-encoded prove input data
    /// @dev Overrides base implementation to use LibProveInputDecoder
    /// @param _data The custom-encoded prove input data
    /// @return The decoded ProveInput struct
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
    /// @dev Optimized implementation using LibHashing
    /// @notice Uses efficient hashing for composite key generation
    /// @param _proposalId The proposal ID
    /// @param _parentTransitionHash The parent transition hash
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
        return LibHashing.composeTransitionKey(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized blob hashes array hashing using LibHashing
    /// @dev Uses LibHashing for efficient blob hashes array hashing
    /// @param _blobHashes The blob hashes array to hash
    /// @return bytes32 The keccak256 hash of the blob hashes array
    function _hashBlobHashesArray(bytes32[] memory _blobHashes)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashBlobHashesArray(_blobHashes);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized checkpoint hashing using LibHashing
    /// @dev Uses LibHashing for efficient checkpoint hashing
    /// @param _checkpoint The checkpoint data to hash
    /// @return bytes32 The keccak256 hash of the checkpoint struct
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized core state hashing using LibHashing
    /// @dev Uses LibHashing for efficient core state hashing
    /// @param _coreState The core state data to hash
    /// @return bytes32 The keccak256 hash of the core state struct
    function _hashCoreState(CoreState memory _coreState) internal pure override returns (bytes32) {
        return LibHashing.hashCoreState(_coreState);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized derivation hashing using LibHashing
    /// @dev Uses LibHashing for efficient derivation hashing
    /// @param _derivation The derivation data to hash
    /// @return bytes32 The keccak256 hash of the derivation struct
    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashDerivation(_derivation);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized proposal hashing using LibHashing
    /// @dev Uses LibHashing for efficient proposal hashing
    /// @param _proposal The proposal data to hash
    /// @return bytes32 The keccak256 hash of the proposal struct
    function _hashProposal(Proposal memory _proposal) internal pure override returns (bytes32) {
        return LibHashing.hashProposal(_proposal);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized transition hashing using LibHashing
    /// @dev Uses LibHashing for efficient transition hashing
    /// @param _transition The transition data to hash
    /// @return bytes32 The keccak256 hash of the transition struct
    function _hashTransition(Transition memory _transition)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashTransition(_transition);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized transition record hashing using LibHashing
    /// @dev Uses LibHashing for efficient transition record hashing
    /// @param _transitionRecord The transition record to hash
    /// @return bytes26 The truncated keccak256 hash of the transition record
    function _hashTransitionRecord(TransitionRecord memory _transitionRecord)
        internal
        pure
        override
        returns (bytes26)
    {
        return LibHashing.hashTransitionRecord(_transitionRecord);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized transitions array hashing using LibHashing
    /// @dev Uses LibHashing for efficient array hashing
    /// @param _transitions The transitions array to hash
    /// @return bytes32 The keccak256 hash of the transitions array
    function _hashTransitionsArray(Transition[] memory _transitions)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashTransitionsArray(_transitions);
    }
}
