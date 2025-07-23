// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    struct ForcedInclusion {
        bytes32 blobHash;
        uint64 feeInGwei;
        uint64 createdAtBatchId;
        uint64 blobCreatedIn;
    }

    /// @dev Event emitted when a forced inclusion is stored.
    event ForcedInclusionStored(ForcedInclusion forcedInclusion);
    /// @dev Event emitted when a forced inclusion is consumed.
    event ForcedInclusionConsumed(ForcedInclusion forcedInclusion);

    /// @dev Error thrown when a blob is not found.
    error BlobNotFound();
    /// @dev Error thrown when the parameters are invalid.
    error InvalidParams();
    /// @dev Error thrown when the fee is incorrect.
    error IncorrectFee();
    /// @dev Error thrown when the index is invalid.
    error InvalidIndex();
    /// @dev Error thrown when a forced inclusion is not found.
    error NoForcedInclusionFound();
    /// @dev Error thrown when a function is called more than once in one transaction.
    error MultipleCallsInOneTx();

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
    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        returns (ForcedInclusion memory);

    /// @dev Store a forced inclusion request.
    /// The priority fee must be paid to the contract.
    /// @param blobIndex The index of the blob that contains the transaction data.
    ///                  The entire blob is used as the forced inclusion.
    function storeForcedInclusion(uint8 blobIndex) external payable;

    /// @dev Get the oldest forced inclusion without consuming it
    /// @return The oldest forced inclusion in the queue
    function getOldestForcedInclusion() external view returns (ForcedInclusion memory);
}
