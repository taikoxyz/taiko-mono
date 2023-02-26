// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

struct SyncData {
    bytes32 blockHash;
    bytes32 signalServiceStorageRoot;
}

/**
 * Interface implemented by both the TaikoL1 and TaikoL2 contracts. It exposes
 * the methods needed to access the block hashes of the other chain.
 */
interface IHeaderSync {
    event HeaderSynced(uint256 indexed srcHeight, SyncData syncData);

    function getSyncData(
        uint256 number
    ) external view returns (SyncData memory);

    function getLatestSyncData() external view returns (SyncData memory);
}
