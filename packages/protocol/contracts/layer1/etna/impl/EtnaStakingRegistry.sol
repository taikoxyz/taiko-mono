// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEntriesTree } from "../libs/LibEntriesTree.sol";
import { LibEtnaKeys } from "../libs/LibEtnaKeys.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./EtnaStakingRegistry_Layout.sol"; // DO NOT DELETE

/// @title EtnaStakingRegistry
/// @notice The TAIKO staking registry of the Etna PoS chain; see `IEtnaStakingRegistry`.
/// @dev All state lives in three ERC-7201 namespaces (spec appendix B). `taiko.etna.registry`
/// holds, from its base R: `checkpoints` (R) and `entries` (R + 1), the only slots nodes read,
/// then the tree nodes, the free slot list and the used key addresses (C12).
/// `taiko.etna.registry.owners` holds the bond owners and
/// `taiko.etna.registry.exit-confirmations` the exit confirmations; neither enters the entries
/// root. The Inbox proxy and the L2 chain id are immutables. Every L1 block the registry stores
/// (activation, exit and checkpoint blocks) is below the no-exit sentinel 2^48 - 1.
/// @custom:security-contact security@taiko.xyz
contract EtnaStakingRegistry is EssentialContract, IEtnaStakingRegistry {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @custom:storage-location erc7201:taiko.etna.registry
    struct RegistryStorage {
        /// @dev Slot R: one checkpoint per L1 block that changed an entry.
        Checkpoint[] checkpoints;
        /// @dev Slot R + 1: the entries, indexed by bond id.
        Entry[] entries;
        /// @dev Slot R + 2: the `LibEntriesTree` nodes.
        mapping(uint256 node => bytes32 hash) tree;
        /// @dev Slot R + 3: released bond ids, reused last-in first-out.
        uint256[] freeSlots;
        /// @dev Slot R + 4: the consensus key addresses ever registered.
        mapping(address ckAddr => bool used) keyUsed;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry.owners
    struct OwnersStorage {
        mapping(uint256 bondId => address owner) owners;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry.exit-confirmations
    struct ExitConfirmationsStorage {
        mapping(uint256 bondId => uint256 l1Block) exitConfirmedAtL1;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The `exitEffectiveL1` of an entry with no exit set.
    uint48 public constant NO_EXIT = type(uint48).max;

    /// @notice The number of slots (the entries tree capacity).
    uint256 public constant MAX_ENTRIES = LibEntriesTree.CAPACITY;

    /// @dev Delays must be below this bound (C14).
    uint256 private constant _DELAY_BOUND = 2 ** 32;

    /// @dev The basis points of a whole stake.
    uint256 private constant _BPS = 10_000;

    /// @dev `erc7201("taiko.etna.registry")`: the base slot R of `RegistryStorage`.
    bytes32 private constant _REGISTRY_STORAGE_SLOT =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;

    /// @dev `erc7201("taiko.etna.registry.owners")`.
    bytes32 private constant _OWNERS_STORAGE_SLOT =
        0x39c9f3adc28a427dc5a3705913196a8ee3e586999e5fd34170cb091706065d00;

    /// @dev `erc7201("taiko.etna.registry.exit-confirmations")`.
    bytes32 private constant _EXIT_CONFIRMATIONS_STORAGE_SLOT =
        0x25e74f824855a18216fe2fa8b7d9dcc76ad83f6de1a344c666c3293e57124900;

    /// @dev The EIP-712 domain type hash.
    bytes32 private constant _DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev The hash of the EIP-712 domain name "EtnaStakingRegistry".
    bytes32 private constant _NAME_HASH = keccak256("EtnaStakingRegistry");

    /// @dev The hash of the EIP-712 domain version "1".
    bytes32 private constant _VERSION_HASH = keccak256("1");

    /// @dev The EIP-712 type hash of `Register(address owner)`.
    bytes32 private constant _REGISTER_TYPEHASH = keccak256("Register(address owner)");

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The staked TAIKO token.
    IERC20 public immutable token;

    /// @notice The minimum stake of a registration in token base units.
    uint256 public immutable minStake;

    /// @notice The L1 blocks from registration until the entry is active.
    uint256 public immutable activationDelay;

    /// @notice The L1 blocks from the exit request, or the activation if later, until the exit
    /// takes effect.
    uint256 public immutable exitDelay;

    /// @notice The L1 blocks from the exit confirmation until the slot can be released.
    uint256 public immutable withdrawalDelay;

    /// @notice The share of a slashed stake paid to the reporter, in basis points.
    uint256 public immutable slashBountyBps;

    /// @notice The receiver of a slashed stake minus the bounty.
    address public immutable slashSink;

    /// @dev The chain id of the Etna L2.
    uint64 private immutable _l2ChainId;

    /// @dev The Etna Inbox proxy.
    address private immutable _inbox;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the registry's immutable parameters.
    /// @param _config The configuration: non-zero token, minimum stake, slash sink and L2 chain
    /// id, delays in [1, 2^32), a bounty of at most 10,000 bps and an Inbox with code.
    constructor(Config memory _config) {
        require(_config.token != address(0), InvalidConfig());
        require(_config.minStake != 0, InvalidConfig());
        require(_isValidDelay(_config.activationDelay), InvalidConfig());
        require(_isValidDelay(_config.exitDelay), InvalidConfig());
        require(_isValidDelay(_config.withdrawalDelay), InvalidConfig());
        require(_config.slashBountyBps <= _BPS, InvalidConfig());
        require(_config.slashSink != address(0), InvalidConfig());
        require(_config.l2ChainId != 0, InvalidConfig());
        require(_config.inbox.code.length != 0, InvalidConfig());

        token = IERC20(_config.token);
        minStake = _config.minStake;
        activationDelay = _config.activationDelay;
        exitDelay = _config.exitDelay;
        withdrawalDelay = _config.withdrawalDelay;
        slashBountyBps = _config.slashBountyBps;
        slashSink = _config.slashSink;
        _l2ChainId = _config.l2ChainId;
        _inbox = _config.inbox;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner of the registry.
    /// @param _owner The owner; `msg.sender` if zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function register(
        bytes calldata _publicKey,
        uint256 _amount,
        bytes calldata _popSig
    )
        external
        nonReentrant
        returns (uint256 bondId_)
    {
        require(_amount >= minStake, StakeTooLow());
        (uint8 prefix, bytes32 x, bytes32 y) = LibEtnaKeys.parsePublicKey(_publicKey);
        address ckAddr = LibEtnaKeys.ckAddr(x, y);
        // The digest names the caller, so a copied transaction cannot change the owner.
        require(
            LibEtnaKeys.recoverSigner(registerDigest(msg.sender), _popSig) == ckAddr,
            InvalidSignature()
        );

        RegistryStorage storage $ = _registryStorage();
        require(!$.keyUsed[ckAddr], KeyAlreadyUsed());
        bondId_ = _takeSlot($);
        uint48 activeFromL1 = _toEventBlock(block.number + activationDelay);

        _ownersStorage().owners[bondId_] = msg.sender;
        $.keyUsed[ckAddr] = true;
        _commit(
            $,
            bondId_,
            Entry({
                ckX: x,
                effStake: _amount,
                ckPrefix: prefix,
                activeFromL1: activeFromL1,
                exitEffectiveL1: NO_EXIT
            })
        );

        token.safeTransferFrom(msg.sender, address(this), _amount);
        emit Registered(bondId_, msg.sender, ckAddr, prefix, x, _amount, activeFromL1);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function requestExit(uint256 _bondId) external {
        RegistryStorage storage $ = _registryStorage();
        // Existence comes before ownership: an unknown or released slot has no owner.
        Entry memory entry = _unreleasedEntry($, _bondId);
        require(_ownersStorage().owners[_bondId] == msg.sender, NotBondOwner());
        require(entry.exitEffectiveL1 == NO_EXIT, ExitAlreadySet());

        entry.exitEffectiveL1 =
            _toEventBlock(Math.max(block.number, entry.activeFromL1) + exitDelay);
        _commit($, _bondId, entry);
        emit ExitRequested(_bondId, entry.exitEffectiveL1);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function confirmExit(uint256 _bondId) external {
        _checkInboxUnlocked();
        require(IEtnaInbox(_inbox).isInitialized(), InboxNotInitialized());
        uint48 exitEffectiveL1 = _unreleasedEntry(_registryStorage(), _bondId).exitEffectiveL1;
        require(exitEffectiveL1 != NO_EXIT, ExitNotSet());
        require(IEtnaInbox(_inbox).activeCommitteeSnapshot() >= exitEffectiveL1, ExitNotCovered());

        mapping(uint256 => uint256) storage confirmations =
            _exitConfirmationsStorage().exitConfirmedAtL1;
        if (confirmations[_bondId] != 0) return;
        confirmations[_bondId] = block.number;
        emit ExitConfirmed(_bondId, block.number);
    }

    /// @inheritdoc IEtnaStakingRegistry
    /// @dev Only an unreleased slot has a confirmation, so the confirmation check also rejects
    /// unknown and released bonds.
    function withdraw(uint256 _bondId, address _to) external nonReentrant {
        _checkInboxUnlocked();
        mapping(uint256 => uint256) storage confirmations =
            _exitConfirmationsStorage().exitConfirmedAtL1;
        uint256 confirmedAt = confirmations[_bondId];
        require(confirmedAt != 0, ExitNotConfirmed());
        require(block.number >= confirmedAt + withdrawalDelay, WithdrawalNotReady());

        RegistryStorage storage $ = _registryStorage();
        mapping(uint256 => address) storage owners = _ownersStorage().owners;
        uint256 amount = $.entries[_bondId].effStake;
        if (amount != 0) {
            require(owners[_bondId] == msg.sender, NotBondOwner());
            require(_to != address(0), ZERO_ADDRESS());
        }

        delete owners[_bondId];
        delete confirmations[_bondId];
        Entry memory released;
        _commit($, _bondId, released);
        $.freeSlots.push(_bondId);

        if (amount != 0) token.safeTransfer(_to, amount);
        emit StakeWithdrawn(_bondId, _to, amount);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function slashDoubleSign(uint256, Vote calldata, Vote calldata) external notImplemented { }

    /// @inheritdoc IEtnaStakingRegistry
    function forceExit(uint256, bytes32, uint256) external notImplemented { }

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
    function ownerOf(uint256 _bondId) external view returns (address) {
        return _ownersStorage().owners[_bondId];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function exitConfirmedAtL1(uint256 _bondId) external view returns (uint256) {
        return _exitConfirmationsStorage().exitConfirmedAtL1[_bondId];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function keyUsed(address _ckAddr) external view returns (bool) {
        return _registryStorage().keyUsed[_ckAddr];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function freeSlotCount() external view returns (uint256) {
        return _registryStorage().freeSlots.length;
    }

    /// @inheritdoc IEtnaStakingRegistry
    function registerDigest(address _owner) public view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this))
        );
        bytes32 structHash = keccak256(abi.encode(_REGISTER_TYPEHASH, _owner));
        return keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
    }

    /// @inheritdoc IEtnaStakingRegistry
    function inbox() external view returns (address) {
        return _inbox;
    }

    /// @inheritdoc IEtnaStakingRegistry
    function l2ChainId() external view returns (uint64) {
        return _l2ChainId;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Takes the slot of a new entry: the most recently released slot if there is one,
    /// otherwise a new slot appended after the used ones. Reverts with `RegistryFull` when all
    /// `MAX_ENTRIES` slots are used and none is free.
    /// @param $ The registry storage.
    /// @return bondId_ The slot.
    function _takeSlot(RegistryStorage storage $) private returns (uint256 bondId_) {
        uint256 freeCount = $.freeSlots.length;
        if (freeCount != 0) {
            bondId_ = $.freeSlots[freeCount - 1];
            $.freeSlots.pop();
        } else {
            bondId_ = $.entries.length;
            require(bondId_ < MAX_ENTRIES, RegistryFull());
            $.entries.push();
        }
    }

    /// @dev Returns the entry of a used, unreleased slot. A registered entry's `ckPrefix` is 0x02
    /// or 0x03, and a released slot's entry is all zero.
    /// @param $ The registry storage.
    /// @param _bondId The bond id.
    /// @return entry_ The entry; reverts with `UnknownBond` for a never-used slot and with
    /// `SlotReleased` for a released one.
    function _unreleasedEntry(
        RegistryStorage storage $,
        uint256 _bondId
    )
        private
        view
        returns (Entry storage entry_)
    {
        require(_bondId < $.entries.length, UnknownBond());
        entry_ = $.entries[_bondId];
        require(entry_.ckPrefix != 0, SlotReleased());
    }

    /// @dev Writes entry `_bondId`, its tree leaf and the current block's checkpoint. The
    /// checkpoint overwrites the last one if that is from this block and is appended otherwise,
    /// so every L1 block that changes an entry ends with exactly one checkpoint.
    /// @param $ The registry storage.
    /// @param _bondId The bond id, below `entries.length`.
    /// @param _entry The entry's new value.
    function _commit(RegistryStorage storage $, uint256 _bondId, Entry memory _entry) private {
        $.entries[_bondId] = _entry;
        uint256 count = $.entries.length;
        bytes32 root =
            LibEntriesTree.update($.tree, count, _bondId, LibEntriesTree.leaf(_bondId, _entry));

        uint48 l1Block = _toEventBlock(block.number);
        // `count` is at most MAX_ENTRIES.
        Checkpoint memory checkpoint =
            Checkpoint({ l1Block: l1Block, count: uint48(count), entriesRoot: root });
        uint256 index = $.checkpoints.length;
        if (index != 0 && $.checkpoints[index - 1].l1Block == l1Block) {
            $.checkpoints[--index] = checkpoint;
        } else {
            $.checkpoints.push(checkpoint);
        }
        emit CheckpointWritten(index, l1Block, uint48(count), root);
    }

    /// @dev Reverts with `InboxLocked` while the Inbox is executing `land` or `recover` (C8).
    function _checkInboxUnlocked() private view {
        require(!EssentialContract(_inbox).inNonReentrant(), InboxLocked());
    }

    /// @dev Returns an L1 block as a 48-bit value below the no-exit sentinel.
    /// @param _block The L1 block.
    /// @return The block; reverts with `InvalidEventBlock` unless it is below `NO_EXIT`.
    function _toEventBlock(uint256 _block) private pure returns (uint48) {
        require(_block < NO_EXIT, InvalidEventBlock());
        return uint48(_block);
    }

    /// @dev Returns whether a delay is in [1, 2^32) (C14).
    /// @param _delay The delay in L1 blocks.
    /// @return Whether the delay is valid.
    function _isValidDelay(uint256 _delay) private pure returns (bool) {
        return _delay != 0 && _delay < _DELAY_BOUND;
    }

    /// @dev Returns the `taiko.etna.registry` storage.
    /// @return $ The registry storage.
    function _registryStorage() private pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := _REGISTRY_STORAGE_SLOT
        }
    }

    /// @dev Returns the `taiko.etna.registry.owners` storage.
    /// @return $ The owners storage.
    function _ownersStorage() private pure returns (OwnersStorage storage $) {
        assembly {
            $.slot := _OWNERS_STORAGE_SLOT
        }
    }

    /// @dev Returns the `taiko.etna.registry.exit-confirmations` storage.
    /// @return $ The exit confirmations storage.
    function _exitConfirmationsStorage() private pure returns (ExitConfirmationsStorage storage $) {
        assembly {
            $.slot := _EXIT_CONFIRMATIONS_STORAGE_SLOT
        }
    }
}
