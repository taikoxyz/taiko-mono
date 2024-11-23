// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoData.sol";

/// @title ITaikoL1v2 (OntakeFork)
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1v2 {
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (TaikoData.BlockMetadataV2 memory meta_);

    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        returns (TaikoData.BlockMetadataV2[] memory metaArr_);

    function proveBlock(uint64 _blockId, bytes calldata _input) external;

    function proveBlocks(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external;

    function getBlockV2(uint64 _blockId) external view returns (TaikoData.BlockV2 memory blk_);

    function getTransition(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        returns (TaikoData.TransitionState memory);

    function getConfig() external pure returns (TaikoData.Config memory);
}
