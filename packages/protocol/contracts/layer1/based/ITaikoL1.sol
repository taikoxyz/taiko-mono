// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoData.sol";

/// @title ITaikoL1
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 {
    /// @notice Proposes a Taiko L2 block (version 2)
    /// @param _params Block parameters, an encoded BlockParamsV2 object.
    /// @param _txList txList data if calldata is used for DA.
    /// @return meta_ The metadata of the proposed L2 block.
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (TaikoData.BlockMetadataV2 memory meta_);

    /// @notice Proposes multiple Taiko L2 blocks (version 2)
    /// @param _paramsArr A list of encoded BlockParamsV2 objects.
    /// @param _txListArr A list of txList.
    /// @return metaArr_ The metadata objects of the proposed L2 blocks.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        returns (TaikoData.BlockMetadataV2[] memory metaArr_);

    /// @notice Proves or contests multiple block transitions (version 2)
    /// @param _blockIds The indices of the blocks to prove.
    /// @param _inputs An list of abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TierProof) tuples.
    /// @param _batchProof An abi-encoded TaikoData.TierProof that contains the batch/aggregated
    /// proof for the given blocks.
    function proveBlocks(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external;

    /// @notice Verifies up to a specified number of blocks.
    /// @param _maxBlocksToVerify Maximum number of blocks to verify.
    function verifyBlocks(uint64 _maxBlocksToVerify) external;

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

    /// @notice Gets the details of a block.
    /// @param _blockId Index of the block.
    /// @return blk_ The block.
    function getBlockV2(uint64 _blockId) external view returns (TaikoData.BlockV2 memory blk_);

    /// @notice Gets the state transition for a specific block.
    /// @param _blockId Index of the block.
    /// @param _tid The transition id.
    /// @return The state transition data of the block. The transition's state root will be zero if
    /// the block is not a sync-block.
    function getTransition(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        returns (TaikoData.TransitionState memory);

    /// @notice Retrieves the ID of the L1 block where the most recent L2 block was proposed.
    /// @return The ID of the Li block where the most recent block was proposed.
    function lastProposedIn() external view returns (uint56);

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig() external view returns (TaikoData.Config memory);
}
