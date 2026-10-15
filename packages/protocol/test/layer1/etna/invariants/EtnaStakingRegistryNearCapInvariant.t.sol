// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryInvariantBase } from "./EtnaStakingRegistryInvariant.t.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title EtnaStakingRegistryNearCapInvariantBase
/// @notice Prefills the registry to three registrations short of `MAX_ENTRIES`, so runs fill
/// it, hit `RegistryFull`, free slots and reuse them at the cap.
/// @dev The prefill makes real registrations through the handler, so the model, ghost tree,
/// queues and checkpoint copies cover every entry. Per-call checks stay cheap: they compare the
/// root with the handler's incremental ghost tree and only the slots and pubkeys a run touched
/// with the model.
abstract contract EtnaStakingRegistryNearCapInvariantBase is EtnaStakingRegistryInvariantBase {
    /// @dev The first prefilled pubkey, above the handler's pool pubkeys.
    uint256 internal constant PREFILL_KEY = 0x10000;

    uint256 internal maxEntries;

    function setUp() public virtual override {
        super.setUp();
        maxEntries = registry.MAX_ENTRIES();
        vm.pauseGasMetering();
        handler.prefill(maxEntries - 3, PREFILL_KEY);
        vm.resumeGasMetering();

        assertEq(registry.entryCount(), maxEntries - 3, "prefilled");
        assertEq(registry.entriesRoot(), _naiveRootOfEntries(), "prefilled root");
        _assertModelHeld();
    }

    /// @dev Snapshots of 4093 or more entries keep their count and root only.
    function _keepSnapshotLeaves() internal pure override returns (bool) {
        return false;
    }
}

/// @title EtnaStakingRegistryNearCapInvariantTest
/// @notice Registry invariants 2 to 6 near and at `MAX_ENTRIES`.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingRegistryNearCapInvariantTest is EtnaStakingRegistryNearCapInvariantBase {
    /// @notice 6. Entries never exceed `MAX_ENTRIES`: a registration at the cap reverts
    /// `RegistryFull` unless a slot is free, the most recently freed slot is reused first, every
    /// free slot is a distinct withdrawn bond, and no two entries whose exits are not yet
    /// effective share a pubkey.
    function invariant_entriesNeverExceedTheCap() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        assertLe(count, maxEntries, "entries within the cap");
        assertEq(count, handler.slotCount(), "modelled slot count");
        _assertFreeSlots(count);

        // Prefilled pubkeys are distinct and outside the pool, so two live entries can share a
        // pubkey only if a run registered it.
        bytes32[] memory keys = handler.touchedKeys();
        for (uint256 i; i < keys.length; ++i) {
            uint256[] memory holders = handler.keySlots(keys[i]);
            uint256 live;
            for (uint256 j; j < holders.length; ++j) {
                IEtnaStakingRegistry.Entry memory entry = registry.entryAt(holders[j]);
                assertEq(entry.pubkey, keys[i], "modelled pubkey holder");
                if (entry.exitEffectiveL1 > block.number) ++live;
            }
            assertLe(live, 1, "live entries share a pubkey");
        }
    }

    /// @notice 2. Checkpoint blocks strictly increase and a past block's checkpoint, the
    /// prefill's included, never changes.
    function invariant_checkpointHistoryIsImmutable() external view {
        _assertModelHeld();
        _assertCheckpointHistory();
    }

    /// @notice 3. Each checkpoint matches its end-of-block snapshot (count and root of the
    /// modelled entries) after slots are reused at the cap.
    function invariant_snapshotsSurviveSlotReuse() external view {
        _assertModelHeld();
        _assertSnapshots();
    }

    /// @notice 4. Neither churn queue strands requests or admits more than its opened windows
    /// hold, and every touched entry activates and exits within its delays and its queue's
    /// latest window.
    function invariant_churnQueuesNeverStrand() external view {
        _assertModelHeld();
        _assertQueue(ACTIVATION_CHURN_SLOT, handler.activationQueue());
        _assertQueue(EXIT_CHURN_SLOT, handler.exitQueue());
        uint256 activationNext = _load(ACTIVATION_CHURN_SLOT);
        uint256 exitNext = _load(EXIT_CHURN_SLOT);
        uint256[] memory touched = handler.touchedSlots();
        for (uint256 i; i < touched.length; ++i) {
            _assertChurnBounds(
                registry.entryAt(touched[i]), handler.slotAt(touched[i]), activationNext, exitNext
            );
        }
    }

    /// @notice 5. At most one heartbeat per window for every touched holder.
    function invariant_heartbeatsAtMostOncePerWindow() external view {
        _assertModelHeld();
        uint256[] memory touched = handler.touchedSlots();
        for (uint256 i; i < touched.length; ++i) {
            _assertHeartbeats(registry.entryAt(touched[i]), handler.slotAt(touched[i]));
        }
    }

    /// @notice Every touched entry, owner and withdrawn flag matches the model, and so do the
    /// bonded stake and the registry's TAIKO balance.
    function invariant_touchedEntriesMatchTheModel() external view {
        _assertModelHeld();
        uint256[] memory touched = handler.touchedSlots();
        for (uint256 i; i < touched.length; ++i) {
            _assertModelled(touched[i]);
        }
        assertEq(registry.bondedStake(), handler.bondedStake(), "bonded stake");
        assertEq(token.balanceOf(address(registry)), handler.stakedBalance(), "staked TAIKO");
    }
}

/// @title EtnaStakingRegistryNearCapRootInvariantTest
/// @notice Registry invariant 1 near and at `MAX_ENTRIES`, with one full recompute per run.
/// @dev A separate contract, so only this one campaign pays for the 4096-leaf recompute.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingRegistryNearCapRootInvariantTest is EtnaStakingRegistryNearCapInvariantBase {
    /// @notice 1. After every call `entriesRoot()` equals the root of the handler's ghost tree
    /// over the modelled entries, and the latest checkpoint holds it and the entry count.
    function invariant_entriesRootMatchesTheGhostTree() external view {
        _assertModelHeld();
        bytes32 root = registry.entriesRoot();
        assertEq(root, handler.ghostRoot(), "entriesRoot is the modelled root");
        IEtnaStakingRegistry.Checkpoint memory latest =
            registry.checkpointAt(registry.checkpointCount() - 1);
        assertEq(latest.count, registry.entryCount(), "the latest checkpoint counts every slot");
        assertEq(latest.entriesRoot, root, "the latest checkpoint holds the current root");
    }

    /// @notice 1. Once per run, the naive root over `entryAt` of every slot equals
    /// `entriesRoot()` and the modelled root, so no entry, touched or not, left the model.
    function afterInvariant() external view {
        bytes32 root = _naiveRootOfEntries();
        assertEq(registry.entriesRoot(), root, "entriesRoot is the naive root");
        assertEq(handler.ghostRoot(), root, "every entry matches the model");
    }
}
