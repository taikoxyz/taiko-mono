// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IHeaderSync} from "../../common/IHeaderSync.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestHeaderSync is IHeaderSync {
    bytes32 public blockHash;

    function setSyncedHeader(bytes32 _blockHash) external {
        blockHash = _blockHash;
    }

    function getSyncedBlockHash(uint256) external view returns (bytes32) {
        return blockHash;
    }

    function getLatestSyncedBlockHash() external view returns (bytes32) {
        return blockHash;
    }
}
