// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    /// @notice Represents a forced inclusion that will be stored onchain.
    struct ForcedInclusion {
        /// @notice The fee in Gwei that was paid to submit the forced inclusion.
        uint64 feeInGwei;
        /// @notice The proposal's chunk.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @dev Event emitted when a forced inclusion is stored.
    event ForcedInclusionStored(ForcedInclusion forcedInclusion);

    /// @notice Stores a forced inclusion request
    /// The priority fee must be paid to the contract
    /// @param _blobReference The blob locator that contains the transaction data
    function storeForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable;

    /// @notice Consumes the oldest forced inclusion request and removes it from the queue
    /// @param _feeRecipient The address to receive the fee
    /// @return The forced inclusion that was consumed
    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        returns (ForcedInclusion memory);

    /// @notice Checks if the oldest forced inclusion is due
    /// @return True if the oldest forced inclusion is due, false otherwise
    function isOldestForcedInclusionDue() external view returns (bool);
}
