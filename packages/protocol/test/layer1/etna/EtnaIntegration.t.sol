// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLockHarness } from "./EtnaInboxLockHarness.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @notice A forced inclusion sender that overpays and, from the refund, confirms an exit at the
/// registry. With `_catch` it records the registry's answer; without, a revert fails the refund.
contract RefundExitConfirmer {
    EtnaInbox private immutable _inbox;
    IEtnaStakingRegistry private immutable _registry;
    uint256 private immutable _bondId;
    bool private _catchRevert;
    bool public lockHeldDuringRefund;
    bool public confirmSucceeded;
    bytes public confirmError;

    constructor(EtnaInbox _inboxProxy, IEtnaStakingRegistry _stakingRegistry, uint256 _bond) {
        _inbox = _inboxProxy;
        _registry = _stakingRegistry;
        _bondId = _bond;
    }

    function save(bool _catch) external payable {
        _catchRevert = _catch;
        _inbox.saveForcedInclusion{ value: msg.value }(hex"c0");
    }

    receive() external payable {
        lockHeldDuringRefund = EssentialContract(address(_inbox)).inNonReentrant();
        if (!_catchRevert) {
            _registry.confirmExit(_bondId);
            return;
        }
        (confirmSucceeded, confirmError) =
            address(_registry).call(abi.encodeCall(IEtnaStakingRegistry.confirmExit, (_bondId)));
    }
}

/// @notice Stands in for the registry of an Inbox implementation during `recover`: its
/// `forceExit` makes two calls to the real registry while `recover` holds the Inbox lock and
/// records what each returns.
contract RecoverRegistryProbe {
    address private immutable _registry;
    bytes private _firstCall;
    bytes private _secondCall;
    uint256 public forceExits;
    bool public firstSucceeded;
    bytes public firstResult;
    bool public secondSucceeded;
    bytes public secondResult;

    constructor(address _realRegistry, bytes memory _first, bytes memory _second) {
        _registry = _realRegistry;
        _firstCall = _first;
        _secondCall = _second;
    }

    function forceExit(uint256, bytes32, uint256) external {
        ++forceExits;
        (firstSucceeded, firstResult) = _registry.call(_firstCall);
        (secondSucceeded, secondResult) = _registry.call(_secondCall);
    }
}

/// @title EtnaIntegrationTest
/// @notice The staking registry and the Inbox together, both real (spec 4.1, 6.1, 7.1, 8 and
/// design C8): exits confirm only against landed committees, a bootstrap proxy keeps confirmation
/// and slashing closed, recovery's exclusions and generations reach the registry, the Inbox lock
/// closes confirmation and withdrawal but not slashing, and pausing stops neither contract.
/// @dev Runs on the Lean example chain of `EtnaLandTestBase`: L1 block 11, Alice's bond 0
/// (`VALIDATOR_PK`, registered at block 1, active from block 11, no exit), the genesis cutoff 1
/// as the landed snapshot, three forced inclusions queued and reference block 10. Every registry
/// delay is read from the registry. The only stand-ins are the base's land proof verifier and, in
/// the lock test, a registry probe one Inbox implementation calls during `recover`.
contract EtnaIntegrationTest is EtnaLandTestBase {
    /// @dev Bob's consensus private key.
    uint256 private constant _BOB_PK = 0xB0B;

    /// @dev The height and round of the votes `_vote` builds.
    uint64 private constant _HEIGHT = 1000;
    uint32 private constant _ROUND = 3;

    /// @dev Two block hashes; `_vote` gives each a one-part part set header.
    bytes32 private constant _BLOCK_A = keccak256("block a");
    bytes32 private constant _BLOCK_B = keccak256("block b");

    /// @dev The basis points of a whole stake.
    uint256 private constant _BPS = 10_000;

    // ---------------------------------------------------------------
    // Exit confirmation against landed committees
    // ---------------------------------------------------------------

    /// @dev Spec 4.1: Alice's exit takes effect at block E = activation + exitDelay. The genesis
    /// snapshot (block 1), a landing proving snapshot 4 and one proving E - 1 all select a
    /// committee that may still include her bond, so confirmation reverts `ExitNotCovered` and no
    /// withdrawal is possible. The landing proving snapshot E lets anyone confirm; Alice then
    /// waits the full withdrawal delay from that confirmation and gets her whole stake back.
    function test_withdraw_RequiresALandingWhoseCommitteeExcludesTheBond() external {
        uint256 exit = _requestExit(Alice, 0);
        assertGt(exit, LEAN_SNAPSHOT, "exit above the Lean snapshot");
        assertEq(_inbox().activeCommitteeSnapshot(), registryCheckpointBlock, "genesis snapshot");
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotConfirmed.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);

        _land(0, 6);
        assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "snapshot 4");
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);

        _landWithSnapshot(6, 12, exit - 1);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);

        _landWithSnapshot(12, 18, exit);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitConfirmed(0, block.number);
        vm.prank(Carol);
        registry.confirmExit(0);
        uint256 confirmedAt = block.number;
        assertEq(registry.exitConfirmedAtL1(0), confirmedAt, "confirmed");

        vm.roll(confirmedAt + registry.withdrawalDelay() - 1);
        vm.expectRevert(IEtnaStakingRegistry.WithdrawalNotReady.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);

        vm.roll(confirmedAt + registry.withdrawalDelay());
        uint256 aliceBefore = taikoToken.balanceOf(Alice);
        uint256 registryBefore = taikoToken.balanceOf(address(registry));
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.StakeWithdrawn(0, Alice, MIN_STAKE);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(taikoToken.balanceOf(Alice) - aliceBefore, MIN_STAKE, "Alice paid");
        assertEq(registryBefore - taikoToken.balanceOf(address(registry)), MIN_STAKE, "stake left");
        _assertReleased(0);
    }

    // ---------------------------------------------------------------
    // The bootstrap proxy
    // ---------------------------------------------------------------

    /// @dev Spec 4.1 and 10 step 1: on a fresh deployment whose Inbox proxy still runs the
    /// bootstrap implementation, registration and exit requests work, but confirmation and valid
    /// double-sign evidence both revert `InboxNotInitialized`, long after the exit takes effect.
    /// Once the owner upgrades and initializes the proxy, the same evidence slashes and
    /// confirmation moves on to the coverage check.
    function test_confirmExitAndSlash_FailWhileProxyIsBootstrap() external {
        _deployFreshInbox(false);
        assertFalse(EtnaInboxBootstrap(inboxProxy).isInitialized(), "bootstrap");
        uint256 bobBond = _registerValidator(registry, Bob, _BOB_PK);
        assertEq(bobBond, 1, "Bob's bond 1");
        assertEq(registry.ownerOf(bobBond), Bob, "Bob owns it");
        assertEq(registry.entryAt(bobBond).effStake, MIN_STAKE, "Bob staked");
        uint256 exit = _requestExit(Alice, 0);
        vm.roll(exit + 1000);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) =
            _doubleSign(_BOB_PK, 0);

        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        vm.prank(Carol);
        registry.slashDoubleSign(bobBond, a, b);
        assertEq(registry.exitConfirmedAtL1(0), 0, "nothing confirmed");
        assertEq(registry.entryAt(bobBond).effStake, MIN_STAKE, "nothing slashed");

        _upgradeAndInit(inboxImpl, _defaultInitParams());
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);
        vm.prank(Carol);
        registry.slashDoubleSign(bobBond, a, b);
        assertEq(registry.entryAt(bobBond).effStake, 0, "slashed once initialized");
        assertEq(
            taikoToken.balanceOf(Carol),
            MIN_STAKE * registry.slashBountyBps() / _BPS,
            "Carol's bounty"
        );
    }

    /// @dev On the real bootstrap proxy, long after Alice's exit takes effect, confirmation
    /// reverts `InboxNotInitialized` for anyone, and the Inbox is checked before the bond, so an
    /// unknown bond gets the same error. Nothing is recorded.
    function test_confirmExit_RevertWhen_InboxNotInitialized() external {
        _deployFreshInbox(false);
        uint256 exit = _requestExit(Alice, 0);
        vm.roll(exit + 1000);

        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        vm.prank(Alice);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        vm.prank(Carol);
        registry.confirmExit(0);
        uint256 unknownBond = registry.entryCount();
        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        registry.confirmExit(unknownBond);
        assertEq(registry.exitConfirmedAtL1(0), 0, "nothing confirmed");
    }

    /// @dev `withdraw` has no initialization check of its own: it needs a confirmation, and on
    /// the bootstrap proxy none can be recorded (spec 4.1: until initialization "no withdrawal is
    /// possible"). Long after Alice's exit plus the withdrawal delay, confirmation reverts
    /// `InboxNotInitialized` and her withdrawal `ExitNotConfirmed`; the stake stays in the
    /// registry and the slot stays hers.
    function test_withdraw_RevertWhen_InboxNotInitialized() external {
        _deployFreshInbox(false);
        uint256 exit = _requestExit(Alice, 0);
        vm.roll(exit + registry.withdrawalDelay() + 1000);

        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotConfirmed.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(taikoToken.balanceOf(address(registry)), MIN_STAKE, "stake held");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "entry kept");
        assertEq(registry.ownerOf(0), Alice, "slot kept");
        assertEq(registry.freeSlotCount(), 0, "no slot freed");
    }

    // ---------------------------------------------------------------
    // Recovery
    // ---------------------------------------------------------------

    /// @dev Spec 4.1 and 8: after a real recovery at c = 6 moves the Inbox to generation 1,
    /// Alice's double sign from generation 0, signed under generation 0's chain id, still slashes
    /// her whole stake, as does one from generation 1. A pair from generation 2, correctly signed
    /// under that generation's chain id, reverts `FutureGeneration`.
    function test_slashDoubleSign_AcceptsPreRecoveryEvidenceAfterRecovery() external {
        _land(0, 6);
        _recover(0, 6, _noExclusions());
        assertEq(_inbox().recoveryGeneration(), 1, "generation 1");

        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) =
            _doubleSign(VALIDATOR_PK, 2);
        vm.expectRevert(IEtnaStakingRegistry.FutureGeneration.selector);
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);

        uint256 snapshot = vm.snapshotState();
        (a, b) = _doubleSign(VALIDATOR_PK, 1);
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);
        assertEq(registry.entryAt(0).effStake, 0, "generation-1 evidence slashes");
        vm.revertToState(snapshot);

        (a, b) = _doubleSign(VALIDATOR_PK, 0);
        uint256 bounty = MIN_STAKE * registry.slashBountyBps() / _BPS;
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.DoubleSignSlashed(
            0, Bob, MIN_STAKE, bounty, 0, _HEIGHT, _ROUND, 2
        );
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        assertEq(entry.effStake, 0, "generation-0 evidence slashes");
        assertEq(entry.exitEffectiveL1, block.number, "exit at the slash");
        assertEq(taikoToken.balanceOf(Bob), bounty, "Bob's bounty");
        assertEq(taikoToken.balanceOf(registry.slashSink()), MIN_STAKE - bounty, "sink");
    }

    /// @dev Spec 8 steps 2 and 4: a real recovery at c = 12 and R = 20 that excludes Alice's bond
    /// moves its exit to R without slashing. The recovery leaves the landed snapshot (4) alone, so
    /// the exit cannot be confirmed yet; the first landing of generation 1, proved from its origin
    /// 12 with snapshot R, lets anyone confirm, and after the withdrawal delay Alice gets her
    /// whole stake back.
    function test_recover_ExclusionConfirmsAfterTheNextLanding() external {
        _land(0, 6);
        _land(6, 12);
        vm.roll(20);
        uint256 r = block.number;
        IEtnaInbox.Exclusion[] memory exclusions = _exclusionOf(0);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(0, uint48(r));
        _recover(0, 12, exclusions);
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        assertEq(entry.exitEffectiveL1, r, "exit = R");
        assertEq(entry.effStake, MIN_STAKE, "not slashed");
        assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "recovery keeps the snapshot");
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);

        _landWithSnapshot(12, 18, r);
        IEtnaInbox.Landing memory landing = _inbox().landings(18);
        assertEq(landing.generation, 1, "generation-1 landing");
        assertEq(landing.parentHeight, 12, "on the generation origin");
        vm.prank(Carol);
        registry.confirmExit(0);
        uint256 confirmedAt = block.number;
        assertEq(registry.exitConfirmedAtL1(0), confirmedAt, "confirmed");

        vm.roll(confirmedAt + registry.withdrawalDelay());
        uint256 aliceBefore = taikoToken.balanceOf(Alice);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(taikoToken.balanceOf(Alice) - aliceBefore, MIN_STAKE, "whole stake back");
        _assertReleased(0);
    }

    // ---------------------------------------------------------------
    // The Inbox lock
    // ---------------------------------------------------------------

    /// @dev Design C8: Alice's bond 0 is confirmed, slashed and past the withdrawal delay, so
    /// anyone may release it; Bob's bond 1 has a covered exit, so anyone may confirm it. While the
    /// Inbox lock is held, first by the lock harness and then by a real `recover` whose registry
    /// probe makes the calls, both revert `InboxLocked` and change nothing. Outside the lock Carol
    /// confirms bond 1 and releases bond 0 without payment.
    function test_confirmExit_RevertWhen_RecoverHoldsTheInboxLock() external {
        assertEq(_registerValidator(registry, Bob, _BOB_PK), 1, "Bob's bond 1");
        _requestExit(Alice, 0);
        uint256 bobExit = _requestExit(Bob, 1);
        _landWithSnapshot(0, 6, bobExit);
        vm.prank(Carol);
        registry.confirmExit(0);
        uint256 confirmedAt = block.number;
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) =
            _doubleSign(VALIDATOR_PK, 0);
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);
        assertEq(registry.entryAt(0).effStake, 0, "bond 0 slashed");
        assertEq(registry.exitConfirmedAtL1(0), confirmedAt, "confirmation kept");
        vm.roll(confirmedAt + registry.withdrawalDelay());

        bytes memory confirmCall = abi.encodeCall(IEtnaStakingRegistry.confirmExit, (1));
        bytes memory withdrawCall = abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, Carol));
        bytes memory locked = abi.encodeWithSelector(IEtnaStakingRegistry.InboxLocked.selector);

        EtnaInboxLockHarness harness = _upgradeToLockHarness();
        (bool ok, bytes memory ret) = harness.lockedCall(address(registry), confirmCall);
        assertFalse(ok, "harness: confirm");
        assertEq(ret, locked, "harness: confirm InboxLocked");
        (ok, ret) = harness.lockedCall(address(registry), withdrawCall);
        assertFalse(ok, "harness: withdraw");
        assertEq(ret, locked, "harness: withdraw InboxLocked");

        RecoverRegistryProbe probe =
            new RecoverRegistryProbe(address(registry), confirmCall, withdrawCall);
        IEtnaInbox.Config memory config = _defaultConfig();
        config.stakingRegistry = address(probe);
        _inbox().upgradeTo(address(_newInboxImpl(config)));
        _recover(0, 6, _exclusionOf(1));
        assertEq(probe.forceExits(), 1, "recover called the probe");
        assertFalse(probe.firstSucceeded(), "recover: confirm");
        assertEq(probe.firstResult(), locked, "recover: confirm InboxLocked");
        assertFalse(probe.secondSucceeded(), "recover: withdraw");
        assertEq(probe.secondResult(), locked, "recover: withdraw InboxLocked");

        assertEq(registry.exitConfirmedAtL1(1), 0, "bond 1 unconfirmed");
        assertEq(registry.ownerOf(0), Alice, "bond 0 unreleased");
        assertEq(registry.freeSlotCount(), 0, "no slot freed");

        _inbox().upgradeTo(address(inboxImpl));
        assertFalse(_inbox().inNonReentrant(), "unlocked");
        vm.prank(Carol);
        registry.confirmExit(1);
        assertEq(registry.exitConfirmedAtL1(1), block.number, "bond 1 confirmed");
        uint256 carolBefore = taikoToken.balanceOf(Carol);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.StakeWithdrawn(0, Carol, 0);
        vm.prank(Carol);
        registry.withdraw(0, Carol);
        assertEq(taikoToken.balanceOf(Carol), carolBefore, "no payment");
        _assertReleased(0);
    }

    /// @dev `slashDoubleSign` does not check the Inbox lock (C8 covers only `confirmExit` and
    /// `withdraw`). Under the harness's lock Alice's double sign slashes her whole stake, the
    /// bounty going to the caller, the Inbox proxy. A landing then covers the exit the slash set,
    /// yet confirming it under the lock reverts `InboxLocked`; outside the lock Carol confirms it.
    function test_slashDoubleSign_IgnoresTheInboxLock() external {
        EtnaInboxLockHarness harness = _upgradeToLockHarness();
        // One block past Alice's activation (11), so the exit the slash sets differs from it.
        vm.roll(block.number + 1);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) =
            _doubleSign(VALIDATOR_PK, 0);
        uint256 bounty = MIN_STAKE * registry.slashBountyBps() / _BPS;

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.DoubleSignSlashed(
            0, inboxProxy, MIN_STAKE, bounty, 0, _HEIGHT, _ROUND, 2
        );
        (bool ok, bytes memory ret) = harness.lockedCall(
            address(registry), abi.encodeCall(IEtnaStakingRegistry.slashDoubleSign, (0, a, b))
        );
        assertTrue(ok, "slashed under the lock");
        assertEq(ret.length, 0, "no return data");
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        assertEq(entry.effStake, 0, "stake slashed");
        assertEq(entry.exitEffectiveL1, block.number, "exit at the slash");
        assertEq(taikoToken.balanceOf(inboxProxy), bounty, "bounty to the caller");
        assertEq(taikoToken.balanceOf(registry.slashSink()), MIN_STAKE - bounty, "sink");

        _landWithSnapshot(0, 6, entry.exitEffectiveL1);
        (ok, ret) = harness.lockedCall(
            address(registry), abi.encodeCall(IEtnaStakingRegistry.confirmExit, (0))
        );
        assertFalse(ok, "confirm under the lock");
        assertEq(
            ret, abi.encodeWithSelector(IEtnaStakingRegistry.InboxLocked.selector), "InboxLocked"
        );
        vm.prank(Carol);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), block.number, "confirmed outside the lock");
    }

    /// @dev The forced inclusion refund runs under the Inbox lock (`saveForcedInclusion` is
    /// `nonReentrant` and refunds last), so a sender whose `receive` confirms Alice's covered exit
    /// gets `InboxLocked`. If the sender lets that revert propagate, the refund fails and the whole
    /// save reverts `ETH_TRANSFER_FAILED` (LibAddress does not bubble revert data): nothing is
    /// queued or charged. If it catches the revert, the save succeeds and no confirmation is
    /// recorded. Outside the lock the same confirmation succeeds.
    function test_saveForcedInclusion_RefundRecipientCannotConfirmAnExit() external {
        uint256 exit = _requestExit(Alice, 0);
        _landWithSnapshot(0, 6, exit);
        RefundExitConfirmer sender = new RefundExitConfirmer(_inbox(), registry, 0);
        uint256 fee = uint256(_inbox().getCurrentForcedInclusionFee()) * 1 gwei;
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        uint256 balance = inboxProxy.balance;

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        sender.save{ value: fee + 1 }(false);
        _assertQueue(head, tail);
        assertEq(inboxProxy.balance, balance, "nothing charged");
        assertEq(registry.exitConfirmedAtL1(0), 0, "not confirmed by the failed save");

        sender.save{ value: fee + 1 }(true);
        assertTrue(sender.lockHeldDuringRefund(), "refund under the lock");
        assertFalse(sender.confirmSucceeded(), "confirm from the refund");
        assertEq(
            sender.confirmError(),
            abi.encodeWithSelector(IEtnaStakingRegistry.InboxLocked.selector),
            "InboxLocked"
        );
        _assertQueue(head, tail + 1);
        assertEq(inboxProxy.balance, balance + fee, "fee charged");
        assertEq(address(sender).balance, 1, "overpayment refunded");
        assertEq(registry.exitConfirmedAtL1(0), 0, "not confirmed by the refund");

        vm.prank(Carol);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), block.number, "confirmed outside the lock");
    }

    // ---------------------------------------------------------------
    // Pause
    // ---------------------------------------------------------------

    /// @dev Pausing is not part of either contract's rules (spec 1): with both proxies paused by
    /// their owner, every entry point still works. On the Inbox: two landings, a forced inclusion,
    /// a recovery and the fee sweep. On the registry: Bob's registration, Alice's exit request, a
    /// confirmation by Carol once a landing covers that exit, the exclusion `recover` forces on
    /// Bob's bond, a slash of Bob's double sign and, after the withdrawal delay, Alice's
    /// withdrawal of her whole stake.
    function test_pause_DoesNotStopLandForcedInclusionOrRegistry() external {
        _inbox().pause();
        registry.pause();
        assertTrue(_inbox().paused(), "Inbox paused");
        assertTrue(registry.paused(), "registry paused");

        _land(0, 6);
        _assertCheckpoint(6, bytes32(uint256(106)));

        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        _saveForcedInclusions(1);
        _assertQueue(head, tail + 1);

        uint256 bobBond = _registerValidator(registry, Bob, _BOB_PK);
        assertEq(registry.ownerOf(bobBond), Bob, "registered");

        uint256 exit = _requestExit(Alice, 0);
        _landWithSnapshot(6, 12, exit);
        vm.prank(Carol);
        registry.confirmExit(0);
        uint256 confirmedAt = block.number;
        assertEq(registry.exitConfirmedAtL1(0), confirmedAt, "confirmed");

        IEtnaInbox.Exclusion[] memory exclusions = _exclusionOf(bobBond);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(bobBond, uint48(block.number));
        _recover(0, 12, exclusions);
        assertEq(registry.entryAt(bobBond).exitEffectiveL1, block.number, "excluded at R");

        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) =
            _doubleSign(_BOB_PK, 0);
        uint256 bounty = MIN_STAKE * registry.slashBountyBps() / _BPS;
        vm.prank(David);
        registry.slashDoubleSign(bobBond, a, b);
        assertEq(registry.entryAt(bobBond).effStake, 0, "Bob slashed");
        assertEq(taikoToken.balanceOf(David), bounty, "David's bounty");
        assertEq(taikoToken.balanceOf(registry.slashSink()), MIN_STAKE - bounty, "sink");

        vm.roll(confirmedAt + registry.withdrawalDelay());
        uint256 aliceBefore = taikoToken.balanceOf(Alice);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(taikoToken.balanceOf(Alice) - aliceBefore, MIN_STAKE, "Alice paid");
        _assertReleased(0);

        uint256 fees = inboxProxy.balance;
        assertGt(fees, 0, "forced inclusion fees");
        uint256 treasuryBefore = PROTOCOL_FEE_RECIPIENT.balance;
        _inbox().sweepProtocolFees();
        assertEq(PROTOCOL_FEE_RECIPIENT.balance - treasuryBefore, fees, "fees swept");

        assertTrue(_inbox().paused(), "Inbox still paused");
        assertTrue(registry.paused(), "registry still paused");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev `_owner` requests the exit of `_bondId`, expecting it at max(block.number,
    /// activeFromL1) + exitDelay and an `ExitRequested` event.
    function _requestExit(address _owner, uint256 _bondId) private returns (uint256 exit_) {
        uint256 activeFromL1 = registry.entryAt(_bondId).activeFromL1;
        exit_ = (block.number > activeFromL1 ? block.number : activeFromL1) + registry.exitDelay();
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitRequested(_bondId, uint48(exit_));
        vm.prank(_owner);
        registry.requestExit(_bondId);
        assertEq(registry.entryAt(_bondId).exitEffectiveL1, exit_, "exit block");
    }

    /// @dev Bob lands the committed chain's (_p, _h] proving the selection snapshot `_snapshot`.
    /// L1 first moves past the snapshot if needed and the previous L1 block becomes the reference
    /// block, so the snapshot is never later than the reference block (spec 6.1 step 6).
    function _landWithSnapshot(uint256 _p, uint256 _h, uint256 _snapshot) private {
        if (block.number <= _snapshot) vm.roll(_snapshot + 1);
        uint256 referenceBlock = block.number - 1;
        _setReference(referenceBlock, keccak256(abi.encode("L1 block", referenceBlock)));
        IEtnaInbox.LandInput memory input = _input(_p, _h);
        input.activeCommitteeSnapshot = _snapshot;
        _land(input, _leaves(_p, _h));
        assertEq(_inbox().activeCommitteeSnapshot(), _snapshot, "landed snapshot");
    }

    /// @dev The owner recovers at generation `_generation` and checkpoint `_c`, excluding
    /// `_exclusions` and blanking nothing.
    function _recover(
        uint48 _generation,
        uint256 _c,
        IEtnaInbox.Exclusion[] memory _exclusions
    )
        private
    {
        _inbox().recover(_generation, _c, _exclusions, new uint256[](0));
        assertEq(_inbox().recoveryGeneration(), _generation + 1, "next generation");
    }

    /// @dev The exclusion of `_bondId`'s current occupant: keccak256(abi.encode(ckPrefix, ckX)).
    function _exclusionOf(uint256 _bondId)
        private
        view
        returns (IEtnaInbox.Exclusion[] memory list_)
    {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        list_ = new IEtnaInbox.Exclusion[](1);
        list_[0] = IEtnaInbox.Exclusion({
            bondId: _bondId, entryKey: keccak256(abi.encode(uint256(entry.ckPrefix), entry.ckX))
        });
    }

    /// @dev An empty exclusion list.
    function _noExclusions() private pure returns (IEtnaInbox.Exclusion[] memory) {
        return new IEtnaInbox.Exclusion[](0);
    }

    /// @dev Upgrades the Inbox proxy to the lock harness, with the deployment's configuration.
    function _upgradeToLockHarness() private returns (EtnaInboxLockHarness) {
        _inbox().upgradeTo(address(new EtnaInboxLockHarness(_defaultConfig())));
        return EtnaInboxLockHarness(inboxProxy);
    }

    /// @dev Two `_generation` precommits for different blocks at the same height and round,
    /// signed by `_pk` under this deployment's chain id for that generation (this L1,
    /// `L2_CHAIN_ID`, the Inbox proxy).
    function _doubleSign(
        uint256 _pk,
        uint48 _generation
    )
        private
        view
        returns (IEtnaStakingRegistry.Vote memory a_, IEtnaStakingRegistry.Vote memory b_)
    {
        bytes memory cometChainId = LibCometVote.chainId(
            LibCometVote.chainDomain(block.chainid, L2_CHAIN_ID, inboxProxy, _generation)
        );
        a_ = EtnaTestKeys.signVote(_pk, _vote(_BLOCK_A, _generation), cometChainId);
        b_ = EtnaTestKeys.signVote(_pk, _vote(_BLOCK_B, _generation), cometChainId);
    }

    /// @dev An unsigned precommit at `_HEIGHT`, `_ROUND` and `_generation`, timestamped
    /// 1,700,000,000.000000123, for block `_blockHash` with a one-part part set header.
    function _vote(
        bytes32 _blockHash,
        uint48 _generation
    )
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory v_)
    {
        v_.voteType = 2;
        v_.height = _HEIGHT;
        v_.round = _ROUND;
        v_.blockHash = _blockHash;
        v_.partsTotal = 1;
        v_.partsHash = keccak256(abi.encode(_blockHash));
        v_.timestampSeconds = 1_700_000_000;
        v_.timestampNanos = 123;
        v_.generation = _generation;
    }

    /// @dev Asserts that `_bondId`'s slot is released: zero entry, no owner, no confirmation,
    /// and the only free slot.
    function _assertReleased(uint256 _bondId) private view {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        assertEq(entry.ckX, bytes32(0), "released: ckX");
        assertEq(entry.effStake, 0, "released: effStake");
        assertEq(entry.ckPrefix, 0, "released: ckPrefix");
        assertEq(entry.activeFromL1, 0, "released: activeFromL1");
        assertEq(entry.exitEffectiveL1, 0, "released: exitEffectiveL1");
        assertEq(registry.ownerOf(_bondId), address(0), "released: owner");
        assertEq(registry.exitConfirmedAtL1(_bondId), 0, "released: confirmation");
        assertEq(registry.freeSlotCount(), 1, "released: free slot");
    }
}
