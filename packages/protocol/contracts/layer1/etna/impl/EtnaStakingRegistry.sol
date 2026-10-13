// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEntriesTree } from "../libs/LibEntriesTree.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./EtnaStakingRegistry_Layout.sol"; // DO NOT DELETE

/// @title EtnaStakingRegistry
/// @notice The TAIKO staking registry of the Etna PoS chain: validator entries in reusable slots,
/// one checkpoint per L1 block that changes an entry, and an incremental entries Merkle root.
/// @dev All state lives in the ERC-7201 namespace `taiko.etna.registry` (`RegistryStorage`),
/// whose slots the Etna node proves; see `IEtnaStakingRegistry`. The contract upholds the node's
/// registry obligations: checkpoints have strictly increasing `l1Block`s, every L1 block that
/// changes an entry has one, each covers every entry as it stands at the end of its block, and
/// no two entries whose exits are not yet effective share a pubkey.
///
/// A withdrawn bond's slot is reused by a later registration, so `MAX_ENTRIES` bounds the
/// entries holding stake at once rather than every registration ever made. Activations and exits
/// are scheduled through a per-window stake churn limit when `churnWindow` is non-zero.
/// @custom:security-contact security@taiko.xyz
contract EtnaStakingRegistry is EssentialContract, IEtnaStakingRegistry {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev The churn queue of one direction (activations or exits), as in EIP-7251.
    struct Churn {
        /// @dev One past the latest churn window holding a scheduled activation (or exit); 0
        /// before the first request.
        uint256 nextWindow;
        /// @dev The stake that the latest scheduled window can still absorb.
        uint256 remaining;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry
    struct RegistryStorage {
        /// @dev Slot `R`: one checkpoint per L1 block that changed an entry.
        Checkpoint[] checkpoints;
        /// @dev Slot `R + 1`: the entries, indexed by bond id (the slot).
        Entry[] entries;
        /// @dev Slot `R + 2`.
        mapping(uint256 bondId => address owner) bondOwner;
        /// @dev Slot `R + 3`.
        mapping(uint256 bondId => bool withdrawn) withdrawn;
        /// @dev Slot `R + 4`: the bond id plus one of the latest entry registered with a pubkey.
        mapping(bytes32 pubkey => uint256 bondIdPlusOne) keyHolder;
        /// @dev Slot `R + 5`: the `LibEntriesTree` nodes.
        mapping(uint256 node => bytes32 hash) tree;
        /// @dev Slot `R + 6`: withdrawn bond ids whose slots the next registrations reuse.
        uint256[] freeSlots;
        /// @dev Slot `R + 7`: the total stake of entries whose exit was not requested, pending
        /// activations included.
        uint256 bondedStake;
        /// @dev Slots `R + 8` and `R + 9`.
        Churn activationChurn;
        /// @dev Slots `R + 10` and `R + 11`.
        Churn exitChurn;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The maximum number of entries holding stake at once (the tree capacity). A
    /// withdrawn entry's slot is reused.
    uint256 public constant MAX_ENTRIES = LibEntriesTree.CAPACITY;

    /// @dev The basis-point denominator of `churnBps`.
    uint256 private constant _BPS = 10_000;

    /// @dev The ERC-7201 base slot `R` of `RegistryStorage`:
    /// `keccak256(abi.encode(uint256(keccak256("taiko.etna.registry")) - 1)) & ~bytes32(uint256(0xff))`.
    bytes32 private constant _REGISTRY_STORAGE_SLOT =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;

    /// @dev The `exitEffectiveL1` of an entry whose exit was not requested.
    uint64 private constant _NO_EXIT = type(uint64).max;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The TAIKO token staked in this registry.
    IERC20 public immutable taikoToken;

    /// @notice The minimum stake of a registration, in TAIKO base units.
    uint256 public immutable minStake;

    /// @notice The number of L1 blocks from registration until the entry is active.
    uint64 public immutable activationDelay;

    /// @notice The number of L1 blocks from the exit request (or the activation, if later) until
    /// the exit takes effect.
    uint64 public immutable exitDelay;

    /// @notice The number of L1 blocks from the effective exit until the stake can be withdrawn.
    uint64 public immutable withdrawalDelay;

    /// @notice The heartbeat window `W` in L1 blocks; equals the node's `heartbeat_window`.
    uint64 public immutable heartbeatWindow;

    /// @notice The churn window in L1 blocks; 0 disables the churn limit.
    uint64 public immutable churnWindow;

    /// @notice The churn capacity of a window, for activations and separately for exits, in
    /// basis points of `bondedStake` at the time of the request.
    uint16 public immutable churnBps;

    /// @notice The floor of a window's churn capacity, in TAIKO base units; at least `minStake`.
    uint256 public immutable minChurnPerWindow;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the registry's immutable parameters.
    /// @param _taikoToken The TAIKO token.
    /// @param _minStake The minimum stake of a registration; must be non-zero.
    /// @param _activationDelay The activation delay in L1 blocks.
    /// @param _exitDelay The exit delay in L1 blocks.
    /// @param _withdrawalDelay The withdrawal delay in L1 blocks.
    /// @param _heartbeatWindow The heartbeat window in L1 blocks; must be non-zero.
    /// @param _churnWindow The churn window in L1 blocks; 0 disables the churn limit.
    /// @param _churnBps A window's churn capacity in basis points of the bonded stake; at most
    /// 10,000 when the churn limit is enabled.
    /// @param _minChurnPerWindow The floor of a window's churn capacity; at least `_minStake`
    /// when the churn limit is enabled.
    constructor(
        address _taikoToken,
        uint256 _minStake,
        uint64 _activationDelay,
        uint64 _exitDelay,
        uint64 _withdrawalDelay,
        uint64 _heartbeatWindow,
        uint64 _churnWindow,
        uint16 _churnBps,
        uint256 _minChurnPerWindow
    ) {
        require(_taikoToken != address(0), ZERO_ADDRESS());
        require(_minStake != 0, ZERO_VALUE());
        require(_heartbeatWindow != 0, InvalidHeartbeatWindow());
        require(
            _churnWindow == 0 || (_churnBps <= _BPS && _minChurnPerWindow >= _minStake),
            InvalidChurn()
        );

        taikoToken = IERC20(_taikoToken);
        minStake = _minStake;
        activationDelay = _activationDelay;
        exitDelay = _exitDelay;
        withdrawalDelay = _withdrawalDelay;
        heartbeatWindow = _heartbeatWindow;
        churnWindow = _churnWindow;
        churnBps = _churnBps;
        minChurnPerWindow = _minChurnPerWindow;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner of the registry.
    /// @param _owner The owner of this contract; `msg.sender` if zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function register(
        bytes32 _pubkey,
        uint256 _amount
    )
        external
        nonReentrant
        returns (uint256 bondId_)
    {
        require(_amount >= minStake, StakeTooLow());
        require(_pubkey != 0, ZeroPubkey());

        RegistryStorage storage $ = _registryStorage();
        uint256 count = $.entries.length;
        uint256 freeCount = $.freeSlots.length;
        require(freeCount != 0 || count < MAX_ENTRIES, RegistryFull());

        uint256 holder = $.keyHolder[_pubkey];
        if (holder != 0) {
            // A slot reused by another pubkey no longer holds this one: its holder withdrew.
            Entry storage held = $.entries[holder - 1];
            require(held.pubkey != _pubkey || held.exitEffectiveL1 <= block.number, PubkeyInUse());
        }

        Entry memory entry = Entry({
            pubkey: _pubkey,
            effStake: _amount,
            activeFromL1: _scheduleChurn(
                $.activationChurn, uint64(block.number) + activationDelay, _amount, $.bondedStake
            ),
            exitEffectiveL1: _NO_EXIT,
            lastHeartbeatAt: 0,
            lastHeartbeatSeq: 0
        });
        if (freeCount != 0) {
            bondId_ = $.freeSlots[freeCount - 1];
            $.freeSlots.pop();
            $.entries[bondId_] = entry;
            delete $.withdrawn[bondId_];
        } else {
            bondId_ = count++;
            $.entries.push(entry);
        }
        $.bondedStake += _amount;
        $.bondOwner[bondId_] = msg.sender;
        $.keyHolder[_pubkey] = bondId_ + 1;
        _commit($, count, bondId_, entry);

        taikoToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Registered(bondId_, msg.sender, _pubkey, _amount, entry.activeFromL1);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function heartbeat(uint256 _bondId) external nonReentrant {
        RegistryStorage storage $ = _registryStorage();
        uint256 count = _checkBondOwner($, _bondId);

        Entry memory entry = $.entries[_bondId];
        require(block.number < entry.exitEffectiveL1, AlreadyExited());

        uint64 windowStart = uint64(block.number / heartbeatWindow * heartbeatWindow);
        require(
            entry.lastHeartbeatSeq == 0 || windowStart > entry.lastHeartbeatAt,
            HeartbeatAlreadyRecorded()
        );

        entry.lastHeartbeatAt = windowStart;
        ++entry.lastHeartbeatSeq;
        Entry storage stored = $.entries[_bondId];
        stored.lastHeartbeatAt = windowStart;
        stored.lastHeartbeatSeq = entry.lastHeartbeatSeq;
        _commit($, count, _bondId, entry);

        emit HeartbeatRecorded(_bondId, windowStart, entry.lastHeartbeatSeq);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function requestExit(uint256 _bondId) external nonReentrant {
        RegistryStorage storage $ = _registryStorage();
        uint256 count = _checkBondOwner($, _bondId);

        Entry memory entry = $.entries[_bondId];
        require(entry.exitEffectiveL1 == _NO_EXIT, ExitAlreadyRequested());

        // The exit queue advances with the request block only: an entry still waiting for its
        // activation takes its exit slot now and exits no earlier than `exitDelay` after it
        // activates, so a far-off activation cannot strand the queue in a distant window.
        uint256 bonded = $.bondedStake;
        uint64 queued =
            _scheduleChurn($.exitChurn, uint64(block.number) + exitDelay, entry.effStake, bonded);
        uint64 afterActivation = entry.activeFromL1 + exitDelay;
        entry.exitEffectiveL1 = queued > afterActivation ? queued : afterActivation;
        $.bondedStake = bonded - entry.effStake;
        $.entries[_bondId].exitEffectiveL1 = entry.exitEffectiveL1;
        _commit($, count, _bondId, entry);

        emit ExitRequested(_bondId, entry.exitEffectiveL1);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function withdraw(uint256 _bondId, address _to) external nonReentrant nonZeroAddr(_to) {
        RegistryStorage storage $ = _registryStorage();
        _checkBondOwner($, _bondId);
        require(!$.withdrawn[_bondId], AlreadyWithdrawn());

        Entry storage entry = $.entries[_bondId];
        uint64 exitEffectiveL1 = entry.exitEffectiveL1;
        require(exitEffectiveL1 != _NO_EXIT, ExitNotRequested());
        require(block.number >= uint256(exitEffectiveL1) + withdrawalDelay, WithdrawalNotReady());

        $.withdrawn[_bondId] = true;
        $.freeSlots.push(_bondId);
        uint256 amount = entry.effStake;
        taikoToken.safeTransfer(_to, amount);
        emit StakeWithdrawn(_bondId, _to, amount);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function checkpointCount() external view returns (uint256) {
        return _registryStorage().checkpoints.length;
    }

    /// @inheritdoc IEtnaStakingRegistry
    function checkpointAt(uint256 _index) external view returns (Checkpoint memory) {
        RegistryStorage storage $ = _registryStorage();
        require(_index < $.checkpoints.length, UnknownCheckpoint());
        return $.checkpoints[_index];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function entryCount() external view returns (uint256) {
        return _registryStorage().entries.length;
    }

    /// @inheritdoc IEtnaStakingRegistry
    function entryAt(uint256 _bondId) external view returns (Entry memory) {
        RegistryStorage storage $ = _registryStorage();
        require(_bondId < $.entries.length, UnknownBond());
        return $.entries[_bondId];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function entriesRoot() external view returns (bytes32) {
        RegistryStorage storage $ = _registryStorage();
        return LibEntriesTree.root($.tree, $.entries.length);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function bondOwnerOf(uint256 _bondId) external view returns (address) {
        return _registryStorage().bondOwner[_bondId];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function isWithdrawn(uint256 _bondId) external view returns (bool) {
        return _registryStorage().withdrawn[_bondId];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function freeSlotCount() external view returns (uint256) {
        return _registryStorage().freeSlots.length;
    }

    /// @inheritdoc IEtnaStakingRegistry
    function bondedStake() external view returns (uint256) {
        return _registryStorage().bondedStake;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Checks that `_bondId` exists and that the caller owns it.
    /// @param $ The registry storage.
    /// @param _bondId The bond id.
    /// @return count_ The number of entries.
    function _checkBondOwner(
        RegistryStorage storage $,
        uint256 _bondId
    )
        private
        view
        returns (uint256 count_)
    {
        count_ = $.entries.length;
        require(_bondId < count_, UnknownBond());
        require($.bondOwner[_bondId] == msg.sender, NotBondOwner());
    }

    /// @dev Rewrites the leaf of entry `_bondId` and records the new root in the current block's
    /// checkpoint: overwritten if the latest checkpoint is this block's, appended otherwise.
    /// @param $ The registry storage.
    /// @param _count The number of entries.
    /// @param _bondId The changed entry's bond id.
    /// @param _entry The changed entry's new value.
    function _commit(
        RegistryStorage storage $,
        uint256 _count,
        uint256 _bondId,
        Entry memory _entry
    )
        private
    {
        bytes32 root =
            LibEntriesTree.update($.tree, _count, _bondId, LibEntriesTree.leaf(_bondId, _entry));
        uint64 l1Block = uint64(block.number);
        // `_count` is at most MAX_ENTRIES, so it fits in a uint32.
        uint32 count = uint32(_count);

        uint256 index = $.checkpoints.length;
        if (index != 0 && $.checkpoints[index - 1].l1Block == l1Block) {
            --index;
            Checkpoint storage last = $.checkpoints[index];
            last.count = count;
            last.entriesRoot = root;
        } else {
            $.checkpoints.push(Checkpoint({ l1Block: l1Block, count: count, entriesRoot: root }));
        }
        emit CheckpointWritten(index, l1Block, count, root);
    }

    /// @dev Schedules `_amount` of stake to activate (or exit) at or after `_earliest`, the way
    /// EIP-7251 schedules exits: each window has a capacity of
    /// `max(minChurnPerWindow, _bonded * churnBps / 10_000)`. A request consumes capacity from
    /// the latest scheduled window on and takes effect at the start of the window where it is
    /// fully absorbed; one that fits the window containing `_earliest` keeps `_earliest`. A
    /// request larger than one window's capacity therefore takes effect in full at once, so
    /// the limit bounds the average rate over consecutive windows, not each window.
    /// @param _churn The churn queue to schedule in.
    /// @param _earliest The L1 block the request would take effect at without a churn limit.
    /// @param _amount The stake to schedule.
    /// @param _bonded The bonded stake the per-window churn is a fraction of.
    /// @return effective_ The L1 block the request takes effect at.
    function _scheduleChurn(
        Churn storage _churn,
        uint64 _earliest,
        uint256 _amount,
        uint256 _bonded
    )
        private
        returns (uint64 effective_)
    {
        if (churnWindow == 0) return _earliest;

        uint256 perWindow = _bonded * churnBps / _BPS;
        if (perWindow < minChurnPerWindow) perWindow = minChurnPerWindow;

        uint256 window = _earliest / churnWindow;
        uint256 remaining = perWindow;
        if (_churn.nextWindow > window) {
            // Earlier requests already reach this window: continue from the latest one.
            window = _churn.nextWindow - 1;
            remaining = _churn.remaining;
        }
        if (_amount > remaining) {
            uint256 extraWindows = (_amount - remaining - 1) / perWindow + 1;
            window += extraWindows;
            remaining += extraWindows * perWindow;
        }
        _churn.nextWindow = window + 1;
        _churn.remaining = remaining - _amount;

        uint256 windowStart = window * churnWindow;
        effective_ = windowStart > _earliest ? SafeCast.toUint64(windowStart) : _earliest;
    }

    /// @dev Returns the registry's ERC-7201 storage.
    /// @return $ The registry storage.
    function _registryStorage() private pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := _REGISTRY_STORAGE_SLOT
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error AlreadyExited();
    error AlreadyWithdrawn();
    error ExitAlreadyRequested();
    error ExitNotRequested();
    error HeartbeatAlreadyRecorded();
    error InvalidChurn();
    error InvalidHeartbeatWindow();
    error NotBondOwner();
    error PubkeyInUse();
    error RegistryFull();
    error StakeTooLow();
    error UnknownBond();
    error UnknownCheckpoint();
    error WithdrawalNotReady();
    error ZeroPubkey();
}
