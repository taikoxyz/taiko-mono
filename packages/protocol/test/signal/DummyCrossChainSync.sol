// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ICrossChainSync } from "../../contracts/common/ICrossChainSync.sol";

contract DummyCrossChainSync is ICrossChainSync {
    bytes32 private _blockHash;
    bytes32 private _signalRoot;

    function setCrossChainBlockHeader(bytes32 blockHash) external {
        _blockHash = blockHash;
    }

    function setCrossChainSignalRoot(bytes32 signalRoot) external {
        _signalRoot = signalRoot;
    }

    function getCrossChainBlockHash(uint64) external view returns (bytes32) {
        return _blockHash;
    }

    function getCrossChainSignalRoot(uint64) external view returns (bytes32) {
        return _signalRoot;
    }
}
