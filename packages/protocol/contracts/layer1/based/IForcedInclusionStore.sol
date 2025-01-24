// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {

    error ForcedInclusionAlreadyIncluded();
    error ForcedInclusionAlreadyStored();
    error ForcedInclusionNotFound();
    error ForcedInclusionInsufficientPriorityFee();
    error NotTaikoForcedInclusionInbox();


    event ForcedInclusionStored(ForcedInclusion forcedInclusion);

    event ForcedInclusionConsumed(ForcedInclusion forcedInclusion);

    struct ForcedInclusion {
        bytes32 blobHash;
        uint64 id;
        uint32 blobByteOffset;
        uint32 blobByteSize;
        uint256 priorityFee;
        uint256 timestamp;
        bool processed;
    }

    /// @dev Consume a forced inclusion request.
    /// The inclusion request must be marked as processed and the priority fee must be paid to the
    /// caller.
    function consumeForcedInclusion() external returns (ForcedInclusion memory);

    /// @dev Store a forced inclusion request.
    /// The priority fee must be paid to the contract.
    function storeForcedInclusion(bytes32 blobHash, uint32 blobByteOffset, uint32 blobByteSize) payable external;
}
