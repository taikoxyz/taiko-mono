// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { stdError } from "forge-std/src/StdError.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaRewardPool } from "src/layer1/etna/iface/IEtnaRewardPool.sol";
import { EtnaRewardPool } from "src/layer1/etna/impl/EtnaRewardPool.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
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
        pool = _deployPool(address(bridge), VALIDATOR_PPM, PROVER_PPM);
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
        assertEq(pool.owner(), address(this));
        assertEq(pool.reservedTotal(), 0);
        assertEq(pool.arrivedTotal(), 0);
        assertEq(pool.freeBalance(), 0);
        assertTrue(pool.checkInvariants());
    }

    function test_constructor_RevertWhen_AllocationExceedsOneMillionPpm() external {
        vm.expectRevert(EtnaRewardPool.InvalidAllocation.selector);
        _newPool(address(bridge), 600_000, 400_001);

        // Exactly one million parts per million is accepted.
        _newPool(address(bridge), 1_000_000, 0);
    }

    function test_constructor_RevertWhen_AnyAddressOrChainIdIsZero() external {
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(
            address(0), address(registry), address(bridge), vault, taikoChainId, 1, 1
        );
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(address(this), address(0), address(bridge), vault, taikoChainId, 1, 1);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(address(this), address(registry), address(0), vault, taikoChainId, 1, 1);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaRewardPool(
            address(this), address(registry), address(bridge), address(0), taikoChainId, 1, 1
        );
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        new EtnaRewardPool(address(this), address(registry), address(bridge), vault, 0, 1, 1);
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

    function test_onMessageInvocation_AcceptsARealBridgeMessage() external {
        vm.startPrank(deployer);
        SignalService signalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE")))), deployer
        );
        Bridge l1Bridge = deployBridge(
            address(
                new Bridge(address(resolver), address(signalService), address(0), address(0), false)
            )
        );
        // The source chain's bridge is the app whose signal the L1 bridge checks.
        resolver.registerAddress(taikoChainId, "bridge", randAddress());
        vm.stopPrank();
        vm.deal(address(l1Bridge), 10 ether);

        EtnaRewardPool realPool = _deployPool(address(l1Bridge), VALIDATOR_PPM, PROVER_PPM);

        IBridge.Message memory message;
        message.from = vault;
        message.srcChainId = taikoChainId;
        message.srcOwner = vault;
        message.destChainId = ethereumChainId;
        message.destOwner = address(realPool);
        message.to = address(realPool);
        message.value = 1 ether;
        message.gasLimit = 1_000_000;
        message.data =
            abi.encodeCall(IMessageInvocable.onMessageInvocation, (abi.encode(uint64(0))));
        bytes32 msgHash = l1Bridge.hashMessage(message);

        vm.expectEmit(address(realPool));
        emit IEtnaRewardPool.FeesArrived(msgHash, 0, 1 ether);
        vm.prank(Carol);
        (IBridge.Status status, IBridge.StatusReason reason) = l1Bridge.processMessage(message, "");

        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(uint8(l1Bridge.messageStatus(msgHash)), uint8(IBridge.Status.DONE));
        assertEq(realPool.arrivedTotal(), 1 ether);
        assertEq(address(realPool).balance, 1 ether);
        assertEq(realPool.freeBalance(), 1 ether);
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
        EtnaRewardPool halfPool = _deployPool(address(bridge), 500_000, 250_000);
        vm.deal(address(halfPool), 8 ether);
        IEtnaInbox.CommitteeMember[] memory committee = _aliceAndBob();
        IEtnaInbox.CommitteeMember[][] memory settlements = new IEtnaInbox.CommitteeMember[][](2);
        settlements[0] = committee;
        settlements[1] = committee;
        IEtnaInbox.EpochParticipation[] memory parts = new IEtnaInbox.EpochParticipation[](2);
        parts[0] = _part(0, _hash(committee), _counts2(1, 1));
        parts[1] = _part(1, _hash(committee), _counts2(1, 1));

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
        EtnaRewardPool fullPool = _deployPool(address(bridge), 1_000_000, 0);
        vm.deal(address(fullPool), 10);
        uint256 inboxBefore = address(this).balance;
        // Weights 1000·3 : 3000·1 : 1000·3 = 1 : 1 : 1.
        IEtnaInbox.CommitteeMember[] memory committee = _aliceBobCarol();
        uint32[] memory counts = new uint32[](3);
        counts[0] = 3;
        counts[1] = 1;
        counts[2] = 3;

        fullPool.recordLanding(
            11, EPOCH_LEN, _single(_part(0, _hash(committee), counts)), _settle(committee)
        );

        IEtnaRewardPool.EpochRecord memory record = fullPool.epochRecord(0);
        assertEq(record.alloc, 10);
        assertEq(record.paid, 9);
        assertEq(record.provingShare, 0);
        assertEq(fullPool.creditsOf(Alice), 3);
        assertEq(fullPool.creditsOf(Bob), 3);
        assertEq(fullPool.creditsOf(Carol), 3);
        assertEq(fullPool.reservedTotal(), 9);
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
        uint256 n = 128;
        IEtnaInbox.CommitteeMember[] memory committee = new IEtnaInbox.CommitteeMember[](n);
        uint32[] memory counts = new uint32[](n);
        for (uint256 i; i < n; ++i) {
            address owner = address(uint160(0x10000 + i));
            (uint256 bondId, uint64 activeFromL1) =
                _registerValidator(owner, bytes32(0x1000 + i), MIN_STAKE + i * 1 ether);
            committee[i] = _member(bondId, activeFromL1, MIN_STAKE + i * 1 ether);
            counts[i] = uint32(EPOCH_LEN);
        }
        vm.deal(address(pool), 100 ether);
        IEtnaInbox.EpochParticipation[] memory parts = _single(_part(0, _hash(committee), counts));
        IEtnaInbox.CommitteeMember[][] memory settlements = _settle(committee);
        // The registrations above warmed the registry's storage; a landing reads it cold.
        _cool(address(registry));
        _cool(address(pool));

        // Worst case: one landing records the whole epoch and freezes it, and every owner's
        // credit slot is written for the first time.
        pool.recordLanding(11, EPOCH_LEN, parts, settlements);
        uint256 gasUsed = vm.lastCallGas().gasTotalUsed;
        console2.log("recordLanding gas, 128 members:", gasUsed);

        // Measured ~4.46M (4,464,698) cold.
        assertLt(gasUsed, 5_000_000);
        assertEq(pool.epochRecord(0).frozenAtL1, block.number);
        assertEq(pool.reservedTotal(), pool.epochRecord(0).paid);
        assertTrue(pool.epochRecord(0).paid > 60 ether - n);
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
    /// reports: one part per epoch of the commit range `[max(_parent, 1), _lastHeight - 1]`, and
    /// one settlement per epoch whose last commit is in that range.
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
            uint32[] memory counts = new uint32[](_committee.length);
            for (uint256 i; i < counts.length; ++i) {
                counts[i] = uint32(uint256(keccak256(abi.encode(_r, e, i))) % 11);
            }
            parts_[e - eFirst] = _part(e, _committeeHash, counts);
            if (c1 >= (e + 1) * EPOCH_LEN) ++complete;
        }
        settlements_ = new IEtnaInbox.CommitteeMember[][](complete);
        for (uint256 k; k < complete; ++k) {
            settlements_[k] = _committee;
        }
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
        bondId_ = registry.register(_pubkey, _stake);
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
        uint32 _proverPpm
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
            _proverPpm
        );
    }

    function _deployPool(
        address _bridge,
        uint32 _validatorPpm,
        uint32 _proverPpm
    )
        internal
        returns (EtnaRewardPool)
    {
        return EtnaRewardPool(
            payable(new ERC1967Proxy(
                    address(_newPool(_bridge, _validatorPpm, _proverPpm)),
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

    function _part(
        uint64 _epoch,
        bytes32 _committeeHash,
        uint32[] memory _counts
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation memory)
    {
        return IEtnaInbox.EpochParticipation({
            epoch: _epoch, committeeHash: _committeeHash, signedCounts: _counts
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

    function _countLogs(Vm.Log[] memory _logs, bytes32 _topic) internal view returns (uint256 n_) {
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].emitter == address(pool) && _logs[i].topics[0] == _topic) ++n_;
        }
    }
}
