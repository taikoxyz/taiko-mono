// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
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

    /// @dev While the Inbox runs `land` or `recover` (C8), checked before anything else.
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
    /// place in the tree with the all-zero entry's leaf (C9).
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

    /// @dev While the Inbox runs `land` or `recover` (C8), checked before the confirmation and
    /// the owner.
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
}
