// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoData.sol";

/// @title TaikoEvents
/// @notice This abstract contract provides event declarations for the Taiko
/// protocol, which are emitted during block proposal, proof, verification, and
/// Ethereum deposit processes.
/// @dev The events defined here must match the definitions in the corresponding
/// L1 libraries.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoEvents {
    /// @dev Emitted when token is credited back to a user's bond balance.
    event BondCredited(address indexed user, uint256 blockId, uint256 amount);

    /// @dev Emitted when token is debited from a user's bond balance.
    event BondDebited(address indexed user, uint256 blockId, uint256 amount);

    /// @dev DEPRECATED but used by node/client for syncing old blocks
    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param assignedProver The address of the assigned prover.
    /// @param livenessBond The liveness bond of the proposed block.
    /// @param meta The metadata of the proposed block.
    /// @param depositsProcessed The EthDeposit array about processed deposits in this proposed
    /// block.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        TaikoData.BlockMetadata meta,
        TaikoData.EthDeposit[] depositsProcessed
    );

    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param meta The metadata of the proposed block.
    event BlockProposedV2(uint256 indexed blockId, TaikoData.BlockMetadataV2 meta);

    /// @notice Emitted when a block's txList is in the calldata.
    /// @param blockId The ID of the proposed block.
    /// @param txList The txList.
    event CalldataTxList(uint256 indexed blockId, bytes txList);

    /// @dev DEPRECATED but used by node/client for syncing old blocks
    /// @notice Emitted when a transition is proved.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param prover The prover's address.
    /// @param validityBond The validity bond amount.
    /// @param tier The tier of the proof.
    event TransitionProved(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address prover,
        uint96 validityBond,
        uint16 tier
    );

    /// @notice Emitted when a transition is proved.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param prover The prover's address.
    /// @param validityBond The validity bond amount.
    /// @param tier The tier of the proof.
    /// @param proposedIn The L1 block in which a transition is proved.
    event TransitionProvedV2(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address prover,
        uint96 validityBond,
        uint16 tier,
        uint64 proposedIn
    );

    /// @dev DEPRECATED but used by node/client for syncing old blocks
    /// @notice Emitted when a transition is contested.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param contester The contester's address.
    /// @param contestBond The contest bond amount.
    /// @param tier The tier of the proof.
    event TransitionContested(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    /// @notice Emitted when a transition is contested.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param contester The contester's address.
    /// @param contestBond The contest bond amount.
    /// @param tier The tier of the proof.
    /// @param proposedIn The L1 block in which this L2 block is proposed.
    event TransitionContestedV2(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address contester,
        uint96 contestBond,
        uint16 tier,
        uint64 proposedIn
    );

    /// @notice Emitted when proving is paused or unpaused.
    /// @param paused The pause status.
    event ProvingPaused(bool paused);

    /// @dev DEPRECATED but used by node/client for syncing old blocks
    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The prover whose transition is used for verifying the
    /// block.
    /// @param blockHash The hash of the verified block.
    /// @param stateRoot Deprecated and is always zero.
    /// @param tier The tier ID of the proof.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed prover,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tier
    );

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The prover whose transition is used for verifying the
    /// block.
    /// @param blockHash The hash of the verified block.
    /// @param tier The tier ID of the proof.
    event BlockVerifiedV2(
        uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier
    );

    /// @notice Emitted when some state variable values changed.
    /// @dev This event is currently used by Taiko node/client for block proposal/proving.
    /// @param slotB The SlotB data structure.
    event StateVariablesUpdated(TaikoData.SlotB slotB);
}
