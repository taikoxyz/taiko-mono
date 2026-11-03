// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryInvariantBase } from "./EtnaStakingRegistryInvariant.t.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title EtnaStakingRegistryNearCapInvariantBase
/// @notice Prefills the registry with 4,095 real registrations, one short of the 4,096 slots, so
/// runs take the last slot, then admit only stakes above the smallest slot value, displacing its
/// bond, and reuse withdrawn bonds' slots at the cap.
/// @dev The prefill registers through the handler in four blocks (four checkpoints), so the
/// model, ghost tree and checkpoint copies cover every entry. Four prefilled bonds then request
/// their exits and two of those are confirmed, so a run can release a slot within a few calls.
/// Per-call checks stay cheap: the handler compares every root with its incremental ghost tree,
/// and the invariants check only the bonds a run touched against the model.
abstract contract EtnaStakingRegistryNearCapInvariantBase is EtnaStakingRegistryInvariantBase {
    /// @dev The first prefilled consensus key, outside the handler's pool.
    uint256 internal constant PREFILL_KEY = 0x10000;
    uint256 internal constant PREFILL_BLOCKS = 4;
    /// @dev Registrations per `prefill` call: one call frame's memory must stay within the
    /// transaction gas cap.
    uint256 internal constant PREFILL_CALL = 128;
    /// @dev Prefilled bonds `0 .. PREPARED_EXITS - 1` request their exits; the first half is
    /// confirmed.
    uint256 internal constant PREPARED_EXITS = 4;

    function setUp() public virtual override {
        super.setUp();
        vm.pauseGasMetering();
        uint256 total = CAPACITY - 1;
        uint256 done;
        for (uint256 i; i < PREFILL_BLOCKS; ++i) {
            uint256 end = done + (total - done) / (PREFILL_BLOCKS - i);
            while (done < end) {
                uint256 count = end - done < PREFILL_CALL ? end - done : PREFILL_CALL;
                handler.prefill(count, PREFILL_KEY + done);
                done += count;
            }
            vm.roll(block.number + 1);
        }
        vm.roll(block.number + registry.activationDelay());
        for (uint256 b; b < PREPARED_EXITS; ++b) {
            handler.requestExitOf(b);
        }
        vm.roll(block.number + registry.exitDelay());
        handler.settle(0);
        for (uint256 b; b < PREPARED_EXITS / 2; ++b) {
            handler.confirmExitOf(b);
        }
        vm.resumeGasMetering();

        assertEq(registry.entryCount(), CAPACITY - 1, "prefilled");
        assertEq(registry.checkpointCount(), PREFILL_BLOCKS + 1, "prefill and exit checkpoints");
        assertEq(handler.confirmations(), PREPARED_EXITS / 2, "prepared confirmations");
        vm.pauseGasMetering();
        bytes32 root = _naiveRootOfEntries();
        vm.resumeGasMetering();
        assertEq(registry.entriesRoot(), root, "prefilled root");
        assertEq(handler.ghostRoot(), root, "the ghost tree is the naive tree");
        _assertModelHeld();
    }

    /// @dev Snapshots of 4,095 or more entries keep their count and root only.
    function _keepSnapshotLeaves() internal pure override returns (bool) {
        return false;
    }
}

/// @title EtnaStakingRegistryNearCapInvariantTest
/// @notice Registry invariants near and at the 4,096-slot cap.
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingRegistryNearCapInvariantTest is EtnaStakingRegistryNearCapInvariantBase {
    /// @notice The 4,096th registration takes the last slot. With every slot at the minimum
    /// stake, a minimum registration reverts `StakeTooLow` and a double one displaces the bond in
    /// slot 0; after bond 1 is withdrawn, the next minimum registration takes its emptied slot.
    /// With the slot empty and again after it is taken, the naive root over all 4,096 raw entries
    /// equals `entriesRoot()` and the ghost tree's root.
    function test_handler_FillsDisplacesAndReusesAtTheCap() external {
        handler.register(0, 0, 0);
        assertEq(registry.entryCount(), CAPACITY, "the 4096th registration");
        assertEq(handler.capFills(), 1, "cap filled");
        handler.register(1, 1, 0);
        assertEq(
            handler.rejections(0, IEtnaStakingRegistry.StakeTooLow.selector),
            1,
            "not above the smallest value"
        );
        handler.register(2, 2, 1);
        assertEq(handler.displacements(), 1, "a double stake displaces");
        (bool holdsSlot,) = registry.slotOfBond(0);
        assertFalse(holdsSlot, "bond 0 displaced from slot 0");

        handler.advanceToWithdrawal(0);
        address owner = registry.ownerOf(1);
        handler.withdrawOf(1, owner, owner);
        assertEq(handler.withdrawals(), 1, "bond 1 withdrawn");
        (bool occupied,) = registry.bondInSlot(1);
        assertFalse(occupied, "slot 1 emptied");
        _assertNaiveRoot("at the cap with an empty slot");
        handler.register(4, 4, 0);
        assertEq(handler.reuses(), 1, "the emptied slot reused at the cap");
        assertEq(registry.entryCount(), CAPACITY, "still 4096 slots");

        _assertNaiveRoot("at the cap after the reuse");
        _assertModelHeld();
    }

    /// @notice 8. Entries never exceed the 4,096 slots: at the cap a registration takes the
    /// slot of the smallest value (the per-call checks hold the admission threshold to the
    /// model) and the slot holders are the model's. Every bond and key a run touched matches the
    /// model, and the registry's balance is the modelled stake. `entriesRoot()` is the ghost
    /// tree's root over all modelled entries, and the latest checkpoint holds it and the count.
    function invariant_entriesStayWithinTheCap() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        assertLe(count, CAPACITY, "entries within the cap");
        assertEq(count, handler.slotCount(), "modelled slot count");
        _assertSlots(count);

        uint256[] memory touched = handler.touchedBonds();
        for (uint256 i; i < touched.length; ++i) {
            _assertModelled(touched[i]);
        }
        address[] memory keys = handler.touchedKeys();
        for (uint256 i; i < keys.length; ++i) {
            (bool registered, uint256 bondId) = registry.bondForKey(keys[i]);
            assertTrue(registered, "a registered key stays registered");
            assertEq(bondId + 1, handler.keyBond(keys[i]), "the key names its bond");
        }
        assertEq(token.balanceOf(address(registry)), handler.staked(), "modelled stake");

        bytes32 root = registry.entriesRoot();
        assertEq(root, handler.ghostRoot(), "entriesRoot is the modelled root");
        IEtnaStakingRegistry.Checkpoint memory latest =
            registry.checkpointAt(registry.checkpointCount() - 1);
        assertEq(latest.count, count, "the latest checkpoint counts every slot");
        assertEq(latest.entriesRoot, root, "the latest checkpoint holds the current root");
    }

    /// @dev Asserts that the naive root over all raw entries equals `entriesRoot()` and the ghost
    /// tree's root.
    function _assertNaiveRoot(string memory _when) internal {
        vm.pauseGasMetering();
        bytes32 root = _naiveRootOfEntries();
        vm.resumeGasMetering();
        assertEq(
            registry.entriesRoot(), root, string.concat("entriesRoot is the naive root ", _when)
        );
        assertEq(
            handler.ghostRoot(), root, string.concat("the ghost tree is the naive tree ", _when)
        );
    }

    /// @notice 2. One checkpoint per L1 block that changed an entry, the prefill's included;
    /// blocks strictly increase and a past block's checkpoint never changes.
    function invariant_checkpointHistoryIsImmutable() external view {
        _assertModelHeld();
        _assertCheckpointHistory();
    }

    /// @notice 3. Each checkpoint matches its end-of-block snapshot (count and root of the
    /// modelled entries) after bonds are displaced and slots reused at the cap.
    function invariant_snapshotsSurviveSlotReuse() external view {
        _assertModelHeld();
        _assertSnapshots();
    }

    /// @notice 7. Every touched entry activates exactly `activationDelay` after its
    /// registration, its exit never moves later, and a confirmed exit is covered by the snapshot
    /// of its confirmation, also at the cap.
    function invariant_activationAndExitTiming() external view {
        _assertModelHeld();
        uint256[] memory touched = handler.touchedBonds();
        for (uint256 i; i < touched.length; ++i) {
            _assertTiming(touched[i]);
        }
    }
}
