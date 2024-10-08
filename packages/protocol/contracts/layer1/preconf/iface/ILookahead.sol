// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibEIP4788.sol";

/// @title ILookahead
/// @custom:security-contact security@taiko.xyz
interface ILookahead {
    struct Entry {
        // The address of this preconfer.
        address preconfer;
        // The slot from which this preconfer becomes the current preconfer.
        uint40 startSlot; // exclusive
        // The slot until which this preconfer remains the current preconfer.
        uint40 endSlot; // inclusive
        // Indicates if this entry is for a fallback preconfer, which is selected randomly.
        bool isFallback;
    }

    struct EntryParam {
        // The AVS operator who is also the L1 validator for the slot and will preconf L2
        // transactions
        address preconfer;
        // The slot until which this preconfer remains the current preconfer.
        uint40 endSlot;
    }

    /// @notice Emitted when a lookahead entry is updated.
    event EntryUpdated(uint256 indexed id, Entry entry);

    /// @notice Emitted when a lookahead entry is proven to be incorrect.
    event IncorrectLookaheadProved(
        uint256 indexed slot,
        bytes32 indexed validatorBLSPubKeyHash,
        address indexed poster,
        Entry entry
    );

    /// @notice Forces the posting of lookahead parameters regardless of current conditions.
    /// This function is only callable by preconfers.
    /// @param _lookaheadParams An array of `EntryParam` structures detailing the lookahead
    /// entries.
    function forcePostLookahead(EntryParam[] calldata _lookaheadParams) external;

    /// @notice Posts lookahead parameters if certain conditions are met.
    /// This function is only callable by the PreconfTaskManager.
    /// @param _lookaheadParams An array of `EntryParam` structures detailing the lookahead
    /// entries.
    function postLookahead(EntryParam[] calldata _lookaheadParams) external;

    /// @notice Proves that the lookahead entry is incorrect for a given slot.
    /// @param _lookaheadPointer The pointer to the lookahead entry being disputed.
    /// @param _slot The timestamp of the slot for which the lookahead is being proved
    /// incorrect.
    /// @param _validatorBLSPubKey The BLS public key of the validator involved in the dispute.
    /// @param _validatorInclusionProof The proof of inclusion for the validator's BLS public key.
    function proveIncorrectLookahead(
        uint256 _lookaheadPointer,
        uint256 _slot,
        bytes calldata _validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata _validatorInclusionProof
    )
        external;

    /// @notice Builds and returns lookahead set parameters for an epoch
    /// @dev This function can be used by the offchain node to create the lookahead to be posted.
    /// @param _epochSlot The start timestamp of the epoch for which the lookahead is to be
    /// generated
    /// @param _validatorBLSPubKeys The BLS public keys of the validators who are expected to
    /// propose
    /// in the epoch
    /// in the same sequence as they appear in the epoch. So at index n - 1, we have the validator
    /// for slot n in that
    /// epoch.
    /// @return An array of EntryParam structures for the given epoch.
    function buildEntryParamsForEpoch(
        uint256 _epochSlot,
        bytes[32] calldata _validatorBLSPubKeys
    )
        external
        view
        returns (EntryParam[] memory);

    /// @notice Returns if the given address is the current preconfer.
    /// @param _lookaheadPointer The index of the lookahead entry to check.
    /// @param _address The address to verify as the current preconfer.
    /// @return True if the address is the current preconfer for the specified lookahead entry,
    /// false otherwise.
    function isCurrentPreconfer(
        uint256 _lookaheadPointer,
        address _address
    )
        external
        view
        returns (bool);

    /// @dev Retrieves the addresses of the preconfers assigned to each of the 32 slots within the
    /// specified epoch.
    /// @param _epochFirstSlot starting timestamp of the epoch for which the lookahead is
    /// requested.
    /// @return An array of 32 addresses, each representing the preconfer for a corresponding slot
    /// in the epoch.
    function getLookaheadForEpoch(uint256 _epochFirstSlot)
        external
        view
        returns (address[32] memory);

    /// @notice Retrieves the fallback preconfer for a given epoch timestamp.
    /// @param _epochFirstSlot The epoch timestamp to query the fallback preconfer for.
    /// @return The address of the fallback preconfer for the specified epoch timestamp.
    function getFallbackPreconfer(uint256 _epochFirstSlot) external view returns (address);

    /// @notice Retrieves the address of the poster responsible for a given epoch timestamp.
    /// @param _epochFirstSlot The epoch timestamp to query the poster for.
    /// @return The address of the poster for the specified epoch timestamp.
    function getPoster(uint256 _epochFirstSlot) external view returns (address);
}
