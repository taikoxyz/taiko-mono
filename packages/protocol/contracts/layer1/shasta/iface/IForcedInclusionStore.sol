// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../lib/LibBlobs.sol";

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    /// @notice Represents a forced inclusion that will be stored onchain.
    struct ForcedInclusion {
        /// @notice The fee in Gwei that was paid to submit the forced inclusion.
        uint64 feeInGwei;
        /// @notice The timestamp when the forced inclusion was submitted.
        uint64 submittedAt;
        /// @notice The byte offset of the forced inclusion in the blob.
        /// @notice The proposal's frame.
        LibBlobs.BlobFrame frame;
    }

    /// @dev Event emitted when a forced inclusion is stored.
    event ForcedInclusionStored(ForcedInclusion forcedInclusion);

    /// @notice Store a forced inclusion request
    /// The priority fee must be paid to the contract
    /// @param _blobLocator The blob locator that contains the transaction data
    function storeForcedInclusion(LibBlobs.BlobLocator memory _blobLocator) external payable;

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
