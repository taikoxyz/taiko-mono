// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoL1.sol";

/// @title TaikoL1_EmptyStub
/// @custom:security-contact security@taiko.xyz
contract TaikoL1_EmptyStub is ITaikoL1 {
    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        BlockParamsV3[] calldata _blockParams
    )
        external
        returns (ITaikoL1.BlockMetadataV3[] memory)
    { }

    function proveBlocksV3(
        ITaikoL1.BlockMetadataV3[] calldata _metas,
        ITaikoL1.TransitionV3[] calldata _transitions,
        bytes calldata proof
    )
        external
    { }

    function depositBond(uint256 _amount) external payable virtual { }

    function withdrawBond(uint256 _amount) external virtual { }

    function bondBalanceOf(address _user) external view returns (uint256) { }

    function getBlockV3(uint64 _blockId)
        external
        view
        virtual
        returns (ITaikoL1.BlockV3 memory blk_)
    { }

    function getTransitionV3(
        uint64 _blockId,
        uint24 _tid
    )
        external
        view
        virtual
        returns (ITaikoL1.TransitionV3 memory)
    { }

    function getLastVerifiedTransitionV3()
        external
        view
        returns (uint64 blockId_, TransitionV3 memory tran_)
    { }

    function getLastSyncedTransitionV3()
        external
        view
        returns (uint64 blockId_, TransitionV3 memory tran_)
    { }

    function getStats1() external view returns (Stats1 memory) { }

    function getStats2() external view returns (Stats2 memory) { }

    function getConfigV3() external pure virtual returns (ITaikoL1.ConfigV3 memory) { }
}
