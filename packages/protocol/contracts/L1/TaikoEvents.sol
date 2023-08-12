// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "./TaikoData.sol";

/// @title TaikoEvents
/// @notice This abstract contract provides event declarations for the Taiko
/// protocol, which are emitted during block proposal, proof, verification, and
/// Ethereum deposit processes.
/// @dev The events defined here must match the definitions in the corresponding
/// L1 libraries.
abstract contract TaikoEvents {
    /// @dev Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param assignedProver The address of the assigned prover for the block.
    /// @param rewardPerGas The reward per gas unit for processing transactions
    /// in the block.
    /// @param feePerGas The fee per gas unit used for processing transactions
    /// in the block.
    /// @param meta The block metadata containing information about the proposed
    /// block.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint32 rewardPerGas,
        uint64 feePerGas,
        TaikoData.BlockMetadata meta
    );

    /// @dev Emitted when a block is proven.
    /// @param blockId The ID of the proven block.
    /// @param parentHash The hash of the parent block.
    /// @param blockHash The hash of the proven block.
    /// @param signalRoot The signal root of the proven block.
    /// @param prover The address of the prover who submitted the proof.
    /// @param parentGasUsed The gas used in the parent block.
    event BlockProven(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint32 parentGasUsed
    );

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param blockHash The hash of the verified block.
    /// @param prover The address of the prover that proved the block which is
    /// verified.
    /// @param blockFee The fee paid by the proposer for proposing the block.
    /// @param proofReward The reward earned by the prover for submitting the
    /// proof.
    event BlockVerified(
        uint256 indexed blockId,
        bytes32 blockHash,
        address prover,
        uint64 blockFee,
        uint64 proofReward
    );

    /// @dev Emitted when an Ethereum deposit is made.
    /// @param deposit The Ethereum deposit information including recipient,
    /// amount, and ID.
    event EthDeposited(TaikoData.EthDeposit deposit);
}
