// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

/// @title ICrossChainSync
/// @dev This interface is implemented by both the TaikoL1 and TaikoL2
/// contracts.
/// It outlines the essential methods required for synchronizing and accessing
/// block hashes across chains. The core idea is to ensure that data between
/// both chains remain consistent and can be cross-referenced with integrity.
interface ICrossChainSync {
    struct Snippet {
        uint64 blockId;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    /// @dev Emitted when a block has been synced across chains.
    /// @param blockId The ID of the remote block whose block hash are synced.
    /// @param blockHash The hash of the synced block.
    /// @param stateRoot The block's state root.
    event CrossChainSynced(uint64 indexed blockId, bytes32 blockHash, bytes32 stateRoot);

    /// @notice Fetches the hash of a block from the opposite chain.
    /// @return snippet The block hash and signal root synced.
    function getSyncedSnippet() external view returns (Snippet memory snippet);
}
