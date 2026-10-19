// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockCommitteeInbox } from "../MockCommitteeInbox.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

/// @title EtnaStakingRegistryHandler
/// @notice Drives an `EtnaStakingRegistry` through `register`, `heartbeat`, `requestExit`,
/// `withdraw` (to the owner) and L1 block advances, and keeps an independent model of its
/// entries, free slots, checkpoints and churn queues for the invariant campaigns.
/// @dev The model predicts each call's outcome before it runs in try/catch: success (and the
/// bond id a registration must take) or the exact custom error. A mismatch or a broken property
/// is recorded as a violation that the invariants assert never happened, so the handler itself
/// never reverts and its ghost state stays exact.
contract EtnaStakingRegistryHandler is CommonBase {
    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    /// @dev The invariant a recorded violation breaks.
    enum Property {
        Root,
        History,
        Churn,
        Heartbeat,
        Slots,
        Model
    }

    /// @dev The model of one slot: its current holder's expected entry and bookkeeping.
    struct Slot {
        IEtnaStakingRegistry.Entry entry;
        address owner;
        bool withdrawn;
        uint64 registeredAt;
        uint64 exitRequestedAt;
        uint64 heartbeats;
        uint64 lastHeartbeatBlock;
    }

    /// @dev The model of one churn queue (see `_schedule`): its `nextWindow`, the current busy
    /// period's first window, stake and opened capacity, and every request so far.
    struct Queue {
        uint256 nextWindow;
        uint256 busyStart;
        uint256 busyAmount;
        uint256 busyCapacity;
        uint256 maxEarliestWindow;
        uint256 totalAmount;
        uint256 deferred;
    }

    /// @dev The entry count and the root over the modelled entries at the end of one
    /// checkpoint's block: refreshed after every change in that block, frozen once it is over.
    struct Snapshot {
        uint32 count;
        bytes32 root;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The ERC-7201 base slot `R` of the registry storage.
    uint256 internal constant REGISTRY_BASE =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;
    /// @dev `RegistryStorage.activationChurn.nextWindow`; `remaining` follows it.
    uint256 internal constant ACTIVATION_CHURN_SLOT = REGISTRY_BASE + 8;
    /// @dev `RegistryStorage.exitChurn.nextWindow`; `remaining` follows it.
    uint256 internal constant EXIT_CHURN_SLOT = REGISTRY_BASE + 10;

    uint64 internal constant NO_EXIT = type(uint64).max;
    uint256 internal constant TREE_DEPTH = 12;
    /// @dev The longest single block advance, so a run stays within a few churn windows.
    uint256 internal constant MAX_JUMP = 10_000;

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    EtnaStakingRegistry public immutable registry;
    TestERC20 public immutable token;
    uint256 public immutable minStake;
    uint256 public immutable maxEntries;
    uint64 public immutable activationDelay;
    uint64 public immutable exitDelay;
    uint64 public immutable withdrawalDelay;
    uint64 public immutable heartbeatWindow;
    uint64 public immutable churnWindow;
    uint16 public immutable churnBps;
    uint256 public immutable minChurnPerWindow;

    address[] internal _stakers;
    bytes32[] internal _pubkeys;

    // ---------------------------------------------------------------
    // Model
    // ---------------------------------------------------------------

    mapping(uint256 bondId => Slot) internal _slots;
    uint256 public slotCount;
    /// @dev The freed slots, most recently freed last.
    uint256[] internal _freeSlots;
    /// @dev The slots whose current entry holds a pubkey.
    mapping(bytes32 pubkey => uint256[] bondIds) internal _keySlots;
    /// @dev The slots whose exit was requested and whose stake was not withdrawn.
    uint256[] internal _pendingWithdrawals;
    uint256 public bondedStake;
    uint256 public stakedBalance;

    /// @dev A full depth-12 tree over the modelled leaves, node `(level, index)` at
    /// `(level << 32) | index`; an unwritten node is the level's zero hash.
    mapping(uint256 node => bytes32 hash) internal _nodes;
    bytes32[TREE_DEPTH + 1] internal _zeros;

    /// @dev The registry's checkpoints as read when their block last changed an entry.
    IEtnaStakingRegistry.Checkpoint[] internal _checkpoints;
    /// @dev One snapshot per checkpoint, same index.
    Snapshot[] internal _snapshots;
    /// @dev With `keepSnapshotLeaves`, the modelled leaves of each snapshot, same index.
    bytes32[][] internal _snapshotLeaves;
    /// @notice Whether every snapshot keeps all its leaves, not only their root; for campaigns
    /// with few slots.
    bool public immutable keepSnapshotLeaves;

    Queue internal _activations;
    Queue internal _exits;

    /// @dev The slots and pubkeys a successful call touched after the prefill.
    uint256[] internal _touchedSlots;
    mapping(uint256 bondId => bool) internal _isTouchedSlot;
    bytes32[] internal _touchedKeys;
    mapping(bytes32 pubkey => bool) internal _isTouchedKey;
    bool internal _prefilling;
    // The setup-only prefill is monotone, equal-sized, never exits, and precedes fuzz actions.
    // Binary search counts untouched originals; touched generations use the naive interval sum.
    uint64[] internal _prefillActivations;

    mapping(Property => uint256) public violations;
    mapping(Property => string) public firstViolation;

    // ---------------------------------------------------------------
    // Statistics
    // ---------------------------------------------------------------

    uint256 public registrations;
    /// @dev Registrations that took a freed slot, which a checkpoint of an earlier block covers.
    uint256 public reuses;
    uint256 public heartbeatsAccepted;
    uint256 public sameWindowHeartbeatsRejected;
    uint256 public exits;
    uint256 public exitsBeforeActivation;
    uint256 public withdrawals;
    uint256 public unsettledWithdrawalRejections;
    uint64 public ghostActiveCommitteeSnapshot;
    uint256 public fullRegistryRejections;
    uint256 public rejections;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        EtnaStakingRegistry _registry,
        TestERC20 _token,
        address[] memory _stakerPool,
        bytes32[] memory _pubkeyPool,
        bool _keepSnapshotLeaves
    ) {
        registry = _registry;
        token = _token;
        keepSnapshotLeaves = _keepSnapshotLeaves;
        minStake = _registry.minStake();
        maxEntries = _registry.MAX_ENTRIES();
        activationDelay = _registry.activationDelay();
        exitDelay = _registry.exitDelay();
        withdrawalDelay = _registry.withdrawalDelay();
        heartbeatWindow = _registry.heartbeatWindow();
        churnWindow = _registry.churnWindow();
        churnBps = _registry.churnBps();
        minChurnPerWindow = _registry.minChurnPerWindow();
        require(churnWindow != 0, "churn-limited registry only");
        _stakers = _stakerPool;
        _pubkeys = _pubkeyPool;
        for (uint256 level = 1; level <= TREE_DEPTH; ++level) {
            _zeros[level] = _hashPair(_zeros[level - 1], _zeros[level - 1]);
        }
    }

    // ---------------------------------------------------------------
    // Fuzzed actions
    // ---------------------------------------------------------------

    /// @notice Registers a pool pubkey (rarely the zero key) for a pool staker with one to three
    /// minimum stakes, sometimes off a multiple and rarely below the minimum. Half of the calls
    /// move on to a pubkey no live entry holds, if there is one.
    function register(uint256 _stakerSeed, uint256 _pubkeySeed, uint256 _amountSeed) external {
        bytes32 pubkey;
        if (_pubkeySeed % 32 != 0) {
            uint256 pick = _pubkeySeed >> 5;
            pubkey = _pubkeys[pick % _pubkeys.length];
            for (
                uint256 i = 1;
                i < _pubkeys.length && _pubkeySeed % 2 == 0 && _keyInUse(pubkey);
                ++i
            ) {
                pubkey = _pubkeys[(pick + i) % _pubkeys.length];
            }
        }
        uint256 amount = minStake - 1;
        if (_amountSeed % 16 != 0) {
            amount = (1 + (_amountSeed >> 8) % 3) * minStake;
            if ((_amountSeed >> 16) % 4 == 0) amount += (_amountSeed >> 24) % minStake;
        }
        _register(_staker(_stakerSeed), pubkey, amount);
    }

    /// @notice Records a heartbeat, mostly by the bond owner of an entry whose exit is not yet
    /// effective.
    function heartbeat(uint256 _bondSeed, uint256 _stakerSeed) external {
        (uint256 bondId, address caller) = _pickBondFor(_bondSeed, _stakerSeed, false);
        bytes4 expected = _expectOwner(bondId, caller);
        if (expected == 0) {
            Slot storage s = _slots[bondId];
            if (block.number >= s.entry.exitEffectiveL1) {
                expected = EtnaStakingRegistry.AlreadyExited.selector;
            } else if (
                s.heartbeats != 0
                    && block.number / heartbeatWindow <= s.lastHeartbeatBlock / heartbeatWindow
            ) {
                expected = EtnaStakingRegistry.HeartbeatAlreadyRecorded.selector;
            }
        }

        vm.prank(caller);
        try registry.heartbeat(bondId) {
            if (expected == 0) _recordHeartbeat(bondId);
            else _violate(Property.Heartbeat, "heartbeat accepted where the model rejects it");
        } catch (bytes memory reason) {
            if (expected == EtnaStakingRegistry.HeartbeatAlreadyRecorded.selector) {
                ++sameWindowHeartbeatsRejected;
            }
            _checkRevert(Property.Heartbeat, expected, reason, "heartbeat");
        }
    }

    /// @notice Requests an exit, mostly by the bond owner of an entry that has not exited.
    function requestExit(uint256 _bondSeed, uint256 _stakerSeed) external {
        (uint256 bondId, address caller) = _pickBondFor(_bondSeed, _stakerSeed, true);
        bytes4 expected = _expectOwner(bondId, caller);
        if (expected == 0 && _slots[bondId].entry.exitEffectiveL1 != NO_EXIT) {
            expected = EtnaStakingRegistry.ExitAlreadyRequested.selector;
        }
        _checkQueue(_exits, EXIT_CHURN_SLOT);

        vm.prank(caller);
        try registry.requestExit(bondId) {
            if (expected == 0) _recordExit(bondId);
            else _violate(Property.Churn, "requestExit accepted where the model rejects it");
        } catch (bytes memory reason) {
            _checkRevert(Property.Churn, expected, reason, "requestExit");
        }
    }

    /// @notice Withdraws a stake to its owner, mostly one whose exit is pending and, if any is,
    /// withdrawable.
    function withdraw(uint256 _bondSeed, uint256 _stakerSeed) external {
        uint256 bondId;
        address caller;
        uint256 pending = _pendingWithdrawals.length;
        if (pending != 0 && _bondSeed % 4 != 0) {
            uint256 start = (_bondSeed >> 2) % pending;
            bondId = _pendingWithdrawals[start];
            for (uint256 i = 1; i < pending && _withdrawableAt(bondId) > block.number; ++i) {
                bondId = _pendingWithdrawals[(start + i) % pending];
            }
            caller = _stakerSeed % 8 == 0 ? _staker(_stakerSeed >> 3) : _slots[bondId].owner;
        } else {
            (bondId, caller) = _pickBond(_bondSeed, _stakerSeed);
        }
        bytes4 expected = _expectWithdraw(bondId, caller);
        uint256 activeBefore = registry.activeStake();
        uint256 balanceBefore = token.balanceOf(caller);
        uint256 checkpointsBefore = registry.checkpointCount();

        vm.prank(caller);
        try registry.withdraw(bondId, caller) {
            if (registry.activeStake() != activeBefore) {
                _violate(Property.Model, "withdrawal changed current active stake");
            }
            if (expected == 0) _recordWithdrawal(bondId, caller, balanceBefore, checkpointsBefore);
            else _violate(Property.Slots, "withdraw accepted where the model rejects it");
        } catch (bytes memory reason) {
            if (expected == EtnaStakingRegistry.CommitteeExitNotSettled.selector) {
                ++unsettledWithdrawalRejections;
            }
            _checkRevert(Property.Slots, expected, reason, "withdraw");
        }
    }

    /// @notice Advances the L1 block: not at all (so several actions share a block), within or
    /// across heartbeat windows, or exactly to a random entry's pending activation or exit
    /// (across churn windows if it has none).
    function advanceBlocks(uint256 _seed) external {
        uint256 mode = _seed % 4;
        uint256 target = block.number;
        if (mode == 1) {
            target += 1 + (_seed >> 2) % heartbeatWindow;
        } else if (mode == 2) {
            target += 1 + (_seed >> 2) % (4 * heartbeatWindow);
        } else if (mode == 3) {
            uint256 milestone;
            if (slotCount != 0) {
                IEtnaStakingRegistry.Entry storage entry = _slots[(_seed >> 3) % slotCount].entry;
                milestone = (_seed >> 2) % 2 == 0 && entry.exitEffectiveL1 != NO_EXIT
                    ? entry.exitEffectiveL1
                    : entry.activeFromL1;
            }
            target = milestone > target
                ? _min(milestone, target + MAX_JUMP)
                : target + 1 + (_seed >> 3) % (3 * churnWindow);
        }
        vm.roll(target);
    }

    /// @notice Advances the L1 block to where the first (or a random) pending exit's stake
    /// becomes withdrawable, so slots are freed and reused within a run.
    function advanceToWithdrawal(uint256 _seed) external {
        uint256 pending = _pendingWithdrawals.length;
        if (pending == 0) {
            vm.roll(block.number + 1 + _seed % churnWindow);
            return;
        }
        uint256 target = _withdrawableAt(_pendingWithdrawals[(_seed >> 1) % pending]);
        for (uint256 i; i < pending && _seed % 2 == 0; ++i) {
            target = _min(target, _withdrawableAt(_pendingWithdrawals[i]));
        }
        if (target > block.number) vm.roll(_min(target, block.number + MAX_JUMP));
    }

    /// @notice Advances the settled active committee independently of L1 time.
    function settleCommittee(uint256 _seed) external {
        uint64 snapshot = uint64(block.number);
        if (_seed % 2 != 0) {
            snapshot = ghostActiveCommitteeSnapshot
                + uint64((_seed >> 1) % (block.number - ghostActiveCommitteeSnapshot + 1));
        }
        MockCommitteeInbox(registry.inbox()).setActiveCommitteeSnapshot(snapshot);
        ghostActiveCommitteeSnapshot = snapshot;
    }

    // ---------------------------------------------------------------
    // Setup helpers (not fuzzed)
    // ---------------------------------------------------------------

    /// @notice Registers `_count` minimum stakes in the current block with the distinct pubkeys
    /// `_firstKey`, `_firstKey + 1`, ... round-robin over the stakers, through the same checks
    /// as `register`. The slots are not tracked as touched by the campaign.
    function prefill(uint256 _count, uint256 _firstKey) external {
        _prefilling = true;
        for (uint256 i; i < _count; ++i) {
            _register(_stakers[i % _stakers.length], bytes32(_firstKey + i), minStake);
            _prefillActivations.push(_slots[slotCount - 1].entry.activeFromL1);
        }
        _prefilling = false;
    }

    // ---------------------------------------------------------------
    // Views for the invariants
    // ---------------------------------------------------------------

    /// @notice Independent interval sum over all modelled slots, including untouched prefill.
    function activeStake() public view returns (uint256 stake_) {
        if (_prefilling) return 0; // setup has positive activation delay and never rolls time
        uint256 low;
        uint256 high = _prefillActivations.length;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_prefillActivations[mid] <= block.number) low = mid + 1;
            else high = mid;
        }
        stake_ = low * minStake;
        for (uint256 i; i < _touchedSlots.length; ++i) {
            uint256 id = _touchedSlots[i];
            if (id < low) stake_ -= minStake;
            Slot storage s = _slots[id];
            if (
                !s.withdrawn && s.entry.activeFromL1 <= block.number
                    && block.number < s.entry.exitEffectiveL1
            ) stake_ += s.entry.effStake;
        }
    }

    /// @notice Slow independent model sum for the small campaigns. Near-cap campaigns reuse
    /// the bounded-frame all-entry root pass for their independent full interval sum.
    function naiveActiveStake() external view returns (uint256 stake_) {
        for (uint256 i; i < slotCount; ++i) {
            Slot storage s = _slots[i];
            if (
                !s.withdrawn && s.entry.activeFromL1 <= block.number
                    && block.number < s.entry.exitEffectiveL1
            ) stake_ += s.entry.effStake;
        }
    }

    function slotAt(uint256 _bondId) external view returns (Slot memory) {
        return _slots[_bondId];
    }

    function freeSlots() external view returns (uint256[] memory) {
        return _freeSlots;
    }

    function keySlots(bytes32 _pubkey) external view returns (uint256[] memory) {
        return _keySlots[_pubkey];
    }

    function checkpoints() external view returns (IEtnaStakingRegistry.Checkpoint[] memory) {
        return _checkpoints;
    }

    function snapshots() external view returns (Snapshot[] memory) {
        return _snapshots;
    }

    function snapshotLeaves(uint256 _index) external view returns (bytes32[] memory) {
        return _snapshotLeaves[_index];
    }

    function activationQueue() external view returns (Queue memory) {
        return _activations;
    }

    function exitQueue() external view returns (Queue memory) {
        return _exits;
    }

    function touchedSlots() external view returns (uint256[] memory) {
        return _touchedSlots;
    }

    function touchedKeys() external view returns (bytes32[] memory) {
        return _touchedKeys;
    }

    /// @notice The root of the modelled entries: the ghost tree's node at level
    /// `ceil(log2(slotCount))`, index 0.
    function ghostRoot() public view returns (bytes32) {
        if (slotCount == 0) return 0;
        uint256 level;
        while ((slotCount - 1) >> level != 0) {
            ++level;
        }
        return _node(level, 0);
    }

    // ---------------------------------------------------------------
    // Registration
    // ---------------------------------------------------------------

    function _register(address _caller, bytes32 _pubkey, uint256 _amount) internal {
        bytes4 expected = _expectRegister(_pubkey, _amount);
        uint256 expectedId = _freeSlots.length != 0 ? _freeSlots[_freeSlots.length - 1] : slotCount;
        _checkQueue(_activations, ACTIVATION_CHURN_SLOT);

        vm.prank(_caller);
        try registry.register(_pubkey, _amount, _caller) returns (uint256 bondId) {
            if (expected != 0) {
                _violate(Property.Slots, "register accepted where the model rejects it");
            } else if (bondId != expectedId) {
                _violate(Property.Slots, "register skipped the most recently freed slot");
            } else {
                _recordRegistration(_caller, bondId, _pubkey, _amount);
            }
        } catch (bytes memory reason) {
            if (expected == EtnaStakingRegistry.RegistryFull.selector) ++fullRegistryRejections;
            _checkRevert(Property.Slots, expected, reason, "register");
        }
    }

    /// @dev The registration's expected custom error, in the registry's check order, or zero.
    function _expectRegister(bytes32 _pubkey, uint256 _amount) internal view returns (bytes4) {
        if (_amount < minStake) return EtnaStakingRegistry.StakeTooLow.selector;
        if (_pubkey == 0) return EtnaStakingRegistry.ZeroPubkey.selector;
        if (_freeSlots.length == 0 && slotCount >= maxEntries) {
            return EtnaStakingRegistry.RegistryFull.selector;
        }
        if (_keyInUse(_pubkey)) return EtnaStakingRegistry.PubkeyInUse.selector;
        return 0;
    }

    /// @dev Whether a modelled entry holds `_pubkey` and its exit is not yet effective.
    function _keyInUse(bytes32 _pubkey) internal view returns (bool) {
        uint256[] storage holders = _keySlots[_pubkey];
        for (uint256 i; i < holders.length; ++i) {
            if (_slots[holders[i]].entry.exitEffectiveL1 > block.number) return true;
        }
        return false;
    }

    function _recordRegistration(
        address _caller,
        uint256 _bondId,
        bytes32 _pubkey,
        uint256 _amount
    )
        internal
    {
        uint64 activeFromL1 = _schedule(
            _activations, ACTIVATION_CHURN_SLOT, uint64(block.number) + activationDelay, _amount
        );
        Slot storage s = _slots[_bondId];
        if (_bondId < slotCount) {
            _freeSlots.pop();
            _removeKeySlot(s.entry.pubkey, _bondId);
            ++reuses;
        } else {
            ++slotCount;
        }
        s.entry = IEtnaStakingRegistry.Entry({
            pubkey: _pubkey,
            effStake: _amount,
            activeFromL1: activeFromL1,
            exitEffectiveL1: NO_EXIT,
            lastHeartbeatAt: 0,
            lastHeartbeatSeq: 0,
            rewardRecipient: _caller
        });
        s.owner = _caller;
        s.withdrawn = false;
        s.registeredAt = uint64(block.number);
        s.exitRequestedAt = 0;
        s.heartbeats = 0;
        s.lastHeartbeatBlock = 0;
        _keySlots[_pubkey].push(_bondId);
        if (!_prefilling && !_isTouchedKey[_pubkey]) {
            _isTouchedKey[_pubkey] = true;
            _touchedKeys.push(_pubkey);
        }
        bondedStake += _amount;
        stakedBalance += _amount;
        ++registrations;
        _commit(_bondId);
    }

    // ---------------------------------------------------------------
    // Heartbeat, exit and withdrawal
    // ---------------------------------------------------------------

    function _recordHeartbeat(uint256 _bondId) internal {
        Slot storage s = _slots[_bondId];
        uint64 windowStart = uint64(block.number / heartbeatWindow * heartbeatWindow);
        if (block.number >= s.entry.exitEffectiveL1) {
            _violate(Property.Heartbeat, "heartbeat accepted at or after the exit");
        }
        if (
            s.heartbeats != 0
                && block.number / heartbeatWindow <= s.lastHeartbeatBlock / heartbeatWindow
        ) {
            _violate(Property.Heartbeat, "two heartbeats of one holder in one window");
        }
        if (windowStart < s.entry.lastHeartbeatAt) {
            _violate(Property.Heartbeat, "lastHeartbeatAt decreased");
        }
        ++s.heartbeats;
        s.lastHeartbeatBlock = uint64(block.number);
        s.entry.lastHeartbeatAt = windowStart;
        s.entry.lastHeartbeatSeq = s.heartbeats;
        ++heartbeatsAccepted;
        _commit(_bondId);
    }

    function _recordExit(uint256 _bondId) internal {
        Slot storage s = _slots[_bondId];
        uint64 earliest = uint64(block.number) + exitDelay;
        uint64 queued = _schedule(_exits, EXIT_CHURN_SLOT, earliest, s.entry.effStake);
        uint64 afterActivation = s.entry.activeFromL1 + exitDelay;
        uint64 exitEffectiveL1 = queued > afterActivation ? queued : afterActivation;

        uint64 actual = registry.entryAt(_bondId).exitEffectiveL1;
        if (actual < earliest || actual < afterActivation) {
            _violate(Property.Churn, "exit takes effect before both of its delays");
        }
        if (s.entry.activeFromL1 <= block.number) {
            // An active entry's exit waits only for its own request block and the exit stake
            // queued in the current busy period, never for a pending activation: the
            // queue's last window is below busyStart + busyAmount / minChurnPerWindow.
            uint256 lastWindow =
                _exits.busyStart + _ceilDiv(_exits.busyAmount, minChurnPerWindow) - 1;
            if (actual > _max(earliest, lastWindow * churnWindow)) {
                _violate(Property.Churn, "an active entry's exit waits beyond the queued stake");
            }
        } else {
            ++exitsBeforeActivation;
        }

        s.entry.exitEffectiveL1 = exitEffectiveL1;
        s.exitRequestedAt = uint64(block.number);
        bondedStake -= s.entry.effStake;
        _pendingWithdrawals.push(_bondId);
        ++exits;
        _commit(_bondId);
    }

    /// @dev The withdrawal's expected custom error, in the registry's check order, or zero.
    function _expectWithdraw(uint256 _bondId, address _caller) internal view returns (bytes4) {
        bytes4 expected = _expectOwner(_bondId, _caller);
        if (expected != 0) return expected;
        Slot storage s = _slots[_bondId];
        if (s.withdrawn) return EtnaStakingRegistry.AlreadyWithdrawn.selector;
        if (s.entry.exitEffectiveL1 == NO_EXIT) {
            return EtnaStakingRegistry.ExitNotRequested.selector;
        }
        if (block.number < uint256(s.entry.exitEffectiveL1) + withdrawalDelay) {
            return EtnaStakingRegistry.WithdrawalNotReady.selector;
        }
        if (ghostActiveCommitteeSnapshot < s.entry.exitEffectiveL1) {
            return EtnaStakingRegistry.CommitteeExitNotSettled.selector;
        }
        return 0;
    }

    function _recordWithdrawal(
        uint256 _bondId,
        address _caller,
        uint256 _balanceBefore,
        uint256 _checkpointsBefore
    )
        internal
    {
        Slot storage s = _slots[_bondId];
        if (ghostActiveCommitteeSnapshot < s.entry.exitEffectiveL1) {
            _violate(Property.Model, "withdraw succeeded before settled committee retirement");
        }
        if (token.balanceOf(_caller) != _balanceBefore + s.entry.effStake) {
            _violate(Property.Model, "withdraw paid the owner another amount than the stake");
        }
        if (registry.checkpointCount() != _checkpointsBefore) {
            _violate(Property.History, "withdraw wrote a checkpoint");
        }
        if (!_sameEntry(registry.entryAt(_bondId), s.entry)) {
            _violate(Property.Model, "withdraw changed the entry");
        }
        s.withdrawn = true;
        _freeSlots.push(_bondId);
        stakedBalance -= s.entry.effStake;
        for (uint256 i; i < _pendingWithdrawals.length; ++i) {
            if (_pendingWithdrawals[i] == _bondId) {
                _pendingWithdrawals[i] = _pendingWithdrawals[_pendingWithdrawals.length - 1];
                _pendingWithdrawals.pop();
                break;
            }
        }
        ++withdrawals;
    }

    // ---------------------------------------------------------------
    // Churn
    // ---------------------------------------------------------------

    /// @dev Checks that nothing but a scheduling call moved the queue since the model last saw it.
    function _checkQueue(Queue storage _queue, uint256 _slot) internal {
        if (_load(_slot) != _queue.nextWindow) {
            _violate(Property.Churn, "a churn queue moved outside register and requestExit");
        }
    }

    /// @dev Folds a request of `_amount` that would take effect at `_earliest` without a churn
    /// limit into the queue model, checks where the registry put the queue and returns the
    /// block the request should take effect at: the start of the queue's latest window, or
    /// `_earliest` if later. Call it before changing the model's active interval.
    ///
    /// A busy period starts at the earliest window of a request that finds the queue behind it
    /// and opens one window, and later requests continue it while the queue reaches their
    /// earliest window. Every window a request opens holds `max(active * churnBps / 10_000,
    /// minChurnPerWindow)`, and a request opens a further window only while the stake scheduled
    /// in the period exceeds the windows opened so far. Hence, exactly:
    /// - rate: the stored `remaining` is the capacity of the windows the period opened minus its
    ///   stake, so no window absorbs more than it holds;
    /// - no stranding: every window but the latest is full and holds at least
    ///   `minChurnPerWindow`, so `(last - busyStart) * minChurnPerWindow < busyAmount`, and
    ///   loosely `last <= maxEarliestWindow + ceil(totalAmount / minChurnPerWindow)`.
    /// Neither bound depends on when a scheduled stake activates, only on request blocks and
    /// amounts: an exit requested before a deferred activation cannot push the exit queue out.
    function _schedule(
        Queue storage _queue,
        uint256 _slot,
        uint64 _earliest,
        uint256 _amount
    )
        internal
        returns (uint64 effective_)
    {
        uint256 earliestWindow = _earliest / churnWindow;
        uint256 previous = _queue.nextWindow;
        uint256 next = _load(_slot);
        _queue.nextWindow = next;
        if (next < previous || next <= earliestWindow) {
            _violate(
                Property.Churn, "a request was scheduled before the queue or its earliest window"
            );
            return _earliest;
        }

        uint256 perWindow = _max(activeStake() * churnBps / 10_000, minChurnPerWindow);
        if (previous > earliestWindow) {
            _queue.busyAmount += _amount;
            _queue.busyCapacity += (next - previous) * perWindow;
        } else {
            _queue.busyStart = earliestWindow;
            _queue.busyAmount = _amount;
            _queue.busyCapacity = (next - earliestWindow) * perWindow;
        }
        if (earliestWindow > _queue.maxEarliestWindow) _queue.maxEarliestWindow = earliestWindow;
        _queue.totalAmount += _amount;

        if (
            _queue.busyAmount > _queue.busyCapacity
                || _load(_slot + 1) != _queue.busyCapacity - _queue.busyAmount
        ) {
            _violate(Property.Churn, "a churn queue admitted other than its opened windows hold");
        }
        uint256 last = next - 1;
        if (
            last < _queue.busyStart
                || (last - _queue.busyStart) * minChurnPerWindow >= _queue.busyAmount
        ) {
            _violate(Property.Churn, "a churn queue runs past the stake its busy period absorbed");
        }
        if (last > _queue.maxEarliestWindow + _ceilDiv(_queue.totalAmount, minChurnPerWindow)) {
            _violate(Property.Churn, "a churn queue runs past every scheduled stake");
        }
        uint256 windowStart = last * churnWindow;
        effective_ = windowStart > _earliest ? uint64(windowStart) : _earliest;
        if (effective_ != _earliest) ++_queue.deferred;
    }

    // ---------------------------------------------------------------
    // Tree and checkpoints
    // ---------------------------------------------------------------

    /// @dev After a successful register, heartbeat or requestExit of `_bondId`: checks the entry
    /// against the model, folds its leaf into the ghost tree, then checks that exactly the
    /// current block's checkpoint was written with the modelled count and root, and refreshes
    /// that block's checkpoint copy and snapshot.
    function _commit(uint256 _bondId) internal {
        Slot storage s = _slots[_bondId];
        if (!_sameEntry(registry.entryAt(_bondId), s.entry)) {
            _violate(Property.Model, "the changed entry differs from the model");
        }
        _setLeaf(_bondId, LibEntriesTree.leaf(_bondId, s.entry));
        if (!_prefilling && !_isTouchedSlot[_bondId]) {
            _isTouchedSlot[_bondId] = true;
            _touchedSlots.push(_bondId);
        }

        uint256 count = registry.checkpointCount();
        uint256 known = _checkpoints.length;
        bool sameBlock = known != 0 && _checkpoints[known - 1].l1Block == block.number;
        if (count != (sameBlock ? known : known + 1)) {
            _violate(Property.History, "a change did not write exactly its block's checkpoint");
            return;
        }
        IEtnaStakingRegistry.Checkpoint memory latest = registry.checkpointAt(count - 1);
        Snapshot memory snapshot = Snapshot({ count: uint32(slotCount), root: ghostRoot() });
        if (latest.l1Block != block.number || latest.count != slotCount) {
            _violate(Property.History, "the block's checkpoint names another block or count");
        }
        if (latest.entriesRoot != snapshot.root) {
            _violate(Property.Root, "the block's checkpoint root differs from the modelled tree");
        }
        if (!sameBlock) {
            _checkpoints.push();
            _snapshots.push();
            if (keepSnapshotLeaves) _snapshotLeaves.push();
        }
        _checkpoints[count - 1] = latest;
        _snapshots[count - 1] = snapshot;
        if (keepSnapshotLeaves) {
            delete _snapshotLeaves[count - 1];
            bytes32[] storage leaves = _snapshotLeaves[count - 1];
            for (uint256 i; i < slotCount; ++i) {
                leaves.push(LibEntriesTree.leaf(i, _slots[i].entry));
            }
        }
    }

    function _setLeaf(uint256 _index, bytes32 _leaf) internal {
        bytes32 hash = _leaf;
        uint256 index = _index;
        _nodes[index] = hash;
        for (uint256 level; level < TREE_DEPTH; ++level) {
            bytes32 sibling = _node(level, index ^ 1);
            hash = index & 1 == 0 ? _hashPair(hash, sibling) : _hashPair(sibling, hash);
            index >>= 1;
            _nodes[((level + 1) << 32) | index] = hash;
        }
    }

    function _node(uint256 _level, uint256 _index) internal view returns (bytes32 node_) {
        node_ = _nodes[(_level << 32) | _index];
        if (node_ == 0) node_ = _zeros[_level];
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Picks a bond id, one past the last slot about once in sixteen calls, and a caller:
    /// the bond owner about seven times in eight, otherwise a pool staker.
    function _pickBond(
        uint256 _bondSeed,
        uint256 _stakerSeed
    )
        internal
        view
        returns (uint256 bondId_, address caller_)
    {
        bondId_ = slotCount == 0 || _bondSeed % 16 == 0 ? slotCount : (_bondSeed >> 4) % slotCount;
        caller_ = bondId_ < slotCount && _stakerSeed % 8 != 0
            ? _slots[bondId_].owner
            : _staker(_stakerSeed >> 3);
    }

    /// @dev Like `_pickBond`, but probes up to four slots for one that has not exited (for an
    /// exit request) or whose exit is not yet effective (for a heartbeat).
    function _pickBondFor(
        uint256 _bondSeed,
        uint256 _stakerSeed,
        bool _forExit
    )
        internal
        view
        returns (uint256 bondId_, address caller_)
    {
        (bondId_, caller_) = _pickBond(_bondSeed, _stakerSeed);
        for (uint256 i = 1; i < 4 && bondId_ < slotCount; ++i) {
            uint64 exitEffectiveL1 = _slots[bondId_].entry.exitEffectiveL1;
            if (_forExit ? exitEffectiveL1 == NO_EXIT : exitEffectiveL1 > block.number) break;
            (bondId_, caller_) =
                _pickBond(uint256(keccak256(abi.encode(_bondSeed, i))), _stakerSeed);
        }
    }

    function _expectOwner(uint256 _bondId, address _caller) internal view returns (bytes4) {
        if (_bondId >= slotCount) return EtnaStakingRegistry.UnknownBond.selector;
        if (_slots[_bondId].owner != _caller) return EtnaStakingRegistry.NotBondOwner.selector;
        return 0;
    }

    /// @dev Records a violation unless the call reverted with exactly the expected error.
    function _checkRevert(
        Property _property,
        bytes4 _expected,
        bytes memory _reason,
        string memory _call
    )
        internal
    {
        if (_expected == 0) {
            _violate(
                _property,
                string.concat(
                    _call, " reverted where the model expects success: ", vm.toString(_reason)
                )
            );
        } else if (_reason.length < 4 || bytes4(_reason) != _expected) {
            _violate(
                _property,
                string.concat(_call, " reverted with an unexpected error: ", vm.toString(_reason))
            );
        } else {
            ++rejections;
        }
    }

    function _violate(Property _property, string memory _reason) internal {
        if (violations[_property]++ != 0) return;
        string[6] memory names = ["root", "history", "churn", "heartbeat", "slots", "model"];
        firstViolation[_property] = string.concat(names[uint8(_property)], ": ", _reason);
    }

    function _removeKeySlot(bytes32 _pubkey, uint256 _bondId) internal {
        uint256[] storage ids = _keySlots[_pubkey];
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == _bondId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                return;
            }
        }
    }

    function _sameEntry(
        IEtnaStakingRegistry.Entry memory _a,
        IEtnaStakingRegistry.Entry memory _b
    )
        internal
        pure
        returns (bool)
    {
        return _a.pubkey == _b.pubkey && _a.effStake == _b.effStake
            && _a.activeFromL1 == _b.activeFromL1 && _a.exitEffectiveL1 == _b.exitEffectiveL1
            && _a.lastHeartbeatAt == _b.lastHeartbeatAt
            && _a.lastHeartbeatSeq == _b.lastHeartbeatSeq
            && _a.rewardRecipient == _b.rewardRecipient;
    }

    /// @dev The first block at which the stake of `_bondId`, whose exit was requested, can be
    /// withdrawn.
    function _withdrawableAt(uint256 _bondId) internal view returns (uint256) {
        return uint256(_slots[_bondId].entry.exitEffectiveL1) + withdrawalDelay;
    }

    function _staker(uint256 _seed) internal view returns (address) {
        return _stakers[_seed % _stakers.length];
    }

    function _load(uint256 _slot) internal view returns (uint256) {
        return uint256(vm.load(address(registry), bytes32(_slot)));
    }

    function _hashPair(bytes32 _left, bytes32 _right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_left, _right));
    }

    function _ceilDiv(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a == 0 ? 0 : (_a - 1) / _b + 1;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
