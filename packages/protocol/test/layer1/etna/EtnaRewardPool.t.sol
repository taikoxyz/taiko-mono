// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { stdError } from "forge-std/src/StdError.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaRewardPool } from "src/layer1/etna/iface/IEtnaRewardPool.sol";
import { EtnaRewardPool } from "src/layer1/etna/impl/EtnaRewardPool.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @dev `vm.cool` (forge 1.0+), which the pinned forge-std does not declare yet.
interface IVmCool {
    function cool(address _target) external;
}

/// @notice A Bridge stand-in: sets the message context, then invokes the target with the value.
contract MockBridge {
    IBridge.Context private _context;

    function context() external view returns (IBridge.Context memory) {
        return _context;
    }

    function deliver(
        address _to,
        bytes32 _msgHash,
        address _from,
        uint64 _srcChainId,
        bytes calldata _data
    )
        external
        payable
    {
        _context = IBridge.Context({ msgHash: _msgHash, from: _from, srcChainId: _srcChainId });
        IMessageInvocable(_to).onMessageInvocation{ value: msg.value }(_data);
        delete _context;
    }
}

/// @dev Rejects every Ether transfer.
contract RejectingRecipient {
    receive() external payable {
        revert();
    }
}

/// @dev The test contract itself is the pool's `inbox`: it calls `recordLanding` and receives the
/// proving shares.
contract EtnaRewardPoolTest is CommonTest {
    uint256 internal constant MIN_STAKE = 1000 ether;
    uint64 internal constant EPOCH_LEN = 10;
    uint32 internal constant VALIDATOR_PPM = 600_000;
    uint32 internal constant PROVER_PPM = 400_000;
    uint32 internal constant BONUS_PPM = 300_000;

    TestERC20 internal taikoToken;
    EtnaStakingRegistry internal registry;
    MockBridge internal bridge;
    address internal vault = randAddress();
    EtnaRewardPool internal pool;

    uint256 internal aliceBond;
    uint64 internal aliceActive;
    uint256 internal bobBond;
    uint64 internal bobActive;
    uint256 internal carolBond;
    uint64 internal carolActive;

    receive() external payable { }

    function setUp() public override {
        super.setUp();
        vm.roll(100);
        taikoToken = new TestERC20("Taiko Token", "TAIKO");
        registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(
                        new EtnaStakingRegistry(
                            address(taikoToken), MIN_STAKE, 10, 20, 30, 50, 0, 0, 0
                        )
                    ),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
        (aliceBond, aliceActive) = _registerValidator(Alice, bytes32(uint256(0xa1)), 1000 ether);
        (bobBond, bobActive) = _registerValidator(Bob, bytes32(uint256(0xb2)), 3000 ether);
        (carolBond, carolActive) = _registerValidator(Carol, bytes32(uint256(0xc3)), 1000 ether);
        bridge = new MockBridge();
        // The default pool pays no proposer bonus, so its tests split the whole validator share
        // as the base part; the proposer bonus tests deploy their own pools.
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, 0);
    }

    // ---------------------------------------------------------------
    // constructor & init
    // ---------------------------------------------------------------

    function test_constructor_SetsTheConfiguration() external view {
        assertEq(pool.inbox(), address(this));
        assertEq(pool.stakingRegistry(), address(registry));
        assertEq(pool.l1Bridge(), address(bridge));
        assertEq(pool.l2FeeVault(), vault);
        assertEq(pool.l2ChainId(), taikoChainId);
        assertEq(pool.allocValidatorPpm(), VALIDATOR_PPM);
        assertEq(pool.allocProverPpm(), PROVER_PPM);
        assertEq(pool.proposerBonusPpm(), 0);
        assertEq(pool.owner(), address(this));
        assertEq(pool.reservedTotal(), 0);
        assertEq(pool.arrivedTotal(), 0);
        assertEq(pool.freeBalance(), 0);
        assertTrue(pool.checkInvariants());
    }

    function test_constructor_RevertWhen_AllocationExceedsOneMillionPpm() external {
        vm.expectRevert(EtnaRewardPool.InvalidAllocation.selector);
        _newPool(address(bridge), 600_000, 400_001, 0);

        // Exactly one million parts per million is accepted.
        _newPool(address(bridge), 1_000_000, 0, 0);
    }

    function test_constructor_RevertWhen_ProposerBonusExceedsOneMillionPpm() external {
        vm.expectRevert(EtnaRewardPool.InvalidAllocation.selector);
        _newPool(address(bridge), 600_000, 400_000, 1_000_001);

        // The whole validator share may be bonus.
        assertEq(
            _newPool(address(bridge), 600_000, 400_000, 1_000_000).proposerBonusPpm(), 1_000_000
        );
        assertEq(_newPool(address(bridge), 1, 2, BONUS_PPM).proposerBonusPpm(), BONUS_PPM);
    }

    function test_constructor_RevertWhen_AnyAddressOrChainIdIsZero() external {
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(
            address(0), address(registry), address(bridge), vault, taikoChainId, 1, 1, 1
        );
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(address(this), address(0), address(bridge), vault, taikoChainId, 1, 1, 1);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(
            address(this), address(registry), address(0), vault, taikoChainId, 1, 1, 1
        );
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(
            address(this), address(registry), address(bridge), address(0), taikoChainId, 1, 1, 1
        );
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        new EtnaRewardPool(address(this), address(registry), address(bridge), vault, 0, 1, 1, 1);
    }

    function test_init_RevertWhen_CalledTwice() external {
        vm.expectRevert("Initializable: contract is already initialized");
        pool.init(Alice);
    }

    // ---------------------------------------------------------------
    // onMessageInvocation & receive
    // ---------------------------------------------------------------

    function test_onMessageInvocation_CreditsTheVaultSweep() external {
        bytes32 msgHash = keccak256("sweep 7");

        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.FeesArrived(msgHash, 7, 1 ether);
        bridge.deliver{ value: 1 ether }(
            address(pool), msgHash, vault, taikoChainId, abi.encode(uint64(7))
        );

        assertEq(pool.arrivedTotal(), 1 ether);
        assertEq(address(pool).balance, 1 ether);
        assertEq(pool.freeBalance(), 1 ether);
        assertEq(pool.reservedTotal(), 0);
        assertTrue(pool.checkInvariants());
    }

    function test_onMessageInvocation_RevertWhen_NotFromTheBridge() external {
        // A contract that is not the configured bridge, even with a valid context.
        MockBridge other = new MockBridge();

        vm.expectRevert(EtnaRewardPool.UnauthorizedSender.selector);
        other.deliver{ value: 1 ether }(
            address(pool), keccak256("m"), vault, taikoChainId, abi.encode(uint64(0))
        );

        vm.deal(Alice, 1 ether);
        vm.expectRevert(EtnaRewardPool.UnauthorizedSender.selector);
        vm.prank(Alice);
        pool.onMessageInvocation{ value: 1 ether }(abi.encode(uint64(0)));
    }

    function test_onMessageInvocation_RevertWhen_SenderIsNotTheVault() external {
        vm.expectRevert(EtnaRewardPool.UnauthorizedSender.selector);
        bridge.deliver{ value: 1 ether }(
            address(pool), keccak256("m"), Alice, taikoChainId, abi.encode(uint64(0))
        );
    }

    function test_onMessageInvocation_RevertWhen_SourceChainDiffers() external {
        vm.expectRevert(EtnaRewardPool.UnauthorizedSender.selector);
        bridge.deliver{ value: 1 ether }(
            address(pool), keccak256("m"), vault, taikoChainId + 1, abi.encode(uint64(0))
        );
    }

    function test_onMessageInvocation_WorksWhilePaused() external {
        pool.pause();

        bridge.deliver{ value: 1 ether }(
            address(pool), keccak256("m"), vault, taikoChainId, abi.encode(uint64(3))
        );
        assertEq(pool.arrivedTotal(), 1 ether);
    }

    /// @dev A relayer processes a real vault sweep on a real L1 Bridge at the vault's fixed
    /// `SWEEP_GAS_LIMIT`. It is the pool's first arrival, the most expensive one: `arrivedTotal`
    /// goes from zero to non-zero.
    function test_onMessageInvocation_FirstArrivalOfAVaultSweepFitsTheSweepGasLimit() external {
        (Bridge l1Bridge, Bridge l2Bridge, L2FeeVault l2Vault, EtnaRewardPool realPool) =
            _deploySweepPath();
        (IBridge.Message memory message, bytes32 msgHash) =
            _sweepOnL2(l2Vault, address(l2Bridge), 1 ether, 0.01 ether);

        assertEq(message.gasLimit, l2Vault.SWEEP_GAS_LIMIT());
        assertEq(l1Bridge.hashMessage(message), msgHash);
        assertEq(realPool.arrivedTotal(), 0);
        vm.deal(address(l1Bridge), 10 ether);

        uint256 carolBefore = Carol.balance;

        vm.expectEmit(address(realPool));
        emit IEtnaRewardPool.FeesArrived(msgHash, 0, 1 ether);
        vm.prank(Carol);
        (IBridge.Status status, IBridge.StatusReason reason) = l1Bridge.processMessage(message, "");

        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(uint8(l1Bridge.messageStatus(msgHash)), uint8(IBridge.Status.DONE));
        assertEq(realPool.arrivedTotal(), 1 ether);
        // The pool, as `destOwner`, also receives the relay fee the relayer did not earn.
        assertEq(realPool.freeBalance(), 1.01 ether - (Carol.balance - carolBefore));
    }

    /// @dev The L1 Bridge pays a message's relayer at most `gasCharged * fee / gasLimit`, where
    /// `gasCharged` is its own measure of the relay's gas, and refunds the rest of the fee to the
    /// pool as `destOwner`. At a 10 gwei base fee, a sweep fee of `SWEEP_GAS_LIMIT * basefee` (0.01
    /// ether) pays the relayer `gasCharged * basefee`, 1.78e15 wei, more than its 1.46e15 gas cost
    /// (measured here warm and without a proof, plus the intrinsic 21,000), while a fee of that gas
    /// cost pays the next relayer 2.29e14, 15.6% of the fee and about 23% of that relay's own
    /// 9.96e14 gas cost. Either way the part of the fee the relayer does not earn joins the pool's
    /// free balance.
    function test_onMessageInvocation_ASweepFeeOfTheGasLimitTimesTheBaseFeeRepaysTheRelayer()
        external
    {
        (Bridge l1Bridge, Bridge l2Bridge, L2FeeVault l2Vault, EtnaRewardPool realPool) =
            _deploySweepPath();
        uint256 baseFee = 10 gwei;
        vm.fee(baseFee);
        vm.deal(address(l1Bridge), 10 ether);

        uint256 fee = uint256(l2Vault.SWEEP_GAS_LIMIT()) * baseFee;
        (IBridge.Message memory message,) = _sweepOnL2(l2Vault, address(l2Bridge), 1 ether, fee);
        (uint256 paid, uint256 gasUsed) = _relay(l1Bridge, message);
        uint256 cost = (gasUsed + 21_000) * baseFee;
        console2.log("fee = SWEEP_GAS_LIMIT * basefee: paid", paid, "of cost", cost);
        assertGe(paid, cost, "the relayer recovers its gas");
        assertEq(realPool.freeBalance(), 1 ether + fee - paid, "the rest of the fee is the pool's");

        uint256 freeBefore = realPool.freeBalance();
        (message,) = _sweepOnL2(l2Vault, address(l2Bridge), 1 ether, cost);
        (paid, gasUsed) = _relay(l1Bridge, message);
        console2.log(
            "fee = one relay's gas cost: paid", paid, "of cost", (gasUsed + 21_000) * baseFee
        );
        assertLt(paid, (gasUsed + 21_000) * baseFee / 2, "a fee of one relay's cost repays less");
        assertEq(realPool.freeBalance() - freeBefore, 1 ether + cost - paid, "refund");
    }

    function test_receive_RecordsADonation() external {
        vm.deal(Bob, 2 ether);

        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.Donation(Bob, 2 ether);
        vm.prank(Bob);
        (bool success,) = address(pool).call{ value: 2 ether }("");

        assertTrue(success);
        assertEq(pool.freeBalance(), 2 ether);
        assertEq(pool.arrivedTotal(), 0);
    }

    // ---------------------------------------------------------------
    // recordLanding
    // ---------------------------------------------------------------

    function test_recordLanding_AccumulatesCountsAcrossLandings() external {
        bytes32 committeeHash = keccak256("nine members");
        uint32[] memory first = new uint32[](9);
        first[0] = 3;
        first[1] = 4;
        first[8] = 1;
        uint32[] memory second = new uint32[](10);
        second[0] = 2;
        second[7] = 5;
        second[8] = 2;
        second[9] = 9;

        _record(4, _single(_part(0, committeeHash, first)), _noSettlements());
        _record(8, _single(_part(0, committeeHash, second)), _noSettlements());

        assertEq(pool.signedCountOf(0, 0), 5);
        assertEq(pool.signedCountOf(0, 1), 4);
        assertEq(pool.signedCountOf(0, 2), 0);
        assertEq(pool.signedCountOf(0, 7), 5);
        assertEq(pool.signedCountOf(0, 8), 3);
        assertEq(pool.signedCountOf(0, 9), 9);
        assertEq(pool.signedCountOf(0, 10), 0);
        assertEq(pool.signedCountOf(1, 0), 0);

        IEtnaRewardPool.EpochRecord memory record = pool.epochRecord(0);
        assertEq(record.committeeHash, committeeHash);
        assertEq(record.frozenAtL1, 0);
        assertEq(record.alloc, 0);
    }

    function test_recordLanding_EmptyPartsIsANoOp() external {
        vm.deal(address(pool), 1 ether);

        vm.recordLogs();
        _record(1, new IEtnaInbox.EpochParticipation[](0), _noSettlements());

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(pool.freeBalance(), 1 ether);
    }

    function test_recordLanding_FreezesAndSettlesTheCompletedEpoch() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        uint256 inboxBefore = address(this).balance;

        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.ValidatorRewarded(0, 0, uint32(aliceBond), Alice, 1.5 ether);
        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.ValidatorRewarded(0, 1, uint32(bobBond), Bob, 4.5 ether);
        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.EpochFrozen(0, 6 ether, 6 ether, 4 ether);
        // The commit of height 10, the last of epoch 0, rides in block 11.
        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));

        assertEq(address(this).balance - inboxBefore, 4 ether);
        assertEq(pool.creditsOf(Alice), 1.5 ether);
        assertEq(pool.creditsOf(Bob), 4.5 ether);
        assertEq(pool.reservedTotal(), 6 ether);
        assertEq(address(pool).balance, 6 ether);
        assertEq(pool.freeBalance(), 0);
        assertTrue(pool.checkInvariants());

        IEtnaRewardPool.EpochRecord memory record = pool.epochRecord(0);
        assertEq(record.committeeHash, _hash(committee));
        assertEq(record.alloc, 6 ether);
        assertEq(record.paid, 6 ether);
        assertEq(record.provingShare, 4 ether);
        assertEq(record.frozenAtL1, block.number);
    }

    /// @dev The `committee_hashes` vectors of `testdata/etna_vectors/vectors.json`, which
    /// taiko-client-rs reads too: each committee's encoding and hash, and a freeze of an epoch
    /// whose part binds the vector hash, settled with the vector committee.
    function test_recordLanding_SettlesTheSharedCommitteeHashVectors() external {
        string memory json = LibEtnaVectors.load();
        uint256 count = LibEtnaVectors.lengthAt(json, ".committee_hashes");
        assertEq(count, 3, "three committees");
        for (uint256 k; k < count; ++k) {
            string memory p = string.concat(".committee_hashes[", vm.toString(k), "].");
            IEtnaInbox.CommitteeMember[] memory committee = LibEtnaVectors.committee(json, k);
            bytes32 expected = LibEtnaVectors.bytes32At(json, string.concat(p, "hash"));
            assertEq(
                abi.encode(committee),
                LibEtnaVectors.bytesAt(json, string.concat(p, "encoding")),
                "encoding"
            );
            assertEq(_hash(committee), expected, "hash");

            uint64 epoch = uint64(k);
            _record(
                (epoch + 1) * EPOCH_LEN + 1,
                _single(_part(epoch, expected, new uint32[](0))),
                _settle(committee)
            );
            IEtnaRewardPool.EpochRecord memory record = pool.epochRecord(epoch);
            assertEq(record.committeeHash, expected, "bound hash");
            assertEq(record.frozenAtL1, block.number, "frozen");
        }
    }

    function test_recordLanding_DoesNotFreezeBeforeTheLastCommitLands() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        // Block 10 carries the commit of height 9; height 10's commit is still outstanding.
        _record(10, _single(_part(0, _hash(committee), _counts2(9, 9))), _noSettlements());

        assertEq(pool.epochRecord(0).frozenAtL1, 0);
        assertEq(pool.creditsOf(Alice), 0);
        assertEq(pool.freeBalance(), 10 ether);
    }

    function test_recordLanding_FreezesEveryCompletedEpochInPartOrder() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory first = _aliceAndBob();
        IEtnaInbox.CommitteeMember[] memory second = new IEtnaInbox.CommitteeMember[](1);
        second[0] = _member(carolBond, carolActive, 1000 ether);
        IEtnaInbox.CommitteeMember[][] memory settlements = new IEtnaInbox.CommitteeMember[][](2);
        settlements[0] = first;
        settlements[1] = second;
        IEtnaInbox.EpochParticipation[] memory parts = new IEtnaInbox.EpochParticipation[](3);
        parts[0] = _part(0, _hash(first), _counts2(10, 10));
        parts[1] = _part(1, _hash(second), _counts1(10));
        parts[2] = _part(2, keccak256("epoch 2"), _counts1(4));

        // Commits of heights 1..24: epochs 0 and 1 complete, epoch 2 does not.
        _record(25, parts, settlements);

        // With 100% of the free balance allocated, epoch 0 takes it all and epoch 1 gets nothing.
        IEtnaRewardPool.EpochRecord memory record0 = pool.epochRecord(0);
        assertEq(record0.alloc, 6 ether);
        assertEq(record0.provingShare, 4 ether);
        assertEq(record0.frozenAtL1, block.number);
        IEtnaRewardPool.EpochRecord memory record1 = pool.epochRecord(1);
        assertEq(record1.alloc, 0);
        assertEq(record1.paid, 0);
        assertEq(record1.provingShare, 0);
        assertEq(record1.frozenAtL1, block.number);
        assertEq(pool.epochRecord(2).frozenAtL1, 0);
        assertEq(pool.signedCountOf(2, 0), 4);
        assertEq(pool.creditsOf(Carol), 0);
        assertEq(pool.reservedTotal(), 6 ether);
    }

    function test_recordLanding_LaterEpochUsesTheFreeBalanceLeftByTheEarlierOne() external {
        EtnaRewardPool halfPool = _deployPool(address(bridge), 500_000, 250_000, 0);
        vm.deal(address(halfPool), 8 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        IEtnaInbox.CommitteeMember[][] memory settlements = new IEtnaInbox.CommitteeMember[][](2);
        settlements[0] = committee;
        settlements[1] = committee;
        IEtnaInbox.EpochParticipation[] memory parts = new IEtnaInbox.EpochParticipation[](2);
        parts[0] = _part(0, _hash(committee), _counts2(10, 10));
        parts[1] = _part(1, _hash(committee), _counts2(10, 10));

        halfPool.recordLanding(21, EPOCH_LEN, parts, settlements);

        // Epoch 0: free 8 → alloc 4, proving 2. Epoch 1: free 8 - 4 - 2 = 2 → alloc 1, proving 0.5.
        assertEq(halfPool.epochRecord(0).alloc, 4 ether);
        assertEq(halfPool.epochRecord(0).provingShare, 2 ether);
        assertEq(halfPool.epochRecord(1).alloc, 1 ether);
        assertEq(halfPool.epochRecord(1).provingShare, 0.5 ether);
        assertEq(halfPool.reservedTotal(), 5 ether);
        assertEq(halfPool.freeBalance(), 0.5 ether);
        assertEq(halfPool.creditsOf(Alice), 1.25 ether);
        assertEq(halfPool.creditsOf(Bob), 3.75 ether);
    }

    function test_recordLanding_RoundsDownAndLeavesTheRemainderFree() external {
        EtnaRewardPool fullPool = _deployPool(address(bridge), 1_000_000, 0, 0);
        vm.deal(address(fullPool), 11);
        uint256 inboxBefore = address(this).balance;
        // Everyone signs all ten heights: weights 1000 : 3000 : 1000 of 11 wei are 2.2, 6.6 and
        // 2.2.
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory counts = new uint32[](3);
        (counts[0], counts[1], counts[2]) = (10, 10, 10);

        fullPool.recordLanding(
            11, EPOCH_LEN, _single(_part(0, _hash(committee), counts)), _settle(committee)
        );

        IEtnaRewardPool.EpochRecord memory record = fullPool.epochRecord(0);
        assertEq(record.alloc, 11);
        assertEq(record.paid, 10);
        assertEq(record.provingShare, 0);
        assertEq(fullPool.creditsOf(Alice), 2);
        assertEq(fullPool.creditsOf(Bob), 6);
        assertEq(fullPool.creditsOf(Carol), 2);
        assertEq(fullPool.reservedTotal(), 10);
        assertEq(fullPool.freeBalance(), 1);
        // A zero proving share sends nothing to the inbox.
        assertEq(address(this).balance, inboxBefore);
    }

    function test_recordLanding_SkipsMembersWithoutARegistrationOwner() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        // No registration of Alice's slot became active at this block.
        committee[0].activeFromL1 = aliceActive + 1;

        vm.recordLogs();
        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));

        assertEq(_countLogs(vm.getRecordedLogs(), IEtnaRewardPool.ValidatorRewarded.selector), 1);
        IEtnaRewardPool.EpochRecord memory record = pool.epochRecord(0);
        assertEq(record.alloc, 6 ether);
        assertEq(record.paid, 4.5 ether);
        assertEq(pool.creditsOf(Alice), 0);
        assertEq(pool.creditsOf(Bob), 4.5 ether);
        assertEq(pool.reservedTotal(), 4.5 ether);
        // The unowned 1.5 ether stays in the free balance.
        assertEq(pool.freeBalance(), 1.5 ether);
    }

    function test_recordLanding_ZeroWeightCreditsNothing() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        uint256 inboxBefore = address(this).balance;

        vm.recordLogs();
        _record(11, _single(_part(0, _hash(committee), _counts2(0, 0))), _settle(committee));

        assertEq(_countLogs(vm.getRecordedLogs(), IEtnaRewardPool.ValidatorRewarded.selector), 0);
        IEtnaRewardPool.EpochRecord memory record = pool.epochRecord(0);
        assertEq(record.alloc, 6 ether);
        assertEq(record.paid, 0);
        assertEq(record.provingShare, 4 ether);
        assertEq(address(this).balance - inboxBefore, 4 ether);
        assertEq(pool.reservedTotal(), 0);
        assertEq(pool.freeBalance(), 6 ether);
    }

    function test_recordLanding_IgnoresCountsBeyondTheCommittee() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        uint32[] memory counts = new uint32[](3);
        counts[0] = 10;
        counts[1] = 10;
        counts[2] = 1000;

        _record(11, _single(_part(0, _hash(committee), counts)), _settle(committee));

        assertEq(pool.signedCountOf(0, 2), 1000);
        assertEq(pool.epochRecord(0).paid, 6 ether);
        assertEq(pool.creditsOf(Alice), 1.5 ether);
        assertEq(pool.creditsOf(Bob), 4.5 ether);
    }

    /// @dev The base divides by the whole committee's weight, its stake times the epoch length,
    /// so each signed height earns the same whoever else signed. Alice signs four of the ten
    /// heights and Bob all ten: Alice earns 6 ether * 1000 * 4 / (4000 * 10) = 0.6 ether and Bob
    /// 4.5 ether, and the base of Alice's six missing heights stays free.
    function test_recordLanding_PaysEachSignedHeightItsShareOfTheFullWeight() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        _record(11, _single(_part(0, _hash(committee), _counts2(4, 10))), _settle(committee));

        assertEq(pool.creditsOf(Alice), 0.6 ether);
        assertEq(pool.creditsOf(Bob), 4.5 ether);
        assertEq(pool.epochRecord(0).paid, 5.1 ether);
        assertEq(pool.freeBalance(), 0.9 ether, "Alice's unsigned heights");
        assertTrue(pool.checkInvariants());
    }

    /// @dev Bob, three quarters of the stake, is offline and signs nothing. Alice still earns
    /// only her quarter of the 6 ether, and Bob's 4.5 ether stays in the free balance for later
    /// epochs rather than going to Alice.
    function test_recordLanding_AnOfflineMembersBaseStaysFree() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        vm.recordLogs();
        _record(11, _single(_part(0, _hash(committee), _counts2(10, 0))), _settle(committee));

        assertEq(_countLogs(vm.getRecordedLogs(), IEtnaRewardPool.ValidatorRewarded.selector), 1);
        assertEq(pool.creditsOf(Alice), 1.5 ether, "a quarter of 6 ether");
        assertEq(pool.creditsOf(Bob), 0);
        assertEq(pool.epochRecord(0).paid, 1.5 ether);
        assertEq(pool.reservedTotal(), 1.5 ether);
        assertEq(pool.freeBalance(), 4.5 ether, "Bob's base stays free");
        assertTrue(pool.checkInvariants());
    }

    /// @dev Carol's count falls from ten to seven, as when a proposer leaves her precommit out
    /// of three of its blocks; with the scores unchanged, Alice's and Bob's credits are exactly
    /// what they are when Carol signs everything, and only Carol's falls.
    function test_recordLanding_OmittingAMemberChangesNoOtherMembersCredit() external {
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory scores = new uint32[](3);
        (scores[0], scores[1], scores[2]) = (30_000, 40_000, 30_000);
        uint32[] memory signed = new uint32[](3);
        (signed[0], signed[1], signed[2]) = (10, 10, 10);
        uint32[] memory omitted = new uint32[](3);
        (omitted[0], omitted[1], omitted[2]) = (10, 10, 7);

        EtnaRewardPool honest = _freezeFresh(committee, signed, scores, EPOCH_LEN, BONUS_PPM);
        EtnaRewardPool omitting = _freezeFresh(committee, omitted, scores, EPOCH_LEN, BONUS_PPM);

        assertEq(omitting.creditsOf(Alice), honest.creditsOf(Alice), "Alice");
        assertEq(omitting.creditsOf(Bob), honest.creditsOf(Bob), "Bob");
        assertLt(omitting.creditsOf(Carol), honest.creditsOf(Carol), "Carol");
    }

    /// @dev Defence in depth: counts above the epoch length, fed straight to the pool, cannot
    /// make it credit more than the base part. Alice and Bob each report 30 signed heights of a
    /// ten-height epoch, a weight of 120,000 ether-heights against the committee's full 40,000,
    /// so the pool divides by the larger: 1 : 3 of the 6 ether. Dividing by the full weight would
    /// have credited 18 ether and left the balance below the reservations.
    function test_recordLanding_OverCapCountsCreditAtMostTheBasePart() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        _record(11, _single(_part(0, _hash(committee), _counts2(30, 30))), _settle(committee));

        assertEq(pool.creditsOf(Alice), 1.5 ether);
        assertEq(pool.creditsOf(Bob), 4.5 ether);
        assertEq(pool.epochRecord(0).paid, 6 ether);
        assertEq(pool.reservedTotal(), 6 ether);
        assertEq(pool.freeBalance(), 0);
        assertTrue(pool.checkInvariants());
    }

    /// @dev Any counts, within the Inbox's bound or not, credit at most the base part and keep
    /// the balance above the reservations. The pool pays no bonus, so every credit is base.
    function testFuzz_recordLanding_AnyCountsCreditAtMostTheBasePart(
        uint32 _a,
        uint32 _b,
        uint32 _c,
        uint96 _balance
    )
        external
    {
        vm.deal(address(pool), _balance);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory counts = new uint32[](3);
        (counts[0], counts[1], counts[2]) = (_a, _b, _c);

        _record(11, _single(_part(0, _hash(committee), counts)), _settle(committee));

        uint256 baseAlloc = uint256(_balance) * VALIDATOR_PPM / 1_000_000;
        uint256 credited = pool.creditsOf(Alice) + pool.creditsOf(Bob) + pool.creditsOf(Carol);
        assertLe(credited, baseAlloc);
        assertEq(pool.epochRecord(0).paid, credited);
        assertEq(pool.reservedTotal(), credited);
        assertTrue(pool.checkInvariants());
    }

    function test_recordLanding_DonationRaisesOnlyLaterAllocations() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));
        assertEq(pool.reservedTotal(), 6 ether);
        assertEq(pool.freeBalance(), 0);

        vm.deal(Carol, 5 ether);
        vm.prank(Carol);
        (bool success,) = address(pool).call{ value: 5 ether }("");
        assertTrue(success);
        assertEq(pool.freeBalance(), 5 ether);

        _record(21, _single(_part(1, _hash(committee), _counts2(10, 10))), _settle(committee));

        // Epoch 1 allocates only the 5 ether free balance; epoch 0's reservations stay put.
        IEtnaRewardPool.EpochRecord memory record0 = pool.epochRecord(0);
        assertEq(record0.alloc, 6 ether);
        assertEq(record0.paid, 6 ether);
        IEtnaRewardPool.EpochRecord memory record1 = pool.epochRecord(1);
        assertEq(record1.alloc, 3 ether);
        assertEq(record1.paid, 3 ether);
        assertEq(record1.provingShare, 2 ether);
        assertEq(pool.creditsOf(Alice), 1.5 ether + 0.75 ether);
        assertEq(pool.creditsOf(Bob), 4.5 ether + 2.25 ether);
        assertEq(pool.reservedTotal(), 9 ether);
        assertEq(address(pool).balance, 9 ether);
        assertTrue(pool.checkInvariants());
    }

    function test_recordLanding_WorksWhilePaused() external {
        vm.deal(address(pool), 10 ether);
        pool.pause();
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));

        assertEq(pool.reservedTotal(), 6 ether);
    }

    function test_recordLanding_RevertWhen_NotInbox() external {
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        vm.expectRevert(EtnaRewardPool.UnauthorizedSender.selector);
        vm.prank(Alice);
        pool.recordLanding(
            11, EPOCH_LEN, _single(_part(0, _hash(committee), _counts2(1, 1))), _settle(committee)
        );
    }

    function test_recordLanding_RevertWhen_CommitteeHashIsZero() external {
        vm.expectRevert(EtnaRewardPool.ZeroCommitteeHash.selector);
        this.recordAsInbox(5, _single(_part(0, bytes32(0), _counts1(1))), _noSettlements());
    }

    function test_recordLanding_RevertWhen_CommitteeHashChanges() external {
        _record(5, _single(_part(0, keccak256("committee A"), _counts1(1))), _noSettlements());

        vm.expectRevert(EtnaRewardPool.CommitteeMismatch.selector);
        this.recordAsInbox(
            8, _single(_part(0, keccak256("committee B"), _counts1(1))), _noSettlements()
        );
    }

    function test_recordLanding_RevertWhen_SettlementCommitteeDiffers() external {
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        IEtnaInbox.CommitteeMember[] memory other = _aliceAndBob();
        other[1].effStake = 3001 ether;

        vm.expectRevert(EtnaRewardPool.CommitteeMismatch.selector);
        this.recordAsInbox(11, _single(_part(0, _hash(committee), _counts2(1, 1))), _settle(other));
    }

    function test_recordLanding_RevertWhen_SettlementCountMismatch() external {
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        bytes32 committeeHash = _hash(committee);

        // One too many: epoch 0 is not complete at lastHeight 10.
        vm.expectRevert(EtnaRewardPool.SettlementCountMismatch.selector);
        this.recordAsInbox(10, _single(_part(0, committeeHash, _counts2(1, 1))), _settle(committee));

        // One too few: epoch 0 completes at lastHeight 11.
        vm.expectRevert(EtnaRewardPool.SettlementCountMismatch.selector);
        this.recordAsInbox(11, _single(_part(0, committeeHash, _counts2(1, 1))), _noSettlements());

        // A settlement without any part.
        vm.expectRevert(EtnaRewardPool.SettlementCountMismatch.selector);
        this.recordAsInbox(11, new IEtnaInbox.EpochParticipation[](0), _settle(committee));
    }

    function test_recordLanding_RevertWhen_EpochAlreadyFrozen() external {
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        _record(11, _single(_part(0, _hash(committee), _counts2(1, 1))), _settle(committee));

        vm.expectRevert(EtnaRewardPool.EpochAlreadyFrozen.selector);
        this.recordAsInbox(
            12, _single(_part(0, _hash(committee), _counts2(1, 1))), _settle(committee)
        );
    }

    function test_recordLanding_RevertWhen_CountOverflows() external {
        bytes32 committeeHash = keccak256("committee");
        _record(5, _single(_part(0, committeeHash, _counts1(type(uint32).max))), _noSettlements());

        vm.expectRevert(stdError.arithmeticError);
        this.recordAsInbox(8, _single(_part(0, committeeHash, _counts1(1))), _noSettlements());
    }

    function test_recordLanding_Settles128MembersWithinGasBudget() external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        uint256 n = 128;
        uint64 epochLen = uint64(n);
        IEtnaInbox.CommitteeMember[] memory committee = new IEtnaInbox.CommitteeMember[](n);
        uint32[] memory counts = new uint32[](n);
        uint32[] memory scores = new uint32[](n);
        for (uint256 i; i < n; ++i) {
            address owner = address(uint160(0x10000 + i));
            (uint256 bondId, uint64 activeFromL1) =
                _registerValidator(owner, bytes32(0x1000 + i), MIN_STAKE + i * 1 ether);
            committee[i] = _member(bondId, activeFromL1, MIN_STAKE + i * 1 ether);
            counts[i] = uint32(epochLen);
            // Every member proposed one of the epoch's blocks, so every score word is written.
            scores[i] = 10_000;
        }
        vm.deal(address(pool), 100 ether);
        IEtnaInbox.EpochParticipation[] memory parts =
            _single(_part(0, _hash(committee), counts, scores));
        IEtnaInbox.CommitteeMember[][] memory settlements = _settle(committee);
        // The registrations above warmed the registry's storage; a landing reads it cold.
        _cool(address(registry));
        _cool(address(pool));

        // Worst case: one landing records the whole epoch and freezes it, every member has a
        // count and a score, and every owner's credit slot is written for the first time.
        pool.recordLanding(epochLen + 1, epochLen, parts, settlements);
        uint256 gasUsed = vm.lastCallGas().gasTotalUsed;
        console2.log("recordLanding gas, 128 members:", gasUsed);

        // Measured 5,017,144 cold (4,464,698 before proposer scores); the bound leaves about 10%.
        assertLt(gasUsed, 5_500_000);
        assertEq(pool.epochRecord(0).frozenAtL1, block.number);
        assertEq(pool.reservedTotal(), pool.epochRecord(0).paid);
        // Every block scored the whole committee: the bonus is paid in full.
        assertTrue(pool.epochRecord(0).paid > 60 ether - 2 * n);
    }

    // ---------------------------------------------------------------
    // Proposer bonus
    // ---------------------------------------------------------------

    function test_recordLanding_AccumulatesProposerScoresAcrossLandings() external {
        bytes32 committeeHash = keccak256("nine members");
        uint32[] memory scores = new uint32[](9);
        scores[0] = 30_000;
        scores[8] = 6667;
        uint32[] memory more = new uint32[](10);
        more[0] = 10_000;
        more[9] = 9999;

        _record(4, _single(_part(0, committeeHash, new uint32[](9), scores)), _noSettlements());
        _record(8, _single(_part(0, committeeHash, new uint32[](10), more)), _noSettlements());

        assertEq(pool.proposerScoreOf(0, 0), 40_000);
        assertEq(pool.proposerScoreOf(0, 1), 0);
        assertEq(pool.proposerScoreOf(0, 8), 6667);
        assertEq(pool.proposerScoreOf(0, 9), 9999);
        assertEq(pool.proposerScoreOf(1, 0), 0);
        assertEq(pool.signedCountOf(0, 0), 0, "scores and counts are separate");
    }

    function test_recordLanding_RevertWhen_ProposerScoreOverflows() external {
        bytes32 committeeHash = keccak256("committee");
        _record(
            5,
            _single(_part(0, committeeHash, new uint32[](1), _counts1(type(uint32).max))),
            _noSettlements()
        );

        vm.expectRevert(stdError.arithmeticError);
        this.recordAsInbox(
            8, _single(_part(0, committeeHash, new uint32[](1), _counts1(1))), _noSettlements()
        );
    }

    /// @dev 6 ether for validators splits into 4.2 ether base and 1.8 ether bonus. The base goes
    /// 1 : 3 by stake times signed heights; of the epoch's possible 100,000 score Alice's
    /// proposals scored 40,000 and Bob's 50,000, and the 0.18 ether bonus for the rest stays
    /// free.
    function test_recordLanding_PaysEachMemberItsBaseAndProposerBonus() external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.ValidatorRewarded(
            0, 0, uint32(aliceBond), Alice, 1.05 ether + 0.72 ether
        );
        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.ValidatorRewarded(0, 1, uint32(bobBond), Bob, 3.15 ether + 0.9 ether);
        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.EpochFrozen(0, 6 ether, 5.82 ether, 4 ether);
        _record(
            11,
            _single(_part(0, _hash(committee), _counts2(10, 10), _counts2(40_000, 50_000))),
            _settle(committee)
        );

        assertEq(pool.creditsOf(Alice), 1.77 ether);
        assertEq(pool.creditsOf(Bob), 4.05 ether);
        assertEq(pool.reservedTotal(), 5.82 ether);
        assertEq(pool.freeBalance(), 0.18 ether, "unearned bonus");
        assertTrue(pool.checkInvariants());
    }

    /// @dev Without proposer scores the bonus stays free and the base part is split exactly as a
    /// pool without a bonus splits the whole validator share.
    function test_recordLanding_WithoutScoresPaysOnlyTheBase() external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));

        assertEq(pool.creditsOf(Alice), 1.05 ether, "a quarter of 4.2 ether");
        assertEq(pool.creditsOf(Bob), 3.15 ether, "three quarters of 4.2 ether");
        assertEq(pool.epochRecord(0).paid, 4.2 ether);
        assertEq(pool.freeBalance(), 1.8 ether, "the whole bonus");
    }

    /// @dev A zero total weight pays no base part but still pays the bonus.
    function test_recordLanding_ZeroWeightStillPaysTheBonus() external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();

        vm.recordLogs();
        _record(
            11,
            _single(_part(0, _hash(committee), _counts2(0, 0), _counts2(100_000, 0))),
            _settle(committee)
        );

        assertEq(_countLogs(vm.getRecordedLogs(), IEtnaRewardPool.ValidatorRewarded.selector), 1);
        assertEq(pool.creditsOf(Alice), 1.8 ether, "the whole bonus");
        assertEq(pool.creditsOf(Bob), 0);
        assertEq(pool.epochRecord(0).paid, 1.8 ether);
        assertEq(pool.freeBalance(), 4.2 ether, "the unpaid base");
    }

    /// @dev A member without a registration owner is credited neither part; its scores past the
    /// committee are ignored, like its counts.
    function test_recordLanding_BonusOfAnOwnerlessMemberOrBeyondTheCommitteeStaysFree() external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        committee[0].activeFromL1 = aliceActive + 1;
        uint32[] memory counts = new uint32[](3);
        (counts[0], counts[1], counts[2]) = (10, 10, 10);
        uint32[] memory scores = new uint32[](3);
        (scores[0], scores[1], scores[2]) = (50_000, 20_000, 30_000);

        _record(11, _single(_part(0, _hash(committee), counts, scores)), _settle(committee));

        assertEq(pool.proposerScoreOf(0, 2), 30_000, "recorded");
        assertEq(pool.creditsOf(Alice), 0, "no owner");
        assertEq(pool.creditsOf(Bob), 3.15 ether + 0.36 ether, "base and bonus");
        assertEq(pool.freeBalance(), 6 ether - 3.51 ether, "the rest stays free");
    }

    function test_recordLanding_BonusRoundsDown() external {
        EtnaRewardPool bonusPool = _deployPool(address(bridge), 1_000_000, 0, 1_000_000);
        vm.deal(address(bonusPool), 10);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory scores = new uint32[](3);
        (scores[0], scores[1], scores[2]) = (33_333, 33_333, 33_334);

        bonusPool.recordLanding(
            11,
            EPOCH_LEN,
            _single(_part(0, _hash(committee), new uint32[](3), scores)),
            _settle(committee)
        );

        // 10 * 33,333 / 100,000 = 3.3333 and 10 * 33,334 / 100,000 = 3.3334, each rounded down.
        assertEq(bonusPool.creditsOf(Alice), 3);
        assertEq(bonusPool.creditsOf(Bob), 3);
        assertEq(bonusPool.creditsOf(Carol), 3);
        assertEq(bonusPool.freeBalance(), 1);
    }

    /// @dev Defence in depth: scores above the Inbox's bound, fed straight to the pool, cannot
    /// make it credit more than the bonus part. The committee's scores total 240,000 against an
    /// epoch maximum of 100,000, so the pool divides 1.8 ether of bonus by 240,000 instead: 90 :
    /// 80 : 70. The score past the committee is ignored in the total too. Dividing by the maximum
    /// would have credited 4.32 ether of bonus and left the balance below the reservations.
    function test_recordLanding_OverCapScoresCreditAtMostTheBonusPart() external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory counts = new uint32[](3);
        (counts[0], counts[1], counts[2]) = (10, 10, 10);
        uint32[] memory scores = new uint32[](4);
        (scores[0], scores[1], scores[2], scores[3]) = (90_000, 80_000, 70_000, 50_000);

        vm.prank(pool.inbox());
        pool.recordLanding(
            11, EPOCH_LEN, _single(_part(0, _hash(committee), counts, scores)), _settle(committee)
        );

        // 6 ether to validators: 4.2 ether base split 1 : 3 : 1, 1.8 ether bonus.
        uint256 bonusAlloc = 1.8 ether;
        uint256 bonusCredited = (pool.creditsOf(Alice) - 0.84 ether)
            + (pool.creditsOf(Bob) - 2.52 ether) + (pool.creditsOf(Carol) - 0.84 ether);
        assertLe(bonusCredited, bonusAlloc, "the bonus credited stays within its part");
        assertEq(pool.creditsOf(Alice), 0.84 ether + 0.675 ether);
        assertEq(pool.creditsOf(Bob), 2.52 ether + 0.6 ether);
        assertEq(pool.creditsOf(Carol), 0.84 ether + 0.525 ether);
        assertEq(pool.epochRecord(0).paid, 6 ether);
        assertEq(pool.reservedTotal(), 6 ether);
        assertEq(pool.freeBalance(), 0);
        assertTrue(pool.checkInvariants());
    }

    /// @dev Any scores, within the Inbox's bound or not, credit at most the bonus part and keep the
    /// balance above the reservations. The whole validator share is bonus, so every credit is.
    function testFuzz_recordLanding_AnyScoresCreditAtMostTheBonusPart(
        uint32 _a,
        uint32 _b,
        uint32 _c,
        uint96 _balance
    )
        external
    {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, 1_000_000);
        vm.deal(address(pool), _balance);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory scores = new uint32[](3);
        (scores[0], scores[1], scores[2]) = (_a, _b, _c);

        vm.prank(pool.inbox());
        pool.recordLanding(
            11,
            EPOCH_LEN,
            _single(_part(0, _hash(committee), new uint32[](3), scores)),
            _settle(committee)
        );

        uint256 bonusAlloc = uint256(_balance) * VALIDATOR_PPM / 1_000_000;
        uint256 credited = pool.creditsOf(Alice) + pool.creditsOf(Bob) + pool.creditsOf(Carol);
        assertLe(credited, bonusAlloc);
        assertEq(pool.epochRecord(0).paid, credited);
        assertEq(pool.reservedTotal(), credited);
        assertTrue(pool.checkInvariants());
    }

    /// @dev The README's example: of 1000 heights, A (33.3% of the stake), B (33.4%) and C
    /// (23.3%) sign every height and D (10%) is offline. Every block carries A, B and C, 90% of
    /// the stake, and scores 9000; A proposes 370 blocks, B 371 and C 259. Or A leaves C's
    /// precommit out of its 370 blocks, which then carry 66.7% and score 6670, so C signs 630
    /// heights. The base divides by the committee's full weight, so in the epoch it freezes A's
    /// base part does not change: omitting only costs A its lower scores, at any bonus share, and
    /// leaves B's credit as it was. Divided by the signed weight instead, A's base part would rise
    /// from 37% to 40.9% of the base and omitting would pay A within the epoch even at a 30% bonus.
    /// What the omission forfeits stays free, and later freezes give A part of it back, so in the
    /// long run omitting still pays A below a bonus share of about `a * v / (v + p)`; the README's
    /// Proposer bonus section gives that condition.
    function test_recordLanding_OmittingASignerRaisesNoPayoutInItsEpoch() external {
        IEtnaInbox.CommitteeMember[] memory committee = new IEtnaInbox.CommitteeMember[](4);
        uint256[4] memory stakes = [uint256(3330 ether), 3340 ether, 2330 ether, 1000 ether];
        for (uint256 i; i < 4; ++i) {
            (uint256 bondId, uint64 activeFromL1) =
                _registerValidator(_exampleOwner(i), bytes32(0xe000 + i), stakes[i]);
            committee[i] = _member(bondId, activeFromL1, stakes[i]);
        }
        uint32[] memory signedCounts = new uint32[](4);
        (signedCounts[0], signedCounts[1], signedCounts[2]) = (1000, 1000, 1000);
        uint32[] memory signedScores = new uint32[](4);
        (signedScores[0], signedScores[1], signedScores[2]) = (3_330_000, 3_339_000, 2_331_000);
        uint32[] memory omittingCounts = new uint32[](4);
        (omittingCounts[0], omittingCounts[1], omittingCounts[2]) = (1000, 1000, 630);
        uint32[] memory omittingScores = new uint32[](4);
        (omittingScores[0], omittingScores[1], omittingScores[2]) =
        (2_467_900, 3_339_000, 2_331_000);

        uint32[3] memory bonuses = [uint32(300_000), 100_000, 0];
        for (uint256 b; b < 3; ++b) {
            EtnaRewardPool honest =
                _freezeFresh(committee, signedCounts, signedScores, 1000, bonuses[b]);
            EtnaRewardPool omitting =
                _freezeFresh(committee, omittingCounts, omittingScores, 1000, bonuses[b]);
            uint256 a = honest.creditsOf(_exampleOwner(0));
            uint256 aOmitting = omitting.creditsOf(_exampleOwner(0));
            if (bonuses[b] == 0) {
                assertEq(aOmitting, a, "without a bonus, A's credit is unchanged");
            } else {
                assertLt(aOmitting, a, "omitting costs A its lower scores");
            }
            assertEq(omitting.creditsOf(_exampleOwner(1)), honest.creditsOf(_exampleOwner(1)), "B");
            assertLt(omitting.creditsOf(_exampleOwner(2)), honest.creditsOf(_exampleOwner(2)), "C");
            assertEq(honest.creditsOf(_exampleOwner(3)), 0, "D is offline");
        }
    }

    /// @dev The registration owner of the README example's member `_index`.
    function _exampleOwner(uint256 _index) internal pure returns (address) {
        return address(uint160(0xa0 + 0x10 * _index));
    }

    /// @dev Freezes one `_epochLen`-block epoch of a fresh pool holding 1 ether, every wei to
    /// validators with `_bonusPpm` of it as bonus, and returns the pool.
    function _freezeFresh(
        IEtnaInbox.CommitteeMember[] memory _committee,
        uint32[] memory _counts,
        uint32[] memory _scores,
        uint64 _epochLen,
        uint32 _bonusPpm
    )
        internal
        returns (EtnaRewardPool fresh_)
    {
        fresh_ = _deployPool(address(bridge), 1_000_000, 0, _bonusPpm);
        vm.deal(address(fresh_), 1 ether);
        fresh_.recordLanding(
            _epochLen + 1,
            _epochLen,
            _single(_part(0, _hash(_committee), _counts, _scores)),
            _settle(_committee)
        );
    }

    // ---------------------------------------------------------------
    // withdrawRewards
    // ---------------------------------------------------------------

    function test_withdrawRewards_PaysAndReleasesTheReservation() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));

        vm.expectEmit(address(pool));
        emit IEtnaRewardPool.RewardsWithdrawn(Alice, David, 1.5 ether);
        vm.prank(Alice);
        uint256 amount = pool.withdrawRewards(David);

        assertEq(amount, 1.5 ether);
        assertEq(David.balance, 1.5 ether);
        assertEq(pool.creditsOf(Alice), 0);
        assertEq(pool.creditsOf(Bob), 4.5 ether);
        assertEq(pool.reservedTotal(), 4.5 ether);
        assertEq(address(pool).balance, 4.5 ether);
        assertEq(pool.freeBalance(), 0);
        assertTrue(pool.checkInvariants());

        // Nothing is left to withdraw.
        vm.recordLogs();
        vm.prank(Alice);
        assertEq(pool.withdrawRewards(David), 0);
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(David.balance, 1.5 ether);
    }

    function test_withdrawRewards_RevertWhen_RecipientRejects() external {
        vm.deal(address(pool), 10 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        _record(11, _single(_part(0, _hash(committee), _counts2(10, 10))), _settle(committee));
        address rejecting = address(new RejectingRecipient());

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        vm.prank(Alice);
        pool.withdrawRewards(rejecting);

        assertEq(pool.creditsOf(Alice), 1.5 ether);
        assertEq(pool.reservedTotal(), 6 ether);
    }

    function test_withdrawRewards_RevertWhen_RecipientIsZero() external {
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        vm.prank(Alice);
        pool.withdrawRewards(address(0));
    }

    // ---------------------------------------------------------------
    // Invariant
    // ---------------------------------------------------------------

    function testFuzz_invariant_BalanceCoversReservations(uint256 _seed) external {
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        bytes32 committeeHash = _hash(committee);
        address[3] memory owners = [Alice, Bob, Carol];
        uint64 landed;
        uint64 sweepNonce;

        for (uint256 step; step < 32; ++step) {
            uint256 r = uint256(keccak256(abi.encode(_seed, step)));
            uint256 op = r % 4;
            r >>= 8;
            if (op == 0) {
                bridge.deliver{ value: r % 5 ether }(
                    address(pool), bytes32(r), vault, taikoChainId, abi.encode(sweepNonce++)
                );
            } else if (op == 1) {
                (bool success,) = address(pool).call{ value: r % 3 ether }("");
                assertTrue(success);
            } else if (op == 2) {
                uint64 lastHeight = landed + 1 + uint64(r % 25);
                (
                    IEtnaInbox.EpochParticipation[] memory parts,
                    IEtnaInbox.CommitteeMember[][] memory settlements
                ) = _landingShape(landed, lastHeight, committee, committeeHash, r >> 8);
                _record(lastHeight, parts, settlements);
                landed = lastHeight;
            } else {
                address owner = owners[r % 3];
                vm.prank(owner);
                pool.withdrawRewards(owner);
            }

            assertTrue(pool.checkInvariants());
            assertGe(address(pool).balance, pool.reservedTotal());
            assertEq(
                pool.creditsOf(Alice) + pool.creditsOf(Bob) + pool.creditsOf(Carol),
                pool.reservedTotal()
            );
        }
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Lets `vm.expectRevert` observe a revert from the inbox's own call.
    function recordAsInbox(
        uint64 _lastHeight,
        IEtnaInbox.EpochParticipation[] calldata _parts,
        IEtnaInbox.CommitteeMember[][] calldata _settlements
    )
        external
    {
        pool.recordLanding(_lastHeight, EPOCH_LEN, _parts, _settlements);
    }

    function _record(
        uint64 _lastHeight,
        IEtnaInbox.EpochParticipation[] memory _parts,
        IEtnaInbox.CommitteeMember[][] memory _settlements
    )
        internal
    {
        pool.recordLanding(_lastHeight, EPOCH_LEN, _parts, _settlements);
    }

    /// @dev The participation and settlements a well-formed landing `(_parent, _lastHeight]`
    /// reports: one part per epoch of the commit range `[max(_parent, 1), _lastHeight - 1]`,
    /// with proposer scores summing to at most 10,000 per height of the range in the epoch, as
    /// the Inbox requires, and one settlement per epoch whose last commit is in that range.
    function _landingShape(
        uint64 _parent,
        uint64 _lastHeight,
        IEtnaInbox.CommitteeMember[] memory _committee,
        bytes32 _committeeHash,
        uint256 _r
    )
        internal
        pure
        returns (
            IEtnaInbox.EpochParticipation[] memory parts_,
            IEtnaInbox.CommitteeMember[][] memory settlements_
        )
    {
        uint64 c0 = _parent > 1 ? _parent : 1;
        uint64 c1 = _lastHeight - 1;
        if (c0 > c1) {
            return (parts_, settlements_);
        }
        uint64 eFirst = (c0 - 1) / EPOCH_LEN;
        uint64 eLast = (c1 - 1) / EPOCH_LEN;
        parts_ = new IEtnaInbox.EpochParticipation[](eLast - eFirst + 1);
        uint256 complete;
        for (uint64 e = eFirst; e <= eLast; ++e) {
            parts_[e - eFirst] = _randomPart(_r, e, c0, c1, _committee.length, _committeeHash);
            if (c1 >= (e + 1) * EPOCH_LEN) ++complete;
        }
        settlements_ = new IEtnaInbox.CommitteeMember[][](complete);
        for (uint256 k; k < complete; ++k) {
            settlements_[k] = _committee;
        }
    }

    /// @dev Epoch `_epoch`'s part of the commit range `[_c0, _c1]` for `_n` members: random
    /// counts, and random proposer scores that sum to at most 10,000 per height of the range in
    /// the epoch.
    function _randomPart(
        uint256 _r,
        uint64 _epoch,
        uint64 _c0,
        uint64 _c1,
        uint256 _n,
        bytes32 _committeeHash
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation memory)
    {
        uint32[] memory counts = new uint32[](_n);
        uint32[] memory scores = new uint32[](_n);
        uint64 lo = _c0 > _epoch * EPOCH_LEN + 1 ? _c0 : _epoch * EPOCH_LEN + 1;
        uint64 hi = _c1 < (_epoch + 1) * EPOCH_LEN ? _c1 : (_epoch + 1) * EPOCH_LEN;
        uint256 budget = uint256(hi - lo + 1) * 10_000;
        for (uint256 i; i < _n; ++i) {
            counts[i] = uint32(uint256(keccak256(abi.encode(_r, _epoch, i))) % 11);
            uint256 score = uint256(keccak256(abi.encode(_r, _epoch, i, "score"))) % (budget + 1);
            scores[i] = uint32(score);
            budget -= score;
        }
        return _part(_epoch, _committeeHash, counts, scores);
    }

    /// @dev Deploys a real L1 Bridge on a SignalService that skips proofs, a real L2 Bridge, which
    /// registers itself as the source chain's bridge (the app whose signal the L1 Bridge checks),
    /// a vault on it with a 1 wei relay fee floor, and a pool that the L1 Bridge delivers to.
    function _deploySweepPath()
        internal
        returns (Bridge l1Bridge_, Bridge l2Bridge_, L2FeeVault l2Vault_, EtnaRewardPool realPool_)
    {
        vm.startPrank(deployer);
        SignalService l1SignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE")))), deployer
        );
        l1Bridge_ = deployBridge(
            address(
                new Bridge(
                    address(resolver), address(l1SignalService), address(0), address(0), false
                )
            )
        );
        vm.chainId(taikoChainId);
        SignalService l2SignalService =
            deploySignalServiceWithoutProof(address(this), address(l1SignalService), deployer);
        l2Bridge_ = deployBridge(
            address(
                new Bridge(
                    address(resolver), address(l2SignalService), address(0), address(0), false
                )
            )
        );
        vm.chainId(ethereumChainId);
        vm.stopPrank();

        // The vault's implementation and proxy come first, then the pool's.
        address poolAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        l2Vault_ = L2FeeVault(
            address(
                new ERC1967Proxy(
                    address(new L2FeeVault(address(l2Bridge_), ethereumChainId, poolAddress, 1)),
                    abi.encodeCall(L2FeeVault.init, (address(this)))
                )
            )
        );
        vault = address(l2Vault_);
        realPool_ = _deployPool(address(l1Bridge_), VALIDATOR_PPM, PROVER_PPM, BONUS_PPM);
        assertEq(address(realPool_), poolAddress);
    }

    /// @dev Alice sweeps `_amount` from `_l2Vault` on L2 with relay fee `_fee`; returns the
    /// message the L2 Bridge sent and its hash.
    function _sweepOnL2(
        L2FeeVault _l2Vault,
        address _l2Bridge,
        uint256 _amount,
        uint256 _fee
    )
        internal
        returns (IBridge.Message memory message_, bytes32 msgHash_)
    {
        vm.chainId(taikoChainId);
        vm.deal(address(_l2Vault), _amount);
        vm.deal(Alice, _fee);
        vm.recordLogs();
        vm.prank(Alice);
        msgHash_ = _l2Vault.sweep{ value: _fee }();
        message_ = _sentMessage(vm.getRecordedLogs(), _l2Bridge);
        vm.chainId(ethereumChainId);
    }

    /// @dev Carol relays `_message` on `_l1Bridge`; returns what the Bridge paid her and the gas
    /// the call used.
    function _relay(
        Bridge _l1Bridge,
        IBridge.Message memory _message
    )
        internal
        returns (uint256 paid_, uint256 gasUsed_)
    {
        uint256 before = Carol.balance;
        vm.prank(Carol);
        uint256 gasStart = gasleft();
        (IBridge.Status status,) = _l1Bridge.processMessage(_message, "");
        gasUsed_ = gasStart - gasleft();
        assertEq(uint8(status), uint8(IBridge.Status.DONE), "relayed");
        paid_ = Carol.balance - before;
    }

    function _registerValidator(
        address _owner,
        bytes32 _pubkey,
        uint256 _stake
    )
        internal
        returns (uint256 bondId_, uint64 activeFromL1_)
    {
        taikoToken.mint(_owner, _stake);
        vm.startPrank(_owner);
        taikoToken.approve(address(registry), _stake);
        bondId_ = registry.register(_pubkey, _stake, _owner);
        vm.stopPrank();
        activeFromL1_ = registry.entryAt(bondId_).activeFromL1;
    }

    /// @dev Marks a proxy, its implementation and their storage cold, as at the start of a
    /// transaction.
    function _cool(address _proxy) internal {
        address implementation = EssentialContract(_proxy).impl();
        IVmCool(address(vm)).cool(_proxy);
        IVmCool(address(vm)).cool(implementation);
    }

    function _newPool(
        address _bridge,
        uint32 _validatorPpm,
        uint32 _proverPpm,
        uint32 _bonusPpm
    )
        internal
        returns (EtnaRewardPool)
    {
        return new EtnaRewardPool(
            address(this),
            address(registry),
            _bridge,
            vault,
            taikoChainId,
            _validatorPpm,
            _proverPpm,
            _bonusPpm
        );
    }

    function _deployPool(
        address _bridge,
        uint32 _validatorPpm,
        uint32 _proverPpm,
        uint32 _bonusPpm
    )
        internal
        returns (EtnaRewardPool)
    {
        return EtnaRewardPool(
            payable(new ERC1967Proxy(
                    address(_newPool(_bridge, _validatorPpm, _proverPpm, _bonusPpm)),
                    abi.encodeCall(EtnaRewardPool.init, (address(this)))
                ))
        );
    }

    function _member(
        uint256 _bondId,
        uint64 _activeFromL1,
        uint256 _effStake
    )
        internal
        pure
        returns (IEtnaInbox.CommitteeMember memory)
    {
        return IEtnaInbox.CommitteeMember({
            bondId: uint32(_bondId), activeFromL1: _activeFromL1, effStake: _effStake
        });
    }

    function _aliceAndBob() internal view returns (IEtnaInbox.CommitteeMember[] memory c_) {
        c_ = new IEtnaInbox.CommitteeMember[](2);
        c_[0] = _member(aliceBond, aliceActive, 1000 ether);
        c_[1] = _member(bobBond, bobActive, 3000 ether);
    }

    function _aliceBobCarol() internal view returns (IEtnaInbox.CommitteeMember[] memory c_) {
        c_ = new IEtnaInbox.CommitteeMember[](3);
        c_[0] = _member(aliceBond, aliceActive, 1000 ether);
        c_[1] = _member(bobBond, bobActive, 3000 ether);
        c_[2] = _member(carolBond, carolActive, 1000 ether);
    }

    function _hash(IEtnaInbox.CommitteeMember[] memory _committee) internal pure returns (bytes32) {
        return keccak256(abi.encode(_committee));
    }

    /// @dev A part without proposer scores.
    function _part(
        uint64 _epoch,
        bytes32 _committeeHash,
        uint32[] memory _counts
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation memory)
    {
        return _part(_epoch, _committeeHash, _counts, new uint32[](_counts.length));
    }

    function _part(
        uint64 _epoch,
        bytes32 _committeeHash,
        uint32[] memory _counts,
        uint32[] memory _scores
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation memory)
    {
        return IEtnaInbox.EpochParticipation({
            epoch: _epoch,
            committeeHash: _committeeHash,
            signedCounts: _counts,
            proposerScores: _scores
        });
    }

    function _single(IEtnaInbox.EpochParticipation memory _p)
        internal
        pure
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        parts_ = new IEtnaInbox.EpochParticipation[](1);
        parts_[0] = _p;
    }

    function _settle(IEtnaInbox.CommitteeMember[] memory _committee)
        internal
        pure
        returns (IEtnaInbox.CommitteeMember[][] memory settlements_)
    {
        settlements_ = new IEtnaInbox.CommitteeMember[][](1);
        settlements_[0] = _committee;
    }

    function _noSettlements() internal pure returns (IEtnaInbox.CommitteeMember[][] memory) {
        return new IEtnaInbox.CommitteeMember[][](0);
    }

    function _counts1(uint32 _a) internal pure returns (uint32[] memory c_) {
        c_ = new uint32[](1);
        c_[0] = _a;
    }

    function _counts2(uint32 _a, uint32 _b) internal pure returns (uint32[] memory c_) {
        c_ = new uint32[](2);
        c_[0] = _a;
        c_[1] = _b;
    }

    /// @dev Returns the only `MessageSent` that `_bridge` emitted in `_logs`.
    function _sentMessage(
        Vm.Log[] memory _logs,
        address _bridge
    )
        internal
        returns (IBridge.Message memory message_)
    {
        uint256 found;
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].emitter != _bridge || _logs[i].topics[0] != IBridge.MessageSent.selector) {
                continue;
            }
            message_ = abi.decode(_logs[i].data, (IBridge.Message));
            ++found;
        }
        assertEq(found, 1, "MessageSent count");
    }

    function _countLogs(Vm.Log[] memory _logs, bytes32 _topic) internal view returns (uint256 n_) {
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].emitter == address(pool) && _logs[i].topics[0] == _topic) ++n_;
        }
    }
}
