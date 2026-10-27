// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { MockEtnaInbox } from "./MockEtnaInbox.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @dev Every test starts at L1 block 30 with bond 0 registered by Alice (active from block 40)
/// and an initialized mock Inbox at snapshot 0.
contract EtnaStakingRegistryExitTest is EtnaStakingRegistryTestBase {
    /// @dev Consensus private keys.
    uint256 private constant _CK_A = 0xC0A;
    uint256 private constant _CK_B = 0xC0B;
    uint256 private constant _CK_C = 0xC0C;
    uint256 private constant _CK_D = 0xC0D;
    uint256 private constant _CK_E = 0xC0E;
    uint256 private constant _CK_F = 0xC0F;

    /// @dev The `exitEffectiveL1` of an entry with no exit set.
    uint48 private constant _NO_EXIT = type(uint48).max;

    /// @dev Bond 0's registration block and the exit an immediate request gives it.
    uint256 private constant _REGISTERED_AT = 30;
    uint48 private constant _EXIT = 60;

    function setUp() public override {
        super.setUp();
        mockInbox.setInitialized(true);
        vm.roll(_REGISTERED_AT);
        assertEq(_register(Alice, _CK_A), 0, "bond 0");
    }

    // ---------------------------------------------------------------
    // requestExit
    // ---------------------------------------------------------------

    /// @dev Requested at block 30 by a bond active from 40, the exit takes effect at
    /// max(30, 40) + 20 = 60 (Lean `exit_request_rules`). The request in the registration's block
    /// overwrites that block's checkpoint.
    function test_requestExit_CountsFromActivationWhenLater() external {
        IEtnaStakingRegistry.Entry memory expected = registry.entryAt(0);
        assertEq(expected.activeFromL1, 40, "active from");
        expected.exitEffectiveL1 = _EXIT;
        bytes32 leaf = LibEntriesTree.leaf(0, expected);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(0, uint48(_REGISTERED_AT), 1, leaf);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitRequested(0, _EXIT);
        vm.prank(Alice);
        registry.requestExit(0);

        _assertEntry(0, expected);
        assertEq(registry.entriesRoot(), leaf, "root");
        assertEq(registry.checkpointCount(), 1, "checkpoint overwritten");
        _assertCheckpoint(0, _REGISTERED_AT, 1, leaf);
        assertEq(registry.ownerOf(0), Alice, "owner");
        assertEq(registry.exitConfirmedAtL1(0), 0, "no confirmation");
        assertEq(token.balanceOf(address(registry)), MIN_STAKE, "stake held");
    }

    /// @dev Requested at block 45 by a bond active from 40, the exit takes effect at 45 + 20; a
    /// later block appends a checkpoint.
    function test_requestExit_CountsFromCurrentBlock() external {
        bytes32 registeredRoot = registry.entriesRoot();
        IEtnaStakingRegistry.Entry memory expected = registry.entryAt(0);
        expected.exitEffectiveL1 = 65;
        bytes32 leaf = LibEntriesTree.leaf(0, expected);
        vm.roll(45);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(1, 45, 1, leaf);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitRequested(0, 65);
        vm.prank(Alice);
        registry.requestExit(0);

        _assertEntry(0, expected);
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
        _assertCheckpoint(0, _REGISTERED_AT, 1, registeredRoot);
        _assertCheckpoint(1, 45, 1, leaf);
    }

    function test_requestExit_RevertWhen_NotOwner() external {
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.requestExit(0);
        // The registry's owner has no say over a bond either.
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        registry.requestExit(0);

        vm.prank(Alice);
        registry.requestExit(0);
        // The owner is checked before the exit.
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.requestExit(0);
    }

    /// @dev Once set, the exit cannot be requested again, so a request never moves it later.
    function test_requestExit_RevertWhen_AlreadySet() external {
        vm.prank(Alice);
        registry.requestExit(0);

        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(100);
        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        vm.prank(Alice);
        registry.requestExit(0);
        assertEq(registry.entryAt(0).exitEffectiveL1, _EXIT, "exit unchanged");
    }

    /// @dev Release clears the owner, so the former owner and anyone else both get
    /// `SlotReleased`.
    function test_requestExit_RevertWhen_SlotReleased() external {
        _release(0);

        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        vm.prank(Bob);
        registry.requestExit(0);
    }

    function test_requestExit_RevertWhen_UnknownBond() external {
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        vm.prank(Alice);
        registry.requestExit(1);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        vm.prank(Alice);
        registry.requestExit(type(uint256).max);
    }

    /// @dev The exit must stay below the no-exit sentinel 2^48 - 1, whether it counts from a
    /// later activation or from the current block; one block less fits. A rejected request
    /// changes nothing.
    function test_requestExit_RevertWhen_EffectiveBlockReachesSentinel() external {
        uint256 sentinel = 2 ** 48 - 1;
        assertEq(_register(Bob, _CK_B), 1, "bond 1, active from 40");

        // From the activation: bond 2 activates at sentinel - 21, bond 3 at sentinel - 20.
        vm.roll(sentinel - EXIT_DELAY - ACTIVATION_DELAY - 1);
        assertEq(_register(Carol, _CK_C), 2, "bond 2");
        vm.prank(Carol);
        registry.requestExit(2);
        assertEq(registry.entryAt(2).exitEffectiveL1, sentinel - 1, "activation: fits");

        vm.roll(sentinel - EXIT_DELAY - ACTIVATION_DELAY);
        assertEq(_register(David, _CK_D), 3, "bond 3");
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        vm.prank(David);
        registry.requestExit(3);

        // From the current block.
        vm.roll(sentinel - EXIT_DELAY - 1);
        vm.prank(Bob);
        registry.requestExit(1);
        assertEq(registry.entryAt(1).exitEffectiveL1, sentinel - 1, "current block: fits");

        vm.roll(sentinel - EXIT_DELAY);
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        vm.prank(Alice);
        registry.requestExit(0);

        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT, "bond 0 unchanged");
        assertEq(registry.entryAt(3).exitEffectiveL1, _NO_EXIT, "bond 3 unchanged");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        assertEq(registry.entriesRoot(), root, "root");
    }

    // ---------------------------------------------------------------
    // confirmExit
    // ---------------------------------------------------------------

    /// @dev The first confirmation records its block and starts the withdrawal delay; a later
    /// one succeeds without moving it or emitting (Lean `confirmation_starts_new_timer`,
    /// `reconfirmation_does_not_reset_timer`).
    function test_confirmExit_RecordsCurrentBlockOnce() external {
        _requestExitCovered();
        vm.roll(100);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitConfirmed(0, 100);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), 100, "confirmed at 100");

        vm.roll(999);
        vm.recordLogs();
        registry.confirmExit(0);
        assertEq(vm.getRecordedLogs().length, 0, "no event");
        assertEq(registry.exitConfirmedAtL1(0), 100, "not moved");
    }

    function test_confirmExit_IsPermissionless() external {
        _requestExitCovered();
        vm.prank(Carol);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), _REGISTERED_AT, "confirmed");
    }

    /// @dev Only a landed committee chosen at or after the exit block excludes the stake.
    function test_confirmExit_RevertWhen_SnapshotBelowExit() external {
        vm.prank(Alice);
        registry.requestExit(0);

        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);
        mockInbox.setActiveCommitteeSnapshot(_EXIT - 1);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);

        mockInbox.setActiveCommitteeSnapshot(_EXIT);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), _REGISTERED_AT, "equality confirms");
    }

    /// @dev The Inbox's initialization is checked before the bond.
    function test_confirmExit_RevertWhen_InboxNotInitialized() external {
        _requestExitCovered();
        mockInbox.setInitialized(false);

        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        registry.confirmExit(1);

        mockInbox.setInitialized(true);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), _REGISTERED_AT, "confirmed");
    }

    /// @dev No snapshot covers the no-exit sentinel.
    function test_confirmExit_RevertWhen_ExitNotSet() external {
        mockInbox.setActiveCommitteeSnapshot(type(uint256).max);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotSet.selector);
        registry.confirmExit(0);
    }

    function test_confirmExit_RevertWhen_SlotReleased() external {
        _release(0);
        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        registry.confirmExit(0);
    }

    function test_confirmExit_RevertWhen_UnknownBond() external {
        mockInbox.setActiveCommitteeSnapshot(type(uint256).max);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.confirmExit(1);
    }

    /// @dev While the Inbox holds its reentrancy lock (no confirmation runs inside a landing or a
    /// recovery), checked before anything else.
    function test_confirmExit_RevertWhen_InboxLocked() external {
        _requestExitCovered();
        mockInbox.setInNonReentrant(true);

        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.confirmExit(1);
        mockInbox.setInitialized(false);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.confirmExit(0);

        mockInbox.setInitialized(true);
        mockInbox.setInNonReentrant(false);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), _REGISTERED_AT, "confirmed");
    }

    /// @dev The confirmation lives outside the entries: no checkpoint, root or entry changes.
    function test_confirmExit_WritesNoCheckpoint() external {
        _requestExitCovered();
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        bytes32 root = registry.entriesRoot();
        vm.roll(100);

        vm.recordLogs();
        registry.confirmExit(0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "one event");
        assertEq(logs[0].topics[0], IEtnaStakingRegistry.ExitConfirmed.selector, "ExitConfirmed");

        assertEq(registry.checkpointCount(), 1, "no checkpoint appended");
        _assertCheckpoint(0, _REGISTERED_AT, 1, root);
        assertEq(registry.entriesRoot(), root, "root");
        _assertEntry(0, entry);
    }

    // ---------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------

    /// @dev Confirmed at 100 with a 30-block delay: block 129 is too early, block 130 releases
    /// the slot, paying `to` (Lean `confirmation_starts_new_timer`). The released slot keeps its
    /// place in the tree with the all-zero entry's leaf, not a zero leaf.
    function test_withdraw_WaitsFullDelayFromConfirmation() external {
        _requestExitCovered();
        vm.roll(100);
        registry.confirmExit(0);

        vm.roll(129);
        vm.expectRevert(IEtnaStakingRegistry.WithdrawalNotReady.selector);
        vm.prank(Alice);
        registry.withdraw(0, Bob);

        vm.roll(130);
        IEtnaStakingRegistry.Entry memory zero;
        bytes32 releasedLeaf = LibEntriesTree.leaf(0, zero);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(1, 130, 1, releasedLeaf);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.StakeWithdrawn(0, Bob, MIN_STAKE);
        vm.prank(Alice);
        registry.withdraw(0, Bob);

        assertEq(token.balanceOf(Bob), MIN_STAKE, "paid to `to`");
        assertEq(token.balanceOf(Alice), 0, "not to the owner");
        assertEq(token.balanceOf(address(registry)), 0, "registry empty");
        _assertEntry(0, zero);
        assertEq(registry.ownerOf(0), address(0), "owner cleared");
        assertEq(registry.exitConfirmedAtL1(0), 0, "confirmation cleared");
        assertEq(registry.freeSlotCount(), 1, "slot freed");
        assertEq(registry.entryCount(), 1, "count keeps the released slot");
        assertTrue(releasedLeaf != bytes32(0), "released leaf is not zero");
        assertEq(registry.entriesRoot(), releasedLeaf, "root over the released leaf");
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
        _assertCheckpoint(1, 130, 1, releasedLeaf);
        assertTrue(registry.keyUsed(vm.addr(_CK_A)), "key stays used");
    }

    /// @dev The owner is checked before the recipient.
    function test_withdraw_RevertWhen_NotOwnerWithStake() external {
        _confirmAndWait();

        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.withdraw(0, Bob);
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.withdraw(0, address(0));
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        registry.withdraw(0, address(this));

        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(token.balanceOf(Alice), MIN_STAKE, "paid");
    }

    /// @dev Without an exit, before its confirmation, for an unknown bond and after the release
    /// (no second withdrawal).
    function test_withdraw_RevertWhen_Unconfirmed() external {
        vm.roll(10_000);
        _assertWithdrawReverts(0, IEtnaStakingRegistry.ExitNotConfirmed.selector, "no exit");
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(20_000);
        _assertWithdrawReverts(0, IEtnaStakingRegistry.ExitNotConfirmed.selector, "unconfirmed");
        _assertWithdrawReverts(1, IEtnaStakingRegistry.ExitNotConfirmed.selector, "unknown");

        _confirmExit(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        _assertWithdrawReverts(0, IEtnaStakingRegistry.ExitNotConfirmed.selector, "released");
        assertEq(token.balanceOf(Alice), MIN_STAKE, "paid once");
    }

    /// @dev While the Inbox holds its reentrancy lock (no withdrawal runs inside a landing or a
    /// recovery), checked before the confirmation and the owner.
    function test_withdraw_RevertWhen_InboxLocked() external {
        _confirmAndWait();
        mockInbox.setInNonReentrant(true);

        _assertWithdrawReverts(0, IEtnaStakingRegistry.InboxLocked.selector, "owner");
        _assertWithdrawReverts(1, IEtnaStakingRegistry.InboxLocked.selector, "unconfirmed");
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        vm.prank(Bob);
        registry.withdraw(0, Bob);

        mockInbox.setInNonReentrant(false);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(token.balanceOf(Alice), MIN_STAKE, "paid");
    }

    function test_withdraw_RevertWhen_RecipientZero() external {
        _confirmAndWait();

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        vm.prank(Alice);
        registry.withdraw(0, address(0));

        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(token.balanceOf(Alice), MIN_STAKE, "paid");
    }

    /// @dev The snapshot never decreases outside the governed rollback, so withdrawal does not
    /// read it again (Lean `withdraw_ignores_snapshot`).
    function test_withdraw_DoesNotRecheckTheSnapshot() external {
        _confirmAndWait();
        mockInbox.setActiveCommitteeSnapshot(0);

        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(token.balanceOf(Alice), MIN_STAKE, "paid");
        assertEq(registry.freeSlotCount(), 1, "slot freed");
    }

    /// @dev The lock taken by `withdraw` stops a token that re-enters it from `transfer`. The
    /// slot is released before the stake moves, so a re-entrant call into an unguarded function
    /// already finds it released.
    function test_withdraw_RevertWhen_TokenReenters() external {
        ReentrantERC20 reentrant = new ReentrantERC20();
        registry = _deployRegistry(address(reentrant), address(mockInbox));
        reentrant.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        reentrant.approve(address(registry), MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        _confirmAndWait();
        reentrant.armReentry(address(registry), abi.encodeCall(registry.withdraw, (0, Alice)));

        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(registry.exitConfirmedAtL1(0), _REGISTERED_AT, "confirmation kept");
        assertEq(registry.freeSlotCount(), 0, "slot kept");
        assertEq(reentrant.balanceOf(address(registry)), MIN_STAKE, "stake kept");

        reentrant.armReentry(address(registry), abi.encodeCall(registry.confirmExit, (0)));
        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
    }

    // ---------------------------------------------------------------
    // register after a release
    // ---------------------------------------------------------------

    /// @dev The next occupant of a freed slot starts unconfirmed and owns it alone: it cannot
    /// withdraw on the old occupant's timer, and the old owner has no claim (Lean
    /// `slot_reuse_starts_fresh`).
    function test_register_ReusesFreedSlotWithoutInheritedConfirmationOrOwner() external {
        _release(0);
        uint256 reusedAt = block.number;

        assertEq(_register(Bob, _CK_B), 0, "the freed slot");
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        assertEq(entry.ckX, _xOf(_CK_B), "new key");
        assertEq(entry.effStake, MIN_STAKE, "new stake");
        assertEq(entry.activeFromL1, reusedAt + ACTIVATION_DELAY, "new activation");
        assertEq(entry.exitEffectiveL1, _NO_EXIT, "no exit");
        assertEq(registry.ownerOf(0), Bob, "new owner");
        assertEq(registry.exitConfirmedAtL1(0), 0, "no confirmation");
        assertEq(registry.freeSlotCount(), 0, "free list empty");
        assertEq(registry.entryCount(), 1, "no slot appended");

        vm.roll(10_000);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotConfirmed.selector);
        vm.prank(Bob);
        registry.withdraw(0, Bob);
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Alice);
        registry.requestExit(0);
    }

    /// @dev Withdrawal frees the slot, not the key.
    function test_register_RevertWhen_KeyWasUsedByAWithdrawnBond() external {
        _release(0);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        _fund(Alice, MIN_STAKE);
        _fund(Bob, MIN_STAKE);

        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        vm.expectRevert(IEtnaStakingRegistry.KeyAlreadyUsed.selector);
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        pop = EtnaTestKeys.popSig(_CK_A, registry, Bob);
        vm.expectRevert(IEtnaStakingRegistry.KeyAlreadyUsed.selector);
        vm.prank(Bob);
        registry.register(publicKey, MIN_STAKE, pop);

        assertTrue(registry.keyUsed(vm.addr(_CK_A)), "key used");
        assertEq(registry.freeSlotCount(), 1, "slot still free");
    }

    /// @dev Withdrawn slots are reused before new ones are appended, the most recently released
    /// first; each release writes the all-zero entry's leaf.
    function test_register_ReusesMostRecentlyFreedSlotFirst() external {
        assertEq(_register(Alice, _CK_B), 1, "bond 1");
        assertEq(_register(Alice, _CK_C), 2, "bond 2");
        _release(0);
        _release(2);
        assertEq(registry.freeSlotCount(), 2, "free slots");
        IEtnaStakingRegistry.Entry memory zero;
        assertEq(
            registry.entriesRoot(),
            _rootOfFour(LibEntriesTree.leaf(0, zero), _leafAt(1), LibEntriesTree.leaf(2, zero), 0),
            "root over the released leaves"
        );

        assertEq(_register(Bob, _CK_D), 2, "most recently released first");
        assertEq(registry.entryCount(), 3, "no slot appended");
        assertEq(_register(Bob, _CK_E), 0, "then the earlier release");
        assertEq(registry.freeSlotCount(), 0, "free list empty");
        assertEq(_register(Bob, _CK_F), 3, "then a new slot");
        assertEq(registry.entryCount(), 4, "entry count");

        assertEq(registry.ownerOf(0), Bob, "owner 0");
        assertEq(registry.ownerOf(1), Alice, "owner 1");
        assertEq(registry.ownerOf(2), Bob, "owner 2");
        assertEq(registry.entryAt(2).ckX, _xOf(_CK_D), "entry 2");
        assertEq(registry.entryAt(0).ckX, _xOf(_CK_E), "entry 0");
        bytes32 root = _rootOfFour(_leafAt(0), _leafAt(1), _leafAt(2), _leafAt(3));
        assertEq(registry.entriesRoot(), root, "root over the current entries");
        _assertCheckpoint(registry.checkpointCount() - 1, block.number, 4, root);
    }

    // ---------------------------------------------------------------
    // forceExit
    // ---------------------------------------------------------------

    /// @dev The two-argument selector derives the exit from the execution block, keeps an
    /// earlier exit on a later recovery, and leaves the stake available for slashing.
    function test_forceExit_TwoArgumentSelectorUsesCurrentBlock() external {
        bytes memory callData =
            abi.encodeWithSignature("forceExit(uint256,bytes32)", 0, _entryKeyOf(_CK_A));
        uint256 stake = registry.entryAt(0).effStake;
        uint256 balance = token.balanceOf(address(registry));
        vm.roll(50);

        vm.prank(address(mockInbox));
        (bool success,) = address(registry).call(callData);
        assertTrue(success, "two-argument forceExit succeeds");
        assertEq(registry.entryAt(0).exitEffectiveL1, 50, "exit uses the execution block");
        assertEq(registry.entryAt(0).effStake, stake, "stake unchanged");

        vm.roll(70);
        vm.prank(address(mockInbox));
        (success,) = address(registry).call(callData);
        assertTrue(success, "later recovery succeeds");
        assertEq(registry.entryAt(0).exitEffectiveL1, 50, "earlier exit preserved");
        assertEq(registry.entryAt(0).effStake, stake, "stake still unchanged");
        assertEq(token.balanceOf(address(registry)), balance, "no tokens moved");
    }

    /// @dev Governance recovery at block 50 excludes bond 0, which has no exit: the exit moves to
    /// R = 50 and block 50's checkpoint is appended over the new leaf, while the stake, owner and
    /// activation stay and no TAIKO moves (Lean `exclusion_keeps_stake`). Once a landed committee
    /// covers block 50 the exit is confirmed, and after the delay Alice withdraws her whole stake.
    function test_forceExit_MovesExitToRWithoutSlashing() external {
        bytes32 key = _entryKeyOf(_CK_A);
        IEtnaStakingRegistry.Entry memory expected = registry.entryAt(0);
        assertEq(expected.exitEffectiveL1, _NO_EXIT, "no exit");
        expected.exitEffectiveL1 = 50;
        bytes32 leaf = LibEntriesTree.leaf(0, expected);
        vm.roll(50);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(1, 50, 1, leaf);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(0, 50);
        vm.recordLogs();
        mockInbox.forceExit(registry, 0, key);

        assertEq(vm.getRecordedLogs().length, 2, "no other event, no TAIKO transfer");
        _assertEntry(0, expected);
        assertEq(registry.entriesRoot(), leaf, "root");
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
        _assertCheckpoint(1, 50, 1, leaf);
        assertEq(token.balanceOf(address(registry)), MIN_STAKE, "stake held");
        assertEq(registry.ownerOf(0), Alice, "owner kept");
        assertEq(registry.exitConfirmedAtL1(0), 0, "not confirmed");

        mockInbox.setActiveCommitteeSnapshot(49);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);
        mockInbox.setActiveCommitteeSnapshot(50);
        registry.confirmExit(0);
        vm.roll(50 + WITHDRAWAL_DELAY);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(token.balanceOf(Alice), MIN_STAKE, "whole stake back");
    }

    /// @dev A later exit moves earlier: Alice's requested exit (block 60) becomes R = 50 when
    /// recovery runs at block 50. A confirmation already recorded stays (spec 8 step 4: confirmed
    /// exits are unaffected); the mock snapshot covers block 60 early so the exit can be
    /// confirmed, at block 40, before R.
    function test_forceExit_MovesALaterExitEarlier() external {
        bytes32 key = _entryKeyOf(_CK_A);
        _requestExitCovered();
        assertEq(registry.entryAt(0).exitEffectiveL1, _EXIT, "requested");
        vm.roll(40);
        registry.confirmExit(0);
        vm.roll(50);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(0, 50);
        mockInbox.forceExit(registry, 0, key);

        assertEq(registry.entryAt(0).exitEffectiveL1, 50, "moved earlier");
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
        _assertCheckpoint(1, 50, 1, _leafAt(0));
        assertEq(registry.exitConfirmedAtL1(0), 40, "confirmation kept");
    }

    /// @dev An exit at or before R is kept with no write, checkpoint or event: Alice's requested
    /// exit (block 60) meets recoveries at blocks 60 and 70, and bond 1's exit, forced at block
    /// 70, meets a later recovery at block 90.
    function test_forceExit_KeepsAnEarlierExitWithoutCheckpoint() external {
        bytes32 aliceKey = _entryKeyOf(_CK_A);
        bytes32 bobKey = _entryKeyOf(_CK_B);
        vm.prank(Alice);
        registry.requestExit(0);
        IEtnaStakingRegistry.Entry memory alice = registry.entryAt(0);
        bytes32 root = registry.entriesRoot();

        vm.roll(_EXIT);
        _assertForceExitKeeps(0, aliceKey, "R equals the exit");
        vm.roll(70);
        _assertForceExitKeeps(0, aliceKey, "R after the exit");
        _assertEntry(0, alice);
        assertEq(registry.checkpointCount(), 1, "no checkpoint");
        _assertCheckpoint(0, _REGISTERED_AT, 1, root);

        assertEq(_register(Bob, _CK_B), 1, "bond 1");
        mockInbox.forceExit(registry, 1, bobKey);
        assertEq(registry.entryAt(1).exitEffectiveL1, 70, "forced");
        vm.roll(90);
        _assertForceExitKeeps(1, bobKey, "earlier forced exit");
    }

    /// @dev A forced exit is a set exit, so the owner cannot request another afterwards and the
    /// exit, forced at block 35 before the activation, never moves later.
    function test_forceExit_BlocksLaterRequestExit() external {
        bytes32 key = _entryKeyOf(_CK_A);
        vm.roll(35);
        mockInbox.forceExit(registry, 0, key);
        assertEq(registry.entryAt(0).exitEffectiveL1, 35, "forced");

        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(1000);
        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        vm.prank(Alice);
        registry.requestExit(0);
        assertEq(registry.entryAt(0).exitEffectiveL1, 35, "exit unchanged");
    }

    /// @dev A recovery excluding several bonds in one block leaves one checkpoint for that block,
    /// over both new leaves.
    function test_forceExit_SeveralExclusionsInOneBlockLeaveOneCheckpoint() external {
        bytes32 aliceKey = _entryKeyOf(_CK_A);
        bytes32 bobKey = _entryKeyOf(_CK_B);
        assertEq(_register(Bob, _CK_B), 1, "bond 1");
        vm.roll(50);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(0, 50);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(1, 50);
        mockInbox.forceExit(registry, 1, bobKey);

        assertEq(registry.entryAt(0).exitEffectiveL1, 50, "bond 0");
        assertEq(registry.entryAt(1).exitEffectiveL1, 50, "bond 1");
        bytes32 root = keccak256(abi.encodePacked(_leafAt(0), _leafAt(1)));
        assertEq(registry.entriesRoot(), root, "root over both exits");
        assertEq(registry.checkpointCount(), 2, "one checkpoint for block 50");
        _assertCheckpoint(1, 50, 2, root);
    }

    /// @dev A slashed entry keeps its key and slot, so an exclusion naming it succeeds. The slash
    /// at block 45 already moved the exit to 45, so recovery at block 50 keeps it with no write
    /// or event. The key is still checked.
    function test_forceExit_AllowsSlashedEntry() external {
        bytes32 aliceKey = _entryKeyOf(_CK_A);
        bytes32 bobKey = _entryKeyOf(_CK_B);
        vm.roll(45);
        _slashDoubleSign(0, _CK_A);
        IEtnaStakingRegistry.Entry memory slashed = registry.entryAt(0);
        assertEq(slashed.effStake, 0, "slashed");
        assertEq(slashed.exitEffectiveL1, 45, "exit at the slash");

        vm.roll(50);
        _assertForceExitKeeps(0, aliceKey, "slashed entry");
        _assertEntry(0, slashed);

        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        mockInbox.forceExit(registry, 0, bobKey);
    }

    /// @dev An exclusion takes no stake, so double-sign evidence can still take all of it (spec 8
    /// step 2): bond 0, forced to exit at block 50, is slashed at block 60, which keeps the
    /// earlier exit.
    function test_forceExit_LeavesTheStakeToDoubleSignSlashing() external {
        bytes32 key = _entryKeyOf(_CK_A);
        vm.roll(50);
        mockInbox.forceExit(registry, 0, key);

        vm.roll(60);
        _slashDoubleSign(0, _CK_A);
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        assertEq(entry.effStake, 0, "slashed");
        assertEq(entry.exitEffectiveL1, 50, "forced exit kept");
        assertEq(token.balanceOf(address(registry)), 0, "stake taken");
    }

    /// @dev Only the Inbox fixed in the registry: not the registry owner, the bond owner, anyone
    /// else or another Inbox. The caller is checked first, before the bond, the key and R.
    function test_forceExit_RevertWhen_NotInbox() external {
        bytes32 key = _entryKeyOf(_CK_A);
        MockEtnaInbox otherInbox = new MockEtnaInbox();

        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        registry.forceExit(0, key);
        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        vm.prank(Alice);
        registry.forceExit(0, key);
        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        vm.prank(Bob);
        registry.forceExit(0, key);
        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        otherInbox.forceExit(registry, 0, key);

        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        registry.forceExit(1, key);
        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        registry.forceExit(0, bytes32(0));
        vm.roll(_NO_EXIT);
        vm.expectRevert(IEtnaStakingRegistry.NotInbox.selector);
        registry.forceExit(0, key);
        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT, "unchanged");

        vm.roll(_REGISTERED_AT);
        mockInbox.forceExit(registry, 0, key);
        assertEq(registry.entryAt(0).exitEffectiveL1, 30, "the Inbox forces");
    }

    /// @dev A bond id past the used slots, checked before the key and R.
    function test_forceExit_RevertWhen_UnknownBond() external {
        bytes32 key = _entryKeyOf(_CK_A);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        mockInbox.forceExit(registry, 1, key);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        mockInbox.forceExit(registry, type(uint256).max, key);
        vm.roll(_NO_EXIT);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        mockInbox.forceExit(registry, 1, keccak256(abi.encode(0, 0)));
    }

    /// @dev A released slot holds the all-zero entry, whose key keccak256(abi.encode(0, 0)) an
    /// exclusion could otherwise match: naming it, or the withdrawn occupant's key, reverts
    /// `SlotReleased` before the key and R are checked (Lean `released_slot_exclusion_rejected`).
    function test_forceExit_RevertWhen_SlotReleased() external {
        bytes32 aliceKey = _entryKeyOf(_CK_A);
        bytes32 releasedKey = keccak256(abi.encode(0, 0));
        _release(0);
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();

        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        mockInbox.forceExit(registry, 0, releasedKey);
        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.roll(_NO_EXIT);
        vm.expectRevert(IEtnaStakingRegistry.SlotReleased.selector);
        mockInbox.forceExit(registry, 0, releasedKey);

        IEtnaStakingRegistry.Entry memory zero;
        _assertEntry(0, zero);
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        assertEq(registry.entriesRoot(), root, "root");
        assertEq(registry.freeSlotCount(), 1, "slot still free");
    }

    /// @dev Governance prepared the exclusion of bond 0 for Alice's key, but Alice withdrew and
    /// Bob's key reused the slot: the stale exclusion reverts and Bob's entry is untouched (Lean
    /// `stale_exclusion_identity_rejected`). So do Bob's X under the other prefix (another point),
    /// the zero key and Bob's key against Carol's bond 1, and the key is checked before R. Bob's
    /// own key then excludes him.
    function test_forceExit_RevertWhen_EntryKeyMismatch() external {
        bytes32 aliceKey = _entryKeyOf(_CK_A);
        bytes32 bobKey = _entryKeyOf(_CK_B);
        _release(0);
        assertEq(_register(Bob, _CK_B), 0, "Bob reuses slot 0");
        assertEq(_register(Carol, _CK_C), 1, "bond 1");
        IEtnaStakingRegistry.Entry memory bob = registry.entryAt(0);
        bytes32 otherPrefixKey = keccak256(abi.encode(uint256(bob.ckPrefix ^ 1), bob.ckX));
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();
        uint256 r = block.number;

        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        mockInbox.forceExit(registry, 0, otherPrefixKey);
        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        mockInbox.forceExit(registry, 0, bytes32(0));
        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        mockInbox.forceExit(registry, 1, bobKey);
        vm.roll(_NO_EXIT);
        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.roll(r);

        _assertEntry(0, bob);
        assertEq(registry.entryAt(1).exitEffectiveL1, _NO_EXIT, "bond 1 unchanged");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        assertEq(registry.entriesRoot(), root, "root");

        mockInbox.forceExit(registry, 0, bobKey);
        assertEq(registry.entryAt(0).exitEffectiveL1, r, "Bob excluded");
    }

    /// @dev R is an L1 block, and the registry keeps every L1 block it stores below the no-exit
    /// sentinel 2^48 - 1, so an R at or above it reverts `InvalidEventBlock` with nothing
    /// written: min(no exit, R) would leave an excluded entry without an exit, still selectable.
    /// An entry that already exits rejects it too. One block less fits.
    function test_forceExit_RevertWhen_CurrentBlockReachesSentinel() external {
        bytes32 aliceKey = _entryKeyOf(_CK_A);
        bytes32 bobKey = _entryKeyOf(_CK_B);
        assertEq(_register(Bob, _CK_B), 1, "bond 1");
        vm.prank(Bob);
        registry.requestExit(1);
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();

        vm.roll(_NO_EXIT);
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.roll(2 ** 48);
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.roll(type(uint256).max);
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        mockInbox.forceExit(registry, 0, aliceKey);
        vm.roll(_NO_EXIT);
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        mockInbox.forceExit(registry, 1, bobKey);

        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT, "bond 0 keeps no exit");
        assertEq(registry.entryAt(1).exitEffectiveL1, _EXIT, "bond 1 keeps its exit");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        assertEq(registry.entriesRoot(), root, "root");

        vm.roll(_NO_EXIT - 1);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(0, _NO_EXIT - 1);
        mockInbox.forceExit(registry, 0, aliceKey);
        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT - 1, "one block less fits");
    }

    /// @dev `forceExit` takes the registry's lock: reached from a registry call that holds it,
    /// here a token re-entering through the Inbox from `register`'s `transferFrom` after the
    /// entry is written, it reverts the registration.
    function test_forceExit_RevertWhen_Reentered() external {
        ReentrantERC20 reentrant = new ReentrantERC20();
        registry = _deployRegistry(address(reentrant), address(mockInbox));
        reentrant.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        reentrant.approve(address(registry), MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        bytes memory forceExitCall =
            abi.encodeCall(MockEtnaInbox.forceExit, (registry, 0, _entryKeyOf(_CK_A)));

        reentrant.armReentry(address(mockInbox), forceExitCall);
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        assertEq(registry.entryCount(), 0, "not registered");

        reentrant.armReentry(address(0), "");
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT, "registered without an exit");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Alice requests bond 0's exit (block 60) and the mock snapshot covers it.
    function _requestExitCovered() private {
        vm.prank(Alice);
        registry.requestExit(0);
        mockInbox.setActiveCommitteeSnapshot(_EXIT);
    }

    /// @dev Requests, covers and confirms bond 0's exit in the current block (30), then rolls to
    /// the first block a withdrawal may happen.
    function _confirmAndWait() private {
        _requestExitCovered();
        registry.confirmExit(0);
        vm.roll(_REGISTERED_AT + WITHDRAWAL_DELAY);
    }

    function _assertWithdrawReverts(uint256 _bondId, bytes4 _error, string memory _label) private {
        vm.prank(Alice);
        try registry.withdraw(_bondId, Alice) {
            assertTrue(false, string.concat(_label, ": withdrew"));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(_error), _label);
        }
    }

    /// @dev The leaf of the entry the registry holds at `_bondId`.
    function _leafAt(uint256 _bondId) private view returns (bytes32) {
        return LibEntriesTree.leaf(_bondId, registry.entryAt(_bondId));
    }

    /// @dev The root over four leaf positions.
    function _rootOfFour(
        bytes32 _a,
        bytes32 _b,
        bytes32 _c,
        bytes32 _d
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(_a, _b)), keccak256(abi.encodePacked(_c, _d))
            )
        );
    }

    function _xOf(uint256 _pk) private returns (bytes32) {
        return bytes32(vm.createWallet(_pk).publicKeyX);
    }

    /// @dev The entry key of `_pk`'s consensus key: keccak256(abi.encode(ckPrefix, ckX)).
    function _entryKeyOf(uint256 _pk) private returns (bytes32) {
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        return keccak256(abi.encode(uint256(uint8(publicKey[0])), _xOf(_pk)));
    }

    /// @dev Forces bond `_bondId`'s exit in the current block through the Inbox and asserts nothing
    /// changes: no event, checkpoint, root or exit.
    function _assertForceExitKeeps(
        uint256 _bondId,
        bytes32 _entryKey,
        string memory _label
    )
        private
    {
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();
        uint48 exit = registry.entryAt(_bondId).exitEffectiveL1;

        vm.recordLogs();
        mockInbox.forceExit(registry, _bondId, _entryKey);

        assertEq(vm.getRecordedLogs().length, 0, string.concat(_label, ": no event"));
        assertEq(registry.checkpointCount(), checkpoints, string.concat(_label, ": no checkpoint"));
        assertEq(registry.entriesRoot(), root, string.concat(_label, ": root"));
        assertEq(registry.entryAt(_bondId).exitEffectiveL1, exit, string.concat(_label, ": exit"));
    }

    /// @dev Bob reports a nil and a non-nil generation-0 precommit at the same height and round,
    /// both signed with `_pk` for this deployment, against bond `_bondId`.
    function _slashDoubleSign(uint256 _bondId, uint256 _pk) private {
        bytes memory cometChainId = LibCometVote.chainId(
            LibCometVote.chainDomain(block.chainid, L2_CHAIN_ID, address(mockInbox), 0)
        );
        IEtnaStakingRegistry.Vote memory nil = _precommit(_pk, 0, cometChainId);
        IEtnaStakingRegistry.Vote memory forBlock =
            _precommit(_pk, keccak256("block"), cometChainId);
        vm.prank(Bob);
        registry.slashDoubleSign(_bondId, nil, forBlock);
    }

    /// @dev A generation-0 precommit at height 1, round 0 and timestamp 0 for block `_blockHash`
    /// with an empty part set header (nil when `_blockHash` is zero), signed with `_pk` under
    /// `_cometChainId`.
    function _precommit(
        uint256 _pk,
        bytes32 _blockHash,
        bytes memory _cometChainId
    )
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory v_)
    {
        v_.voteType = 2;
        v_.height = 1;
        v_.blockHash = _blockHash;
        v_.signature = new bytes(65);
        v_ = EtnaTestKeys.signVote(_pk, v_, _cometChainId);
    }
}
