// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibEIP4788.sol";

/// @title ILookahead
/// @custom:security-contact security@taiko.xyz
interface ILookahead {
    struct LookaheadEntry {
        // Indicates if this entry is for a fallback preconfer, which is selected randomly.
        bool isFallback;
        // The timestamp from which this preconfer becomes the current preconfer.
        uint40 validSince; // exclusive
        // The timestamp until which this preconfer remains the current preconfer.
        uint40 validUntil; // inclusive
        // The address of this preconfer.
        address preconfer;
    }

    struct LookaheadParam {
        // The timestamp until which this preconfer remains the current preconfer.
        uint40 validUntil;
        // The AVS operator who is also the L1 validator for the slot and will preconf L2
        // transactions
        address preconfer;
    }

    struct LookaheadMetadata {
        // True if the lookahead was proved to be incorrect
        bool incorrect;
        // The poster of the lookahead
        address poster;
        // Fallback preconfer selected for the epoch in which the lookahead was posted
        // This is only set when the lookahead is proved to be incorrect
        address fallbackPreconfer;
    }

    event EntryUpdated(uint256 indexed id, LookaheadEntry entry);

    event IncorrectLookaheadProved(
        address indexed poster, uint256 indexed timestamp, address indexed disputer
    );

    function forcePostLookahead(LookaheadParam[] calldata _lookaheadParams) external;
    function postLookahead(LookaheadParam[] calldata _lookaheadParams) external;
    function isCurrentPreconfer(address addr) external view returns (bool);
    function getPoster(uint256 _epochTimestamp) external view returns (address);

    /// @notice Proves that the lookahead entry is incorrect for a given slot.
    /// @param _lookaheadPointer The pointer to the lookahead entry being disputed.
    /// @param _slotTimestamp The timestamp of the slot for which the lookahead is being proved
    /// incorrect.
    /// @param _validatorBLSPubKey The BLS public key of the validator involved in the dispute.
    /// @param _validatorInclusionProof The proof of inclusion for the validator's BLS public key.
    function proveIncorrectLookahead(
        uint256 _lookaheadPointer,
        uint256 _slotTimestamp,
        bytes calldata _validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata _validatorInclusionProof
    )
        external;
}
