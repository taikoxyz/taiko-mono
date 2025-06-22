// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    /// @dev 3 slots are used
    struct ForcedInclusion {
        bytes32 blobHash;
        uint64 feeInGwei;
        uint64 createdAtBatchId;
        uint32 blobByteOffset;
        uint32 blobByteSize;
        uint64 blobCreatedIn;
        address user;
        uint96 bondDeposit;
    }

    /// @dev Event emitted when a forced inclusion is stored.
    event ForcedInclusionStored(ForcedInclusion forcedInclusion);
    /// @dev Event emitted when a forced inclusion is consumed.
    event ForcedInclusionConsumed(ForcedInclusion forcedInclusion, bool successful);

    error BlobNotFound();
    error InvalidParams();
    error IncorrectFee();
    error InvalidIndex();
    error NoForcedInclusionFound();
    error MultipleCallsInOneTx();
    error BondDepositTooSmall();
    error InvalidMsgValue();

    /// @dev Retrieve a forced inclusion request by its index.
    /// @param index The index of the forced inclusion request in the queue.
    /// @return The forced inclusion request at the specified index.
    function getForcedInclusion(uint256 index) external view returns (ForcedInclusion memory);

    /// @dev Get the deadline for the oldest forced inclusion.
    /// @return The deadline for the oldest forced inclusion.
    function getOldestForcedInclusionDeadline() external view returns (uint256);

    /// @dev Check if the oldest forced inclusion is due.
    /// @return True if the oldest forced inclusion is due, false otherwise.
    function isOldestForcedInclusionDue() external view returns (bool);

    /// @dev Consume a forced inclusion request.
    /// The inclusion request must be marked as processed and the priority fee must be paid to the
    /// caller.
    /// @param _feeRecipient The address to receive the priority fee.
    /// @return inclusion_ The forced inclusion request.
    /// @return successful_ True if the forced inclusion was successfully processed, false
    /// otherwise.
    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        returns (ForcedInclusion memory inclusion_, bool successful_);

    /// @dev Store a forced inclusion request.
    /// The priority fee must be paid to the contract.
    /// @param blobIndex The index of the blob that contains the transaction data.
    /// @param blobByteOffset The byte offset in the blob
    /// @param blobByteSize The size of the blob in bytes
    /// @param bondDeposit The bond deposit amount in Taiko tokens.
    function storeForcedInclusion(
        uint8 blobIndex,
        uint32 blobByteOffset,
        uint32 blobByteSize,
        uint96 bondDeposit
    )
        external
        payable;
}
