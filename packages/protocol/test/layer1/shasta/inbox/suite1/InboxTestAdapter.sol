// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestInboxFactory.sol";
import "./InboxTestLib.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibProposeInputDecoder.sol";
import "contracts/layer1/shasta/libs/LibProveInputDecoder.sol";
import "contracts/layer1/shasta/libs/LibProposedEventEncoder.sol";
import "contracts/layer1/shasta/libs/LibProvedEventEncoder.sol";

/// @title InboxTestAdapter
/// @notice Adapter to handle encoding/decoding differences between Inbox implementations
/// @dev Provides unified interface for test data encoding across all Inbox variants
/// @custom:security-contact security@taiko.xyz
library InboxTestAdapter {
    /// @dev Encodes propose input based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _deadline The deadline for the proposal
    /// @param _coreState The core state
    /// @param _proposals The validation proposals
    /// @param _blobRef The blob reference
    /// @param _transitionRecords The transition records for finalization
    /// @return Encoded propose input
    function encodeProposeInput(
        TestInboxFactory.InboxType _inboxType,
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        // Default checkpoint - will be overridden by the other function if needed
        ICheckpointManager.Checkpoint memory checkpoint = ICheckpointManager.Checkpoint({
            blockNumber: 0,
            blockHash: bytes32(0),
            stateRoot: bytes32(0)
        });

        return encodeProposeInputWithEndBlock(
            _inboxType, _deadline, _coreState, _proposals, _blobRef, _transitionRecords, checkpoint
        );
    }

    /// @dev Encodes propose input with explicit checkpoint
    function encodeProposeInputWithEndBlock(
        TestInboxFactory.InboxType _inboxType,
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords,
        ICheckpointManager.Checkpoint memory _checkpoint
    )
        internal
        pure
        returns (bytes memory)
    {
        if (_inboxType == TestInboxFactory.InboxType.Optimized3) {
            // InboxOptimized3 uses custom encoding
            // Create ProposeInput struct
            IInbox.ProposeInput memory input = IInbox.ProposeInput({
                deadline: _deadline,
                coreState: _coreState,
                parentProposals: _proposals,
                blobReference: _blobRef,
                transitionRecords: _transitionRecords,
                checkpoint: _checkpoint,
                numForcedInclusions: 0
            });
            return LibProposeInputDecoder.encode(input);
        } else {
            // Base, Optimized1, and Optimized2 use standard abi.encode
            // Create ProposeInput struct for proper encoding
            IInbox.ProposeInput memory input = IInbox.ProposeInput({
                deadline: _deadline,
                coreState: _coreState,
                parentProposals: _proposals,
                blobReference: _blobRef,
                transitionRecords: _transitionRecords,
                checkpoint: _checkpoint,
                numForcedInclusions: 0
            });
            return abi.encode(input);
        }
    }

    /// @dev Encodes prove input based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _proposals The proposals to prove
    /// @param _transitions The transitions with proof details
    /// @return Encoded prove input
    function encodeProveInput(
        TestInboxFactory.InboxType _inboxType,
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions
    )
        internal
        pure
        returns (bytes memory)
    {
        // Default to address(0) for both provers - for backward compatibility
        // Create array of zeros for designated provers
        address[] memory designatedProvers = new address[](_transitions.length);
        // actualProver is also address(0)
        return encodeProveInputWithMultipleProvers(
            _inboxType, _proposals, _transitions, designatedProvers, address(0)
        );
    }

    /// @dev Encodes prove input with multiple different prover pairs for each transition
    /// @param _inboxType The type of Inbox implementation
    /// @param _proposals The proposals to prove
    /// @param _transitions The transitions with proof details
    /// @param _designatedProvers Array of designated prover addresses (one per transition)
    /// @param _actualProver The actual prover address (same for all transitions)
    /// @return Encoded prove input
    function encodeProveInputWithMultipleProvers(
        TestInboxFactory.InboxType _inboxType,
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
        address[] memory _designatedProvers,
        address _actualProver
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_designatedProvers.length == _transitions.length, "Mismatch in prover count");

        if (_inboxType == TestInboxFactory.InboxType.Optimized3) {
            // InboxOptimized3 uses custom encoding
            // Create metadata array matching transitions
            IInbox.TransitionMetadata[] memory metadata =
                new IInbox.TransitionMetadata[](_transitions.length);
            for (uint256 i = 0; i < _transitions.length; i++) {
                metadata[i] = IInbox.TransitionMetadata({
                    designatedProver: _designatedProvers[i],
                    actualProver: _actualProver
                });
            }
            // Create ProveInput struct
            IInbox.ProveInput memory input = IInbox.ProveInput({
                proposals: _proposals,
                transitions: _transitions,
                metadata: metadata
            });
            return LibProveInputDecoder.encode(input);
        } else {
            // Base, Optimized1, and Optimized2 use standard abi.encode
            // Create metadata array matching transitions
            IInbox.TransitionMetadata[] memory metadata =
                new IInbox.TransitionMetadata[](_transitions.length);
            for (uint256 i = 0; i < _transitions.length; i++) {
                metadata[i] = IInbox.TransitionMetadata({
                    designatedProver: _designatedProvers[i],
                    actualProver: _actualProver
                });
            }
            // Create ProveInput struct for proper encoding
            IInbox.ProveInput memory input = IInbox.ProveInput({
                proposals: _proposals,
                transitions: _transitions,
                metadata: metadata
            });
            return abi.encode(input);
        }
    }

    /// @dev Decodes proposed event data based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _data The encoded event data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decodeProposedEventData(
        TestInboxFactory.InboxType _inboxType,
        bytes memory _data
    )
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        if (
            _inboxType == TestInboxFactory.InboxType.Optimized2
                || _inboxType == TestInboxFactory.InboxType.Optimized3
        ) {
            // InboxOptimized2 and InboxOptimized3 use custom event encoding
            IInbox.ProposedEventPayload memory payload = LibProposedEventEncoder.decode(_data);
            proposal_ = payload.proposal;
            coreState_ = payload.coreState;
        } else {
            // Base and Optimized1 emit the standard structs
            // The event data would be the encoded structs
            IInbox.Derivation memory derivation;
            (proposal_, derivation, coreState_) =
                abi.decode(_data, (IInbox.Proposal, IInbox.Derivation, IInbox.CoreState));
        }
    }

    /// @dev Decodes proved event data based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _data The encoded event data
    /// @return transitionRecord_ The decoded transition record
    function decodeProvedEventData(
        TestInboxFactory.InboxType _inboxType,
        bytes memory _data
    )
        internal
        pure
        returns (IInbox.TransitionRecord memory transitionRecord_)
    {
        if (
            _inboxType == TestInboxFactory.InboxType.Optimized2
                || _inboxType == TestInboxFactory.InboxType.Optimized3
        ) {
            // InboxOptimized2 and InboxOptimized3 use custom event encoding
            IInbox.ProvedEventPayload memory payload = LibProvedEventEncoder.decode(_data);
            return payload.transitionRecord;
        } else {
            // Base and Optimized1 emit the standard struct
            transitionRecord_ = abi.decode(_data, (IInbox.TransitionRecord));
        }
    }

    /// @dev Checks if an Inbox type uses custom propose data encoding
    /// @param _inboxType The type of Inbox implementation
    /// @return True if the implementation uses custom encoding
    function usesCustomProposeEncoding(TestInboxFactory.InboxType _inboxType)
        internal
        pure
        returns (bool)
    {
        return _inboxType == TestInboxFactory.InboxType.Optimized3;
    }

    /// @dev Checks if an Inbox type uses custom event encoding
    /// @param _inboxType The type of Inbox implementation
    /// @return True if the implementation uses custom event encoding
    function usesCustomEventEncoding(TestInboxFactory.InboxType _inboxType)
        internal
        pure
        returns (bool)
    {
        return _inboxType == TestInboxFactory.InboxType.Optimized2
            || _inboxType == TestInboxFactory.InboxType.Optimized3;
    }

    /// @dev Gets a string representation of the Inbox type for logging
    /// @param _inboxType The type of Inbox implementation
    /// @return String representation of the type
    function getInboxTypeName(TestInboxFactory.InboxType _inboxType)
        internal
        pure
        returns (string memory)
    {
        if (_inboxType == TestInboxFactory.InboxType.Base) {
            return "Inbox (base)";
        } else if (_inboxType == TestInboxFactory.InboxType.Optimized1) {
            return "InboxOptimized1";
        } else if (_inboxType == TestInboxFactory.InboxType.Optimized2) {
            return "InboxOptimized2";
        } else if (_inboxType == TestInboxFactory.InboxType.Optimized3) {
            return "InboxOptimized3";
        } else {
            return "Unknown";
        }
    }
}
