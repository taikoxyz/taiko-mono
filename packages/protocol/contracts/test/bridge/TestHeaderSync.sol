// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IHeaderSync, SyncData} from "../../common/IHeaderSync.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestHeaderSync is IHeaderSync {
    SyncData public syncData;

    function setSyncedHeader(SyncData calldata _syncData) external {
        syncData = _syncData;
    }

    function getSyncedBlockHash(uint256) external view returns (bytes32) {
        return syncData.blockHash;
    }

    function getSyncedSignalStorageRoot(
        uint256
    ) external view returns (bytes32) {
        return syncData.sssr;
    }
}
