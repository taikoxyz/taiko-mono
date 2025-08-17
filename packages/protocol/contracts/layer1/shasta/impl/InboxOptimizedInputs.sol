// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxOptimized.sol";

/// @title InboxOptimized
/// @notice Combines slot reuse and claim aggregation optimizations for the Inbox contract
/// @dev This contract merges the optimizations from InboxWithSlotReuse and
/// InboxWithClaimAggregation
/// to provide both storage optimization through slot reuse and gas optimization through claim
/// aggregation
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimizedInputs is InboxOptimized {
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() InboxOptimized() { }

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
        return super.decodeProposeData(_data);
    }

    /// @inheritdoc Inbox
    function decodeProveData(bytes calldata _data)
        public
        pure
        override
        returns (Proposal[] memory proposals_, Claim[] memory claims_)
    {
        return super.decodeProveData(_data);
    }
}
