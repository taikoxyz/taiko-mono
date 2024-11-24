// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoData.sol";

/// @title ITaikoL1 (Pacaya Fork)
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 {
    /// @notice Proposes multiple Taiko L2 blocks (version 2)
    /// @param _paramsArr A list of encoded BlockParamsV3 objects.
    /// @return metaArr_ The metadata objects of the proposed L2 blocks.
    function proposeBlocksV3(bytes[] calldata _paramsArr)
        external
        returns (TaikoData.BlockMetadataV3[] memory metaArr_);

    /// @notice Proves or contests multiple block transitions (version 2)
    /// @param _blockIds The indices of the blocks to prove.
    /// @param _inputs An list of abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TypedProof) tuples.
    /// @param _batchProof An abi-encoded TaikoData.TypedProof that contains the batch/aggregated
    /// proof for the given blocks.
    function proveBlocksV3(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external;

    /// @notice Gets the details of a block.
    /// @param _blockId Index of the block.
    /// @return blk_ The block.
    function getBlockV3(uint64 _blockId) external view returns (TaikoData.BlockV3 memory blk_);

    /// @notice Gets the state transition for a specific block.
    /// @param _blockId Index of the block.
    /// @param _tid The transition id.
    /// @return The state transition data of the block. The transition's state root will be zero if
    /// the block is not a sync-block.
    function getTransitionV3(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        returns (TaikoData.TransitionStateV3 memory);

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfigV3() external view returns (TaikoData.ConfigV3 memory);

    /// @notice Pauses or unpauses block proving.
    /// @param _pause True to pause, false to unpause.
    function pauseProving(bool _pause) external;

    /// @notice Deposits bond ERC20 token or Ether.
    /// @param _amount The amount of Taiko token to deposit.
    function depositBond(uint256 _amount) external payable;

    /// @notice Withdraws bond ERC20 token or Ether.
    /// @param _amount Amount of Taiko tokens to withdraw.
    function withdrawBond(uint256 _amount) external;

    /// @notice Gets the prover that actually proved a verified block.
    /// @param _blockId Index of the block.
    /// @return The prover's address. If the block is not verified yet, address(0) will be returned.
    function getVerifiedBlockProver(uint64 _blockId) external view returns (address);

    /// @notice Retrieves the ID of the L1 block where the most recent L2 block was proposed.
    /// @return The ID of the Li block where the most recent block was proposed.
    function lastProposedIn() external view returns (uint56);
}
