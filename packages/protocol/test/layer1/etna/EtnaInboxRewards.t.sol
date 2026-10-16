// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLandTest } from "./EtnaInboxLand.t.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract CountingRecipient {
    uint256 public transfers;
    uint256 public lastValue;

    receive() external payable {
        ++transfers;
        lastValue = msg.value;
    }
}

contract RejectingFeeRecipient {
    receive() external payable {
        revert();
    }
}

contract EtnaInboxRewardsTest is EtnaInboxLandTest {
    event BatchRewardRecorded(
        bytes32 indexed batchId,
        address indexed l2RewardRecipient,
        uint256 baseFeeAmount,
        uint64 generation,
        uint64 parentHeight,
        bytes32 parentHash,
        uint64 lastHeight,
        bytes32 lastBlockHash
    );

    function test_land_RecordsZeroRewardAndDiscoveryEvent() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        LibEtnaRewards.Receipt memory receipt = _receipt(input);
        bytes32 id = LibEtnaRewards.batchId(receipt);
        vm.expectEmit();
        emit BatchRewardRecorded(
            id,
            input.l2RewardRecipient,
            0,
            0,
            0,
            genesisBlockHash,
            input.lastHeight,
            input.lastBlockHash
        );
        _land(input);
        assertEq(etnaInbox.rewardCommitments(id), LibEtnaRewards.commitment(receipt));
        assertEq(
            vm.load(address(etnaInbox), LibEtnaRewards.receiptSlot(id)),
            LibEtnaRewards.commitment(receipt)
        );
        assertEq(address(etnaInbox).balance, 0);
    }

    function test_land_SeparatesL1FeesAndL2Rewards() external {
        uint64[] memory fees = _saveForcedInclusions(1);
        IEtnaInbox.LandInput memory input = _batch(1);
        input.forcedInclusionHead = 1;
        input.baseFeeAmount = type(uint256).max;
        input.l2RewardRecipient = Alice;
        LibEtnaRewards.Receipt memory receipt = _receipt(input);
        uint256 l1Before = Bob.balance;
        uint256 l2Before = Alice.balance;
        _land(input);
        assertEq(Bob.balance - l1Before, uint256(fees[0]) * 1 gwei);
        assertEq(Alice.balance, l2Before);
        assertEq(
            etnaInbox.rewardCommitments(LibEtnaRewards.batchId(receipt)),
            LibEtnaRewards.commitment(receipt)
        );
        assertEq(address(etnaInbox).balance, 0);
    }

    function test_land_RevertWhen_RewardRecipientIsZero() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        input.l2RewardRecipient = address(0);
        _expectLandRevert(input, EtnaInbox.ZeroRewardRecipient.selector);
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    function test_land_RejectingL1PaymentRollsBackReceiptCheckpointAndQueue() external {
        _saveForcedInclusions(1);
        IEtnaInbox.LandInput memory input = _batch(1);
        input.forcedInclusionHead = 1;
        input.baseFeeAmount = 2 ether;
        input.feeRecipient = address(new RejectingFeeRecipient());
        bytes32 id = LibEtnaRewards.batchId(_receipt(input));
        uint256 held = address(etnaInbox).balance;
        _expectLandRevert(input, LibAddress.ETH_TRANSFER_FAILED.selector);
        assertEq(etnaInbox.rewardCommitments(id), bytes32(0));
        assertEq(address(etnaInbox).balance, held);
        _assertForcedInclusionState(0, 1);
        _assertLastCheckpoint(0, genesisBlockHash);
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(1);
        // The exact same receipt can be recorded once the payment is accepted.
        input.feeRecipient = Bob;
        _land(input);
        assertNotEq(etnaInbox.rewardCommitments(id), bytes32(0));
    }

    function test_land_DoesNotCallL1RecipientForZeroFees() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        input.feeRecipient = address(new RejectingFeeRecipient());
        input.baseFeeAmount = 1 ether;
        _land(input);
        _assertLastCheckpoint(1, input.lastBlockHash);
    }

    function test_land_RevertWhen_ReceiptAlreadyRecorded() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        bytes32 id = LibEtnaRewards.batchId(_receipt(input));
        vm.store(address(etnaInbox), LibEtnaRewards.receiptSlot(id), bytes32(uint256(7)));
        _expectLandRevert(input, EtnaInbox.RewardAlreadyRecorded.selector);
        assertEq(etnaInbox.rewardCommitments(id), bytes32(uint256(7)));
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    function test_land_RejectsSubstitutedRewardRecipientAndAmount() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        bytes32 statement = _statement(0, genesisBlockHash, input);
        input.l2RewardRecipient = Carol;
        _rejectStatementAndAssertRollback(input, statement);
        input.l2RewardRecipient = Alice;
        input.baseFeeAmount = 1;
        _rejectStatementAndAssertRollback(input, statement);
    }

    function test_land_IsNonpayableAndRejectsPlainEther() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        vm.deal(address(this), 1 ether);
        (bool ok,) =
            address(etnaInbox).call{ value: 1 }(abi.encodeCall(IEtnaInbox.land, (input, PROOF)));
        assertFalse(ok);
        (ok,) = address(etnaInbox).call{ value: 1 }("");
        assertFalse(ok);
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    function test_land_ReceiptUsesStoredGenerationAndActualParent() external {
        _land(_batch(7));
        vm.store(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT), bytes32(uint256(5)));
        IEtnaInbox.LandInput memory input = _batch(9);
        input.baseFeeAmount = 42;
        LibEtnaRewards.Receipt memory receipt = _receipt(input);
        assertEq(receipt.parentHeight, 7);
        assertEq(receipt.parentHash, _batch(7).lastBlockHash);
        assertEq(receipt.generation, 5);
        _land(input);
        assertEq(
            etnaInbox.rewardCommitments(LibEtnaRewards.batchId(receipt)),
            LibEtnaRewards.commitment(receipt)
        );
    }

    function _receipt(IEtnaInbox.LandInput memory _input)
        internal
        view
        returns (LibEtnaRewards.Receipt memory)
    {
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        return LibEtnaRewards.Receipt(
            block.chainid,
            L2_CHAIN_ID,
            address(etnaInbox),
            etnaInbox.recoveryGeneration(),
            parent.height,
            parent.blockHash,
            _input.lastHeight,
            _input.lastBlockHash,
            _input.l2RewardRecipient,
            _input.baseFeeAmount
        );
    }
}
