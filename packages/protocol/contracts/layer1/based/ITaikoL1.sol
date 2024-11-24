// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoData.sol";

/// @title ITaikoL1
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 is ITaikoData {
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
    /// @param statsB The StatsB data structure.
    event StateVariablesUpdated(StatsB statsB);

    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param meta The metadata of the proposed block.
    event BlockProposedV3(uint256 indexed blockId, BlockMetadataV3 meta);

    /// @notice Emitted when a transition is proved.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    event BlockProvedV3(uint256 indexed blockId, TransitionV3 tran);

    /// @notice Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param blockHash The hash of the verified block.
    event BlockVerifiedV3(uint256 indexed blockId, bytes32 blockHash);

    /// @notice Emitted when a block is synced.
    /// @param blockId The ID of the synced block.
    /// @param stateRoot The state root of the synced block.
    event BlockSyncedV3(uint256 indexed blockId, bytes32 stateRoot);

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

    function bondBalanceOf(address _user) external view returns (uint256);

    function getStatsA() external view returns (StatsA memory);

    function getStatsB() external view returns (StatsB memory);

    function getConfigV3() external view returns (ConfigV3 memory);
}
