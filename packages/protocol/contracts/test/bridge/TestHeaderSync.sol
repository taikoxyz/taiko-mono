// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {ISnippetSync, Snippet} from "../../common/ISnippetSync.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestSnippetSync is ISnippetSync {
    Snippet public snippet;

    function setSyncedHeader(Snippet calldata _snippet) external {
        snippet = _snippet;
    }

    function getSyncedBlockHash(uint256) external view returns (bytes32) {
        return snippet.blockHash;
    }

    function getSyncedSignalStorageRoot(
        uint256
    ) external view returns (bytes32) {
        return snippet.signalStorageRoot;
    }
}
