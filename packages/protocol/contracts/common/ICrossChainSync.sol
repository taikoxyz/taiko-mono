// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title ICrossChainSync
/// @dev This interface is implemented by both the TaikoL1 and TaikoL2
/// contracts.
/// It outlines the essential methods required for synchronizing and accessing
/// block hashes across chains. The core idea is to ensure that data between
/// both chains remain consistent and can be cross-referenced with integrity.
interface ICrossChainSync {
    /// @dev Emitted when a block has been synced across chains.
    /// @param srcHeight The height (block id_ that was synced.
    /// @param blockHash The hash of the synced block.
    /// @param signalRoot The root hash representing cross-chain signals.
    event CrossChainSynced(
        uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot
    );

    /// @notice Fetches the hash of a block from the opposite chain.
    /// @param blockId The target block id. Specifying 0 retrieves the hash
    /// of the latest block.
    /// @return The hash of the desired block from the other chain.
    function getCrossChainBlockHash(uint64 blockId)
        external
        view
        returns (bytes32);

    /// @notice Retrieves the root hash of the signal service storage for a
    /// given block from the opposite chain.
    /// @param blockId The target block id. Specifying 0 retrieves the root
    /// of the latest block.
    /// @return The root hash for the specified block's signal service.
    function getCrossChainSignalRoot(uint64 blockId)
        external
        view
        returns (bytes32);
}
