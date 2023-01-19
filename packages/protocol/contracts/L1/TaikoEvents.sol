// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "./TaikoData.sol";

/// @author david <david@taiko.xyz>
abstract contract TaikoEvents {
    // The following events must match the definitions in other V1 libraries.
    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event BlockCommitted(
        uint64 commitSlot,
        uint64 commitHeight,
        bytes32 commitHash
    );

    event BlockProposed(uint256 indexed id, TaikoData.BlockMetadata meta);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 timestamp,
        uint64 provenAt,
        address prover
    );

    event Halted(bool halted);
}
