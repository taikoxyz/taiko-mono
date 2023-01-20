// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../common/IHeaderSync.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestHeaderSync is IHeaderSync {
    bytes32 public headerHash;

    function setSyncedHeader(bytes32 header) external {
        headerHash = header;
    }

    function getSyncedHeader(uint256 number) external view returns (bytes32) {
        number;
        return headerHash;
    }

    function getLatestSyncedHeader() external view returns (bytes32) {
        return headerHash;
    }
}
