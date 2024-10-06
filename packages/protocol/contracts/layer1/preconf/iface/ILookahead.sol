// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILookahead
/// @custom:security-contact security@taiko.xyz
interface ILookahead {
    struct LookaheadBufferEntry {
        // True when the preconfer is randomly selected
        bool isFallback;
        // Timestamp of the slot at which the provided preconfer is the L1 validator
        uint40 timestamp;
        // Timestamp of the last slot that had a valid preconfer
        uint40 prevTimestamp;
        // Address of the preconfer who is also the L1 validator
        // The preconfer will have rights to propose a block in the range (prevTimestamp, timestamp]
        address preconfer;
    }

    struct LookaheadSetParam {
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

    event LookaheadUpdated(LookaheadSetParam[]);
    event IncorrectLookaheadProved(
        address indexed poster, uint256 indexed timestamp, address indexed disputer
    );

    function forceUpdateLookahead(LookaheadSetParam[] calldata lookaheadSetParams) external;
    function updateLookahead(LookaheadSetParam calldata _lookaheadSetParams) external;
    function isCurrentPreconfer(address addr) external view returns (bool);
    function isLookaheadRequired() external view returns (bool);
}
