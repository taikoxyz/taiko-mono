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
    /// @param id The ID of the proposed block
    /// @param meta The metadata of the proposed block
    /// @param blockFee The fee associated with the proposed block
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint32 rewardPerGas,
        uint64 feePerGas,
        TaikoData.BlockMetadata meta
    );

    /// @dev Emitted when a block is proven
    /// @param id The ID of the proven block
    /// @param parentHash The hash of the parent block
    /// @param blockHash The hash of the proven block
    /// @param signalRoot The signal root of the proven block
    /// @param prover The address of the prover
    /// @param parentGasUsed The gas used by the parent block
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
    /// @param deposit The information of the deposited Ethereum
    event EthDeposited(TaikoData.EthDeposit deposit);
}
