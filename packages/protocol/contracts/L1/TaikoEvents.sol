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
    /// @param assignedProver The block's assigned prover.
    /// @param livenessBond The bond in Taiko token from the assigned prover.
    /// @param proverFee The fee paid to the assigned prover.
    /// @param reward The proposer's block reward in Taiko token.
    /// @param meta The block metadata containing information about the proposed
    /// block.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        uint256 proverFee,
        uint256 reward,
        TaikoData.BlockMetadata meta
    );

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param assignedProver The block's assigned prover.
    /// @param prover The prover whose transition is used for verifing the
    /// block.
    /// @param blockHash The hash of the verified block.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed assignedProver,
        address indexed prover,
        bytes32 blockHash,
        bytes32 signalRoot
    );

    /// @dev Emitted when a block transition is proved or re-proved.
    event TransitionProved(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint96 validityBond,
        uint16 tier
    );

    /// @dev Emitted when a block transition is contested.
    event TransitionContested(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    /// @dev Emitted when an Ethereum deposit is made.
    /// @param deposit The Ethereum deposit information including recipient,
    /// amount, and ID.
    event EthDeposited(TaikoData.EthDeposit deposit);

    /// @dev Emitted when a user deposited Taiko token into this contract.
    event TokenDeposited(uint256 amount);

    /// @dev Emitted when a user withdrawed Taiko token from this contract.
    event TokenWithdrawn(uint256 amount);

    /// @dev Emitted when Taiko token are credited  to the user's in-protocol
    /// balance.
    event TokenCredited(uint256 amount, bool minted);

    /// @dev Emitted when Taiko token are debited from the user's in-protocol
    /// balance.
    event TokenDebited(uint256 amount, bool fromLocalBalance);

    /// @dev Emitted when the owner withdrawn Taiko token from this contract.
    event TokenWithdrawnByOwner(address to, uint256 amount);
}
