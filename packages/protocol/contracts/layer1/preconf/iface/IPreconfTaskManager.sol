// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPreconfTaskManager
/// @custom:security-contact security@taiko.xyz
interface IPreconfTaskManager {
    struct Receipt {
        uint64 blockId;
        uint64 chainId;
        uint32 position;
        bool isExecutionPreconf;
        bytes32 txHash;
        bytes signature;
    }
}
