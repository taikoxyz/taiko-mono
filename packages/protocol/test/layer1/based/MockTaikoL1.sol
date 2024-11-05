// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoL1.sol";

/// @title MockTaikoL1
/// @custom:security-contact security@taiko.xyz
contract MockTaikoL1 is ITaikoL1 {
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        virtual
        returns (TaikoData.BlockMetadataV2 memory meta_)
    { }

    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        virtual
        returns (TaikoData.BlockMetadataV2[] memory metaArr_)
    { }

    function proveBlock(uint64 _blockId, bytes calldata _input) external virtual { }

    function proveBlocks(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external
        virtual
    { }

    function verifyBlocks(uint64 _maxBlocksToVerify) external virtual { }

    function pauseProving(bool _pause) external virtual { }

    function depositBond(uint256 _amount) external payable virtual { }

    function withdrawBond(uint256 _amount) external virtual { }

    function getVerifiedBlockProver(uint64 _blockId) external view virtual returns (address) { }

    function getBlockV2(uint64 _blockId)
        external
        view
        virtual
        returns (TaikoData.BlockV2 memory blk_)
    { }

    function getTransition(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        virtual
        returns (TaikoData.TransitionState memory)
    { }

    function getConfig() external pure virtual returns (TaikoData.Config memory) { }
}
