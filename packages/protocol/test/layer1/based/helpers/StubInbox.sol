// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title StubInbox
/// @custom:security-contact security@taiko.xyz
contract StubInbox is ITaikoInbox {
    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata _additionalData
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    { }

    function v4ProveBatches(bytes calldata _params, bytes calldata _proof) external { }

    function v4VerifyBatches(uint8 _count) external { }

    function v4DepositBond(uint256 _amount) external payable virtual { }

    function v4WithdrawBond(uint256 _amount) external virtual { }

    function v4BondBalanceOf(address _user) external view returns (uint256) { }

    function v4BondToken() external pure returns (address) {
        return address(0);
    }

    function v4GetBatch(uint64 _batchId) external view virtual returns (ITaikoInbox.Batch memory) { }

    function v4GetTransitionById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        virtual
        returns (ITaikoInbox.TransitionState memory)
    { }

    function v4GetTransitionByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (ITaikoInbox.TransitionState memory)
    { }

    function v4GetLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory)
    { }

    function v4GetLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory)
    { }

    function v4GetBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (TransitionState memory)
    { }

    function v4GetStats1() external view returns (Stats1 memory) { }

    function v4GetStats2() external view returns (Stats2 memory) { }

    function v4GetConfig() external pure virtual returns (ITaikoInbox.Config memory) { }
}
