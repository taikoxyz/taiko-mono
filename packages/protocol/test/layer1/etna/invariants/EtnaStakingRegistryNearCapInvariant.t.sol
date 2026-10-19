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
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingRegistryNearCapRootInvariantTest is EtnaStakingRegistryNearCapInvariantBase {
    function test_afterInvariant_RecomputesShrunkActiveStakeSequence() external {
        // Exact shrunk sequence from the active-stake full L1 campaign. Separate all-slot
        // model sums plus the root used to exhaust the unchanged 80M test block budget.
        handler.register(
            15,
            807,
            30_584_289_561_776_583_941_746_202_149_392_733_863_213_593_424_061_743_603_444_173_643_665_275
        );
        handler.requestExit(470_511_122_643_028_811, 10_174_662_948_016_785_898_493_330_045);
        handler.advanceToWithdrawal(278);
        handler.advanceToWithdrawal(6_537_125);
        handler.register(
            42_074_452_920_338_049_047_454_362_924_523,
            1_417_999_511_838_388_177_736_846,
            10_112_886_773_944_299_088_360_885_301_773_434_294_761_410_734_445_998_197_093_458_047_207_225_175_761
        );
        handler.advanceToWithdrawal(7_088_922_887);
        handler.advanceToWithdrawal(
            35_764_698_360_094_278_603_359_650_114_301_029_149_450_104_599_126_940_763_648_699_185_560_379_923_514
        );
        handler.register(
            462,
            53_570_214_247_414_036_950_511,
            375_456_856_308_074_133_127_107_487_055_625_362_537_783_880_987_133_921_535_883_070
        );
        handler.advanceBlocks(5639);
        handler.advanceToWithdrawal(
            68_934_948_763_163_461_588_092_822_426_762_078_374_572_717_053_448_644_877_002_161_169_584_035_944_111
        );
        handler.advanceBlocks(
            115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
        );
        this.afterInvariant();
    }

    function test_afterInvariant_RecomputesAfterWithdrawalAdvance() external {
        // The shrunk sequence from the original full L1 MemoryOOG failure.
        handler.advanceToWithdrawal(
            189_689_194_050_321_522_700_280_257_463_889_328_031_035_485_734_358_930_318_117_075_242
        );
        this.afterInvariant();
    }

    function test_afterInvariant_RecomputesAllEntriesAtCapacity() external {
        vm.pauseGasMetering();
        handler.prefill(3, PREFILL_KEY + maxEntries - 3);
        vm.resumeGasMetering();
        assertEq(registry.entryCount(), 4096);
        this.afterInvariant();
    }

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
        (bytes32 root, uint256 active) = _naiveRootAndActiveStake();
        assertEq(registry.activeStake(), active, "all-slot active recompute");
        assertEq(handler.activeStake(), active, "prefill model matches naive");
        assertEq(registry.entriesRoot(), root, "entriesRoot is the naive root");
        assertEq(handler.ghostRoot(), root, "every entry matches the model");
    }
}
