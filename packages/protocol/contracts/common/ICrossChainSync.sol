// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * Interface implemented by both the TaikoL1 and TaikoL2 contracts. It exposes
 * the methods needed to access the block hashes of the other chain.
 */

interface ICrossChainSync {
    event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot);

    /**
     * @notice Returns the cross-chain block hash at the given block number.
     * @param number The block number. Use 0 for the latest block.
     * @return The cross-chain block hash.
     */
    function getCrossChainBlockHash(uint256 number) external view returns (bytes32);

    /**
     * @notice Returns the cross-chain signal service storage root at the given
     *         block number.
     * @param number The block number. Use 0 for the latest block.
     * @return The cross-chain signal service storage root.
     */
    function getCrossChainSignalRoot(uint256 number) external view returns (bytes32);
}
