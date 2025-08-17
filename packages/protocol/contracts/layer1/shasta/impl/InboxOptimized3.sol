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
