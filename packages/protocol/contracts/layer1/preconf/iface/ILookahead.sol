// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
        // The timestamp of the slot
        uint256 timestamp;
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

    event LookaheadPosted(LookaheadParam[]);
    event IncorrectLookaheadProved(
        address indexed poster, uint256 indexed timestamp, address indexed disputer
    );

    function forcePostLookahead(LookaheadParam[] calldata _lookaheadParams) external;
    function postLookahead(LookaheadParam[] calldata _lookaheadParams) external;
    function isCurrentPreconfer(address addr) external view returns (bool);
}
