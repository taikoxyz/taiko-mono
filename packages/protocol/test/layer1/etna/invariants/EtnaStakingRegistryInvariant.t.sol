// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockCommitteeInbox } from "../MockCommitteeInbox.sol";
import { EtnaStakingRegistryHandler } from "./EtnaStakingRegistryHandler.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title EtnaStakingRegistryInvariantBase
/// @notice Deploys a churn-limited registry behind a proxy, funds four stakers and targets the
/// handler's actions; holds the checks the registry campaigns share.
/// @dev Churn windows of 100 blocks with a capacity of max(10% of the current active stake, one minimum
/// stake) defer most activations and exits, and the 12-block heartbeat window rolls over many
/// times within a run. Foundry runs a separate campaign per invariant function and asserts only
/// that function in it, so every invariant also asserts that the handler saw no violation of
/// any kind: each campaign enforces every per-call check.
abstract contract EtnaStakingRegistryInvariantBase is CommonTest {
    uint256 internal constant MIN_STAKE = 1000 ether;
    uint64 internal constant ACTIVATION_DELAY = 10;
    uint64 internal constant EXIT_DELAY = 20;
    uint64 internal constant WITHDRAWAL_DELAY = 30;
    uint64 internal constant HEARTBEAT_WINDOW = 12;
    uint64 internal constant CHURN_WINDOW = 100;
    uint16 internal constant CHURN_BPS = 1000;
    uint64 internal constant START_BLOCK = 1001;
    uint64 internal constant NO_EXIT = type(uint64).max;

    /// @dev The ERC-7201 base slot `R` of the registry storage and the `RegistryStorage` fields
    /// read directly: `freeSlots` (R + 6) and the activation and exit queues' `nextWindow`
    /// (R + 8, R + 10), each followed by its `remaining`.
    uint256 internal constant REGISTRY_BASE =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;
    uint256 internal constant FREE_SLOTS_SLOT = REGISTRY_BASE + 6;
    uint256 internal constant ACTIVATION_CHURN_SLOT = REGISTRY_BASE + 8;
    uint256 internal constant EXIT_CHURN_SLOT = REGISTRY_BASE + 10;

    TestERC20 internal token;
    EtnaStakingRegistry internal registry;
    EtnaStakingRegistryHandler internal handler;

    function setUp() public virtual override {
        super.setUp();
        vm.roll(START_BLOCK);
        token = new TestERC20("Taiko Token", "TAIKO");
        registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(
                        new EtnaStakingRegistry(
                            address(token),
                            MIN_STAKE,
                            ACTIVATION_DELAY,
                            EXIT_DELAY,
                            WITHDRAWAL_DELAY,
                            HEARTBEAT_WINDOW,
                            CHURN_WINDOW,
                            CHURN_BPS,
                            MIN_STAKE
                        )
                    ),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(0)))
                )
            )
        );

        MockCommitteeInbox committeeInbox = new MockCommitteeInbox(address(registry));
        vm.prank(registry.owner());
        registry.bindInbox(address(committeeInbox));

        address[] memory stakers = new address[](4);
        (stakers[0], stakers[1], stakers[2], stakers[3]) = (Alice, Bob, Carol, David);
        for (uint256 i; i < stakers.length; ++i) {
            token.mint(stakers[i], 1e9 * MIN_STAKE);
            vm.prank(stakers[i]);
            token.approve(address(registry), type(uint256).max);
        }
        bytes32[] memory pubkeys = new bytes32[](8);
        for (uint256 i; i < pubkeys.length; ++i) {
            pubkeys[i] = bytes32(0xe7a0 + i);
        }
        handler = new EtnaStakingRegistryHandler(
            registry, token, stakers, pubkeys, _keepSnapshotLeaves()
        );

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = EtnaStakingRegistryHandler.register.selector;
        selectors[1] = EtnaStakingRegistryHandler.heartbeat.selector;
        selectors[2] = EtnaStakingRegistryHandler.requestExit.selector;
        selectors[3] = EtnaStakingRegistryHandler.withdraw.selector;
        selectors[4] = EtnaStakingRegistryHandler.advanceBlocks.selector;
        selectors[5] = EtnaStakingRegistryHandler.advanceToWithdrawal.selector;
        selectors[6] = EtnaStakingRegistryHandler.settleCommittee.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /// @notice Exercises blocked withdrawal, settled withdrawal, and slot reuse in the model.
    function test_handler_SettlementEnablesWithdrawalAndReuse() external {
        handler.register(0, 33, 1);
        handler.requestExit(1, 1);
        handler.advanceToWithdrawal(0);
        handler.withdraw(1, 1);
        assertEq(handler.unsettledWithdrawalRejections(), 1);
        assertEq(handler.withdrawals(), 0);
        handler.settleCommittee(0);
        handler.withdraw(1, 1);
        assertEq(handler.withdrawals(), 1);
        handler.register(0, 65, 1);
        assertEq(handler.reuses(), 1);
        _assertModelHeld();
    }

    /// @dev Whether the handler keeps every snapshot's leaves, which only pays off with few slots.
    function _keepSnapshotLeaves() internal pure virtual returns (bool) {
        return true;
    }

    // ---------------------------------------------------------------
    // Shared checks
    // ---------------------------------------------------------------

    /// @dev Invariant 2: checkpoint blocks strictly increase, none lies ahead, and each equals
    /// the handler's copy taken when its block last changed an entry. A past block's copy is
    /// frozen, so equality means its checkpoint never changed afterwards.
    function _assertCheckpointHistory() internal view {
        IEtnaStakingRegistry.Checkpoint[] memory copies = handler.checkpoints();
        uint256 count = registry.checkpointCount();
        assertEq(count, copies.length, "one checkpoint per block that changed an entry");
        uint64 previous;
        for (uint256 i; i < count; ++i) {
            IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(i);
            if (i != 0) assertGt(checkpoint.l1Block, previous, "strictly increasing l1Block");
            previous = checkpoint.l1Block;
            assertLe(checkpoint.l1Block, block.number, "no checkpoint of a future block");
            assertEq(checkpoint.l1Block, copies[i].l1Block, "checkpoint l1Block is final");
            assertEq(checkpoint.count, copies[i].count, "checkpoint count is final");
            assertEq(checkpoint.entriesRoot, copies[i].entriesRoot, "checkpoint root is final");
        }
    }

    /// @dev Invariant 3: every checkpoint matches the snapshot of the modelled entries at the
    /// end of its block (count and root), however often its slots were reused since.
    function _assertSnapshots() internal view {
        EtnaStakingRegistryHandler.Snapshot[] memory snapshots = handler.snapshots();
        uint256 count = registry.checkpointCount();
        assertEq(snapshots.length, count, "one snapshot per checkpoint");
        for (uint256 i; i < count; ++i) {
            IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(i);
            assertEq(snapshots[i].count, checkpoint.count, "snapshot length equals the count");
            assertEq(snapshots[i].root, checkpoint.entriesRoot, "snapshot root equals the root");
        }
    }

    /// @dev Invariant 4, queue part: only scheduling calls moved the queue, its spare capacity is
    /// that of the windows its busy period opened minus the period's stake, and its latest window
    /// is bounded by that stake (tight) and by all requests so far (loose); see
    /// `EtnaStakingRegistryHandler._schedule`.
    function _assertQueue(
        uint256 _slot,
        EtnaStakingRegistryHandler.Queue memory _queue
    )
        internal
        view
    {
        uint256 nextWindow = _load(_slot);
        assertEq(nextWindow, _queue.nextWindow, "only register and requestExit move a queue");
        if (nextWindow == 0) return;
        assertLe(_queue.busyAmount, _queue.busyCapacity, "the opened windows hold the stake");
        assertEq(
            _load(_slot + 1),
            _queue.busyCapacity - _queue.busyAmount,
            "the queue's spare capacity is its opened windows' minus its stake"
        );
        uint256 last = nextWindow - 1;
        uint256 floor = handler.minChurnPerWindow();
        assertGe(last, _queue.busyStart, "the queue ends at or after its busy period's start");
        assertLt(
            (last - _queue.busyStart) * floor,
            _queue.busyAmount,
            "the queue ends within the stake of its busy period"
        );
        assertLe(
            last,
            _queue.maxEarliestWindow + _ceilDiv(_queue.totalAmount, floor),
            "the queue ends within the latest earliest window plus all scheduled stake"
        );
    }

    /// @dev Invariant 4, entry part: an entry activates no earlier than its delay and no later
    /// than the activation queue's latest window allows; it exits no earlier than both exit
    /// delays and no later than its own activation or the exit queue's latest window allows.
    function _assertChurnBounds(
        IEtnaStakingRegistry.Entry memory _entry,
        EtnaStakingRegistryHandler.Slot memory _slot,
        uint256 _activationNext,
        uint256 _exitNext
    )
        internal
        pure
    {
        uint256 earliestActivation = _slot.registeredAt + ACTIVATION_DELAY;
        assertGe(_entry.activeFromL1, earliestActivation, "activation before its delay");
        assertLe(
            _entry.activeFromL1,
            _max(earliestActivation, _activationNext * CHURN_WINDOW),
            "activation beyond the activation queue"
        );
        if (_entry.exitEffectiveL1 == NO_EXIT) return;
        uint256 afterActivation = uint256(_entry.activeFromL1) + EXIT_DELAY;
        assertGe(
            _entry.exitEffectiveL1, _slot.exitRequestedAt + EXIT_DELAY, "exit before its delay"
        );
        assertGe(_entry.exitEffectiveL1, afterActivation, "exit before the delay after activation");
        assertLe(
            _entry.exitEffectiveL1,
            _max(afterActivation, _exitNext * CHURN_WINDOW),
            "exit beyond the exit queue"
        );
    }

    /// @dev Invariant 5, per holder: the sequence counts the holder's accepted heartbeats (zero
    /// again after a reuse), and `lastHeartbeatAt` is the window start of the last one, which
    /// the holder sent before its exit took effect.
    function _assertHeartbeats(
        IEtnaStakingRegistry.Entry memory _entry,
        EtnaStakingRegistryHandler.Slot memory _slot
    )
        internal
        pure
    {
        assertEq(_entry.lastHeartbeatSeq, _slot.heartbeats, "seq counts the accepted heartbeats");
        if (_slot.heartbeats == 0) {
            assertEq(_entry.lastHeartbeatAt, 0, "no heartbeat, no window");
            return;
        }
        assertEq(
            _entry.lastHeartbeatAt,
            _slot.lastHeartbeatBlock / HEARTBEAT_WINDOW * HEARTBEAT_WINDOW,
            "lastHeartbeatAt is the last heartbeat's window start"
        );
        assertLt(_slot.lastHeartbeatBlock, _entry.exitEffectiveL1, "heartbeat after the exit");
        assertGe(_slot.lastHeartbeatBlock, _slot.registeredAt, "heartbeat of a former holder");
    }

    /// @dev Invariant 6, free slots: the registry's free list is the model's, most recently freed
    /// last, and holds distinct withdrawn bonds.
    function _assertFreeSlots(uint256 _entryCount) internal view {
        uint256[] memory free = handler.freeSlots();
        assertEq(registry.freeSlotCount(), free.length, "free slot count");
        uint256 base = uint256(keccak256(abi.encode(FREE_SLOTS_SLOT)));
        for (uint256 i; i < free.length; ++i) {
            assertEq(_load(base + i), free[i], "free slots in the order they were freed");
            assertLt(free[i], _entryCount, "a free slot is a used slot");
            assertTrue(registry.isWithdrawn(free[i]), "a free slot is a withdrawn bond");
            for (uint256 j; j < i; ++j) {
                assertNotEq(free[i], free[j], "a free slot appears once");
            }
        }
    }

    /// @dev Checks the registry's entry, owner and withdrawn flag of `_bondId` against the model.
    function _assertModelled(uint256 _bondId) internal view {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        EtnaStakingRegistryHandler.Slot memory slot = handler.slotAt(_bondId);
        assertEq(entry.pubkey, slot.entry.pubkey, "modelled pubkey");
        assertEq(entry.effStake, slot.entry.effStake, "modelled stake");
        assertEq(entry.activeFromL1, slot.entry.activeFromL1, "modelled activation");
        assertEq(entry.exitEffectiveL1, slot.entry.exitEffectiveL1, "modelled exit");
        assertEq(entry.lastHeartbeatAt, slot.entry.lastHeartbeatAt, "modelled heartbeat window");
        assertEq(entry.lastHeartbeatSeq, slot.entry.lastHeartbeatSeq, "modelled heartbeat seq");
        assertEq(entry.rewardRecipient, slot.entry.rewardRecipient, "modelled reward recipient");
        assertTrue(entry.rewardRecipient != address(0), "nonzero reward recipient");
        assertEq(registry.bondOwnerOf(_bondId), slot.owner, "modelled owner");
        assertEq(registry.isWithdrawn(_bondId), slot.withdrawn, "modelled withdrawal");
    }

    /// @dev Asserts that the handler recorded no broken property and no call whose outcome
    /// (success, bond id or custom error) differed from the model's prediction.
    function _assertModelHeld() internal view {
        assertEq(registry.activeStake(), handler.activeStake(), "independent active interval sum");
        uint256 root = uint256(1) << 64;
        assertEq(
            _load(uint256(keccak256(abi.encode(root, REGISTRY_BASE + 13)))),
            handler.stakedBalance(),
            "activation root is all unwithdrawn stake"
        );
        assertEq(
            _load(uint256(keccak256(abi.encode(root, REGISTRY_BASE + 14)))),
            handler.stakedBalance() - handler.bondedStake(),
            "exit root is requested unwithdrawn stake"
        );
        assertEq(
            MockCommitteeInbox(registry.inbox()).activeCommitteeSnapshot(),
            handler.ghostActiveCommitteeSnapshot(),
            "independent settled snapshot model"
        );
        for (uint8 p; p <= uint8(type(EtnaStakingRegistryHandler.Property).max); ++p) {
            EtnaStakingRegistryHandler.Property property = EtnaStakingRegistryHandler.Property(p);
            assertEq(handler.violations(property), 0, handler.firstViolation(property));
        }
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

    /// @notice Returns one registry entry leaf and its current active stake contribution.
    /// @dev A separate call frame bounds temporary Entry/ABI allocations per leaf. Otherwise
    /// the near-cap recompute retains thousands of those allocations and pays quadratic memory
    /// expansion costs before reducing the tree, exceeding the test block's gas limit.
    /// @param _index The entry index.
    /// @return leaf_ The independently encoded leaf hash.
    /// @return active_ The independently derived current interval contribution.
    function entryLeafAt(uint256 _index) external view returns (bytes32 leaf_, uint256 active_) {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_index);
        // A withdrawn entry has already exited, so the interval alone excludes it.
        if (entry.activeFromL1 <= block.number && block.number < entry.exitEffectiveL1) {
            active_ = entry.effStake;
        }
        leaf_ = keccak256(
            abi.encode(
                bytes32("ETNA_REG_ENTRY_V2"),
                _index,
                entry.pubkey,
                entry.effStake,
                uint256(entry.activeFromL1),
                uint256(entry.exitEffectiveL1),
                uint256(entry.lastHeartbeatAt),
                uint256(entry.lastHeartbeatSeq),
                entry.rewardRecipient
            )
        );
    }

    /// @dev Independently recomputes both invariants over every slot in one bounded-memory
    /// pass. Re-reading all model entries separately would exceed the existing 80M test block
    /// budget when combined with the 4096-leaf root and the fuzzed actions.
    function _naiveRootAndActiveStake() internal view returns (bytes32 root_, uint256 active_) {
        uint256 count = registry.entryCount();
        bytes32[] memory leaves = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 contribution;
            (leaves[i], contribution) = this.entryLeafAt(i);
            active_ += contribution;
        }
        root_ = _naiveRoot(leaves);
    }

    /// @dev The naive root over independently encoded V2 entry leaves for every slot.
    function _naiveRootOfEntries() internal view returns (bytes32 root_) {
        (root_,) = _naiveRootAndActiveStake();
    }

    function _load(uint256 _slot) internal view returns (uint256) {
        return uint256(vm.load(address(registry), bytes32(_slot)));
    }

    function _ceilDiv(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a == 0 ? 0 : (_a - 1) / _b + 1;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}

/// @title EtnaStakingRegistryInvariantTest
/// @notice Registry invariants over four stakers sharing eight pubkeys, recomputing every
/// entry after every call.
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingRegistryInvariantTest is EtnaStakingRegistryInvariantBase {
    /// @notice 1. `entriesRoot()` equals the naive zero-padded pairwise tree over
    /// `LibEntriesTree.leaf(i, entryAt(i))` for every slot, and the latest checkpoint holds that
    /// root and the entry count.
    function invariant_entriesRootEqualsTheNaiveTree() external view {
        _assertModelHeld();
        bytes32 root = _naiveRootOfEntries();
        assertEq(registry.entriesRoot(), root, "entriesRoot is the naive root");
        uint256 count = registry.entryCount();
        uint256 checkpointCount = registry.checkpointCount();
        if (count == 0) {
            assertEq(checkpointCount, 0, "no checkpoint before the first entry");
            return;
        }
        IEtnaStakingRegistry.Checkpoint memory latest = registry.checkpointAt(checkpointCount - 1);
        assertEq(latest.count, count, "the latest checkpoint counts every slot");
        assertEq(latest.entriesRoot, root, "the latest checkpoint holds the current root");
    }

    /// @notice 2. Checkpoint blocks strictly increase and a past block's checkpoint never
    /// changes: only the current block's may be overwritten.
    function invariant_checkpointHistoryIsImmutable() external view {
        _assertModelHeld();
        _assertCheckpointHistory();
    }

    /// @notice 3. Each checkpoint matches the snapshot of every modelled entry taken at the end
    /// of its block: the snapshot's length is the checkpoint's count and its naive root the
    /// checkpoint's root, even after later registrations reuse withdrawn slots.
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

    /// @notice 4. Neither churn queue strands requests: each queue ends within the stake its
    /// current busy period scheduled (request blocks and amounts only) and never admits more
    /// than the windows it opened hold; every entry activates and exits within its delays and
    /// its queue's latest window.
    function invariant_churnQueuesNeverStrand() external view {
        _assertModelHeld();
        _assertQueue(ACTIVATION_CHURN_SLOT, handler.activationQueue());
        _assertQueue(EXIT_CHURN_SLOT, handler.exitQueue());
        uint256 activationNext = _load(ACTIVATION_CHURN_SLOT);
        uint256 exitNext = _load(EXIT_CHURN_SLOT);
        uint256 count = registry.entryCount();
        for (uint256 i; i < count; ++i) {
            _assertChurnBounds(registry.entryAt(i), handler.slotAt(i), activationNext, exitNext);
        }
    }

    /// @notice 5. At most one heartbeat per window: each holder's sequence counts its accepted
    /// heartbeats and restarts on reuse, `lastHeartbeatAt` never decreases, no two accepted
    /// heartbeats share a window and none is accepted once the exit is effective.
    function invariant_heartbeatsAtMostOncePerWindow() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        for (uint256 i; i < count; ++i) {
            _assertHeartbeats(registry.entryAt(i), handler.slotAt(i));
        }
    }

    /// @notice 6. Entries never exceed `MAX_ENTRIES`; every free slot is a distinct withdrawn
    /// bond, reused most recently freed first; no two entries whose exits are not yet effective
    /// share a pubkey.
    function invariant_entriesStayWithinTheCap() external view {
        _assertModelHeld();
        uint256 count = registry.entryCount();
        assertLe(count, registry.MAX_ENTRIES(), "entries within the cap");
        assertEq(count, handler.slotCount(), "modelled slot count");
        _assertFreeSlots(count);

        IEtnaStakingRegistry.Entry[] memory entries = new IEtnaStakingRegistry.Entry[](count);
        for (uint256 i; i < count; ++i) {
            entries[i] = registry.entryAt(i);
            if (entries[i].exitEffectiveL1 <= block.number) continue;
            for (uint256 j; j < i; ++j) {
                if (entries[j].exitEffectiveL1 <= block.number) continue;
                assertNotEq(entries[i].pubkey, entries[j].pubkey, "live entries share a pubkey");
            }
        }
    }

    /// @notice Every entry, owner and withdrawn flag matches the model, and so do the bonded
    /// stake and the registry's TAIKO balance. The handler's incremental ghost tree, which the
    /// near-cap campaign checks the root against, is the naive tree over the modelled entries.
    function invariant_entriesAndStakeMatchTheModel() external view {
        _assertModelHeld();
        assertEq(handler.activeStake(), handler.naiveActiveStake(), "naive model interval sum");
        uint256 count = registry.entryCount();
        bytes32[] memory leaves = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            _assertModelled(i);
            leaves[i] = LibEntriesTree.leaf(i, handler.slotAt(i).entry);
        }
        assertEq(handler.ghostRoot(), _naiveRoot(leaves), "the ghost tree is the naive tree");
        assertEq(registry.bondedStake(), handler.bondedStake(), "bonded stake");
        assertEq(token.balanceOf(address(registry)), handler.stakedBalance(), "staked TAIKO");
    }
}
