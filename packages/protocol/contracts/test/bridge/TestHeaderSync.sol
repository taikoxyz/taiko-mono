// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IXchainSync} from "../../common/IXchainSync.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestXchainSync is IXchainSync {
    bytes32 private _blockHash;
    bytes32 private _signalRoot;

    function setXchainBlockHeader(bytes32 blockHash) external {
        _blockHash = blockHash;
    }

    function seXchainSignalRoot(bytes32 signalRoot) external {
        _blockHash = signalRoot;
    }

    function getXchainBlockHash(uint256) external view returns (bytes32) {
        return _blockHash;
    }

    function getXchainSignalRoot(uint256) external view returns (bytes32) {
        return _signalRoot;
    }
}
