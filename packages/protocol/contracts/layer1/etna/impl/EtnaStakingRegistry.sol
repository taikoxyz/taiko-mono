// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEntriesTree } from "../libs/LibEntriesTree.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./EtnaStakingRegistry_Layout.sol"; // DO NOT DELETE

/// @title EtnaStakingRegistry
/// @notice The TAIKO staking registry of the Etna PoS chain: append-only validator entries, one
/// checkpoint per L1 block that changes an entry, and an incremental entries Merkle root.
/// @dev All state lives in the ERC-7201 namespace `taiko.etna.registry` (`RegistryStorage`),
/// whose slots the Etna node proves; see `IEtnaStakingRegistry`. The contract upholds the node's
/// registry obligations: checkpoints have strictly increasing `l1Block`s, every L1 block that
/// changes an entry has one, each covers every entry as it stands at the end of its block, and
/// no two entries whose exits are not yet effective share a pubkey.
/// @custom:security-contact security@taiko.xyz
contract EtnaStakingRegistry is EssentialContract, IEtnaStakingRegistry {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @custom:storage-location erc7201:taiko.etna.registry
    struct RegistryStorage {
        /// @dev Slot `R`: one checkpoint per L1 block that changed an entry.
        Checkpoint[] checkpoints;
        /// @dev Slot `R + 1`: the entries, indexed by bond id.
        Entry[] entries;
        /// @dev Slot `R + 2`.
        mapping(uint256 bondId => address owner) bondOwner;
        /// @dev Slot `R + 3`.
        mapping(uint256 bondId => bool withdrawn) withdrawn;
        /// @dev Slot `R + 4`: the bond id plus one of the latest entry registered with a pubkey.
        mapping(bytes32 pubkey => uint256 bondIdPlusOne) keyHolder;
        /// @dev Slot `R + 5`: the `LibEntriesTree` nodes.
        mapping(uint256 node => bytes32 hash) tree;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The maximum number of entries, exited ones included (the tree capacity).
    uint256 public constant MAX_ENTRIES = LibEntriesTree.CAPACITY;

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
    constructor(
        address _taikoToken,
        uint256 _minStake,
        uint64 _activationDelay,
        uint64 _exitDelay,
        uint64 _withdrawalDelay,
        uint64 _heartbeatWindow
    ) {
        require(_taikoToken != address(0), ZERO_ADDRESS());
        require(_minStake != 0, ZERO_VALUE());
        require(_heartbeatWindow != 0, InvalidHeartbeatWindow());

        taikoToken = IERC20(_taikoToken);
        minStake = _minStake;
        activationDelay = _activationDelay;
        exitDelay = _exitDelay;
        withdrawalDelay = _withdrawalDelay;
        heartbeatWindow = _heartbeatWindow;
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
        bondId_ = $.entries.length;
        require(bondId_ < MAX_ENTRIES, RegistryFull());

        uint256 holder = $.keyHolder[_pubkey];
        if (holder != 0) {
            require($.entries[holder - 1].exitEffectiveL1 <= block.number, PubkeyInUse());
        }

        Entry memory entry = Entry({
            pubkey: _pubkey,
            effStake: _amount,
            activeFromL1: uint64(block.number) + activationDelay,
            exitEffectiveL1: _NO_EXIT,
            lastHeartbeatAt: 0,
            lastHeartbeatSeq: 0
        });
        $.entries.push(entry);
        $.bondOwner[bondId_] = msg.sender;
        $.keyHolder[_pubkey] = bondId_ + 1;
        _commit($, bondId_ + 1, bondId_, entry);

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

        uint64 exitFrom =
            block.number > entry.activeFromL1 ? uint64(block.number) : entry.activeFromL1;
        entry.exitEffectiveL1 = exitFrom + exitDelay;
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
