// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "../EtnaStakingRegistryTestBase.sol";
import { EtnaStakingRegistryHandler } from "./EtnaStakingRegistryHandler.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title EtnaStakingRegistryInvariantBase
/// @notice Deploys a registry fixed to an initialized `MockEtnaInbox`, funds four stakers and
/// targets the handler's actions; holds the checks the registry campaigns share.
/// @dev Foundry runs a separate campaign per invariant function and asserts only that function
/// in it, so every invariant also asserts that the handler saw no violation of any kind: each
/// campaign enforces every per-call check. Storage is read both through the getters and as the
/// raw words of spec appendix B.
abstract contract EtnaStakingRegistryInvariantBase is EtnaStakingRegistryTestBase {
    uint256 internal constant START_BLOCK = 1001;
    uint256 internal constant STAKER_FUNDS = 2000 * MIN_STAKE;
    uint48 internal constant NO_EXIT = type(uint48).max;
    uint256 internal constant CAPACITY = 4096;

    /// @dev The ERC-7201 base slot R of `taiko.etna.registry`, its fields read directly
    /// (`checkpoints` at R, `entries` at R + 1, `freeSlots` at R + 3, `keyUsed` at R + 4), and
    /// the bases of the owners and exit-confirmations namespaces.
    uint256 internal constant REGISTRY_BASE =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;
    uint256 internal constant CHECKPOINTS_SLOT = REGISTRY_BASE;
    uint256 internal constant ENTRIES_SLOT = REGISTRY_BASE + 1;
    uint256 internal constant FREE_SLOTS_SLOT = REGISTRY_BASE + 3;
    uint256 internal constant KEY_USED_SLOT = REGISTRY_BASE + 4;
    uint256 internal constant OWNERS_SLOT =
        0x39c9f3adc28a427dc5a3705913196a8ee3e586999e5fd34170cb091706065d00;
    uint256 internal constant EXIT_CONFIRMATIONS_SLOT =
        0x25e74f824855a18216fe2fa8b7d9dcc76ad83f6de1a344c666c3293e57124900;

    EtnaStakingRegistryHandler internal handler;

    function setUp() public virtual override {
        super.setUp();
        vm.roll(START_BLOCK);
        mockInbox.setInitialized(true);

        address[] memory stakers = new address[](4);
        (stakers[0], stakers[1], stakers[2], stakers[3]) = (Alice, Bob, Carol, David);
        for (uint256 i; i < stakers.length; ++i) {
            _fund(stakers[i], STAKER_FUNDS);
        }
        handler =
            new EtnaStakingRegistryHandler(registry, mockInbox, stakers, _keepSnapshotLeaves());

        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = EtnaStakingRegistryHandler.register.selector;
        selectors[1] = EtnaStakingRegistryHandler.requestExit.selector;
        selectors[2] = EtnaStakingRegistryHandler.confirmExit.selector;
        selectors[3] = EtnaStakingRegistryHandler.withdraw.selector;
        selectors[4] = EtnaStakingRegistryHandler.slash.selector;
        selectors[5] = EtnaStakingRegistryHandler.forceExit.selector;
        selectors[6] = EtnaStakingRegistryHandler.settle.selector;
        selectors[7] = EtnaStakingRegistryHandler.advanceBlocks.selector;
        selectors[8] = EtnaStakingRegistryHandler.advanceToWithdrawal.selector;
        selectors[9] = EtnaStakingRegistryHandler.topUp.selector;
        selectors[10] = EtnaStakingRegistryHandler.activateTopUp.selector;
        selectors[11] = EtnaStakingRegistryHandler.forfeit.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetSender(makeAddr("invariant sender"));
    }

    /// @dev Whether the handler keeps every snapshot's leaves, which only pays off with few slots.
    function _keepSnapshotLeaves() internal pure virtual returns (bool) {
        return true;
    }

    // ---------------------------------------------------------------
    // Shared checks
    // ---------------------------------------------------------------

    /// @dev Asserts that the handler recorded no broken property and no call whose outcome
    /// (success, bond id or revert data) differed from the model's prediction, and that the mock
    /// Inbox is as the model left it: initialized, unlocked, at the modelled snapshot and
    /// generation.
    function _assertModelHeld() internal view {
        assertEq(mockInbox.activeCommitteeSnapshot(), handler.ghostSnapshot(), "landed snapshot");
        assertEq(mockInbox.recoveryGeneration(), handler.ghostGeneration(), "generation");
        assertTrue(mockInbox.isInitialized(), "the Inbox stays initialized between calls");
        assertFalse(mockInbox.inNonReentrant(), "the Inbox lock is released between calls");
        for (uint8 p; p <= uint8(type(EtnaStakingRegistryHandler.Property).max); ++p) {
            EtnaStakingRegistryHandler.Property property = EtnaStakingRegistryHandler.Property(p);
            assertEq(handler.violations(property), 0, handler.firstViolation(property));
        }
    }

    /// @dev Checkpoint blocks strictly increase, none lies ahead, there is one per L1 block that
    /// changed an entry, and each equals the handler's copy taken when its block last changed an
    /// entry, through the getter and its two slot R words. A past block's copy is frozen, so
    /// equality means its checkpoint was never rewritten afterwards.
    function _assertCheckpointHistory() internal view {
        IEtnaStakingRegistry.Checkpoint[] memory copies = handler.checkpoints();
        uint256 count = registry.checkpointCount();
        assertEq(count, copies.length, "one checkpoint per L1 block that changed an entry");
        assertEq(_load(CHECKPOINTS_SLOT), count, "checkpoints length (slot R)");
        uint256 base = uint256(keccak256(abi.encode(CHECKPOINTS_SLOT)));
        uint48 previous;
        for (uint256 i; i < count; ++i) {
            IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(i);
            if (i != 0) assertGt(checkpoint.l1Block, previous, "strictly increasing l1Block");
            previous = checkpoint.l1Block;
            assertLe(checkpoint.l1Block, block.number, "no checkpoint of a future block");
            assertEq(checkpoint.l1Block, copies[i].l1Block, "checkpoint l1Block is final");
            assertEq(checkpoint.count, copies[i].count, "checkpoint count is final");
            assertEq(checkpoint.entriesRoot, copies[i].entriesRoot, "checkpoint root is final");
            assertEq(
                _load(base + 2 * i),
                uint256(checkpoint.l1Block) | (uint256(checkpoint.count) << 48),
                "checkpoint word 1 packs l1Block and count"
            );
            assertEq(bytes32(_load(base + 2 * i + 1)), checkpoint.entriesRoot, "checkpoint word 2");
        }
    }

    /// @dev Every checkpoint matches the snapshot of the modelled entries at the end of its
    /// block (count and root), however often its slots were released and reused since.
    function _assertSnapshots() internal view {
        EtnaStakingRegistryHandler.Snapshot[] memory snapshots = handler.snapshots();
        uint256 count = registry.checkpointCount();
        assertEq(snapshots.length, count, "one snapshot per checkpoint");
        for (uint256 i; i < count; ++i) {
            IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(i);
            assertEq(snapshots[i].count, checkpoint.count, "snapshot count equals the count");
            assertEq(snapshots[i].root, checkpoint.entriesRoot, "snapshot root equals the root");
        }
    }

    /// @dev Per unreleased entry: it activates exactly `activationDelay` after its registration;
    /// its exit is the earliest of the requested exit (the exit delay after the later of request
    /// and activation), the slash block and every recovery R, so it never moved later; and a
    /// confirmed exit is at or before the landed snapshot of its confirmation.
    function _assertTiming(uint256 _bondId) internal view {
        EtnaStakingRegistryHandler.Slot memory slot = handler.slotAt(_bondId);
        if (slot.entry.ckPrefix == 0) return;
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        assertEq(
            entry.activeFromL1,
            slot.registeredAt + registry.activationDelay(),
            "activation is its delay after registration"
        );
        uint256 earliest = _min(slot.requestedExit, slot.forcedExit);
        if (slot.slashedAt != 0) earliest = _min(earliest, slot.slashedAt);
        assertEq(entry.exitEffectiveL1, earliest, "exit is the earliest request, slash or R");
        if (slot.requestedAt != 0) {
            assertEq(
                slot.requestedExit,
                _max(slot.requestedAt, entry.activeFromL1) + registry.exitDelay(),
                "requested exit is its delay after the later of request and activation"
            );
            assertLe(entry.exitEffectiveL1, slot.requestedExit, "the exit never moved later");
        }
        uint256 confirmedAt = registry.exitConfirmedAtL1(_bondId);
        assertEq(confirmedAt, slot.confirmedAt, "modelled confirmation");
        if (confirmedAt != 0) {
            assertLe(
                entry.exitEffectiveL1,
                slot.snapshotAtConfirmation,
                "a confirmed exit is covered by the snapshot of its confirmation"
            );
            assertGe(confirmedAt, slot.registeredAt, "confirmed after the registration");
            assertLe(confirmedAt, block.number, "confirmed in the past");
        }
    }

    /// @dev The registry's free list is the model's (released bonds, most recently released
    /// last), through the getter and the raw slot R + 3 array; each is a used, released slot
    /// with no owner or confirmation, listed once.
    function _assertFreeSlots(uint256 _entryCount) internal view {
        uint256[] memory free = handler.freeSlots();
        assertEq(registry.freeSlotCount(), free.length, "free slot count");
        assertEq(_load(FREE_SLOTS_SLOT), free.length, "freeSlots length (slot R + 3)");
        uint256 base = uint256(keccak256(abi.encode(FREE_SLOTS_SLOT)));
        for (uint256 i; i < free.length; ++i) {
            assertEq(_load(base + i), free[i], "free slots in the order they were released");
            assertLt(free[i], _entryCount, "a free slot is a used slot");
            _assertReleased(free[i]);
            for (uint256 j; j < i; ++j) {
                assertNotEq(free[i], free[j], "a free slot appears once");
            }
        }
    }

    /// @dev A released slot's entry words are zero and it has no owner or confirmation.
    function _assertReleased(uint256 _bondId) internal view {
        uint256 slot = _entrySlot(_bondId);
        assertEq(_load(slot), 0, "a released entry's ckX is zero");
        assertEq(_load(slot + 1), 0, "a released entry's stake is zero");
        assertEq(_load(slot + 2), 0, "a released entry's packed word is zero");
        assertEq(registry.ownerOf(_bondId), address(0), "a released slot has no owner");
        assertEq(registry.exitConfirmedAtL1(_bondId), 0, "a released slot has no confirmation");
        assertEq(_load(_mappingSlot(_bondId, OWNERS_SLOT)), 0, "owners namespace cleared");
        assertEq(_load(_mappingSlot(_bondId, EXIT_CONFIRMATIONS_SLOT)), 0, "confirmations cleared");
    }

    /// @dev Checks the registry's entry, owner and confirmation of `_bondId` against the model.
    function _assertModelled(uint256 _bondId) internal view {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        EtnaStakingRegistryHandler.Slot memory slot = handler.slotAt(_bondId);
        assertEq(entry.ckX, slot.entry.ckX, "modelled ckX");
        assertEq(entry.effStake, slot.entry.effStake, "modelled stake");
        assertEq(entry.ckPrefix, slot.entry.ckPrefix, "modelled ckPrefix");
        assertEq(entry.activeFromL1, slot.entry.activeFromL1, "modelled activation");
        assertEq(entry.exitEffectiveL1, slot.entry.exitEffectiveL1, "modelled exit");
        assertEq(registry.ownerOf(_bondId), slot.owner, "modelled owner");
        assertEq(registry.exitConfirmedAtL1(_bondId), slot.confirmedAt, "modelled confirmation");
        (uint256 pending, uint48 ready) = registry.topUpOf(_bondId);
        assertEq(pending, slot.pendingTopUp, "modelled pending principal");
        assertEq(ready, slot.topUpReadyAtL1, "modelled readiness");
        if (entry.ckPrefix != 0) {
            bytes32 key = keccak256(abi.encode(entry.ckPrefix, entry.ckX));
            assertEq(registry.forfeited(key), handler.lifetimeForfeited(key), "lifetime flag");
        }
        if (slot.formerEntryKey != 0) {
            assertEq(
                registry.forfeited(slot.formerEntryKey),
                handler.lifetimeForfeited(slot.formerEntryKey),
                "former lifetime flag survives reuse"
            );
        }
    }

    /// @dev Reads entry `_index` from its three raw slot R + 1 words, checking that the packed
    /// third word holds `ckPrefix` (8 bits), `activeFromL1` and `exitEffectiveL1` (48 bits each)
    /// from the least-significant bit with the high bits zero, and that the getter agrees.
    function _rawEntry(uint256 _index)
        internal
        view
        returns (IEtnaStakingRegistry.Entry memory entry_)
    {
        uint256 slot = _entrySlot(_index);
        uint256 packed = _load(slot + 2);
        assertEq(packed >> 104, 0, "entry word 3 high bits are zero");
        entry_ = IEtnaStakingRegistry.Entry({
            ckX: bytes32(_load(slot)),
            effStake: _load(slot + 1),
            ckPrefix: uint8(packed),
            activeFromL1: uint48(packed >> 8),
            exitEffectiveL1: uint48(packed >> 56)
        });
        IEtnaStakingRegistry.Entry memory got = registry.entryAt(_index);
        assertEq(got.ckX, entry_.ckX, "entry word 1 is ckX");
        assertEq(got.effStake, entry_.effStake, "entry word 2 is effStake");
        assertEq(got.ckPrefix, entry_.ckPrefix, "entry word 3 ckPrefix");
        assertEq(got.activeFromL1, entry_.activeFromL1, "entry word 3 activeFromL1");
        assertEq(got.exitEffectiveL1, entry_.exitEffectiveL1, "entry word 3 exitEffectiveL1");
    }

    /// @notice Returns the leaf of entry `_index` read from its raw storage words.
    /// @dev A separate call frame per leaf bounds the memory a recompute over all 4,096 slots
    /// keeps; one frame would expand memory past the transaction gas cap.
    /// @param _index The entry index.
    /// @return The leaf.
    function rawLeafAt(uint256 _index) external view returns (bytes32) {
        return _leaf(_index, _rawEntry(_index));
    }

    /// @dev The naive root over every slot's leaf read from raw storage.
    function _naiveRootOfEntries() internal view returns (bytes32) {
        uint256 count = registry.entryCount();
        bytes32[] memory leaves = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            leaves[i] = this.rawLeafAt(i);
        }
        return _naiveRoot(leaves);
    }

    /// @dev Spec appendix A `regLeaf`, written out: keccak256 of the seven words tag, index,
    /// ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1.
    function _leaf(
        uint256 _index,
        IEtnaStakingRegistry.Entry memory _entry
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32("ETNA_REG_ENTRY_V1"),
                _index,
                uint256(_entry.ckPrefix),
                _entry.ckX,
                _entry.effStake,
                uint256(_entry.activeFromL1),
                uint256(_entry.exitEffectiveL1)
            )
        );
    }

    /// @dev The root of `_leaves` padded with zero leaves to the next power of two and hashed
    /// pairwise level by level; `bytes32(0)` without leaves.
    function _naiveRoot(bytes32[] memory _leaves) internal pure returns (bytes32) {
        if (_leaves.length == 0) return bytes32(0);
        uint256 width = 1;
        while (width < _leaves.length) {
            width <<= 1;
        }
        bytes32[] memory level = new bytes32[](width);
        for (uint256 i; i < _leaves.length; ++i) {
            level[i] = _leaves[i];
        }
        while (width > 1) {
            width >>= 1;
            for (uint256 i; i < width; ++i) {
                level[i] = keccak256(abi.encodePacked(level[2 * i], level[2 * i + 1]));
            }
        }
        return level[0];
    }

    function _entrySlot(uint256 _index) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(ENTRIES_SLOT))) + 3 * _index;
    }

    function _mappingSlot(uint256 _key, uint256 _base) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_key, _base)));
    }

    function _load(uint256 _slot) internal view returns (uint256) {
        return uint256(vm.load(address(registry), bytes32(_slot)));
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}

/// @title EtnaStakingRegistryInvariantTest
/// @notice Registry invariants over four stakers registering real secp256k1 keys, exits,
/// confirmations, withdrawals, slashing, recovery exclusions, landed snapshots and L1 time,
/// recomputing every entry after every call.
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingRegistryInvariantTest is EtnaStakingRegistryInvariantBase {
    /// @notice A registration, exit, confirmation and withdrawal release a slot that the next
    /// registration reuses.
    function test_handler_ReleasesAndReusesASlot() external {
        handler.register(0, 0, 0);
        handler.requestExit(0);
        handler.advanceToWithdrawal(0);
        handler.settle(0);
        handler.confirmExit(0);
        handler.advanceToWithdrawal(0);
        handler.withdraw(0);
        handler.register(1, 0, 0);
        assertEq(handler.registrations(), 2, "registrations");
        assertEq(handler.confirmations(), 1, "confirmations");
        assertEq(handler.withdrawals(), 1, "withdrawals");
        assertEq(handler.reuses(), 1, "reuses");
        assertEq(registry.entryCount(), 1, "one slot");
        _assertModelHeld();
    }

    /// @notice A slash moves the whole stake out; after a landed snapshot covers the slash block
    /// and the withdrawal delay, the slot is released without payment.
    function test_handler_SlashedEntryIsReleasedWithoutPayment() external {
        handler.register(0, 0, 0);
        handler.slash(0);
        handler.settle(0);
        handler.confirmExit(0);
        handler.advanceToWithdrawal(0);
        handler.withdraw(0);
        assertEq(handler.slashes(), 1, "slashes");
        assertEq(handler.releasesWithoutPayment(), 1, "releases without payment");
        assertEq(token.balanceOf(address(registry)), 0, "no stake left");
        _assertModelHeld();
    }

    /// @notice An entry slashed after its exit is confirmed keeps its exit and confirmation;
    /// after the withdrawal delay from that confirmation, a non-owner releases the slot to the
    /// zero address and no TAIKO moves (spec 4.1).
    function test_handler_SlashAfterConfirmationKeepsItAndAnyoneReleases() external {
        handler.register(0, 0, 0);
        address bondOwner = registry.ownerOf(0);
        assertEq(bondOwner, Alice, "Alice owns bond 0");
        handler.requestExit(0);
        handler.advanceToWithdrawal(0);
        handler.settle(0);
        handler.confirmExit(0);
        uint256 confirmedAt = registry.exitConfirmedAtL1(0);
        uint48 exit = registry.entryAt(0).exitEffectiveL1;
        assertGt(confirmedAt, 0, "confirmed");

        handler.slash(0);
        assertEq(handler.slashesAfterConfirmation(), 1, "slashed after confirmation");
        assertEq(registry.entryAt(0).effStake, 0, "whole stake slashed");
        assertEq(registry.entryAt(0).exitEffectiveL1, exit, "exit kept: min(old, block)");
        assertEq(registry.exitConfirmedAtL1(0), confirmedAt, "confirmation kept");
        assertEq(registry.ownerOf(0), bondOwner, "owner kept");

        handler.advanceToWithdrawal(0);
        assertEq(block.number, confirmedAt + registry.withdrawalDelay(), "delay from confirmation");
        uint256 carolBefore = token.balanceOf(Carol);
        handler.withdrawOf(0, Carol, address(0));
        assertEq(handler.releasesAfterConfirmedSlash(), 1, "released after the slash");
        assertEq(handler.releasesByOthers(), 1, "released by a non-owner");
        assertEq(registry.freeSlotCount(), 1, "slot released");
        assertEq(registry.ownerOf(0), address(0), "no owner");
        assertEq(registry.exitConfirmedAtL1(0), 0, "no confirmation");
        assertEq(token.balanceOf(Carol), carolBefore, "nothing to the releaser");
        assertEq(token.balanceOf(address(registry)), 0, "no stake left");
        _assertModelHeld();
    }

    /// @notice 1. `entriesRoot()` equals the naive zero-padded pairwise tree over the leaf of
    /// every slot's raw entry words (a released slot's all-zero entry contributes
    /// `leaf(j, zero)`), the handler's ghost tree has the same root, and the latest checkpoint
    /// holds that root and the slot count.
    function invariant_entriesRootEqualsTheNaiveTree() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        assertEq(_load(ENTRIES_SLOT), count, "entries length (slot R + 1)");
        bytes32[] memory leaves = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            leaves[i] = _leaf(i, _rawEntry(i));
        }
        IEtnaStakingRegistry.Entry memory zero;
        uint256[] memory free = handler.freeSlots();
        for (uint256 i; i < free.length; ++i) {
            assertEq(leaves[free[i]], _leaf(free[i], zero), "a released slot is leaf(j, zero)");
        }
        bytes32 root = _naiveRoot(leaves);
        assertEq(registry.entriesRoot(), root, "entriesRoot is the naive root");
        assertEq(handler.ghostRoot(), root, "the ghost tree is the naive tree");

        uint256 checkpointCount = registry.checkpointCount();
        if (count == 0) {
            assertEq(checkpointCount, 0, "no checkpoint before the first entry");
            return;
        }
        IEtnaStakingRegistry.Checkpoint memory latest = registry.checkpointAt(checkpointCount - 1);
        assertEq(latest.count, count, "the latest checkpoint counts every slot");
        assertEq(latest.entriesRoot, root, "the latest checkpoint holds the current root");
    }

    /// @notice 2. One checkpoint per L1 block that changed an entry: blocks strictly increase,
    /// and a past block's checkpoint (getter and raw words) never changes.
    function invariant_checkpointHistoryIsImmutable() external view {
        _assertModelHeld();
        _assertCheckpointHistory();
    }

    /// @notice 3. Each checkpoint matches the snapshot of every modelled entry taken at the end
    /// of its block: the snapshot's length is the checkpoint's count and its naive root the
    /// checkpoint's root, even after later registrations reuse released slots.
    function invariant_snapshotsSurviveSlotReuse() external view {
        _assertModelHeld();
        _assertSnapshots();
        uint256 count = registry.checkpointCount();
        for (uint256 i; i < count; ++i) {
            IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(i);
            bytes32[] memory snapshot = handler.snapshotLeaves(i);
            assertEq(snapshot.length, checkpoint.count, "snapshot length equals the count");
            assertEq(_naiveRoot(snapshot), checkpoint.entriesRoot, "naive snapshot root");
        }
    }

    /// @notice 4. Owners and confirmations (getters and the raw words of their namespaces) are
    /// the model's. A released slot has a zero entry, no owner and no confirmation; a reused slot
    /// holds the new registrant as owner, a fresh entry with a new key, and no confirmation from
    /// before its registration.
    function invariant_reusedSlotsInheritNoConfirmationOrOwner() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        uint256 released;
        for (uint256 i; i < count; ++i) {
            EtnaStakingRegistryHandler.Slot memory slot = handler.slotAt(i);
            address owner = registry.ownerOf(i);
            uint256 confirmedAt = registry.exitConfirmedAtL1(i);
            assertEq(owner, slot.owner, "modelled owner");
            assertEq(confirmedAt, slot.confirmedAt, "modelled confirmation");
            assertEq(_load(_mappingSlot(i, OWNERS_SLOT)), uint160(owner), "owners namespace");
            assertEq(
                _load(_mappingSlot(i, EXIT_CONFIRMATIONS_SLOT)),
                confirmedAt,
                "exit-confirmations namespace"
            );
            if (slot.entry.ckPrefix == 0) {
                _assertReleased(i);
                ++released;
                continue;
            }
            assertTrue(owner != address(0), "an occupied slot has an owner");
            _assertModelled(i);
            if (confirmedAt != 0) {
                assertGe(confirmedAt, slot.registeredAt, "no confirmation from before the entry");
                assertNotEq(registry.entryAt(i).exitEffectiveL1, NO_EXIT, "confirmed exit is set");
            }
            if (slot.occupancies > 1) {
                IEtnaStakingRegistry.Entry memory entry = registry.entryAt(i);
                assertNotEq(
                    keccak256(abi.encode(uint256(entry.ckPrefix), entry.ckX)),
                    slot.formerEntryKey,
                    "a reused slot holds a new key"
                );
            }
        }
        assertEq(released, handler.freeSlots().length, "every released slot is free");
    }

    /// @notice 5. `keyUsed` never clears: every key ever registered stays used (getter and raw
    /// slot R + 4 word) and no pool key that was never registered is used. No two unreleased
    /// entries share a key address, and each holds the modelled occupant's key. (The model
    /// records a key only after the registry accepted it as unused, so registered keys are
    /// distinct by construction; the per-call `KeyAlreadyUsed` predictions test reuse.)
    function invariant_keysAreLifetimeUnique() external view {
        _assertModelHeld();
        uint256[] memory used = handler.usedPks();
        for (uint256 i; i < used.length; ++i) {
            address ckAddr = vm.addr(used[i]);
            assertTrue(registry.keyUsed(ckAddr), "a registered key stays used");
            assertEq(_load(_mappingSlot(uint160(ckAddr), KEY_USED_SLOT)), 1, "keyUsed word");
        }
        uint256[] memory pool = handler.poolKeys();
        for (uint256 i; i < pool.length; ++i) {
            address ckAddr = vm.addr(pool[i]);
            assertEq(registry.keyUsed(ckAddr), handler.isKeyUsed(ckAddr), "pool key use");
        }

        uint256 count = registry.entryCount();
        address[] memory live = new address[](count);
        uint256 liveCount;
        for (uint256 i; i < count; ++i) {
            EtnaStakingRegistryHandler.Slot memory slot = handler.slotAt(i);
            if (slot.entry.ckPrefix == 0) continue;
            IEtnaStakingRegistry.Entry memory entry = registry.entryAt(i);
            assertEq(entry.ckPrefix, slot.entry.ckPrefix, "the occupant's prefix");
            assertEq(entry.ckX, slot.entry.ckX, "the occupant's X");
            address ckAddr = vm.addr(slot.pk);
            assertTrue(registry.keyUsed(ckAddr), "an occupant's key is used");
            for (uint256 j; j < liveCount; ++j) {
                assertNotEq(ckAddr, live[j], "two unreleased entries share a key address");
            }
            live[liveCount++] = ckAddr;
        }
    }

    /// @notice 6. The registry holds exactly the stake of its unreleased entries, which is every
    /// deposit minus the stake paid to owners and the recipient and the stake slashed; the sink
    /// and the reporters hold exactly the slashed stake (bounties at `slashBountyBps`), and the
    /// stakers hold their funding minus deposits plus what they withdrew. A slashed entry has no
    /// stake and an unslashed one keeps its deposit.
    function invariant_tokenBalanceEqualsStakes() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        uint256 sum;
        for (uint256 i; i < count; ++i) {
            uint256 stake = _load(_entrySlot(i) + 1);
            (uint256 pending,) = registry.topUpOf(i);
            sum += stake + pending;
            EtnaStakingRegistryHandler.Slot memory slot = handler.slotAt(i);
            if (slot.entry.ckPrefix != 0) {
                if (slot.slashedAt != 0) {
                    assertEq(stake + pending, 0, "slashing consumes all principal");
                }
                assertEq(stake, slot.entry.effStake, "the deposit until a slash");
            }
        }
        assertEq(token.balanceOf(address(registry)), sum, "registry balance = unreleased stake");
        assertEq(sum, handler.staked(), "modelled stake");
        assertEq(
            handler.deposited(),
            sum + handler.paidToOwners() + handler.paidToRecipient() + handler.slashedTotal()
                + handler.forfeitedTotal(),
            "deposits = stake + withdrawals + slashes"
        );
        assertEq(
            handler.slashedTotal() + handler.forfeitedTotal(),
            handler.bountiesPaid() + handler.sinkPaid(),
            "slashed = bounties + sink"
        );
        assertEq(token.balanceOf(SLASH_SINK), handler.sinkPaid(), "sink balance");
        address[] memory reporters = handler.reporters();
        uint256 bounties;
        for (uint256 i; i < reporters.length; ++i) {
            bounties += token.balanceOf(reporters[i]);
        }
        assertEq(bounties, handler.bountiesPaid(), "reporters hold the bounties");
        assertEq(token.balanceOf(handler.recipient()), handler.paidToRecipient(), "recipient");
        address[] memory stakers = handler.stakers();
        uint256 stakerBalance;
        for (uint256 i; i < stakers.length; ++i) {
            stakerBalance += token.balanceOf(stakers[i]);
        }
        assertEq(
            stakerBalance + handler.deposited(),
            handler.initialStakerBalance() + handler.paidToOwners(),
            "stakers hold their funding minus deposits plus withdrawals"
        );
    }

    /// @notice 7. Every entry activates exactly `activationDelay` (read from the registry) after
    /// its registration; its exit never moves later (the earliest of its requested exit, slash
    /// block and recovery R); a confirmed exit is at or before the landed snapshot at its
    /// confirmation.
    function invariant_activationAndExitTiming() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        for (uint256 i; i < count; ++i) {
            _assertTiming(i);
        }
    }

    /// @notice 8. Entries never exceed the 4096 slots; the slot count is the model's; every free
    /// slot is a distinct released bond, reused most recently released first.
    function invariant_entriesStayWithinTheCap() external view {
        _assertModelHeld();
        assertEq(registry.MAX_ENTRIES(), CAPACITY, "4096 slots");
        uint256 count = registry.entryCount();
        assertLe(count, CAPACITY, "entries within the cap");
        assertEq(count, handler.slotCount(), "modelled slot count");
        _assertFreeSlots(count);
    }
}
