// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title StubInbox
/// @custom:security-contact security@taiko.xyz
contract StubInbox is ITaikoInbox {
    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        BlockParamsV3[] calldata _blockParams,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BlockMetadataV3[] memory)
    { }

    function proveBlocksV3(
        ITaikoInbox.BlockMetadataV3[] calldata _metas,
        ITaikoInbox.TransitionV3[] calldata _transitions,
        bytes calldata proof
    )
        external
    { }

    function depositBond(uint256 _amount) external payable virtual { }

    function withdrawBond(uint256 _amount) external virtual { }

    function bondBalanceOf(address _user) external view returns (uint256) { }

    function bondToken() external pure returns (address) {
        return address(0);
    }

    function getBlockV3(uint64 _blockId)
        external
        view
        virtual
        returns (ITaikoInbox.BlockV3 memory blk_)
    { }

    function getTransitionV3(
        uint64 _blockId,
        uint24 _tid
    )
        external
        view
        virtual
        returns (ITaikoInbox.TransitionV3 memory)
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

    function getBlockVerifyingTransition(uint64 _blockId)
        external
        view
        returns (TransitionV3 memory)
    { }

    function getStats1() external view returns (Stats1 memory) { }

    function getStats2() external view returns (Stats2 memory) { }

    function getConfigV3() external pure virtual returns (ITaikoInbox.ConfigV3 memory) { }
}
