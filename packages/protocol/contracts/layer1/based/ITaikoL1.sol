// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoData.sol";

/// @title TaikoEvents
/// @notice This abstract contract provides event declarations for the Taiko protocol, which are
/// emitted during block proposal, proof, verification, and Ethereum deposit processes.
/// @dev The events defined here must match the definitions in the corresponding L1 libraries.
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 is TaikoData {
    /// @notice Emitted when tokens are deposited into a user's bond balance.
    /// @param user The address of the user who deposited the tokens.
    /// @param amount The amount of tokens deposited.
    event BondDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from a user's bond balance.
    /// @param user The address of the user who withdrew the tokens.
    /// @param amount The amount of tokens withdrawn.
    event BondWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a token is credited back to a user's bond balance.
    /// @param user The address of the user whose bond balance is credited.
    /// @param blockId The ID of the block to credit for.
    /// @param amount The amount of tokens credited.
    event BondCredited(address indexed user, uint256 blockId, uint256 amount);

    /// @notice Emitted when a token is debited from a user's bond balance.
    /// @param user The address of the user whose bond balance is debited.
    /// @param blockId The ID of the block to debit for. TODO: remove this.
    /// @param amount The amount of tokens debited.
    event BondDebited(address indexed user, uint256 blockId, uint256 amount);

    /// @notice Emitted when proving is paused or unpaused.
    /// @param paused The pause status.
    event ProvingPaused(bool paused);

    /// @notice Emitted when some state variable values changed.
    /// @dev This event is currently used by Taiko node/client for block proposal/proving.
    /// @param slotB The SlotB data structure.
    event StateVariablesUpdated(SlotB slotB);

    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param meta The metadata of the proposed block.
    event BlockProposedV3(uint256 indexed blockId, BlockMetadataV3 meta);

    /// @notice Emitted when a transition is proved.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param prover The prover's address.
    /// @param validityBond The validity bond amount.
    /// @param tier The tier of the proof.
    /// @param proposedIn The L1 block in which a transition is proved.
    event TransitionProvedV3(
        uint256 indexed blockId,
        TransitionV3 tran,
        address prover,
        uint96 validityBond,
        uint16 tier,
        uint64 proposedIn
    );

    /// @notice Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The prover whose transition is used for verifying the block.
    /// @param blockHash The hash of the verified block.
    event BlockVerifiedV3(uint256 indexed blockId, address indexed prover, bytes32 blockHash);

    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        bytes[] calldata _blockParams
    )
        external
        returns (BlockMetadataV3[] memory);

    function proveBlocksV3(
        BlockMetadataV3[] calldata _metas,
        TransitionV3[] calldata _transitions,
        bytes calldata proof
    )
        external;

    function depositBond(uint256 _amount) external payable;

    function withdrawBond(uint256 _amount) external;

    /// @notice Retrieves the ID of the L1 block where the most recent L2 block was proposed.
    /// @return The ID of the L1 block where the most recent block was proposed.
    function lastProposedIn() external view returns (uint56);

    function getConfigV3() external view returns (ConfigV3 memory);
}
