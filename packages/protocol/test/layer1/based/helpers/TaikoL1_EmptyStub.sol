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
        returns (ITaikoData.BlockMetadataV3[] memory)
    { }

    function proveBlocksV3(
        ITaikoData.BlockMetadataV3[] calldata _metas,
        ITaikoData.TransitionV3[] calldata _transitions,
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
        returns (ITaikoData.BlockV3 memory blk_)
    { }

    function getTransitionV3(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        virtual
        returns (ITaikoData.TransitionV3 memory)
    { }

    function lastProposedIn() external view returns (uint56) { }

    function getConfigV3() external pure virtual returns (ITaikoData.ConfigV3 memory) { }
}
