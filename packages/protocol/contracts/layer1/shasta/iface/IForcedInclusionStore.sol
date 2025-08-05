// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    /// @notice Represents a forced inclusion that will be stored onchain.
    struct ForcedInclusion {
        /// @notice The hash of the blob that contains the forced inclusion.
        bytes32 blobHash;
        /// @notice The fee in Gwei that was paid to submit the forced inclusion.
        uint64 feeInGwei;
        /// @notice The timestamp when the forced inclusion was submitted.
        uint64 submittedAt;
        /// @notice The byte offset of the forced inclusion in the blob.
        uint32 blobByteOffset;
        /// @notice The size in bytes of the forced inclusion in the blob.
        uint32 blobByteSize;
    }
    /// @dev Event emitted when a forced inclusion is stored.

    event ForcedInclusionStored(ForcedInclusion forcedInclusion);

    /// @dev Error thrown when a blob is not found
    error BlobNotFound();
    /// @dev Error thrown when the fee is incorrect
    error IncorrectFee();
    /// @dev Error thrown when a function is called more than once in one transaction
    error MultipleCallsInOneTx();
    /// @dev Error thrown when a forced inclusion is not found
    error NoForcedInclusionFound();

    /// @notice Store a forced inclusion request
    /// The priority fee must be paid to the contract
    /// @param blobIndex The index of the blob that contains the transaction data
    /// @param blobByteOffset The byte offset in the blob
    /// @param blobByteSize The size of the blob in bytes
    function storeForcedInclusion(
        uint256 blobIndex,
        uint32 blobByteOffset,
        uint32 blobByteSize
    )
        external
        payable;

    /// @notice Consume the oldest forced inclusion request and removes it from the queue
    /// @param _feeRecipient The address to receive the fee
    /// @return The forced inclusion that was consumed
    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        returns (ForcedInclusion memory);

    /// @notice Check if the oldest forced inclusion is due
    /// @return True if the oldest forced inclusion is due, false otherwise
    function isOldestForcedInclusionDue() external view returns (bool);
}
