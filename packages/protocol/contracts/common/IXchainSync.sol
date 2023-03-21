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



interface IXchainSync {
    event XchainSynced(uint256 indexed srcHeight,  bytes32 blockHash,
    bytes32 signalRoot);

    /**
     * @notice Returns the cross-chain block hash at the given block number.
     * @param number The block number. Use 0 for the latest block.
     * @return The cross-chain block hash.
     */
    function getXchainBlockHash(uint256 number) external view returns (bytes32);

    /**
     * @notice Returns the cross-chain signal service storage root at the given
     *         block number.
     * @param number The block number. Use 0 for the latest block.
     * @return The cross-chain signal service storage root.
     */
    function getXchainSignalRoot(
        uint256 number
    ) external view returns (bytes32);
}
