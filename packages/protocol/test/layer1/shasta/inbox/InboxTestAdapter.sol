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
    /// @param _claimRecords The claim records for finalization
    /// @return Encoded propose input
    function encodeProposeInput(
        TestInboxFactory.InboxType _inboxType,
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        // Default endBlockMiniHeader - will be overridden by the other function if needed
        IInbox.BlockMiniHeader memory endBlockMiniHeader = IInbox.BlockMiniHeader({
            number: 0,
            hash: bytes32(0),
            stateRoot: bytes32(0)
        });
        
        return encodeProposeInputWithEndBlock(
            _inboxType,
            _deadline,
            _coreState,
            _proposals,
            _blobRef,
            _claimRecords,
            endBlockMiniHeader
        );
    }
    
    /// @dev Encodes propose input with explicit endBlockMiniHeader
    function encodeProposeInputWithEndBlock(
        TestInboxFactory.InboxType _inboxType,
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords,
        IInbox.BlockMiniHeader memory _endBlockMiniHeader
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
                claimRecords: _claimRecords,
                endBlockMiniHeader: _endBlockMiniHeader
            });
            return LibProposeInputDecoder.encode(input);
        } else {
            // Base, Optimized1, and Optimized2 use standard abi.encode
            // For these implementations, endBlockMiniHeader is the 6th parameter
            return abi.encode(_deadline, _coreState, _proposals, _blobRef, _claimRecords, _endBlockMiniHeader);
        }
    }

    /// @dev Encodes prove input based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _proposals The proposals to prove
    /// @param _claims The claims with proof details
    /// @return Encoded prove input
    function encodeProveInput(
        TestInboxFactory.InboxType _inboxType,
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        internal
        pure
        returns (bytes memory)
    {
        if (_inboxType == TestInboxFactory.InboxType.Optimized3) {
            // InboxOptimized3 uses custom encoding
            // Create ProveInput struct
            IInbox.ProveInput memory input = IInbox.ProveInput({
                proposals: _proposals,
                claims: _claims
            });
            return LibProveInputDecoder.encode(input);
        } else {
            // Base, Optimized1, and Optimized2 use standard abi.encode
            return abi.encode(_proposals, _claims);
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
    /// @return claimRecord_ The decoded claim record
    function decodeProvedEventData(
        TestInboxFactory.InboxType _inboxType,
        bytes memory _data
    )
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        if (
            _inboxType == TestInboxFactory.InboxType.Optimized2
                || _inboxType == TestInboxFactory.InboxType.Optimized3
        ) {
            // InboxOptimized2 and InboxOptimized3 use custom event encoding
            IInbox.ProvedEventPayload memory payload = LibProvedEventEncoder.decode(_data);
            return payload.claimRecord;
        } else {
            // Base and Optimized1 emit the standard struct
            claimRecord_ = abi.decode(_data, (IInbox.ClaimRecord));
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
