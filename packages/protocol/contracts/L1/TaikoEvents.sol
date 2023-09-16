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
    /// @param reward The proposer's block reward in Taiko token.
    /// @param meta The block metadata containing information about the proposed
    /// block.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 assignmentBond,
        uint256 reward,
        TaikoData.BlockMetadata meta
    );

    event Proven(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint96 proofBond,
        uint16 tier
    );

    event Contested(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The address of the prover that proved the block which is
    /// verified.
    /// @param blockHash The hash of the verified block.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed assignedProver,
        address indexed prover,
        bytes32 blockHash
    );

    /// @dev Emitted when an Ethereum deposit is made.
    /// @param deposit The Ethereum deposit information including recipient,
    /// amount, and ID.
    event EthDeposited(TaikoData.EthDeposit deposit);

    /// @dev The following events are emitted when bonds are received, returned,
    /// or rewarded. Note that no event is emitted when a bond is kept/burnt as
    /// for a single block, multiple bonds may get burned or retained by the
    /// protocol, emitting events will consume more gas.
    event BondReceived(address indexed from, uint64 blockId, uint256 bond);
    event BondReturned(address indexed to, uint64 blockId, uint256 bond);
    event BondRewarded(address indexed to, uint64 blockId, uint256 bond);
}
