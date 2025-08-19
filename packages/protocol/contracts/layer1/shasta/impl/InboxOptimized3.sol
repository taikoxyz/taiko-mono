// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { InboxOptimized2 } from "./InboxOptimized2.sol";
import { LibProposeDataDecoder } from "../libs/LibProposeDataDecoder.sol";
import { LibProveDataDecoder } from "../libs/LibProveDataDecoder.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";

/// @title InboxOptimized3
/// @notice Inbox optimized, on top of InboxOptimized2, to lower calldata cost.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized3 is InboxOptimized2 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() InboxOptimized2() { }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Encodes the propose data into bytes format.
    /// @param _deadline The deadline for the proposal.
    /// @param _coreState The core state of the proposal.
    /// @param _proposals The array of proposals.
    /// @param _blobReference The blob reference associated with the proposal.
    /// @param _claimRecords The array of claim records.
    /// @return Encoded bytes of the propose data.
    function encodeProposeData(
        uint48 _deadline,
        CoreState memory _coreState,
        Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobReference,
        ClaimRecord[] memory _claimRecords
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProposeDataDecoder.encode(
            _deadline, _coreState, _proposals, _blobReference, _claimRecords
        );
    }

    /// @notice Encodes the prove data into bytes format.
    /// @param _proposals The array of proposals.
    /// @param _claims The array of claims.
    /// @return Encoded bytes of the prove data.
    function encodeProveData(
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProveDataDecoder.encode(_proposals, _claims);
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
            uint48 deadline_,
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
