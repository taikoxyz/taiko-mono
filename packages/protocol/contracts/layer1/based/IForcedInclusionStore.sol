// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    struct ForcedInclusion {
        bytes32 blobHash;
        uint64 id;
        uint32 blobByteOffset;
        uint32 blobByteSize;
        uint256 priorityFee;
    }

    /// @dev Consume a forced inclusion request.
    /// The inclusion request must be marked as process and the priority fee must be paid to the
    /// caller.
    function consumeForcedInclusion() external returns (ForcedInclusion memory);
}
