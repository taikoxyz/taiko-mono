// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryInvariantBase } from "./EtnaStakingRegistryInvariant.t.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title EtnaStakingRegistryNearCapInvariantBase
/// @notice Prefills the registry with 4,095 real registrations, one short of the 4,096 slots, so
/// runs take the last slot, hit `RegistryFull`, release slots and reuse them at the cap.
/// @dev The prefill registers through the handler in four blocks (four checkpoints), so the
/// model, ghost tree and checkpoint copies cover every entry. Four prefilled bonds then request
/// their exits and two of those are confirmed, so a run can release a slot within a few calls.
/// Per-call checks stay cheap: the handler compares every root with its incremental ghost tree,
/// and the invariants check only the slots a run touched against the model.
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
    /// @notice The 4,096th registration takes the last slot, the next one reverts
    /// `RegistryFull`, and after a release the next registration reuses the released slot at the
    /// cap. With the released slot present and again after the reuse, the naive root over all
    /// 4,096 raw entries equals `entriesRoot()` and the ghost tree's root.
    function test_handler_FillsReleasesAndReusesAtTheCap() external {
        handler.register(0, 0, 0);
        assertEq(registry.entryCount(), CAPACITY, "the 4096th registration");
        assertEq(handler.capFills(), 1, "cap filled");
        handler.register(1, 1, 0);
        assertEq(
            handler.rejections(0, IEtnaStakingRegistry.RegistryFull.selector), 1, "registry full"
        );
        handler.advanceToWithdrawal(0);
        handler.withdraw(0);
        assertEq(handler.withdrawals(), 1, "a slot released");
        assertEq(registry.freeSlotCount(), 1, "one free slot at the cap");
        _assertNaiveRoot("at the cap with a free slot");
        handler.register(2, 2, 0);
        assertEq(handler.reusesAtCap(), 1, "the released slot reused at the cap");
        assertEq(registry.entryCount(), CAPACITY, "still 4096 slots");

        _assertNaiveRoot("at the cap after the reuse");
        _assertModelHeld();
    }

    /// @notice 8. Entries never exceed the 4,096 slots: a registration at the cap reverts
    /// `RegistryFull` unless a slot is free, the most recently released slot is reused first,
    /// and every free slot is a distinct released bond. Every slot and key a run touched matches
    /// the model, and the registry's balance is the modelled stake. `entriesRoot()` is the ghost
    /// tree's root over all modelled entries, and the latest checkpoint holds it and the count.
    function invariant_entriesStayWithinTheCap() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        assertLe(count, CAPACITY, "entries within the cap");
        assertEq(count, handler.slotCount(), "modelled slot count");
        _assertFreeSlots(count);

        uint256[] memory touched = handler.touchedSlots();
        for (uint256 i; i < touched.length; ++i) {
            _assertModelled(touched[i]);
        }
        address[] memory keys = handler.touchedKeys();
        for (uint256 i; i < keys.length; ++i) {
            assertTrue(registry.keyUsed(keys[i]), "a registered key stays used");
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
    /// modelled entries) after slots are released and reused at the cap.
    function invariant_snapshotsSurviveSlotReuse() external view {
        _assertModelHeld();
        _assertSnapshots();
    }

    /// @notice 7. Every touched entry activates exactly `activationDelay` after its
    /// registration, its exit never moves later, and a confirmed exit is covered by the snapshot
    /// of its confirmation, also at the cap.
    function invariant_activationAndExitTiming() external view {
        _assertModelHeld();
        uint256[] memory touched = handler.touchedSlots();
        for (uint256 i; i < touched.length; ++i) {
            _assertTiming(touched[i]);
        }
    }
}
