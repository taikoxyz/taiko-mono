// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLockHarness } from "./EtnaInboxLockHarness.sol";
import { MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @notice A registry stand-in that records, while `recover` forces an exit, whether the Inbox
/// holds its reentrancy lock and what re-entries into `land` and `recover` return.
contract LockProbeRegistry {
    function inNonReentrant() external pure returns (bool) {
        return false;
    }
    bytes public landCall;
    bytes public recoverCall;
    uint256 public forceExits;
    bool public lockHeld;
    bool public landSucceeded;
    bytes public landError;
    bool public recoverSucceeded;
    bytes public recoverError;

    function setReentryCalls(bytes calldata _landCall, bytes calldata _recoverCall) external {
        landCall = _landCall;
        recoverCall = _recoverCall;
    }

    function forceExit(uint256, bytes32) external {
        ++forceExits;
        lockHeld = EssentialContract(msg.sender).inNonReentrant();
        (landSucceeded, landError) = msg.sender.call(landCall);
        (recoverSucceeded, recoverError) = msg.sender.call(recoverCall);
    }
}

/// @title EtnaInboxRecoverTest
/// @notice Governance recovery (spec 8 steps 1-4, 8.3, 8.4) and landing across generations.
/// @dev The Lean recovery examples (`Etna.Design.Examples`) run on this suite's state: `world`
/// is the state after `setUp` (c = 0, queue head 0 and tail 3, Alice's bond 0 and Bob's bond 1)
/// and `origin` is R = 11 at timestamp 61, the L1 block and time `setUp` ends at. Landings follow
/// the base's committed chain up to the recovery origin 12; above it the chain is the one
/// generation 1 rebuilds, whose blocks differ from the generation-0 suffix the recovery
/// discards.
contract EtnaInboxRecoverTest is EtnaLandTestBase {
    /// @dev Bob's consensus private key; Alice registered `VALIDATOR_PK` before initialization.
    uint256 private constant _BOB_PK = 0xB0B;

    /// @dev keccak256(""), the txHash of a blanked forced inclusion.
    bytes32 private constant _BLANK_TX_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /// @dev The Lean recovery origin: R = 11 at timestamp 61, then R = 12 at 62 for a second
    /// recovery at the same c.
    uint256 private constant _LEAN_R = 11;
    uint256 private constant _LEAN_R_TIMESTAMP = 61;
    uint256 private constant _LEAN_R2 = 12;
    uint256 private constant _LEAN_R2_TIMESTAMP = 62;

    /// @dev The checkpoint the landing-after-recovery tests recover at.
    uint256 private constant _RECOVERY_C = 12;

    /// @dev The registry's no-exit sentinel, 2^48 - 1.
    uint256 private constant _NO_EXIT = 2 ** 48 - 1;

    uint256 private constant _TWO_POW_48 = 2 ** 48;

    function setUp() public override {
        super.setUp();
        assertEq(block.number, _LEAN_R, "setUp ends at R");
        vm.warp(_LEAN_R_TIMESTAMP);
        assertEq(_registerValidator(registry, Bob, _BOB_PK), 1, "Bob's bond 1");
    }

    /// @dev Up to the recovery origin the base's committed chain; above it the chain generation 1
    /// rebuilds: EL hash 1100 + x and Comet hash 1200 + x instead of 100 + x and 200 + x.
    function _cut(uint256 _x)
        internal
        pure
        override
        returns (bytes32 el_, bytes32 comet_, uint256 head_)
    {
        if (_x <= _RECOVERY_C) return super._cut(_x);
        return (bytes32(1100 + _x), bytes32(1200 + _x), _x / K);
    }

    // ---------------------------------------------------------------
    // The transition
    // ---------------------------------------------------------------

    /// @dev Lean `recovery_fixes_origin`: recovery at c = 12, R = 50 and timestamp 1000 writes
    /// origins(1) = (12, 50, 1000) and moves the generation to 1; both views read the new origin
    /// and generation 0's origin is kept.
    function test_recover_IncrementsGenerationAndWritesOrigin() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.Origin memory origin0 = _inbox().origins(0);
        vm.roll(50);
        vm.warp(1000);

        // `_recover` expects `Recovered(1, 12, 50, 1000, [], [])`.
        _recover(0, 12, _noExclusions(), _noIndices());

        assertEq(_inbox().recoveryGeneration(), 1, "generation");
        assertEq(_inboxWord(RECOVERY_GENERATION_SLOT), bytes32(uint256(1)), "slot 268");
        _assertOrigin(1, 12, 50, 1000);
        assertEq(_inbox().generationStartHeight(), 12, "generationStartHeight");
        assertEq(_inbox().recoverySnapshot(), 50, "recoverySnapshot");
        _assertOrigin(0, origin0.startHeight, origin0.l1BlockNumber, origin0.l1Timestamp);
        _assertOrigin(2, 0, 0, 0);
    }

    /// @dev Lean `recovery_preserves_settled_prefix`: with an exclusion and a blanking, recovery
    /// keeps the checkpoint, every landing record, the queue pointers, the snapshot, the
    /// SignalService checkpoints, the genesis words and the Inbox's ETH. The only Inbox slots it
    /// writes are 268, origins(1) and the blanked entry's txHash.
    function test_recover_PreservesSettledState() external {
        _land(0, 6);
        _land(6, 12);
        uint256[] memory fiToClear = _indices(2);
        uint256 balance = inboxProxy.balance;
        bytes32[] memory settled = _settledWords();
        assertGt(balance, 0, "the forced inclusion fees");

        vm.startStateDiffRecording();
        _recover(0, 12, _exclusions(1, _BOB_PK), fiToClear);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        bytes32[] memory settledAfter = _settledWords();
        for (uint256 i; i < settled.length; ++i) {
            assertEq(settledAfter[i], settled[i], "settled state");
        }
        assertEq(inboxProxy.balance, balance, "ETH");
        _assertCheckpoint(12, bytes32(uint256(112)));
        _assertQueue(2, LEAN_FORCED_INCLUSIONS);
        assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "snapshot");

        uint256 writes;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.StorageAccess[] memory storageAccesses = accesses[i].storageAccesses;
            for (uint256 j; j < storageAccesses.length; ++j) {
                VmSafe.StorageAccess memory s = storageAccesses[j];
                if (s.account != inboxProxy || !s.isWrite || s.reverted) continue;
                uint256 slot = uint256(s.slot);
                assertTrue(
                    slot == RECOVERY_GENERATION_SLOT || slot == 292 || slot == _originSlot(1)
                        || slot == _originSlot(1) + 1 || slot == _originSlot(1) + 2
                        || slot == _queueSlot(2),
                    string.concat("unexpected Inbox write to slot ", vm.toString(s.slot))
                );
                ++writes;
            }
        }
        assertEq(writes, 6, "six Inbox writes including recovery nonce");
    }

    /// @dev Lean `exclusion_and_fi_clear_atomic`: excluding Bob and blanking entry 0 in one call.
    /// Bob's exit moves to R = 11 with his stake, owner and activation kept and no confirmation;
    /// entry 0's txHash becomes keccak256("") with its timestamp and L1 block kept; Alice and the
    /// other entries are untouched. `Recovered` carries both complete lists.
    function test_recover_ExcludesAndBlanksAtomically() external {
        IEtnaStakingRegistry.Entry memory alice = registry.entryAt(0);
        IEtnaStakingRegistry.Entry memory bob = registry.entryAt(1);
        assertEq(bob.exitEffectiveL1, _NO_EXIT, "Bob has no exit");
        IEtnaInbox.ForcedInclusion memory entry0 = _inbox().getForcedInclusion(0);
        IEtnaInbox.ForcedInclusion memory entry1 = _inbox().getForcedInclusion(1);
        IEtnaInbox.ForcedInclusion memory entry2 = _inbox().getForcedInclusion(2);
        assertNotEq(entry0.txHash, _BLANK_TX_HASH, "entry 0 holds a transaction");
        uint256 staked = taikoToken.balanceOf(address(registry));

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.ExitForced(1, uint48(_LEAN_R));
        // `_recover` expects `Recovered(1, 0, 11, 61, [(1, Bob's key)], [0])`.
        _recover(0, 0, _exclusions(1, _BOB_PK), _indices(0));

        bob.exitEffectiveL1 = uint48(_LEAN_R);
        _assertEntry(1, bob);
        _assertEntry(0, alice);
        assertEq(registry.ownerOf(1), Bob, "Bob's owner");
        assertEq(registry.exitConfirmedAtL1(1), 0, "not confirmed");
        assertEq(taikoToken.balanceOf(address(registry)), staked, "no stake moved");

        IEtnaInbox.ForcedInclusion memory blanked = _inbox().getForcedInclusion(0);
        assertEq(blanked.txHash, _BLANK_TX_HASH, "entry 0 blanked");
        assertEq(blanked.txHash, keccak256(""), "keccak256 of the empty string");
        assertEq(blanked.timestamp, entry0.timestamp, "entry 0 timestamp");
        assertEq(blanked.l1Block, entry0.l1Block, "entry 0 L1 block");
        assertEq(_inboxWord(_queueSlot(0)), _BLANK_TX_HASH, "slot 280 entry 0 word 1");
        _assertForcedInclusion(1, entry1);
        _assertForcedInclusion(2, entry2);
        _assertQueue(0, LEAN_FORCED_INCLUSIONS);
    }

    /// @dev Lean `empty_election_is_not_an_inbox_check`: excluding every entry still executes,
    /// leaving no entry eligible at R. Another recovery at the same c, with R = 12, can follow.
    function test_recover_ExcludingEveryoneStillExecutes() external {
        IEtnaInbox.Exclusion[] memory everyone = new IEtnaInbox.Exclusion[](2);
        everyone[0] = _exclusion(0, VALIDATOR_PK);
        everyone[1] = _exclusion(1, _BOB_PK);

        _recover(0, 0, everyone, _noIndices());
        assertEq(registry.entryAt(0).exitEffectiveL1, _LEAN_R, "Alice exits at R");
        assertEq(registry.entryAt(1).exitEffectiveL1, _LEAN_R, "Bob exits at R");
        _assertOrigin(1, 0, _LEAN_R, _LEAN_R_TIMESTAMP);

        vm.roll(_LEAN_R2);
        vm.warp(_LEAN_R2_TIMESTAMP);
        _recover(1, 0, _noExclusions(), _noIndices());
        _assertOrigin(2, 0, _LEAN_R2, _LEAN_R2_TIMESTAMP);
        assertEq(_inbox().recoveryGeneration(), 2, "generation 2");
    }

    // ---------------------------------------------------------------
    // Authorization and replay
    // ---------------------------------------------------------------

    /// @dev Lean `recover_needs_owner_and_expected_values` (owner = false): only the owner, checked
    /// before the arguments. A pending owner cannot call until it accepts, and then the previous
    /// owner cannot.
    function test_recover_RevertWhen_NotOwner() external {
        bytes memory notOwner =
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner");
        IEtnaInbox.Exclusion[] memory none = _noExclusions();
        uint256[] memory noIndices = _noIndices();

        _expectRecoverRevert(Bob, 0, 0, none, noIndices, notOwner);
        _expectRecoverRevert(Alice, 0, 0, none, noIndices, notOwner);
        _expectRecoverRevert(address(registry), 0, 0, none, noIndices, notOwner);
        _expectRecoverRevert(Bob, 5, 7, _exclusions(1, _BOB_PK), _indices(9), notOwner);

        _inbox().transferOwnership(Carol);
        _expectRecoverRevert(Carol, 0, 0, none, noIndices, notOwner);
        vm.prank(Carol);
        _inbox().acceptOwnership();
        _expectRecoverRevert(address(this), 0, 0, none, noIndices, notOwner);

        // `_recover` calls as the current owner, Carol.
        _recover(0, 0, none, noIndices);
        assertEq(_inbox().recoveryGeneration(), 1, "Carol recovered");
    }

    /// @dev Lean `recover_needs_owner_and_expected_values` (generation 1 on generation 0): the
    /// expected generation must equal the current one, below or above it, and is checked before
    /// the checkpoint.
    function test_recover_RevertWhen_ExpectedGenerationStale() external {
        IEtnaInbox.Exclusion[] memory none = _noExclusions();
        uint256[] memory noIndices = _noIndices();
        bytes4 mismatch = IEtnaInbox.GenerationMismatch.selector;

        _expectRecoverRevert(1, 0, none, noIndices, mismatch);
        _expectRecoverRevert(type(uint48).max, 0, none, noIndices, mismatch);
        _expectRecoverRevert(1, 6, none, noIndices, mismatch);

        _recover(0, 0, none, noIndices);
        _expectRecoverRevert(0, 0, none, noIndices, mismatch);
        _expectRecoverRevert(2, 0, none, noIndices, mismatch);
    }

    /// @dev Lean `landing_voids_old_authorization`: a recovery authorized at c = 0 cannot execute
    /// once a landing moves c to 6, nor can one naming a c above it; the checkpoint is checked
    /// before the lists. An authorization at the new c executes.
    function test_recover_RevertWhen_LandingMovedCheckpoint() external {
        IEtnaInbox.Exclusion[] memory none = _noExclusions();
        uint256[] memory noIndices = _noIndices();
        bytes4 mismatch = IEtnaInbox.CheckpointMismatch.selector;
        _land(0, 6);

        _expectRecoverRevert(0, 0, none, noIndices, mismatch);
        _expectRecoverRevert(0, 12, none, noIndices, mismatch);
        _expectRecoverRevert(0, 0, _unsortedExclusions(), _indices(2, 1), mismatch);

        _recover(0, 6, none, noIndices);
        _assertOrigin(1, 6, _LEAN_R, _LEAN_R_TIMESTAMP);
    }

    /// @dev Lean `repeated_recovery_at_same_c_needs_new_generation`: replaying an executed
    /// recovery fails on its stale generation; one authorized for generation 1 at the same c
    /// writes origins(2) and keeps origins(1).
    function test_recover_ReplayNeedsNewGeneration() external {
        IEtnaInbox.Exclusion[] memory none = _noExclusions();
        uint256[] memory noIndices = _noIndices();

        _recover(0, 0, none, noIndices);
        _assertOrigin(1, 0, _LEAN_R, _LEAN_R_TIMESTAMP);

        vm.roll(_LEAN_R2);
        vm.warp(_LEAN_R2_TIMESTAMP);
        _expectRecoverRevert(0, 0, none, noIndices, IEtnaInbox.GenerationMismatch.selector);

        _recover(1, 0, none, noIndices);
        assertEq(_inbox().recoveryGeneration(), 2, "generation 2");
        _assertOrigin(2, 0, _LEAN_R2, _LEAN_R2_TIMESTAMP);
        _assertOrigin(1, 0, _LEAN_R, _LEAN_R_TIMESTAMP);
        assertEq(_inbox().generationStartHeight(), 0, "same start height");
        assertEq(_inbox().recoverySnapshot(), _LEAN_R2, "the latest R");
    }

    // ---------------------------------------------------------------
    // Lists
    // ---------------------------------------------------------------

    /// @dev Lean `stale_exclusion_identity_rejected` and `released_slot_exclusion_rejected`: the
    /// registry checks each exclusion's entry key inside `forceExit` and rejects an exclusion whose
    /// key no longer matches, an unknown bond and a released slot (under the occupant's old key or
    /// the all-zero entry's key). Each list starts with a valid exclusion of Alice and lists a
    /// blanking: the whole call reverts, so Alice's exit, the queue entry and the generation stay
    /// as they were.
    function test_recover_RevertWhen_ExclusionKeyStaleOrReleased() external {
        IEtnaInbox.Exclusion[] memory list = new IEtnaInbox.Exclusion[](2);
        list[0] = _exclusion(0, VALIDATOR_PK);

        list[1] = _exclusion(1, VALIDATOR_PK);
        _expectRecoverRevert(
            0, 0, list, _indices(0), IEtnaStakingRegistry.EntryKeyMismatch.selector
        );
        list[1].entryKey = bytes32(uint256(999));
        _expectRecoverRevert(
            0, 0, list, _indices(0), IEtnaStakingRegistry.EntryKeyMismatch.selector
        );
        list[1] = _exclusion(2, _BOB_PK);
        _expectRecoverRevert(0, 0, list, _indices(0), IEtnaStakingRegistry.UnknownBond.selector);

        // Bob exits, a landing's committee covers the exit, and he withdraws: slot 1 is released.
        vm.prank(Bob);
        registry.requestExit(1);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        input.activeCommitteeSnapshot = registry.entryAt(1).exitEffectiveL1;
        _land(input, new bytes32[](0));
        registry.confirmExit(1);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Bob);
        registry.withdraw(1, Bob);
        assertEq(registry.entryAt(1).ckPrefix, 0, "slot 1 released");

        list[1] = _exclusion(1, _BOB_PK);
        _expectRecoverRevert(0, 6, list, _indices(1), IEtnaStakingRegistry.SlotReleased.selector);
        list[1].entryKey = keccak256(abi.encode(0, 0));
        _expectRecoverRevert(0, 6, list, _indices(1), IEtnaStakingRegistry.SlotReleased.selector);
        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT, "Alice keeps no exit");

        _recover(0, 6, _exclusions(0, VALIDATOR_PK), _indices(1));
        assertEq(registry.entryAt(0).exitEffectiveL1, block.number, "Alice excluded");
    }

    /// @dev Both lists must be strictly increasing: equal or descending neighbours, anywhere in
    /// the list, revert before any exclusion reaches the registry. Exclusions are checked before
    /// the indices, and an index list's order before its range.
    function test_recover_RevertWhen_ListsNotStrictlySorted() external {
        vm.expectCall(
            address(registry), abi.encodePacked(IEtnaStakingRegistry.forceExit.selector), 0
        );
        IEtnaInbox.Exclusion memory alice = _exclusion(0, VALIDATOR_PK);
        IEtnaInbox.Exclusion memory bob = _exclusion(1, _BOB_PK);
        IEtnaInbox.Exclusion[] memory list = new IEtnaInbox.Exclusion[](2);
        bytes4 exclusionsNotSorted = IEtnaInbox.ExclusionsNotSorted.selector;
        bytes4 indicesNotSorted = IEtnaInbox.FiToClearNotSorted.selector;

        (list[0], list[1]) = (alice, alice);
        _expectRecoverRevert(0, 0, list, _noIndices(), exclusionsNotSorted);
        (list[0], list[1]) = (bob, bob);
        _expectRecoverRevert(0, 0, list, _noIndices(), exclusionsNotSorted);
        _expectRecoverRevert(0, 0, _unsortedExclusions(), _noIndices(), exclusionsNotSorted);
        IEtnaInbox.Exclusion[] memory three = new IEtnaInbox.Exclusion[](3);
        (three[0], three[1], three[2]) = (alice, bob, bob);
        _expectRecoverRevert(0, 0, three, _noIndices(), exclusionsNotSorted);

        _expectRecoverRevert(0, 0, _noExclusions(), _indices(1, 1), indicesNotSorted);
        _expectRecoverRevert(0, 0, _noExclusions(), _indices(2, 1), indicesNotSorted);
        _expectRecoverRevert(0, 0, _noExclusions(), _indices(0, 2, 2), indicesNotSorted);
        _expectRecoverRevert(0, 0, _noExclusions(), _indices(5, 3), indicesNotSorted);

        _expectRecoverRevert(0, 0, _unsortedExclusions(), _indices(2, 1), exclusionsNotSorted);
        _expectRecoverRevert(0, 0, three, _indices(3), exclusionsNotSorted);
    }

    /// @dev Every index to blank must be pending, in [head, tail): the tail itself, indices far
    /// beyond it and, once a landing consumed entry 0, that entry are rejected before any
    /// exclusion reaches the registry. [head, tail - 1] is accepted.
    function test_recover_RevertWhen_FiIndexOutsideHeadTail() external {
        vm.expectCall(
            address(registry), abi.encodePacked(IEtnaStakingRegistry.forceExit.selector), 0
        );
        IEtnaInbox.Exclusion[] memory bob = _exclusions(1, _BOB_PK);
        bytes4 outOfRange = IEtnaInbox.FiIndexOutOfRange.selector;
        _assertQueue(0, 3);

        _expectRecoverRevert(0, 0, bob, _indices(3), outOfRange);
        _expectRecoverRevert(0, 0, bob, _indices(0, 3), outOfRange);
        _expectRecoverRevert(0, 0, bob, _indices(_TWO_POW_48), outOfRange);
        _expectRecoverRevert(0, 0, bob, _indices(type(uint256).max), outOfRange);

        _land(0, 6);
        _assertQueue(1, 3);
        _expectRecoverRevert(0, 6, bob, _indices(0), outOfRange);
        _expectRecoverRevert(0, 6, bob, _indices(0, 1), outOfRange);

        IEtnaInbox.ForcedInclusion memory consumed = _inbox().getForcedInclusion(0);
        _recover(0, 6, _noExclusions(), _indices(1, 2));
        assertEq(_inbox().getForcedInclusion(1).txHash, _BLANK_TX_HASH, "entry 1 blanked");
        assertEq(_inbox().getForcedInclusion(2).txHash, _BLANK_TX_HASH, "entry 2 blanked");
        _assertForcedInclusion(0, consumed);
    }

    // ---------------------------------------------------------------
    // 48-bit limits and the written origin
    // ---------------------------------------------------------------

    /// @dev The new generation must fit 48 bits: from 2^48 - 2 recovery reaches 2^48 - 1 and
    /// writes its origin; from there it reverts, lists included, with nothing written.
    function test_recover_RevertWhen_GenerationWouldOverflow() external {
        uint48 last = type(uint48).max;
        _storeInboxWord(RECOVERY_GENERATION_SLOT, bytes32(uint256(last - 1)));

        _recover(last - 1, 0, _noExclusions(), _noIndices());
        assertEq(_inbox().recoveryGeneration(), last, "generation 2^48 - 1");
        _assertOrigin(last, 0, _LEAN_R, _LEAN_R_TIMESTAMP);

        bytes4 overflow = IEtnaInbox.ValueOverflow.selector;
        _expectRecoverRevert(last, 0, _noExclusions(), _noIndices(), overflow);
        _expectRecoverRevert(last, 0, _exclusions(1, _BOB_PK), _indices(0), overflow);
        _assertOrigin(_TWO_POW_48, 0, 0, 0);
    }

    /// @dev Origin timestamps must fit 48 bits: at 2^48 recovery reverts with nothing written,
    /// including the exclusion and the blanking it lists; at 2^48 - 1 it executes.
    function test_recover_RevertWhen_TimestampOverflows48Bits() external {
        vm.warp(_TWO_POW_48);
        _expectRecoverRevert(
            0, 0, _exclusions(1, _BOB_PK), _indices(0), IEtnaInbox.ValueOverflow.selector
        );
        assertEq(registry.entryAt(1).exitEffectiveL1, _NO_EXIT, "Bob keeps no exit");

        vm.warp(_TWO_POW_48 - 1);
        _recover(0, 0, _exclusions(1, _BOB_PK), _indices(0));
        _assertOrigin(1, 0, _LEAN_R, _TWO_POW_48 - 1);
    }

    /// @dev R must fit 48 bits: at block 2^48 recovery reverts. At 2^48 - 1 its own bound passes,
    /// but the registry stores no L1 block at its no-exit sentinel, so an exclusion reverts
    /// `InvalidEventBlock` with nothing written; without one recovery executes.
    function test_recover_RevertWhen_L1BlockOverflows48Bits() external {
        vm.roll(_TWO_POW_48);
        _expectRecoverRevert(0, 0, _noExclusions(), _indices(0), IEtnaInbox.ValueOverflow.selector);

        vm.roll(_NO_EXIT);
        _expectRecoverRevert(
            0,
            0,
            _exclusions(1, _BOB_PK),
            _indices(0),
            IEtnaStakingRegistry.InvalidEventBlock.selector
        );
        _recover(0, 0, _noExclusions(), _indices(0));
        _assertOrigin(1, 0, _NO_EXIT, _LEAN_R_TIMESTAMP);
    }

    /// @dev Before `init` the proxy on the `EtnaInbox` implementation rejects the owner's
    /// recovery, lists included, and nothing is written in the Inbox or the registry.
    function test_recover_RevertWhen_NotInitialized() external {
        _deployFreshInbox(false);
        _inbox().upgradeTo(address(inboxImpl));
        assertFalse(_inbox().isInitialized(), "not initialized");
        uint256 checkpoints = registry.checkpointCount();
        bytes32 root = registry.entriesRoot();

        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox()
            .recover(
                0,
                0,
                uint256(vm.load(inboxProxy, bytes32(uint256(292)))),
                type(uint256).max,
                _noExclusions(),
                _noIndices()
            );
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox()
            .recover(
                0,
                0,
                uint256(vm.load(inboxProxy, bytes32(uint256(292)))),
                type(uint256).max,
                _exclusions(0, VALIDATOR_PK),
                _indices(0)
            );

        for (uint256 slot = 251; slot < 301; ++slot) {
            assertEq(_inboxWord(slot), 0, string.concat("slot ", vm.toString(slot)));
        }
        for (uint256 w; w < 3; ++w) {
            assertEq(_inboxWord(_originSlot(1) + w), 0, "origins(1)");
        }
        assertEq(registry.entryAt(0).exitEffectiveL1, _NO_EXIT, "no exit forced");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        assertEq(registry.entriesRoot(), root, "root");
    }

    // ---------------------------------------------------------------
    // Lock and calls
    // ---------------------------------------------------------------

    /// @dev `recover` and `land` share one lock (spec 8.3): while the harness holds it, re-entering
    /// either reverts `REENTRANT_CALL`. The proxy is made its own owner so its re-entry into
    /// `recover` passes `onlyOwner` and reaches the lock. Outside the lock both execute.
    function test_recover_SharesTheLandLock() external {
        _inbox().upgradeTo(address(new EtnaInboxLockHarness(_defaultConfig())));
        _inbox().transferOwnership(inboxProxy);
        vm.prank(inboxProxy);
        _inbox().acceptOwnership();
        assertEq(_inbox().owner(), inboxProxy, "the proxy owns itself");

        bytes memory reentrant = abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector);
        (bool ok, bytes memory ret) = EtnaInboxLockHarness(inboxProxy)
            .lockedCall(
                inboxProxy,
                abi.encodeCall(
                    IEtnaInbox.recover, (0, 0, 0, type(uint256).max, _noExclusions(), _noIndices())
                )
            );
        assertFalse(ok, "recover under the lock");
        assertEq(ret, reentrant, "recover: REENTRANT_CALL");

        (ok, ret) = EtnaInboxLockHarness(inboxProxy)
            .lockedCall(
                inboxProxy, abi.encodeCall(IEtnaInbox.land, (_input(0, 6), new bytes32[](0), PROOF))
            );
        assertFalse(ok, "land under the lock");
        assertEq(ret, reentrant, "land: REENTRANT_CALL");
        assertFalse(_inbox().inNonReentrant(), "released");
        assertEq(_inbox().recoveryGeneration(), 0, "generation kept");
        _assertCheckpoint(0, bytes32(uint256(100)));

        _land(0, 6);
        _recover(0, 6, _noExclusions(), _noIndices());
        assertEq(_inbox().recoveryGeneration(), 1, "recovered outside the lock");
    }

    /// @dev `recover` holds that lock while it calls the registry: a registry stand-in sees it held
    /// and its re-entries into `land` and `recover` both revert `REENTRANT_CALL`. The stand-in is
    /// made the owner, so it also starts the recovery and its re-entry into `recover` passes
    /// `onlyOwner` and reaches the lock.
    function test_recover_HoldsTheLockWhileCallingTheRegistry() external {
        LockProbeRegistry probe = new LockProbeRegistry();
        IEtnaInbox.Config memory config = _defaultConfig();
        config.stakingRegistry = address(probe);
        _inbox().upgradeTo(address(_newInboxImpl(config)));
        _inbox().transferOwnership(address(probe));
        vm.prank(address(probe));
        _inbox().acceptOwnership();
        probe.setReentryCalls(
            abi.encodeCall(IEtnaInbox.land, (_input(0, 6), new bytes32[](0), PROOF)),
            abi.encodeCall(
                IEtnaInbox.recover, (0, 0, 0, type(uint256).max, _noExclusions(), _noIndices())
            )
        );

        _recover(0, 0, _exclusions(0, VALIDATOR_PK), _noIndices());

        bytes memory reentrant = abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector);
        assertEq(probe.forceExits(), 1, "one exclusion");
        assertTrue(probe.lockHeld(), "lock held while forcing the exit");
        assertFalse(probe.landSucceeded(), "land re-entry rejected");
        assertEq(probe.landError(), reentrant, "land: REENTRANT_CALL");
        assertFalse(probe.recoverSucceeded(), "recover re-entry rejected");
        assertEq(probe.recoverError(), reentrant, "recover: REENTRANT_CALL");
        assertFalse(_inbox().inNonReentrant(), "released after the recovery");
        assertEq(_inbox().recoveryGeneration(), 1, "one generation");
    }

    /// @dev `recover` calls nothing but the fixed registry's `forceExit`, once per exclusion in
    /// list order, and sends no ETH; it never calls the SignalService or the
    /// verifier.
    function test_recover_CallsOnlyTheRegistry() external {
        IEtnaInbox.Exclusion[] memory everyone = new IEtnaInbox.Exclusion[](2);
        everyone[0] = _exclusion(0, VALIDATOR_PK);
        everyone[1] = _exclusion(1, _BOB_PK);
        address registryImpl = registry.impl();

        vm.startStateDiffRecording();
        _inbox()
            .recover(
                0,
                0,
                uint256(vm.load(inboxProxy, bytes32(uint256(292)))),
                type(uint256).max,
                everyone,
                _indices(0)
            );
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 forceExits;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.AccountAccess memory a = accesses[i];
            if (!_isCall(a.kind) || a.account == address(vm)) continue;
            assertEq(a.value, 0, "no ETH sent");
            if (a.account == inboxProxy) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.Call), "Inbox entry");
                assertEq(a.accessor, address(this), "called by the owner");
            } else if (a.account == address(inboxImpl)) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.DelegateCall), "Inbox impl");
            } else if (a.account == address(registry)) {
                assertEq(a.accessor, inboxProxy, "called by the Inbox");
                if (a.kind == VmSafe.AccountAccessKind.StaticCall) {
                    assertEq(
                        a.data,
                        abi.encodeWithSignature("inNonReentrant()"),
                        "reciprocal registry lock check"
                    );
                    continue;
                }
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.Call), "registry forceExit");
                IEtnaInbox.Exclusion memory x = everyone[forceExits++];
                assertEq(
                    a.data,
                    abi.encodeCall(IEtnaStakingRegistry.forceExit, (x.bondId, x.entryKey)),
                    "forceExit(bondId, entryKey)"
                );
            } else if (a.account == registryImpl) {
                assertEq(
                    uint8(a.kind), uint8(VmSafe.AccountAccessKind.DelegateCall), "registry impl"
                );
            } else {
                revert(string.concat("unexpected call to ", vm.toString(a.account)));
            }
        }
        assertEq(forceExits, 2, "one forceExit per exclusion");
    }

    // ---------------------------------------------------------------
    // Landing across generations
    // ---------------------------------------------------------------

    /// @dev After recovery at c = 12, (12, 18] proved from the generation's start height lands:
    /// its cut hash and statement are under generation 1, the origin is `landings(12)` from
    /// generation 0, and the new record carries generation 1.
    function test_land_AfterRecoveryStartsAtTheGenerationOrigin() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.LandInput memory input = _input(12, 18);
        bytes32[] memory none = new bytes32[](0);
        bytes32 generation0Statement =
            _statement(input, _inbox().landings(12), _cutHash(input, none));

        _recover(0, 12, _noExclusions(), _noIndices());
        assertEq(_inbox().generationStartHeight(), 12, "start height");

        bytes32 cutHash = _cutHash(input, none);
        assertEq(
            cutHash,
            keccak256(
                abi.encode(
                    bytes32("ETNA_LAND_CUTS_V1"),
                    uint256(1),
                    uint256(12),
                    uint256(18),
                    keccak256("")
                )
            ),
            "generation-1 cut hash"
        );
        bytes32 statement = _statement(input, _inbox().landings(12), cutHash);
        assertNotEq(statement, generation0Statement, "generation-1 statement");
        landVerifier.setExpectedStatementHash(statement);

        // `_land` expects `Landed(12, 12, 18, cutHash, 4, 1)`.
        assertEq(_land(input, none), statement, "statement over landings(12)");
        _assertLanding(18, _record(12, 1, 3, 18));
        _assertCheckpoint(18, bytes32(uint256(1118)));
        _assertQueue(3, LEAN_FORCED_INCLUSIONS);
        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(18);
        assertEq(saved.blockHash, bytes32(uint256(1118)), "signal block hash");
        assertEq(saved.stateRoot, bytes32(uint256(318)), "signal state root");
    }

    /// @dev With c = 18 landed in generation 1 above the origin 12, whose record is from
    /// generation 0, (12, 24] proved from 12 lands. The leaf at c is checked against the
    /// generation-1 record, so the discarded generation-0 suffix's leaf at 18 is rejected, and
    /// every origin below 12 is rejected although its record exists.
    function test_land_AfterRecoveryOverlapsFromTheGenerationOrigin() external {
        _land(0, 6);
        _land(6, 12);
        _recover(0, 12, _noExclusions(), _noIndices());
        _land(12, 18);
        // A fourth entry lets the head reach 24 / 6 = 4.
        _saveForcedInclusions(1);
        IEtnaInbox.Landing memory origin = _inbox().landings(12);
        assertEq(origin.generation, 0, "origin record from generation 0");
        assertEq(_inbox().landings(18).generation, 1, "checkpoint record from generation 1");

        IEtnaInbox.LandInput memory input = _input(12, 24);
        bytes32[] memory leaves = _leaves(12, 24);
        assertEq(leaves.length, 1, "one grid point inside (12, 24)");
        assertEq(
            leaves[0],
            keccak256(
                abi.encode(uint256(18), bytes32(uint256(1118)), bytes32(uint256(1218)), uint256(3))
            ),
            "the leaf at 18 from the generation-1 record"
        );

        bytes32[] memory discarded = new bytes32[](1);
        discarded[0] = _leafOf(18, bytes32(uint256(118)), bytes32(uint256(218)), 3);
        _expectLandRevert(input, discarded, IEtnaInbox.FrontierLeafMismatch.selector);
        _expectLandRevert(_input(6, 24), _leaves(6, 24), IEtnaInbox.InvalidRange.selector);
        _expectLandRevert(_input(0, 24), _leaves(0, 24), IEtnaInbox.InvalidRange.selector);

        landVerifier.setExpectedStatementHash(_statement(input, origin, _cutHash(input, leaves)));
        // `_land` expects `Landed(12, 18, 24, ...)` and a statement over `landings(12)`.
        _land(input, leaves);
        _assertLanding(24, _record(18, 1, 4, 24));
        _assertCheckpoint(24, bytes32(uint256(1124)));
        _assertLanding(12, _record(6, 0, 2, 12));
    }

    /// @dev Lean `foreign_generation_proof_rejected`: the (0, 18] inputs prepared before recovery
    /// at c = 12 fail after it because origin 0 is below the new generation's start height, and so
    /// do the inputs from origin 6; origin 12 lands. `LandInput` carries no generation (the
    /// statement binds it), so these rejections come from the range check, before any proof.
    function test_land_AfterRecoveryRejectsOlderOrigins() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.LandInput memory full = _input(0, 18);
        bytes32[] memory fullLeaves = _leaves(0, 18);

        _recover(0, 12, _noExclusions(), _noIndices());
        _expectLandRevert(full, fullLeaves, IEtnaInbox.InvalidRange.selector);
        _expectLandRevert(_input(6, 18), _leaves(6, 18), IEtnaInbox.InvalidRange.selector);

        _land(12, 18);
        _assertCheckpoint(18, bytes32(uint256(1118)));
    }

    /// @dev A proof of (12, 18] made for generation 0 does not verify after recovery: a verifier
    /// accepting only the generation-0 statement rejects the landing, and the generation-1
    /// statement lands.
    function test_land_AfterRecoveryOldGenerationProofFails() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.LandInput memory input = _input(12, 18);
        bytes32[] memory none = new bytes32[](0);
        bytes32 generation0Statement =
            _statement(input, _inbox().landings(12), _cutHash(input, none));

        _recover(0, 12, _noExclusions(), _noIndices());
        bytes32 generation1Statement =
            _statement(input, _inbox().landings(12), _cutHash(input, none));
        assertNotEq(generation1Statement, generation0Statement, "statements differ");

        landVerifier.setExpectedStatementHash(generation0Statement);
        _expectLandRevert(input, none, MockLandProofVerifier.ProofRejected.selector);

        landVerifier.setExpectedStatementHash(generation1Statement);
        assertEq(_land(input, none), generation1Statement, "generation-1 proof");
    }

    /// @dev The recovery origin's record stays as generation 0 wrote it, with its Comet hash, through
    /// the recovery and the landings above it, and so does its SignalService checkpoint.
    function test_land_RecoveryOriginRecordIsUntouched() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.Landing memory atOrigin = _record(6, 0, 2, 12);
        assertEq(atOrigin.cometHash, bytes32(uint256(212)), "generation-0 Comet hash");
        _assertLanding(12, atOrigin);

        _recover(0, 12, _noExclusions(), _noIndices());
        _assertLanding(12, atOrigin);

        _land(12, 18);
        _assertLanding(12, atOrigin);
        _assertLanding(18, _record(12, 1, 3, 18));
        _assertLanding(6, _record(0, 0, 1, 6));
        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(12);
        assertEq(saved.blockHash, bytes32(uint256(112)), "signal block hash at 12");
        assertEq(saved.stateRoot, bytes32(uint256(312)), "signal state root at 12");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The owner recovers with `_generation` and `_c` expected, expecting
    /// `Recovered(_generation + 1, _c, block.number, block.timestamp, _exclusions, _fiToClear)`.
    function _recover(
        uint48 _generation,
        uint256 _c,
        IEtnaInbox.Exclusion[] memory _exclusionList,
        uint256[] memory _fiToClear
    )
        private
    {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.Recovered(
            _generation + 1, _c, block.number, block.timestamp, _exclusionList, _fiToClear
        );
        vm.prank(_inbox().owner());
        _inbox()
            .recover(
                _generation,
                _c,
                uint256(vm.load(inboxProxy, bytes32(uint256(292)))),
                type(uint256).max,
                _exclusionList,
                _fiToClear
            );
    }

    /// @dev Expects the owner's recovery to revert with `_selector`, writing nothing.
    function _expectRecoverRevert(
        uint48 _generation,
        uint256 _c,
        IEtnaInbox.Exclusion[] memory _exclusionList,
        uint256[] memory _fiToClear,
        bytes4 _selector
    )
        private
    {
        _expectRecoverRevert(
            _inbox().owner(),
            _generation,
            _c,
            _exclusionList,
            _fiToClear,
            abi.encodeWithSelector(_selector)
        );
    }

    /// @dev Expects `_caller`'s recovery to revert with `_revertData`, leaving the generation,
    /// checkpoint, queue, snapshot, the current and next origins, the checkpoint's record, every
    /// queue entry's txHash and every registry exit and checkpoint unchanged.
    function _expectRecoverRevert(
        address _caller,
        uint48 _generation,
        uint256 _c,
        IEtnaInbox.Exclusion[] memory _exclusionList,
        uint256[] memory _fiToClear,
        bytes memory _revertData
    )
        private
    {
        bytes32[] memory before = _recoveryState();
        vm.expectRevert(_revertData);
        vm.prank(_caller);
        _inbox()
            .recover(
                _generation,
                _c,
                uint256(vm.load(inboxProxy, bytes32(uint256(292)))),
                type(uint256).max,
                _exclusionList,
                _fiToClear
            );
        bytes32[] memory afterRevert = _recoveryState();
        assertEq(afterRevert.length, before.length, "state shape");
        for (uint256 i; i < before.length; ++i) {
            assertEq(afterRevert[i], before[i], "no state change");
        }
    }

    /// @dev The words a recovery may write, and those it must not.
    function _recoveryState() private view returns (bytes32[] memory words_) {
        uint256 generation = _inbox().recoveryGeneration();
        uint256 c = _inbox().lastCheckpoint().height;
        (, uint48 tail) = _inbox().getForcedInclusionState();
        uint256 bonds = registry.entryCount();
        words_ = new bytes32[](17 + tail + bonds);
        uint256 n;
        words_[n++] = _inboxWord(RECOVERY_GENERATION_SLOT);
        words_[n++] = _inboxWord(292);
        words_[n++] = _inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT);
        words_[n++] = _inboxWord(LAST_CHECKPOINT_HASH_SLOT);
        words_[n++] = _inboxWord(FORCED_INCLUSION_HEAD_TAIL_SLOT);
        words_[n++] = _inboxWord(ACTIVE_COMMITTEE_SNAPSHOT_SLOT);
        for (uint256 w; w < 3; ++w) {
            words_[n++] = _inboxWord(_originSlot(generation) + w);
            words_[n++] = _inboxWord(_originSlot(generation + 1) + w);
            words_[n++] = _inboxWord(_landingSlot(c) + w);
        }
        for (uint256 i; i < tail; ++i) {
            words_[n++] = _inboxWord(_queueSlot(i));
        }
        for (uint256 b; b < bonds; ++b) {
            words_[n++] = bytes32(uint256(registry.entryAt(b).exitEffectiveL1));
        }
        words_[n++] = bytes32(registry.checkpointCount());
        words_[n++] = registry.entriesRoot();
    }

    /// @dev The settled state with the chain landed to 12: slots 258-284 except the generation,
    /// landings 0, 6 and 12, origins(0) and the SignalService checkpoints at 0, 6 and 12.
    function _settledWords() private view returns (bytes32[] memory words_) {
        words_ = new bytes32[](26 + 9 + 9 + 3);
        uint256 n;
        for (
            uint256 slot = INITIALIZATION_STATUS_SLOT;
            slot <= ACTIVE_COMMITTEE_SNAPSHOT_SLOT;
            ++slot
        ) {
            if (slot != RECOVERY_GENERATION_SLOT) {
                words_[n++] = _inboxWord(slot);
            }
        }
        for (uint256 h; h <= 12; h += K) {
            for (uint256 w; w < 3; ++w) {
                words_[n++] = _inboxWord(_landingSlot(h) + w);
            }
            ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(uint48(h));
            words_[n++] = bytes32(uint256(saved.blockNumber));
            words_[n++] = saved.blockHash;
            words_[n++] = saved.stateRoot;
        }
        for (uint256 w; w < 3; ++w) {
            words_[n++] = _inboxWord(_originSlot(0) + w);
        }
        assertEq(n, words_.length, "settled words");
    }

    /// @dev The first word (txHash) of queue entry `_index` (slot 280 mapping).
    function _queueSlot(uint256 _index) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(_index, FORCED_INCLUSION_QUEUE_SLOT)));
    }

    /// @dev Checks `origins(_generation)` through the getter and its three raw slot 290 words.
    function _assertOrigin(
        uint256 _generation,
        uint256 _startHeight,
        uint256 _l1BlockNumber,
        uint256 _l1Timestamp
    )
        private
        view
    {
        IEtnaInbox.Origin memory origin = _inbox().origins(_generation);
        assertEq(origin.startHeight, _startHeight, "origin startHeight");
        assertEq(origin.l1BlockNumber, _l1BlockNumber, "origin l1BlockNumber");
        assertEq(origin.l1Timestamp, _l1Timestamp, "origin l1Timestamp");
        uint256 slot = _originSlot(_generation);
        assertEq(uint256(_inboxWord(slot)), _startHeight, "slot 290 word 1");
        assertEq(uint256(_inboxWord(slot + 1)), _l1BlockNumber, "slot 290 word 2");
        assertEq(uint256(_inboxWord(slot + 2)), _l1Timestamp, "slot 290 word 3");
    }

    function _assertForcedInclusion(
        uint48 _index,
        IEtnaInbox.ForcedInclusion memory _expected
    )
        private
        view
    {
        IEtnaInbox.ForcedInclusion memory entry = _inbox().getForcedInclusion(_index);
        assertEq(entry.txHash, _expected.txHash, "entry txHash");
        assertEq(entry.timestamp, _expected.timestamp, "entry timestamp");
        assertEq(entry.l1Block, _expected.l1Block, "entry l1Block");
    }

    function _assertEntry(
        uint256 _bondId,
        IEtnaStakingRegistry.Entry memory _expected
    )
        private
        view
    {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        assertEq(entry.ckX, _expected.ckX, "ckX");
        assertEq(entry.effStake, _expected.effStake, "effStake");
        assertEq(entry.ckPrefix, _expected.ckPrefix, "ckPrefix");
        assertEq(entry.activeFromL1, _expected.activeFromL1, "activeFromL1");
        assertEq(entry.exitEffectiveL1, _expected.exitEffectiveL1, "exitEffectiveL1");
    }

    /// @dev The entry key of `_pk`'s consensus key: keccak256(abi.encode(ckPrefix, ckX)).
    function _entryKeyOf(uint256 _pk) private returns (bytes32) {
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        return keccak256(
            abi.encode(uint256(uint8(publicKey[0])), bytes32(vm.createWallet(_pk).publicKeyX))
        );
    }

    function _exclusion(uint256 _bondId, uint256 _pk)
        private
        returns (IEtnaInbox.Exclusion memory)
    {
        return IEtnaInbox.Exclusion({ bondId: _bondId, entryKey: _entryKeyOf(_pk) });
    }

    function _exclusions(
        uint256 _bondId,
        uint256 _pk
    )
        private
        returns (IEtnaInbox.Exclusion[] memory list_)
    {
        list_ = new IEtnaInbox.Exclusion[](1);
        list_[0] = _exclusion(_bondId, _pk);
    }

    /// @dev Bob's exclusion before Alice's.
    function _unsortedExclusions() private returns (IEtnaInbox.Exclusion[] memory list_) {
        list_ = new IEtnaInbox.Exclusion[](2);
        list_[0] = _exclusion(1, _BOB_PK);
        list_[1] = _exclusion(0, VALIDATOR_PK);
    }

    function _noIndices() private pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function _indices(uint256 _a) private pure returns (uint256[] memory list_) {
        list_ = new uint256[](1);
        list_[0] = _a;
    }

    function _indices(uint256 _a, uint256 _b) private pure returns (uint256[] memory list_) {
        list_ = new uint256[](2);
        (list_[0], list_[1]) = (_a, _b);
    }

    function _indices(
        uint256 _a,
        uint256 _b,
        uint256 _c
    )
        private
        pure
        returns (uint256[] memory list_)
    {
        list_ = new uint256[](3);
        (list_[0], list_[1], list_[2]) = (_a, _b, _c);
    }
}
