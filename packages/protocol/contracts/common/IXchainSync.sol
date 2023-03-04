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

struct Snippet {
    bytes32 blockHash;
    bytes32 signalRoot;
}

interface IXchainSync {
    event XchainSynced(uint256 indexed srcHeight, Snippet srcSnippet);

    function getSyncedBlockHash(uint256 number) external view returns (bytes32);

    function getSyncedSignalRoot(
        uint256 number
    ) external view returns (bytes32);
}
