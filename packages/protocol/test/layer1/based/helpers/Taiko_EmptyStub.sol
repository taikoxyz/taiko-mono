// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaiko.sol";

/// @title Taiko_EmptyStub
/// @custom:security-contact security@taiko.xyz
contract Taiko_EmptyStub is ITaiko {
    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        BlockParamsV3[] calldata _blockParams
    )
        external
        returns (ITaiko.BlockMetadataV3[] memory)
    { }

    function proveBlocksV3(
        ITaiko.BlockMetadataV3[] calldata _metas,
        ITaiko.TransitionV3[] calldata _transitions,
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
        returns (ITaiko.BlockV3 memory blk_)
    { }

    function getTransitionV3(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        virtual
        returns (ITaiko.TransitionV3 memory)
    { }

    function getStats1() external view returns (Stats1 memory) { }

    function getStats2() external view returns (Stats2 memory) { }

    function getConfigV3() external pure virtual returns (ITaiko.ConfigV3 memory) { }
}
