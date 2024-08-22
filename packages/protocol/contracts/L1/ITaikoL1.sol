// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoData.sol";

/// @title ITaikoL1
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 {
    /// @notice Proposes a Taiko L2 block (version 2).
    /// @param _params Encoded block parameters (BlockParamsV2 object).
    /// @param _txList Transaction list data if calldata is used for data availability (DA).
    /// @return meta_ Metadata of the proposed L2 block.
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (TaikoData.BlockMetadataV2 memory meta_);

    /// @notice Proposes multiple Taiko L2 blocks (version 2).
    /// @param _paramsArr List of encoded BlockParamsV2 objects.
    /// @param _txListArr List of transaction lists.
    /// @return metaArr_ Metadata objects of the proposed L2 blocks.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        returns (TaikoData.BlockMetadataV2[] memory metaArr_);

    /// @notice Proves or contests multiple block transitions.
    /// @param _blockIds Indices of the blocks to prove.
    /// @param _inputs List of ABI-encoded (TaikoData.BlockMetadata, TaikoData.Transition) tuples.
    /// @param _proof Proof data for the blocks.
    function proveBlocks(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _proof
    )
        external;

    /// @notice Verifies up to a specified number of blocks.
    /// @param _maxBlocksToVerify Maximum number of blocks to verify.
    function verifyBlocks(uint64 _maxBlocksToVerify) external;

    /// @notice Pauses or unpauses block proving.
    /// @param _pause True to pause, false to unpause.
    function pauseProving(bool _pause) external;

    /// @notice Deposits Taiko tokens to be used as bonds.
    /// @param _amount Amount of Taiko tokens to deposit.
    function depositBond(uint256 _amount) external;

    /// @notice Withdraws Taiko tokens.
    /// @param _amount Amount of Taiko tokens to withdraw.
    function withdrawBond(uint256 _amount) external;

    /// @notice Gets the prover that actually proved a verified block.
    /// @param _blockId Index of the block.
    /// @return The prover's address. If the block is not verified yet, address(0) will be returned.
    function getVerifiedBlockProver(uint64 _blockId) external view returns (address);

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig() external pure returns (TaikoData.Config memory);
}
