// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoL1.sol";

/// @title TaikoL1_EmptyStub
/// @custom:security-contact security@taiko.xyz
contract TaikoL1_EmptyStub is ITaikoL1 {
    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        bytes[] calldata _blockParams
    )
        external
        returns (TaikoData.BlockMetadataV3[] memory)
    { }

    function proveBlocksV3(
        TaikoData.BlockMetadataV3[] calldata _metas,
        TaikoData.TransitionV3[] calldata _transitions,
        bytes calldata proof
    )
        external
    { }

    function depositBond(uint256 _amount) external payable virtual { }

    function withdrawBond(uint256 _amount) external virtual { }

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
