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
// TODO: delete this file.
interface ICrossChainSync {
    struct Snippet {
        uint64 remoteBlockId;
        uint64 syncedInBlock;
        bytes32 blockHash;
        bytes32 stateRoot;
    }
}
