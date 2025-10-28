// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { Inbox } from "./Inbox.sol";
import { InboxOptimized1 } from "./InboxOptimized1.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title InboxOptimized2
/// @notice Second optimization layer with merged event, calldata, and hashing optimizations
/// @dev Key optimizations:
///      - Custom event encoding using LibProposedEventEncoder and LibProvedEventEncoder
///      - Compact binary representation for event data
///      - Reduced calldata size for events
///      - Custom calldata encoding for propose and prove inputs
///      - Compact binary representation using LibProposeInputDecoder and LibProveInputDecoder
///      - Reduced transaction costs through efficient data packing
///      - Uses LibHash library for optimized struct hashing operations
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
    // LibHash Optimizations
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @return bytes32 The composite key for storage mapping
    function _composeTransitionKey(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (bytes32)
    {
        return LibHashOptimized.composeTransitionKey(
            _proposalId, _compositeKeyVersion, _parentTransitionHash
        );
    }

    /// @inheritdoc Inbox
    function _hashBlobHashesArray(bytes32[] memory _blobHashes)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashBlobHashesArray(_blobHashes);
    }

    /// @inheritdoc Inbox
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc Inbox
    function _hashCoreState(CoreState memory _coreState) internal pure override returns (bytes32) {
        return LibHashOptimized.hashCoreState(_coreState);
    }

    /// @inheritdoc Inbox
    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashDerivation(_derivation);
    }

    /// @inheritdoc Inbox
    function _hashProposal(Proposal memory _proposal) internal pure override returns (bytes32) {
        return LibHashOptimized.hashProposal(_proposal);
    }

    /// @inheritdoc Inbox
    function _hashTransition(Transition memory _transition)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashTransition(_transition);
    }

    /// @inheritdoc Inbox
    function _hashTransitionRecord(TransitionRecord memory _transitionRecord)
        internal
        pure
        override
        returns (bytes26)
    {
        return LibHashOptimized.hashTransitionRecord(_transitionRecord);
    }

    /// @inheritdoc Inbox
    function _hashTransitionsWithMetadata(
        Transition[] memory _transitions,
        TransitionMetadata[] memory _metadata
    )
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashTransitionsWithMetadata(_transitions, _metadata);
    }
}

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _shastaInitializer             | address                                            | Slot: 251  | Offset: 0    | Bytes: 20
//   conflictingTransitionDetected  | bool                                               | Slot: 251  | Offset: 20   | Bytes: 1
//   _proposalHashes                | mapping(uint256 => bytes32)                        | Slot: 252  | Offset: 0    | Bytes: 32
//   _transitionRecordHashAndDeadline | mapping(bytes32 => struct Inbox.TransitionRecordHashAndDeadline) | Slot: 253  | Offset: 0    | Bytes: 32
//   _forcedInclusionStorage        | struct LibForcedInclusion.Storage                  | Slot: 254  | Offset: 0    | Bytes: 64
//   __gap                          | uint256[37]                                        | Slot: 256  | Offset: 0    | Bytes: 1184
//   _reusableTransitionRecords     | mapping(uint256 => struct InboxOptimized1.ReusableTransitionRecord) | Slot: 293  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 294  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 343  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _shastaInitializer             | address                                            | Slot: 251  | Offset: 0    | Bytes: 20
//   conflictingTransitionDetected  | bool                                               | Slot: 251  | Offset: 20   | Bytes: 1
//   _proposalHashes                | mapping(uint256 => bytes32)                        | Slot: 252  | Offset: 0    | Bytes: 32
//   _transitionRecordHashAndDeadline | mapping(bytes32 => struct Inbox.TransitionRecordHashAndDeadline) | Slot: 253  | Offset: 0    | Bytes: 32
//   _forcedInclusionStorage        | struct LibForcedInclusion.Storage                  | Slot: 254  | Offset: 0    | Bytes: 64
//   __gap                          | uint256[37]                                        | Slot: 256  | Offset: 0    | Bytes: 1184
//   _reusableTransitionRecords     | mapping(uint256 => struct InboxOptimized1.ReusableTransitionRecord) | Slot: 293  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 294  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 343  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _shastaInitializer             | address                                            | Slot: 251  | Offset: 0    | Bytes: 20
//   conflictingTransitionDetected  | bool                                               | Slot: 251  | Offset: 20   | Bytes: 1
//   _proposalHashes                | mapping(uint256 => bytes32)                        | Slot: 252  | Offset: 0    | Bytes: 32
//   _transitionRecordHashAndDeadline | mapping(bytes32 => struct Inbox.TransitionRecordHashAndDeadline) | Slot: 253  | Offset: 0    | Bytes: 32
//   _forcedInclusionStorage        | struct LibForcedInclusion.Storage                  | Slot: 254  | Offset: 0    | Bytes: 64
//   __gap                          | uint256[37]                                        | Slot: 256  | Offset: 0    | Bytes: 1184
//   _reusableTransitionRecords     | mapping(uint256 => struct InboxOptimized1.ReusableTransitionRecord) | Slot: 293  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 294  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 343  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1   
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1   
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20  
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20  
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1   
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1   
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _shastaInitializer             | address                                            | Slot: 251  | Offset: 0    | Bytes: 20  
//   conflictingTransitionDetected  | bool                                               | Slot: 251  | Offset: 20   | Bytes: 1   
//   _proposalHashes                | mapping(uint256 => bytes32)                        | Slot: 252  | Offset: 0    | Bytes: 32  
//   _transitionRecordHashAndDeadline | mapping(bytes32 => struct Inbox.TransitionRecordHashAndDeadline) | Slot: 253  | Offset: 0    | Bytes: 32  
//   _forcedInclusionStorage        | struct LibForcedInclusion.Storage                  | Slot: 254  | Offset: 0    | Bytes: 64  
//   __gap                          | uint256[37]                                        | Slot: 256  | Offset: 0    | Bytes: 1184
//   _reusableTransitionRecords     | mapping(uint256 => struct InboxOptimized1.ReusableTransitionRecord) | Slot: 293  | Offset: 0    | Bytes: 32  
//   __gap                          | uint256[49]                                        | Slot: 294  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 343  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length
