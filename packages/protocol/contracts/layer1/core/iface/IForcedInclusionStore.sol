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
        /// @notice The proposal's blob slice.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @dev Event emitted when a forced inclusion is stored.
    event ForcedInclusionSaved(ForcedInclusion forcedInclusion);

    /// @notice Saves a forced inclusion request
    /// The priority fee must be paid to the contract
    /// @param _blobReference The blob locator that contains the transaction data
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable;

    /// @notice Returns all forced inclusions that are due for processing.
    /// @return dueInclusions_ Array of inclusions that satisfy the forced inclusion delay.
    function getDueForcedInclusions()
        external
        view
        returns (ForcedInclusion[] memory dueInclusions_);
}
