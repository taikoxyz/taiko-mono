// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title StubInbox
/// @custom:security-contact security@taiko.xyz
contract StubInbox is ITaikoInbox {
    function ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    { }

    function ProveBatches(bytes calldata _params, bytes calldata _proof) external { }

    function DepositBond(uint256 _amount) external payable virtual { }

    function WithdrawBond(uint256 _amount) external virtual { }

    function BondBalanceOf(address _user) external view returns (uint256) { }

    function BondToken() external pure returns (address) {
        return address(0);
    }

    function GetBatch(uint64 _batchId) external view virtual returns (ITaikoInbox.Batch memory) { }

    function GetTransitionById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        virtual
        returns (ITaikoInbox.TransitionState memory)
    { }

    function GetTransitionByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (ITaikoInbox.TransitionState memory)
    { }

    function GetLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory)
    { }

    function GetLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory)
    { }

    function GetBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (TransitionState memory)
    { }

    function GetStats1() external view returns (Stats1 memory) { }

    function GetStats2() external view returns (Stats2 memory) { }

    function GetConfig() external pure virtual returns (ITaikoInbox.Config memory) { }
}
