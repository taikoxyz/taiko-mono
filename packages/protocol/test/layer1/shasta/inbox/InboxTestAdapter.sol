// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestInboxFactory.sol";
import "./InboxTestLib.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibProposeDataDecoder.sol";
import "contracts/layer1/shasta/libs/LibProveDataDecoder.sol";
import "contracts/layer1/shasta/libs/LibProposedEventEncoder.sol";
import "contracts/layer1/shasta/libs/LibProvedEventEncoder.sol";

/// @title InboxTestAdapter
/// @notice Adapter to handle encoding/decoding differences between Inbox implementations
/// @dev Provides unified interface for test data encoding across all Inbox variants
/// @custom:security-contact security@taiko.xyz
library InboxTestAdapter {
    /// @dev Encodes proposal data based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _deadline The deadline for the proposal
    /// @param _coreState The core state
    /// @param _proposals The validation proposals
    /// @param _blobRef The blob reference
    /// @param _claimRecords The claim records for finalization
    /// @return Encoded proposal data
    function encodeProposalData(
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
        if (_inboxType == TestInboxFactory.InboxType.Optimized3) {
            // InboxOptimized3 uses custom encoding
            return LibProposeDataDecoder.encode(
                _deadline, _coreState, _proposals, _blobRef, _claimRecords
            );
        } else {
            // Base, Optimized1, and Optimized2 use standard abi.encode
            return abi.encode(_deadline, _coreState, _proposals, _blobRef, _claimRecords);
        }
    }

    /// @dev Encodes prove data based on the Inbox implementation type
    /// @param _inboxType The type of Inbox implementation
    /// @param _proposals The proposals to prove
    /// @param _claims The claims with proof details
    /// @return Encoded prove data
    function encodeProveData(
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
            return LibProveDataDecoder.encode(_proposals, _claims);
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
            return LibProposedEventEncoder.decode(_data);
        } else {
            // Base and Optimized1 emit the standard structs
            // The event data would be the encoded structs
            (proposal_, coreState_) = abi.decode(_data, (IInbox.Proposal, IInbox.CoreState));
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
            return LibProvedEventEncoder.decode(_data);
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
