// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Generated from the pinned EtnaInbox ABI; do not edit.
event BatchRewardRecorded(
    bytes32 indexed batchId,
    address indexed l2RewardRecipient,
    uint256 baseFeeAmount,
    uint64 generation,
    uint64 parentHeight,
    bytes32 parentHash,
    uint64 lastHeight,
    bytes32 lastBlockHash
);
