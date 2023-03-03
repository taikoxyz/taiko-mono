// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

/**
 * Interface implemented by both the TaikoL1 and TaikoL2 contracts. It exposes
 * the methods needed to access the block hashes of the other chain.
 */

struct SyncData {
    bytes32 blockHash;
    bytes32 signalStorageRoot;
}

interface IHeaderSync {
    event HeaderSynced(uint256 indexed srcHeight, SyncData srcSyncData);

    function getSyncedBlockHash(uint256 number) external view returns (bytes32);

    function getSyncedSignalStorageRoot(
        uint256 number
    ) external view returns (bytes32);
}
