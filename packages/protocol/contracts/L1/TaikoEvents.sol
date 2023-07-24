// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "./TaikoData.sol";

/// @title TaikoEvents - Event declarations for the Taiko protocol
abstract contract TaikoEvents {
    // The following events must match the definitions in corresponding L1
    // libraries.

    /// @dev Emitted when a block is proposed
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint32 rewardPerGas,
        uint64 feePerGas,
        TaikoData.BlockMetadata meta
    );

    /// @dev Emitted when a block is proven
    event BlockProven(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint32 parentGasUsed
    );

    event BlockVerified(
        uint256 indexed blockId,
        bytes32 blockHash,
        address prover,
        uint64 blockFee,
        uint64 proofReward
    );

    /// @dev Emitted when an Ethereum deposit is made
    event EthDeposited(TaikoData.EthDeposit deposit);
}
