// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @notice Delayed principal, lifetime forfeitures and callback atomicity.
contract EtnaStakingRegistryTopUpForfeitTest is EtnaStakingRegistryTestBase {
    uint256 private constant _PK = 0xC0A;
    bytes32 private _key;

    function setUp() public override {
        super.setUp();
        vm.roll(100);
        _register(Alice, _PK);
        vm.roll(110);
        _key = _entryKey(registry, 0);
    }

    function test_topUp_WorksBeforeInboxInitialization() external {
        assertFalse(mockInbox.isInitialized());
        _deposit(21 ether);
        _assertPending(21 ether, 120);
        assertEq(token.balanceOf(address(registry)), MIN_STAKE + 21 ether);
    }

    function test_topUp_PreservesOriginalEntryAndCheckpointUntilExplicitActivation() external {
        IEtnaStakingRegistry.Entry memory beforeEntry = registry.entryAt(0);
        bytes32 root = registry.entriesRoot();
        uint256 checkpoints = registry.checkpointCount();
        _fund(Alice, 21 ether);
        vm.expectEmit();
        emit IEtnaStakingRegistry.TopUpDeposited(0, 21 ether, 120);
        vm.prank(Alice);
        registry.topUp(0, 21 ether);
        _assertEntry(0, beforeEntry);
        assertEq(registry.ownerOf(0), Alice);
        assertEq(registry.entryCount(), 1);
        assertEq(registry.bondCount(), 1);
        assertEq(registry.entriesRoot(), root);
        assertEq(registry.checkpointCount(), checkpoints);
        vm.roll(120);
        _assertEntry(0, beforeEntry);
        assertEq(registry.entriesRoot(), root, "maturity does not activate");
        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(1, 120, 1, _leafWithStake(MIN_STAKE + 21 ether));
        vm.expectEmit();
        emit IEtnaStakingRegistry.TopUpActivated(0, 21 ether);
        vm.prank(Bob);
        registry.activateTopUp(0);
        beforeEntry.effStake += 21 ether;
        _assertEntry(0, beforeEntry);
        _assertPending(0, 0);
        assertEq(registry.checkpointCount(), 2);
        assertEq(registry.checkpointAt(0).entriesRoot, root, "historical snapshot frozen");
        assertEq(registry.entriesRoot(), LibEntriesTree.leaf(0, beforeEntry));
    }

    function test_topUp_RevertWhen_NotOwner() external {
        _fund(Bob, 1 ether);
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.topUp(0, 1 ether);
        _assertPending(0, 0);
    }

    function test_topUp_RevertWhen_EntryNotActive() external {
        vm.roll(109);
        _fund(Alice, 1 ether);
        vm.expectRevert(IEtnaStakingRegistry.TopUpNotAllowed.selector);
        vm.prank(Alice);
        registry.topUp(0, 1 ether);
    }

    function test_topUp_RevertWhen_ZeroAmount() external {
        vm.expectRevert(IEtnaStakingRegistry.InvalidTopUpAmount.selector);
        vm.prank(Alice);
        registry.topUp(0, 0);
    }

    function test_topUp_RevertWhen_AnotherDepositPendingEvenAfterMaturity() external {
        _deposit(1 ether);
        _fund(Alice, 1 ether);
        vm.roll(120);
        vm.expectRevert(IEtnaStakingRegistry.TopUpPending.selector);
        vm.prank(Alice);
        registry.topUp(0, 1 ether);
        _assertPending(1 ether, 120);
    }

    function test_topUp_AllowsAnotherDepositAfterActivation() external {
        _deposit(1 ether);
        vm.roll(120);
        registry.activateTopUp(0);
        _deposit(2 ether);
        _assertPending(2 ether, 130);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE + 1 ether);
    }

    function test_topUp_RevertWhen_UnknownOrWithdrawn() external {
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.topUp(1, 1);
        _withdrawBond(0);
        vm.expectRevert(IEtnaStakingRegistry.BondWithdrawn.selector);
        registry.topUp(0, 1);
    }

    /// @dev Spec 4.1 vector 13a.m: an unissued id (the next one or a far-future one) reverts
    /// without writing any state.
    function test_activateTopUp_RevertWhen_UnknownBond() external {
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.activateTopUp(1);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.activateTopUp(type(uint256).max);
        _assertPending(0, 0);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
    }

    function test_topUp_RevertWhen_ReadinessReachesSentinel() external {
        _fund(Alice, 1);
        vm.roll(uint256(type(uint48).max) - ACTIVATION_DELAY);
        vm.expectRevert(IEtnaStakingRegistry.InvalidEventBlock.selector);
        vm.prank(Alice);
        registry.topUp(0, 1);
        _assertPending(0, 0);
    }

    function test_topUp_RevertWhen_DelayAdditionOverflows() external {
        _fund(Alice, 1);
        vm.roll(type(uint256).max);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        vm.prank(Alice);
        registry.topUp(0, 1);
        _assertPending(0, 0);
    }

    function test_topUp_RevertWhen_PrincipalAdditionOverflows() external {
        _fund(Alice, 1);
        vm.expectRevert();
        vm.prank(Alice);
        registry.topUp(0, type(uint256).max);
        _assertPending(0, 0);
        assertEq(token.balanceOf(address(registry)), MIN_STAKE);
    }

    function test_activateTopUp_RevertWhen_NoPendingOrOneBlockEarly() external {
        vm.expectRevert(IEtnaStakingRegistry.TopUpNotReady.selector);
        registry.activateTopUp(0);
        _deposit(7 ether);
        vm.roll(119);
        vm.expectRevert(IEtnaStakingRegistry.TopUpNotReady.selector);
        registry.activateTopUp(0);
        _assertPending(7 ether, 120);
        vm.roll(120);
        registry.activateTopUp(0);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE + 7 ether);
    }

    function test_topUp_ExitDisallowsDepositAndActivationButWithdrawsBothBalances() external {
        _deposit(7 ether);
        vm.prank(Alice);
        registry.requestExit(0);
        _fund(Alice, 1);
        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        vm.prank(Alice);
        registry.topUp(0, 1);
        vm.roll(120);
        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        registry.activateTopUp(0);
        _confirmExit(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Alice);
        registry.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), MIN_STAKE + 7 ether);
        _assertPending(0, 0);
        assertEq(registry.ownerOf(0), address(0));
        assertEq(_register(Bob, 0xC0B), 1, "bond 1");
        _assertPending(0, 0);
    }

    function test_topUp_FullRegistryStillAcceptsDepositWithoutAllocatingSlot() external {
        _fillRegistry(0);
        bytes32 root = registry.entriesRoot();
        _deposit(1 ether);
        assertEq(registry.entryCount(), 4096);
        assertEq(registry.bondCount(), 4096);
        assertEq(registry.entriesRoot(), root);
        _assertPending(1 ether, 120);
        (uint256 slot,) = registry.admissionThreshold();
        assertEq(slot, 1, "the pending deposit lifts slot 0 above the others");
    }

    function test_forfeit_UsesExecutionBalanceAndAllPenaltyGoesToSink() external {
        mockInbox.setInitialized(true);
        _deposit(10_000 ether);
        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(1, 110, 1, _forfeitedLeaf(0, 110));
        vm.expectEmit();
        emit IEtnaStakingRegistry.Forfeited(
            0, _key, keccak256("incident"), 11_000 ether, 1100 ether
        );
        _forfeit(0);
        assertEq(registry.entryAt(0).effStake, 0, "effective stake exhausted first");
        _assertPending(9900 ether, 120);
        assertEq(token.balanceOf(SLASH_SINK), 1100 ether);
        assertEq(token.balanceOf(Bob), 0, "no reporter bounty");
        assertTrue(registry.forfeited(_key));
        assertEq(registry.entryAt(0).exitEffectiveL1, 110);
    }

    function test_forfeit_PendingOnlyPrincipalStillRequiresOwnerToWithdraw() external {
        mockInbox.setInitialized(true);
        _deposit(10_000 ether);
        _forfeit(0);
        mockInbox.setActiveCommitteeSnapshot(110);
        registry.confirmExit(0);
        vm.roll(140);
        vm.expectRevert(IEtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.withdraw(0, Bob);
        vm.prank(Alice);
        registry.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), 9900 ether);
        _assertPending(0, 0);
        assertTrue(registry.forfeited(_key));
    }

    function test_forfeit_KeepsExistingConfirmationClockAndEarlierExit() external {
        mockInbox.setInitialized(true);
        vm.prank(Alice);
        registry.requestExit(0);
        mockInbox.setActiveCommitteeSnapshot(130);
        vm.roll(140);
        registry.confirmExit(0);
        vm.roll(150);
        _forfeit(0);
        assertEq(registry.entryAt(0).exitEffectiveL1, 130);
        assertEq(registry.exitConfirmedAtL1(0), 140);
        vm.roll(170);
        vm.prank(Alice);
        registry.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), 900 ether);
        assertTrue(registry.forfeited(_key), "withdrawal does not clear lifetime flag");
        assertEq(_register(Bob, 0xC0B), 1);
        assertTrue(registry.forfeited(_key), "reuse does not clear former key flag");
        assertFalse(registry.forfeited(_entryKey(registry, 1)), "the new bond gets its own flag");
    }

    function test_forfeit_RevertWhen_UnauthorizedUninitializedExpiredMismatchedOrReplayed()
        external
    {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(Bob);
        registry.forfeit(0, _key, 0, block.timestamp);
        vm.expectRevert(IEtnaStakingRegistry.InboxNotInitialized.selector);
        registry.forfeit(0, _key, 0, block.timestamp);
        mockInbox.setInitialized(true);
        vm.warp(1000);
        vm.expectRevert(IEtnaStakingRegistry.AuthorizationExpired.selector);
        registry.forfeit(0, _key, 0, 999);
        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        registry.forfeit(0, bytes32(uint256(_key) ^ 1), 0, 1000);
        registry.forfeit(0, _key, 0, 1000); // inclusive deadline
        vm.expectRevert(IEtnaStakingRegistry.AlreadyForfeited.selector);
        registry.forfeit(0, _key, keccak256("different incident"), 1000);
        assertEq(token.balanceOf(SLASH_SINK), 100 ether);
    }

    function test_forfeit_IncidentIdMayRepeatAcrossEntriesAndRecoveryDoesNotCancel() external {
        _register(Bob, 0xC0B);
        bytes32 secondKey = _entryKey(registry, 1);
        mockInbox.setInitialized(true);
        mockInbox.setRecoveryGeneration(10);
        mockInbox.forceExit(registry, 0, _key);
        _forfeit(0);
        registry.forfeit(1, secondKey, keccak256("incident"), block.timestamp);
        assertTrue(registry.forfeited(_key));
        assertTrue(registry.forfeited(secondKey));
        assertEq(token.balanceOf(SLASH_SINK), 200 ether);
    }

    function test_forfeit_WithdrawFirstRejectsAndForfeitFirstPaysOnlyRemainder() external {
        mockInbox.setInitialized(true);
        vm.prank(Alice);
        registry.requestExit(0);
        _confirmExit(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        uint256 snapshot = vm.snapshotState();
        vm.prank(Alice);
        registry.withdraw(0, Carol);
        vm.expectRevert(IEtnaStakingRegistry.BondWithdrawn.selector);
        registry.forfeit(0, _key, 0, block.timestamp);
        assertFalse(registry.forfeited(_key));
        vm.revertToState(snapshot);
        _forfeit(0);
        vm.prank(Alice);
        registry.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), 900 ether);
        assertEq(token.balanceOf(SLASH_SINK), 100 ether);
    }

    function test_slashDoubleSign_ConsumesDepositsMadeAfterEvidenceAndBlocksLaterForfeit()
        external
    {
        mockInbox.setInitialized(true);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _votes();
        _deposit(7 ether);
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);
        assertEq(token.balanceOf(Bob), 100.7 ether);
        assertEq(token.balanceOf(SLASH_SINK), 906.3 ether);
        assertEq(registry.entryAt(0).effStake, 0);
        _assertPending(0, 0);
        vm.expectRevert(IEtnaStakingRegistry.NothingToSlash.selector);
        registry.forfeit(0, _key, 0, block.timestamp);
        assertFalse(registry.forfeited(_key));
        vm.expectRevert(IEtnaStakingRegistry.TopUpNotAllowed.selector);
        vm.prank(Alice);
        registry.topUp(0, 1);
    }

    function test_slashDoubleSign_ForfeitFirstConsumesEntirePendingRemainder() external {
        mockInbox.setInitialized(true);
        _deposit(10_000 ether);
        _forfeit(0);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _votes();
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);
        _assertPending(0, 0);
        assertEq(token.balanceOf(Bob), 990 ether);
        assertEq(token.balanceOf(SLASH_SINK), 10_010 ether);
        assertTrue(registry.forfeited(_key));
    }

    function test_topUp_RevertWhen_TransferFailsRollsBackPendingAndCheckpoint() external {
        bytes32 root = registry.entriesRoot();
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(Alice);
        registry.topUp(0, 7 ether);
        _assertPending(0, 0);
        assertEq(registry.entriesRoot(), root);
        assertEq(registry.checkpointCount(), 1);
    }

    function test_mutations_RevertWhen_InboxLockedIncludingSlashAndDeposits() external {
        mockInbox.setInitialized(true);
        _fund(Alice, 1);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _votes();
        mockInbox.setInNonReentrant(true);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        vm.prank(Alice);
        registry.topUp(0, 1);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.activateTopUp(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.forfeit(0, _key, 0, block.timestamp);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.slashDoubleSign(0, a, b);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.register(hex"04", MIN_STAKE, hex"00");
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        registry.confirmExit(0);
        vm.expectRevert(IEtnaStakingRegistry.InboxLocked.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
        // Recovery's authorized Inbox-to-registry path remains usable under the Inbox lock.
        mockInbox.forceExit(registry, 0, _key);
        assertEq(registry.entryAt(0).exitEffectiveL1, block.number);
    }

    function test_topUp_RevertWhen_TokenCallbackMutatesExit() external {
        ReentrantERC20 reentrant = _useReentrant();
        reentrant.mint(Alice, 7 ether);
        vm.prank(Alice);
        reentrant.approve(address(registry), type(uint256).max);
        reentrant.armReentry(address(registry), abi.encodeCall(registry.confirmExit, (0)));
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Alice);
        registry.topUp(0, 7 ether);
        _assertPending(0, 0);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
        assertEq(reentrant.balanceOf(address(registry)), MIN_STAKE);
        assertEq(reentrant.balanceOf(Alice), 7 ether);
    }

    function test_topUp_RevertWhen_TokenCallbackCallsOtherRegistryMutation() external {
        ReentrantERC20 reentrant = _useReentrant();
        reentrant.mint(Alice, 7 ether);
        vm.prank(Alice);
        reentrant.approve(address(registry), type(uint256).max);
        bytes[] memory attacks = new bytes[](4);
        attacks[0] = abi.encodeCall(registry.requestExit, (0));
        attacks[1] = abi.encodeCall(registry.activateTopUp, (0));
        attacks[2] = abi.encodeCall(registry.withdraw, (0, Bob));
        attacks[3] = abi.encodeCall(registry.register, (hex"04", MIN_STAKE, hex"00"));
        for (uint256 i; i < attacks.length; ++i) {
            reentrant.armReentry(address(registry), attacks[i]);
            vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
            vm.prank(Alice);
            registry.topUp(0, 7 ether);
            _assertPending(0, 0);
            assertEq(registry.ownerOf(0), Alice);
            assertEq(registry.entryAt(0).exitEffectiveL1, type(uint48).max);
            assertEq(reentrant.balanceOf(Alice), 7 ether);
            assertEq(reentrant.balanceOf(address(registry)), MIN_STAKE);
        }
    }

    function test_withdraw_PendingPrincipalRollsBackOnTokenCallback() external {
        ReentrantERC20 reentrant = _useReentrant();
        reentrant.mint(Alice, 7 ether);
        vm.prank(Alice);
        registry.topUp(0, 7 ether);
        vm.prank(Alice);
        registry.requestExit(0);
        _confirmExit(0);
        uint256 confirmation = registry.exitConfirmedAtL1(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        bytes32 root = registry.entriesRoot();
        reentrant.armReentry(address(registry), abi.encodeCall(registry.confirmExit, (0)));
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Alice);
        registry.withdraw(0, Bob);
        assertEq(registry.ownerOf(0), Alice);
        assertEq(registry.exitConfirmedAtL1(0), confirmation);
        assertEq(registry.entriesRoot(), root);
        assertFalse(registry.bondAt(0).withdrawn);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
        _assertPending(7 ether, 130);
        assertEq(reentrant.balanceOf(address(registry)), MIN_STAKE + 7 ether);
        assertEq(reentrant.balanceOf(Bob), 0);
    }

    /// @dev Spec 4.1 vector 13a.m: an authorization naming an unissued id reverts, even with the
    /// key keccak256(abi.encode(0, 0)) that its default fields would hash to, and sets no flag.
    function test_forfeit_RevertWhen_UnknownBond() external {
        mockInbox.setInitialized(true);
        bytes32 defaultKey = keccak256(abi.encode(0, 0));
        uint256 sinkBefore = token.balanceOf(SLASH_SINK);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.forfeit(1, defaultKey, 0, block.timestamp);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.forfeit(type(uint256).max, _key, 0, block.timestamp);
        assertFalse(registry.forfeited(defaultKey));
        assertFalse(registry.forfeited(_key));
        assertEq(token.balanceOf(SLASH_SINK), sinkBefore);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
    }

    /// @dev An authorization naming bond 0 cannot reach bond 1, which now holds bond 0's
    /// emptied slot: bond 0 is withdrawn, and bond 0's key does not match bond 1 (spec 4.4
    /// vector 16.d).
    function test_forfeit_RevertWhen_BondWithdrawnOrKeyOfAnotherBond() external {
        _withdrawBond(0);
        assertEq(_register(Bob, 0xC0B), 1);
        mockInbox.setInitialized(true);
        vm.expectRevert(IEtnaStakingRegistry.BondWithdrawn.selector);
        registry.forfeit(0, _key, 0, block.timestamp);
        vm.expectRevert(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        registry.forfeit(1, _key, 0, block.timestamp);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
        assertFalse(registry.forfeited(_entryKey(registry, 1)));
    }

    /// @dev Forfeiting a displaced bond takes its penalty and sets the lifetime flag without
    /// writing a checkpoint (spec 4.4 vectors 4.g and 11.e).
    function test_forfeit_DisplacedBondWritesNoCheckpoint() external {
        _fillRegistry(1);
        vm.roll(block.number + 1);
        _registerWith(Bob, 0xC0B, MIN_STAKE + 1);
        assertFalse(registry.bondAt(0).holdsSlot, "bond 0 displaced");
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();
        mockInbox.setInitialized(true);

        vm.roll(block.number + 1);
        _forfeit(0);
        assertTrue(registry.forfeited(_key), "flag set");
        assertEq(registry.bondAt(0).entry.effStake, 900 ether, "penalty taken");
        assertEq(token.balanceOf(SLASH_SINK), 100 ether, "penalty to the sink");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        assertEq(registry.entriesRoot(), root, "root");
    }

    function test_topUp_RevertWhen_ZeroEffectiveStakeEvenWithoutExit() external {
        // Bond 0's record: the `bonds` mapping at R + 6, its entry's effStake in the second word.
        uint256 bond = uint256(keccak256(abi.encode(0, REGISTRY_BASE + 6)));
        vm.store(address(registry), bytes32(bond + 1), bytes32(0));
        vm.expectRevert(IEtnaStakingRegistry.TopUpNotAllowed.selector);
        vm.prank(Alice);
        registry.topUp(0, 1);
        _assertPending(0, 0);
    }

    function test_forfeit_RevertWhen_TokenCallbackRollsBackFlagExitPrincipalAndRoot() external {
        ReentrantERC20 reentrant = _useReentrant();
        mockInbox.setInitialized(true);
        bytes32 root = registry.entriesRoot();
        reentrant.armReentry(address(registry), abi.encodeCall(registry.confirmExit, (0)));
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        registry.forfeit(0, _key, 0, block.timestamp);
        assertFalse(registry.forfeited(_key));
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
        assertEq(registry.entryAt(0).exitEffectiveL1, type(uint48).max);
        assertEq(registry.entriesRoot(), root);
        assertEq(registry.checkpointCount(), 1);
        assertEq(reentrant.balanceOf(SLASH_SINK), 0);
    }

    function test_forfeit_RevertWhen_TokenTransferFails() external {
        mockInbox.setInitialized(true);
        // A failed transfer must revert every earlier write, including the lifetime flag.
        vm.mockCallRevert(
            address(token),
            abi.encodeWithSignature("transfer(address,uint256)", SLASH_SINK, 100 ether),
            abi.encodeWithSignature("Error(string)", "sink rejected")
        );
        bytes32 root = registry.entriesRoot();
        vm.expectRevert("sink rejected");
        registry.forfeit(0, _key, 0, block.timestamp);
        assertFalse(registry.forfeited(_key));
        assertEq(registry.entriesRoot(), root);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
    }

    function _deposit(uint256 _amount) private {
        _fund(Alice, _amount);
        vm.prank(Alice);
        registry.topUp(0, _amount);
    }

    function _forfeit(uint256 _bondId) private {
        registry.forfeit(
            _bondId, _entryKey(registry, _bondId), keccak256("incident"), block.timestamp
        );
    }

    function _assertPending(uint256 _amount, uint48 _ready) private view {
        (uint256 amount, uint48 ready) = registry.topUpOf(0);
        assertEq(amount, _amount, "pending principal");
        assertEq(ready, _ready, "readiness");
    }

    function _leafWithStake(uint256 _stake) private view returns (bytes32) {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        entry.effStake = _stake;
        return LibEntriesTree.leaf(0, entry);
    }

    function _forfeitedLeaf(uint256 _stake, uint48 _exit) private view returns (bytes32) {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        entry.effStake = _stake;
        entry.exitEffectiveL1 = _exit;
        return LibEntriesTree.leaf(0, entry);
    }

    function _votes()
        private
        view
        returns (IEtnaStakingRegistry.Vote memory a_, IEtnaStakingRegistry.Vote memory b_)
    {
        a_.voteType = 2;
        a_.height = 1000;
        a_.round = 3;
        a_.timestampSeconds = 1_700_000_000;
        a_.blockHash = keccak256("block A");
        a_.partsTotal = 1;
        a_.partsHash = keccak256("parts A");
        b_.voteType = 2;
        b_.height = 1000;
        b_.round = 3;
        b_.timestampSeconds = 1_700_000_000;
        b_.partsTotal = 1;
        b_.partsHash = keccak256("parts A");
        b_.blockHash = keccak256("block B");
        bytes memory chainId = LibCometVote.chainId(
            LibCometVote.chainDomain(block.chainid, L2_CHAIN_ID, address(mockInbox), 0)
        );
        a_ = EtnaTestKeys.signVote(_PK, a_, chainId);
        b_ = EtnaTestKeys.signVote(_PK, b_, chainId);
    }

    function _useReentrant() private returns (ReentrantERC20 reentrant_) {
        reentrant_ = new ReentrantERC20();
        registry = _deployRegistry(address(reentrant_), address(mockInbox));
        reentrant_.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        reentrant_.approve(address(registry), type(uint256).max);
        bytes memory pop = EtnaTestKeys.popSig(_PK, registry, Alice);
        bytes memory key = EtnaTestKeys.publicKey(_PK);
        vm.prank(Alice);
        registry.register(key, MIN_STAKE, pop);
        _key = _entryKey(registry, 0);
        vm.roll(block.number + ACTIVATION_DELAY);
    }
}
