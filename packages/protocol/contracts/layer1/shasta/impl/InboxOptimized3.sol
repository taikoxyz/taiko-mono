// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxOptimized2.sol";
import "../libs/LibProposeDataDecoder.sol";
import "../libs/LibProveDataDecoder.sol";

/// @title InboxOptimized3
/// @notice Inbox optimized, on top of InboxOptimized2, to lower calldata cost.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized3 is InboxOptimized2 {
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() InboxOptimized2() { }

     // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Encodes the propose data into bytes format.
    /// @param deadline_ The deadline for the proposal.
    /// @param coreState_ The core state of the proposal.
    /// @param proposals_ The array of proposals.
    /// @param blobReference_ The blob reference associated with the proposal.
    /// @param claimRecords_ The array of claim records.
    /// @return Encoded bytes of the propose data.
    function encodeProposeData(
        uint64 deadline_,
        CoreState memory coreState_,
        Proposal[] memory proposals_,
        LibBlobs.BlobReference memory blobReference_,
        ClaimRecord[] memory claimRecords_
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProposeDataDecoder.encode(
            deadline_,
            coreState_,
            proposals_,
            blobReference_,
            claimRecords_
        );
    }

    /// @notice Encodes the prove data into bytes format.
    /// @param proposals_ The array of proposals.
    /// @param claims_ The array of claims.
    /// @return Encoded bytes of the prove data.
    function encodeProveData(
        Proposal[] memory proposals_,
        Claim[] memory claims_
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProveDataDecoder.encode(proposals_, claims_);
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    function decodeProposeData(bytes calldata _data)
        public
        pure
        override
        returns (
            uint64 deadline_,
            CoreState memory coreState_,
            Proposal[] memory proposals_,
            LibBlobs.BlobReference memory blobReference_,
            ClaimRecord[] memory claimRecords_
        )
    {
        return LibProposeDataDecoder.decode(_data);
    }

    /// @inheritdoc Inbox
    function decodeProveData(bytes calldata _data)
        public
        pure
        override
        returns (Proposal[] memory proposals_, Claim[] memory claims_)
    {
        return LibProveDataDecoder.decode(_data);
    }
}
