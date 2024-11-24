// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoL1.sol";

/// @title TaikoL1_EmptyStub
/// @custom:security-contact security@taiko.xyz
contract TaikoL1_EmptyStub is ITaikoL1 {
    function proposeBlocksV3(bytes[] calldata _paramsArr)
        external
        virtual
        returns (TaikoData.BlockMetadataV3[] memory metaArr_)
    { }

    function proveBlocksV3(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external
        virtual
    { }

    function pauseProving(bool _pause) external virtual { }

    function depositBond(uint256 _amount) external payable virtual { }

    function withdrawBond(uint256 _amount) external virtual { }

    function getVerifiedBlockProver(uint64 _blockId) external view virtual returns (address) { }

    function getBlockV3(uint64 _blockId)
        external
        view
        virtual
        returns (TaikoData.BlockV3 memory blk_)
    { }

    function getTransitionV3(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        virtual
        returns (TaikoData.TransitionStateV3 memory)
    { }

    function lastProposedIn() external view returns (uint56) { }

    function getConfigV3() external pure virtual returns (TaikoData.ConfigV3 memory) { }
}
