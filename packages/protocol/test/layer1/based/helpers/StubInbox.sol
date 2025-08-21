// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title StubInbox
/// @custom:security-contact security@taiko.xyz
contract StubInbox is ITaikoInbox {
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_, uint64 lastBlockId_)
    { }

    function proveBatches(bytes calldata _params, bytes calldata _proof) external { }

    function depositBond(uint256 _amount) external payable virtual { }

    function withdrawBond(uint256 _amount) external virtual { }

    function bondBalanceOf(address _user) external view returns (uint256) { }

    function bondToken() external pure returns (address) {
        return address(0);
    }

    function getBatch(uint64 _batchId) external view virtual returns (ITaikoInbox.Batch memory) { }

    function getTransitionById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        virtual
        returns (ITaikoInbox.TransitionState memory)
    { }

    function getTransitionByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (ITaikoInbox.TransitionState memory)
    { }

    function getLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory)
    { }

    function getLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory)
    { }

    function getBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (TransitionState memory)
    { }

    function getStats1() external view returns (Stats1 memory) { }

    function getStats2() external view returns (Stats2 memory) { }

    function pacayaConfig() external pure virtual returns (ITaikoInbox.Config memory) { }
}
