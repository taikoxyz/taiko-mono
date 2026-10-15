// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaRewardPool } from "src/layer1/etna/iface/IEtnaRewardPool.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaRewardPool } from "src/layer1/etna/impl/EtnaRewardPool.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @notice A fee recipient that records every Ether transfer it receives.
contract CountingRecipient {
    uint256 public transfers;
    uint256 public lastValue;

    receive() external payable {
        ++transfers;
        lastValue = msg.value;
    }
}

/// @notice A fee recipient that rejects every Ether transfer.
contract RejectingFeeRecipient {
    receive() external payable {
        revert();
    }
}

/// @notice The V7 participation shape, the reward pool hand-off and the prover reward ledger.
/// @dev The base validator (bond 0, owned by Alice) is the committee of every epoch; epochs are
/// ten L2 blocks. The pool splits each frozen epoch's free balance 60% to validators and 40% to
/// the Inbox ledger, which pays 0.001 ether per landed block.
contract EtnaInboxRewardsTest is EtnaInboxTestBase {
    uint64 internal constant L1_HEAD = 20_000;
    bytes internal constant PROOF = "etna proof";

    function setUp() public override {
        super.setUp();
        vm.roll(L1_HEAD);
        vm.setBlockhash(L1_HEAD - 1, keccak256("anchor"));
    }

    // ---------------------------------------------------------------
    // Participation shape
    // ---------------------------------------------------------------

    /// @dev Every shape error reverts before the proof is consulted (the verifier rejects all
    /// proofs while they are tried) and leaves the checkpoint in place.
    function test_land_RevertWhen_ParticipationShapeIsWrong() external {
        landVerifier.setRejects(true);
        // (0, 1]: block 1 carries no commit, so the batch reports nothing.
        _expectInvalidParticipation(_batch(1, Bob), _partsOf(_part(0, 0)), _noSettlements());
        landVerifier.setRejects(false);
        _landWith(_batch(1, Bob), _noParts(), _noSettlements(), 0);

        // (1, 24]: commits [1, 23] cover epochs 0 (10 heights), 1 (10) and 2 (3).
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _batch(24, Bob);
        IEtnaInbox.CommitteeMember[][] memory settlements = _settlements(1, 24);
        assertEq(settlements.length, 2, "epochs 0 and 1 complete");
        // Missing last epoch.
        _expectInvalidParticipation(input, _partsOf(_part(0, 10), _part(1, 10)), settlements);
        // Missing first epoch.
        _expectInvalidParticipation(input, _partsOf(_part(1, 10), _part(2, 3)), settlements);
        // Extra epoch.
        _expectInvalidParticipation(
            input, _partsOf(_part(0, 10), _part(1, 10), _part(2, 3), _part(3, 0)), settlements
        );
        // Wrong epoch number.
        _expectInvalidParticipation(
            input, _partsOf(_part(0, 10), _part(1, 10), _part(3, 3)), settlements
        );
        // Epochs out of order.
        _expectInvalidParticipation(
            input, _partsOf(_part(1, 10), _part(0, 10), _part(2, 3)), settlements
        );
        // More signed heights than a complete epoch's ten.
        _expectInvalidParticipation(
            input, _partsOf(_part(0, 10), _part(1, 11), _part(2, 3)), settlements
        );
        // More signed heights than the last epoch's three in the range.
        _expectInvalidParticipation(
            input, _partsOf(_part(0, 10), _part(1, 10), _part(2, 4)), settlements
        );
        landVerifier.setRejects(false);
        _landWith(input, _partsOf(_part(0, 10), _part(1, 10), _part(2, 3)), settlements, 0);

        // (24, 27]: commits [24, 26] are three heights of epoch 2, counted from the parent.
        landVerifier.setRejects(true);
        _expectInvalidParticipation(_batch(27, Bob), _partsOf(_part(2, 4)), _noSettlements());
        landVerifier.setRejects(false);
        _landWith(_batch(27, Bob), _partsOf(_part(2, 3)), _noSettlements(), 0);
        assertEq(rewardPool.signedCountOf(2, 0), 6, "both batches' epoch-2 heights");
    }

    /// @dev The pool, not the Inbox, checks the settlement committees.
    function test_land_RevertWhen_SettlementsDoNotMatchTheCompletedEpochs() external {
        IEtnaInbox.LandInput memory input = _batch(11, Bob);
        IEtnaInbox.EpochParticipation[] memory parts = _participation(0, 11);

        _expectLandRevert(
            input, parts, _noSettlements(), 0, EtnaRewardPool.SettlementCountMismatch.selector
        );

        IEtnaInbox.CommitteeMember[][] memory settlements = _settlements(0, 11);
        settlements[0][0].effStake += 1;
        _expectLandRevert(input, parts, settlements, 0, EtnaRewardPool.CommitteeMismatch.selector);
        _assertCheckpoint(0);

        _landWith(input, parts, _settlements(0, 11), 0);
        _assertCheckpoint(11);
    }

    /// @dev Height 0 has no commit: blocks 2 and 3 carry the commits of heights 1 and 2.
    function test_land_FirstBatchCountsFromHeightOne() external {
        IEtnaInbox.EpochParticipation[] memory parts = _participation(0, 3);
        assertEq(parts.length, 1, "one part");
        assertEq(parts[0].epoch, 0, "epoch 0");
        assertEq(parts[0].signedCounts[0], 2, "heights 1 and 2");

        landVerifier.setRejects(true);
        _expectInvalidParticipation(_batch(3, Bob), _partsOf(_part(0, 3)), _noSettlements());
        landVerifier.setRejects(false);

        _landWith(_batch(3, Bob), parts, _noSettlements(), 0);
        _assertCheckpoint(3);
        assertEq(rewardPool.signedCountOf(0, 0), 2, "two signed heights");
        IEtnaRewardPool.EpochRecord memory record = rewardPool.epochRecord(0);
        assertEq(record.committeeHash, keccak256(abi.encode(_committee())), "committee bound");
        assertEq(record.frozenAtL1, 0, "epoch 0 open");
    }

    /// @dev (8, 30]: commits [8, 29] cover epochs 0 (3 heights), 1 (10) and 2 (9); the commits of
    /// heights 10 and 20 complete epochs 0 and 1, which freeze in that order; epoch 2 stays open.
    function test_land_FreezesEveryCompletedEpochInAscendingOrder() external {
        _land(_batch(8, Bob));
        _donateToPool(10 ether);

        IEtnaInbox.EpochParticipation[] memory parts = _participation(8, 30);
        IEtnaInbox.CommitteeMember[][] memory settlements = _settlements(8, 30);
        assertEq(parts.length, 3, "epochs 0 to 2");
        assertEq(parts[0].signedCounts[0], 3, "heights 8 to 10");
        assertEq(parts[1].signedCounts[0], 10, "heights 11 to 20");
        assertEq(parts[2].signedCounts[0], 9, "heights 21 to 29");
        assertEq(settlements.length, 2, "two settlements");

        vm.expectCall(
            address(rewardPool),
            abi.encodeCall(IEtnaRewardPool.recordLanding, (30, EPOCH_LEN_L2, parts, settlements))
        );
        vm.recordLogs();
        _landWith(_batch(30, Carol), parts, settlements, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Epoch 0 takes the whole free balance: 6 ether credited to Alice, 4 ether to the
        // ledger; epoch 1 then freezes on an empty free balance. The ledger pays 22 blocks.
        uint256 frozen;
        uint256 rewardEvents;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(rewardPool)
                    && logs[i].topics[0] == IEtnaRewardPool.EpochFrozen.selector
            ) {
                assertEq(rewardEvents, 0, "frozen before the reward is paid");
                assertEq(uint256(logs[i].topics[1]), frozen, "ascending epochs");
                (uint256 alloc, uint256 paid, uint256 proving) =
                    abi.decode(logs[i].data, (uint256, uint256, uint256));
                assertEq(alloc, frozen == 0 ? 6 ether : 0, "alloc");
                assertEq(paid, alloc, "paid");
                assertEq(proving, frozen == 0 ? 4 ether : 0, "proving share");
                ++frozen;
            } else if (
                logs[i].emitter == address(etnaInbox)
                    && logs[i].topics[0] == IEtnaInbox.LandingRewardPaid.selector
            ) {
                ++rewardEvents;
            }
        }
        assertEq(frozen, 2, "epochs 0 and 1 frozen");
        assertEq(rewardEvents, 1, "one reward");

        assertEq(rewardPool.epochRecord(0).frozenAtL1, block.number, "epoch 0 frozen");
        assertEq(rewardPool.epochRecord(1).frozenAtL1, block.number, "epoch 1 frozen");
        assertEq(rewardPool.epochRecord(2).frozenAtL1, 0, "epoch 2 open");
        assertEq(rewardPool.signedCountOf(0, 0), 10, "epoch 0 over both batches");
        assertEq(rewardPool.signedCountOf(1, 0), 10, "epoch 1");
        assertEq(rewardPool.signedCountOf(2, 0), 9, "epoch 2 so far");
        assertEq(rewardPool.creditsOf(Alice), 6 ether, "registration owner credited");
        assertEq(etnaInbox.proverRewardLedger(), 4 ether - 0.022 ether, "ledger");

        // (30, 31] carries the commit of height 30 and completes epoch 2.
        _land(_batch(31, Carol));
        assertEq(rewardPool.epochRecord(2).frozenAtL1, block.number, "epoch 2 frozen");
        assertEq(rewardPool.signedCountOf(2, 0), 10, "epoch 2 complete");
    }

    // ---------------------------------------------------------------
    // Landing reward
    // ---------------------------------------------------------------

    function test_land_PaysTheLandingRewardFromTheLedger() external {
        _fundLedger(1 ether);
        assertEq(_loadSlot(PROVER_REWARD_LEDGER_SLOT), 1 ether, "slot 283");
        uint256 landerBefore = Bob.balance;

        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.LandingRewardPaid(Carol, 0.005 ether, 0.995 ether);
        _land(_batch(5, Carol));

        assertEq(Carol.balance, 0.005 ether, "recipient paid five blocks");
        assertEq(Bob.balance, landerBefore, "the caller is not paid");
        assertEq(etnaInbox.proverRewardLedger(), 0.995 ether, "ledger debited");
        assertEq(_loadSlot(PROVER_REWARD_LEDGER_SLOT), 0.995 ether, "slot 283 debited");
        assertEq(address(etnaInbox).balance, 0.995 ether, "Inbox paid the reward");
    }

    function test_land_CapsTheRewardAtTheLedger() external {
        _fundLedger(0.002 ether);

        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.LandingRewardPaid(Carol, 0.002 ether, 0);
        _land(_batch(5, Carol));

        assertEq(Carol.balance, 0.002 ether, "the whole ledger");
        assertEq(etnaInbox.proverRewardLedger(), 0, "ledger emptied");
        assertEq(address(etnaInbox).balance, 0, "Inbox emptied");
    }

    function test_land_EmptyLedgerStillLands() external {
        CountingRecipient recipient = new CountingRecipient();

        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.LandingRewardPaid(address(recipient), 0, 0);
        _land(_batch(5, address(recipient)));

        _assertCheckpoint(5);
        assertEq(recipient.transfers(), 0, "no zero-value transfer");
        assertEq(etnaInbox.proverRewardLedger(), 0, "ledger empty");
    }

    function test_land_MsgValueTopsUpTheLedger() external {
        vm.deal(Bob, 1 ether);

        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.LandingRewardPaid(Carol, 0.005 ether, 0.995 ether);
        _landWith(_batch(5, Carol), _participation(0, 5), _noSettlements(), 1 ether);

        assertEq(Bob.balance, 0, "the caller funded the ledger");
        assertEq(Carol.balance, 0.005 ether, "the top-up pays the same landing");
        assertEq(etnaInbox.proverRewardLedger(), 0.995 ether, "the rest stays in the ledger");
        assertEq(address(etnaInbox).balance, 0.995 ether, "Inbox balance");
    }

    function test_land_PaysForcedInclusionFeesAndRewardInOneTransfer() external {
        uint256 feesWei = _saveForcedInclusions(2);
        _fundLedger(1 ether);
        CountingRecipient recipient = new CountingRecipient();
        IEtnaInbox.LandInput memory input = _batch(3, address(recipient));
        input.forcedInclusionHead = 2;

        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.ForcedInclusionsConsumed(0, 2, feesWei, address(recipient));
        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.LandingRewardPaid(address(recipient), 0.003 ether, 0.997 ether);
        _land(input);

        assertEq(recipient.transfers(), 1, "one transfer");
        assertEq(recipient.lastValue(), feesWei + 0.003 ether, "fees plus reward");
        assertEq(address(etnaInbox).balance, 0.997 ether, "only the ledger remains");
        assertEq(etnaInbox.proverRewardLedger(), 0.997 ether, "ledger");
    }

    /// @dev Without forced inclusion fees the reward alone is sent; a recipient that rejects it
    /// fails the landing, the pool's freeze included.
    function test_land_RevertWhen_FeeRecipientRejectsTheReward() external {
        _fundLedger(1 ether);
        _donateToPool(1 ether);
        RejectingFeeRecipient recipient = new RejectingFeeRecipient();
        IEtnaInbox.LandInput memory input = _batch(11, address(recipient));

        _expectLandRevert(
            input,
            _participation(0, 11),
            _settlements(0, 11),
            0,
            LibAddress.ETH_TRANSFER_FAILED.selector
        );

        _assertCheckpoint(0);
        assertEq(etnaInbox.proverRewardLedger(), 1 ether, "ledger retained");
        assertEq(address(etnaInbox).balance, 1 ether, "Inbox balance retained");
        assertEq(rewardPool.epochRecord(0).frozenAtL1, 0, "freeze rolled back");
        assertEq(rewardPool.signedCountOf(0, 0), 0, "counts rolled back");
        assertEq(address(rewardPool).balance, 1 ether, "pool balance retained");
        assertEq(rewardPool.creditsOf(Alice), 0, "no credits");

        // The same batch naming a recipient that accepts the reward lands and freezes epoch 0.
        _land(_batch(11, Carol));
        _assertCheckpoint(11);
        assertEq(rewardPool.epochRecord(0).frozenAtL1, block.number, "epoch 0 frozen");
        assertEq(Carol.balance, 0.011 ether, "reward paid");
    }

    /// @dev The pool sends epoch 0's proving share into the ledger from inside `land`; the
    /// Inbox's `receive` is not behind the reentrancy lock, and the same landing pays from it.
    function test_land_ProvingShareOfAFrozenEpochFundsTheSameLanding() external {
        _donateToPool(1 ether);
        assertEq(etnaInbox.proverRewardLedger(), 0, "empty ledger");

        vm.expectEmit(address(rewardPool));
        emit IEtnaRewardPool.EpochFrozen(0, 0.6 ether, 0.6 ether, 0.4 ether);
        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.LandingRewardPaid(Carol, 0.011 ether, 0.389 ether);
        _land(_batch(11, Carol));

        assertEq(Carol.balance, 0.011 ether, "eleven blocks paid");
        assertEq(etnaInbox.proverRewardLedger(), 0.389 ether, "rest of the proving share");
        assertEq(address(etnaInbox).balance, 0.389 ether, "Inbox balance");
        assertEq(rewardPool.creditsOf(Alice), 0.6 ether, "validator share");
        assertEq(address(rewardPool).balance, 0.6 ether, "pool keeps the credits");
        assertTrue(rewardPool.checkInvariants(), "pool invariant");
    }

    // ---------------------------------------------------------------
    // receive
    // ---------------------------------------------------------------

    function test_receive_RevertWhen_NotTheRewardPool() external {
        vm.deal(Alice, 1 ether);
        vm.prank(Alice);
        (bool success, bytes memory reason) = address(etnaInbox).call{ value: 1 ether }("");
        assertFalse(success, "rejected");
        assertEq(
            reason,
            abi.encodeWithSelector(EtnaInbox.UnauthorizedRewardSender.selector),
            "unauthorized sender"
        );
        assertEq(address(etnaInbox).balance, 0, "nothing received");
        assertEq(etnaInbox.proverRewardLedger(), 0, "ledger unchanged");

        _fundLedger(1 ether);
        assertEq(etnaInbox.proverRewardLedger(), 1 ether, "the pool funds the ledger");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev A batch that consumes no forced inclusion, paying `_recipient`.
    function _batch(
        uint64 _lastHeight,
        address _recipient
    )
        internal
        view
        returns (IEtnaInbox.LandInput memory)
    {
        (uint48 head,) = etnaInbox.getForcedInclusionState();
        return IEtnaInbox.LandInput({
            lastHeight: _lastHeight,
            lastBlockHash: keccak256(abi.encode("l2 block", _lastHeight)),
            lastStateRoot: keccak256(abi.encode("l2 state", _lastHeight)),
            l1ReferenceBlockNumber: L1_HEAD - 1,
            forcedInclusionHead: head,
            feeRecipient: _recipient
        });
    }

    /// @dev Bob lands `_input` with the full participation of its batch.
    function _land(IEtnaInbox.LandInput memory _input) internal {
        uint64 parent = etnaInbox.lastCheckpoint().height;
        _landWith(
            _input,
            _participation(parent, _input.lastHeight),
            _settlements(parent, _input.lastHeight),
            0
        );
    }

    function _landWith(
        IEtnaInbox.LandInput memory _input,
        IEtnaInbox.EpochParticipation[] memory _parts,
        IEtnaInbox.CommitteeMember[][] memory _settlementList,
        uint256 _value
    )
        internal
    {
        vm.blobhashes(_getBlobHashes(1));
        vm.prank(Bob);
        etnaInbox.land{ value: _value }(_input, _parts, _settlementList, PROOF);
    }

    function _expectLandRevert(
        IEtnaInbox.LandInput memory _input,
        IEtnaInbox.EpochParticipation[] memory _parts,
        IEtnaInbox.CommitteeMember[][] memory _settlementList,
        uint256 _value,
        bytes4 _selector
    )
        internal
    {
        vm.blobhashes(_getBlobHashes(1));
        vm.expectRevert(_selector);
        vm.prank(Bob);
        etnaInbox.land{ value: _value }(_input, _parts, _settlementList, PROOF);
    }

    function _expectInvalidParticipation(
        IEtnaInbox.LandInput memory _input,
        IEtnaInbox.EpochParticipation[] memory _parts,
        IEtnaInbox.CommitteeMember[][] memory _settlementList
    )
        internal
    {
        uint64 parent = etnaInbox.lastCheckpoint().height;
        _expectLandRevert(
            _input, _parts, _settlementList, 0, EtnaInbox.InvalidParticipation.selector
        );
        _assertCheckpoint(parent);
    }

    /// @dev Sends `_amount` to the Inbox from the reward pool, as a freeze does.
    function _fundLedger(uint256 _amount) internal {
        vm.deal(address(rewardPool), address(rewardPool).balance + _amount);
        vm.prank(address(rewardPool));
        (bool success,) = address(etnaInbox).call{ value: _amount }("");
        assertTrue(success, "the pool funds the ledger");
    }

    /// @dev Donates `_amount` to the reward pool's free balance.
    function _donateToPool(uint256 _amount) internal {
        vm.deal(Alice, _amount);
        vm.prank(Alice);
        (bool success,) = address(rewardPool).call{ value: _amount }("");
        assertTrue(success, "donation");
    }

    /// @dev Alice saves `_count` forced inclusions; returns their total fee in wei.
    function _saveForcedInclusions(uint256 _count) internal returns (uint256 feesWei_) {
        vm.deal(Alice, 1000 ether);
        vm.blobhashes(_getBlobHashes(1));
        for (uint256 i; i < _count; ++i) {
            uint256 fee = uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei;
            vm.prank(Alice);
            etnaInbox.saveForcedInclusion{ value: fee }(hex"c0");
            feesWei_ += fee;
        }
    }

    function _assertCheckpoint(uint64 _height) internal view {
        assertEq(etnaInbox.lastCheckpoint().height, _height, "checkpoint height");
    }

    /// @dev One epoch's part for the base committee with a single signed count.
    function _part(
        uint64 _epoch,
        uint32 _count
    )
        internal
        view
        returns (IEtnaInbox.EpochParticipation memory)
    {
        uint32[] memory counts = new uint32[](1);
        counts[0] = _count;
        return IEtnaInbox.EpochParticipation({
            epoch: _epoch, committeeHash: keccak256(abi.encode(_committee())), signedCounts: counts
        });
    }

    function _partsOf(IEtnaInbox.EpochParticipation memory _a)
        internal
        pure
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        parts_ = new IEtnaInbox.EpochParticipation[](1);
        parts_[0] = _a;
    }

    function _partsOf(
        IEtnaInbox.EpochParticipation memory _a,
        IEtnaInbox.EpochParticipation memory _b
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        parts_ = new IEtnaInbox.EpochParticipation[](2);
        (parts_[0], parts_[1]) = (_a, _b);
    }

    function _partsOf(
        IEtnaInbox.EpochParticipation memory _a,
        IEtnaInbox.EpochParticipation memory _b,
        IEtnaInbox.EpochParticipation memory _c
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        parts_ = new IEtnaInbox.EpochParticipation[](3);
        (parts_[0], parts_[1], parts_[2]) = (_a, _b, _c);
    }

    function _partsOf(
        IEtnaInbox.EpochParticipation memory _a,
        IEtnaInbox.EpochParticipation memory _b,
        IEtnaInbox.EpochParticipation memory _c,
        IEtnaInbox.EpochParticipation memory _d
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        parts_ = new IEtnaInbox.EpochParticipation[](4);
        (parts_[0], parts_[1], parts_[2], parts_[3]) = (_a, _b, _c, _d);
    }

    function _noParts() internal pure returns (IEtnaInbox.EpochParticipation[] memory) {
        return new IEtnaInbox.EpochParticipation[](0);
    }

    function _noSettlements() internal pure returns (IEtnaInbox.CommitteeMember[][] memory) {
        return new IEtnaInbox.CommitteeMember[][](0);
    }
}
