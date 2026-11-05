// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "../libs/LibCometVote.sol";
import { LibEntriesTree } from "../libs/LibEntriesTree.sol";
import { LibEtnaKeys } from "../libs/LibEtnaKeys.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./EtnaStakingRegistry_Layout.sol"; // DO NOT DELETE

/// @title EtnaStakingRegistry
/// @notice The TAIKO staking registry of the Etna PoS chain; see `IEtnaStakingRegistry`.
/// @dev All state lives in five ERC-7201 namespaces (spec appendix B). `taiko.etna.registry`
/// holds, from its base R: `checkpoints` (R) and the slot-indexed `entries` (R + 1), the only
/// slots nodes read, then the storage appendix B does not name: the entries tree nodes, the
/// admission index, the key and slot lookups, the bond records and the bond count.
/// `taiko.etna.registry.owners` holds the bond owners, `taiko.etna.registry.exit-confirmations`
/// the exit confirmations, `taiko.etna.registry.top-ups` the pending top-ups and
/// `taiko.etna.registry.forfeitures` the lifetime forfeiture flags; none enters the entries root.
/// The Inbox proxy and the L2 chain id are immutables. Every L1 block the registry stores
/// (activation, exit and checkpoint blocks) is below the no-exit sentinel 2^48 - 1.
///
/// The admission index is a tournament tree over the 4096 slots: node 1 is the root and leaf
/// `4096 + slot` holds the slot's key `value << 12 | slot`, so the smallest key is the smallest
/// value, ties going to the lowest slot. An unwritten node reads as value 0 at its leftmost slot;
/// the only written key that is 0, value 0 at slot 0, reads the same.
/// @custom:security-contact security@taiko.xyz
contract EtnaStakingRegistry is EssentialContract, IEtnaStakingRegistry {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @custom:storage-location erc7201:taiko.etna.registry
    struct RegistryStorage {
        /// @dev Slot R: one checkpoint per L1 block that changed the entry in a slot.
        Checkpoint[] checkpoints;
        /// @dev Slot R + 1: the entries, indexed by slot.
        Entry[] entries;
        /// @dev Slot R + 2: the `LibEntriesTree` nodes.
        mapping(uint256 node => bytes32 hash) tree;
        /// @dev Slot R + 3: the admission index nodes.
        mapping(uint256 node => uint256 key) minIndex;
        /// @dev Slot R + 4: bond id + 1 of every consensus key address ever registered.
        mapping(address ckAddr => uint256 bondIdPlusOne) keyBond;
        /// @dev Slot R + 5: bond id + 1 of every held slot.
        mapping(uint256 slot => uint256 bondIdPlusOne) slotBond;
        /// @dev Slot R + 6: the bond records.
        mapping(uint256 bondId => Bond bond) bonds;
        /// @dev Slot R + 7: the number of bonds issued, the next bond id.
        uint256 bondCount;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry.owners
    struct OwnersStorage {
        mapping(uint256 bondId => address owner) owners;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry.exit-confirmations
    struct ExitConfirmationsStorage {
        mapping(uint256 bondId => uint256 l1Block) exitConfirmedAtL1;
    }

    /// @dev Principal awaiting explicit activation, outside the entries root.
    struct TopUp {
        uint256 pendingTopUp;
        uint48 readyAtL1;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry.top-ups
    struct TopUpsStorage {
        mapping(uint256 bondId => TopUp topUp) topUps;
    }

    /// @custom:storage-location erc7201:taiko.etna.registry.forfeitures
    struct ForfeituresStorage {
        mapping(bytes32 entryKey => bool forfeited) forfeitures;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The `exitEffectiveL1` of an entry with no exit set.
    uint48 public constant NO_EXIT = type(uint48).max;

    /// @notice The number of slots (the entries tree capacity).
    uint256 public constant MAX_ENTRIES = LibEntriesTree.CAPACITY;

    /// @dev Slot values must be below this bound, so an admission key fits in a word.
    uint256 private constant _VALUE_BOUND = 2 ** 244;

    /// @dev Delays must be below this bound, so an oversized delay cannot make every
    /// registration or exit request revert.
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

    /// @dev erc7201("taiko.etna.registry.top-ups").
    bytes32 private constant _TOP_UPS_STORAGE_SLOT =
        0x3a1aea98c955969894fa1164a9cf4fb395d732d0191953a25567edb8a7c00400;

    /// @dev erc7201("taiko.etna.registry.forfeitures").
    bytes32 private constant _FORFEITURES_STORAGE_SLOT =
        0xdfeb3c25dc200ebc2d2e4944bf5b28b239af40d34f2491dee100754230b61400;

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

    /// @notice The L1 blocks from the exit confirmation until the bond can be withdrawn.
    uint256 public immutable withdrawalDelay;

    /// @notice The share of a slashed stake paid to the reporter, in basis points.
    uint256 public immutable slashBountyBps;

    /// @notice The receiver of a slashed stake minus the bounty.
    address public immutable slashSink;

    /// @inheritdoc IEtnaStakingRegistry
    uint256 public immutable override forfeitBps;

    /// @inheritdoc IEtnaStakingRegistry
    uint64 public immutable override l2ChainId;

    /// @inheritdoc IEtnaStakingRegistry
    address public immutable override inbox;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the registry's immutable parameters.
    /// @param _config The configuration: non-zero token, minimum stake, slash sink and L2 chain
    /// id, delays in [1, 2^32), a bounty below 10,000 bps (zero allowed), a forfeit rate in
    /// [1, 10,000] bps and an Inbox with code.
    constructor(Config memory _config) {
        require(_config.token != address(0), InvalidConfig());
        require(_config.minStake != 0, InvalidConfig());
        require(_isValidDelay(_config.activationDelay), InvalidConfig());
        require(_isValidDelay(_config.exitDelay), InvalidConfig());
        require(_isValidDelay(_config.withdrawalDelay), InvalidConfig());
        require(_config.slashBountyBps < _BPS, InvalidConfig());
        require(_config.slashSink != address(0), InvalidConfig());
        require(_config.l2ChainId != 0, InvalidConfig());
        require(_config.inbox.code.length != 0, InvalidConfig());
        require(_config.forfeitBps != 0 && _config.forfeitBps <= _BPS, InvalidConfig());

        token = IERC20(_config.token);
        minStake = _config.minStake;
        activationDelay = _config.activationDelay;
        exitDelay = _config.exitDelay;
        withdrawalDelay = _config.withdrawalDelay;
        slashBountyBps = _config.slashBountyBps;
        slashSink = _config.slashSink;
        l2ChainId = _config.l2ChainId;
        inbox = _config.inbox;
        forfeitBps = _config.forfeitBps;
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
    /// @dev Unaffected by pause.
    function register(
        bytes calldata _publicKey,
        uint256 _amount,
        bytes calldata _popSig
    )
        external
        nonReentrant
        returns (uint256 bondId_)
    {
        _checkInboxUnlocked();
        require(_amount >= minStake, StakeTooLow());
        (uint8 prefix, bytes32 x, bytes32 y) = LibEtnaKeys.parsePublicKey(_publicKey);
        address ckAddr = LibEtnaKeys.ckAddr(x, y);
        // The digest names the caller, so a copied transaction cannot change the owner.
        require(
            LibEtnaKeys.recoverSigner(registerDigest(msg.sender), _popSig) == ckAddr,
            InvalidSignature()
        );

        RegistryStorage storage $ = _registryStorage();
        require($.keyBond[ckAddr] == 0, KeyAlreadyUsed());
        bondId_ = $.bondCount++;
        _takeSlot($, bondId_, _amount);
        uint48 activeFromL1 = _toEventBlock(block.number + activationDelay);

        $.keyBond[ckAddr] = bondId_ + 1;
        _ownersStorage().owners[bondId_] = msg.sender;
        _save(
            $,
            $.bonds[bondId_],
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
    /// @dev Unaffected by pause.
    function requestExit(uint256 _bondId) external nonReentrant {
        _checkInboxUnlocked();
        RegistryStorage storage $ = _registryStorage();
        Bond storage bond = _unwithdrawnBond($, _bondId);
        require(_ownersStorage().owners[_bondId] == msg.sender, NotBondOwner());
        Entry memory entry = bond.entry;
        require(entry.exitEffectiveL1 == NO_EXIT, ExitAlreadySet());

        entry.exitEffectiveL1 =
            _toEventBlock(Math.max(block.number, entry.activeFromL1) + exitDelay);
        _save($, bond, entry);
        emit ExitRequested(_bondId, entry.exitEffectiveL1);
    }

    /// @inheritdoc IEtnaStakingRegistry
    /// @dev Unaffected by pause.
    function confirmExit(uint256 _bondId) external nonReentrant {
        _checkInboxUnlocked();
        require(IEtnaInbox(inbox).isInitialized(), InboxNotInitialized());
        uint48 exitEffectiveL1 = _unwithdrawnBond(_registryStorage(), _bondId).entry.exitEffectiveL1;
        require(exitEffectiveL1 != NO_EXIT, ExitNotSet());
        require(IEtnaInbox(inbox).activeCommitteeSnapshot() >= exitEffectiveL1, ExitNotCovered());

        mapping(uint256 => uint256) storage confirmations =
            _exitConfirmationsStorage().exitConfirmedAtL1;
        if (confirmations[_bondId] != 0) return;
        confirmations[_bondId] = block.number;
        emit ExitConfirmed(_bondId, block.number);
    }

    /// @inheritdoc IEtnaStakingRegistry
    /// @dev Unaffected by pause.
    function withdraw(uint256 _bondId, address _to) external nonReentrant {
        _checkInboxUnlocked();
        RegistryStorage storage $ = _registryStorage();
        Bond storage bond = _unwithdrawnBond($, _bondId);
        mapping(uint256 => uint256) storage confirmations =
            _exitConfirmationsStorage().exitConfirmedAtL1;
        uint256 confirmedAt = confirmations[_bondId];
        require(confirmedAt != 0, ExitNotConfirmed());
        require(block.number >= confirmedAt + withdrawalDelay, WithdrawalNotReady());

        mapping(uint256 => address) storage owners = _ownersStorage().owners;
        uint256 amount = bond.entry.effStake + _topUpsStorage().topUps[_bondId].pendingTopUp;
        if (amount != 0) {
            require(owners[_bondId] == msg.sender, NotBondOwner());
            require(_to != address(0), ZERO_ADDRESS());
        }

        delete owners[_bondId];
        delete confirmations[_bondId];
        delete _topUpsStorage().topUps[_bondId];
        bond.entry.effStake = 0;
        bond.withdrawn = true;
        if (bond.holdsSlot) {
            uint256 slot = bond.slot;
            bond.holdsSlot = false;
            delete $.slotBond[slot];
            Entry memory empty;
            _commit($, slot, empty);
            _setSlotValue($, slot, 0);
        }

        if (amount != 0) token.safeTransfer(_to, amount);
        emit StakeWithdrawn(_bondId, _to, amount);
    }

    /// @inheritdoc IEtnaStakingRegistry
    /// @dev Checks in order: the Inbox's initialization, both votes' ranges, the pair (same type,
    /// height, round and generation, different block ids), the generation, the bond and its
    /// stake, then both signatures. The slash is written before either transfer. Unaffected by
    /// pause. The Inbox lock rejects callbacks into slashing from any Inbox entry point.
    function slashDoubleSign(
        uint256 _bondId,
        Vote calldata _voteA,
        Vote calldata _voteB
    )
        external
        nonReentrant
    {
        _checkInboxUnlocked();
        require(IEtnaInbox(inbox).isInitialized(), InboxNotInitialized());
        Vote memory voteA = _voteA;
        Vote memory voteB = _voteB;
        LibCometVote.checkRanges(voteA);
        LibCometVote.checkRanges(voteB);
        require(
            voteA.voteType == voteB.voteType && voteA.height == voteB.height
                && voteA.round == voteB.round && voteA.generation == voteB.generation
                && !LibCometVote.sameBlockId(voteA, voteB),
            NotDoubleSign()
        );
        require(voteA.generation <= IEtnaInbox(inbox).recoveryGeneration(), FutureGeneration());

        Bond storage bond = _unwithdrawnBond(_registryStorage(), _bondId);
        Entry memory entry = bond.entry;
        uint256 amount = entry.effStake + _topUpsStorage().topUps[_bondId].pendingTopUp;
        require(amount != 0, NothingToSlash());

        // The key was validated at registration, so it decompresses.
        address signer =
            LibEtnaKeys.ckAddr(entry.ckX, LibEtnaKeys.decompress(entry.ckPrefix, entry.ckX));
        bytes memory cometChainId = LibCometVote.chainId(
            LibCometVote.chainDomain(block.chainid, l2ChainId, inbox, voteA.generation)
        );
        require(
            _voteSigner(voteA, cometChainId) == signer
                && _voteSigner(voteB, cometChainId) == signer,
            InvalidSignature()
        );

        delete _topUpsStorage().topUps[_bondId];
        // The entry changes only if it has effective stake or its exit is later than this block.
        if (entry.effStake != 0 || block.number < entry.exitEffectiveL1) {
            entry.effStake = 0;
            // At most the stored exit, so it fits in 48 bits.
            entry.exitEffectiveL1 = uint48(Math.min(entry.exitEffectiveL1, block.number));
            _save(_registryStorage(), bond, entry);
        }
        if (bond.holdsSlot) _setSlotValue(_registryStorage(), bond.slot, 0);

        uint256 bounty = Math.mulDiv(amount, slashBountyBps, _BPS);
        // A zero rate or a dust slash pays no bounty; skip the zero transfer.
        if (bounty != 0) token.safeTransfer(msg.sender, bounty);
        token.safeTransfer(slashSink, amount - bounty);
        emit DoubleSignSlashed(
            _bondId,
            msg.sender,
            amount,
            bounty,
            voteA.generation,
            voteA.height,
            voteA.round,
            voteA.voteType
        );
    }

    /// @inheritdoc IEtnaStakingRegistry
    /// @dev Checks in order: the caller, the bond (`UnknownBond`), the entry key, then the current
    /// block, which must be below the no-exit sentinel (`InvalidEventBlock`) so an excluded bond
    /// is always left with an exit. An exit already at or before the current block, as a
    /// displaced or withdrawn bond has, is kept with no checkpoint or event. Unaffected by pause.
    function forceExit(uint256 _bondId, bytes32 _entryKey) external nonReentrant {
        require(msg.sender == inbox, NotInbox());
        RegistryStorage storage $ = _registryStorage();
        Bond storage bond = _issuedBond($, _bondId);
        Entry memory entry = bond.entry;
        require(_entryKey == LibEtnaKeys.entryKey(entry.ckPrefix, entry.ckX), EntryKeyMismatch());
        uint48 r = _toEventBlock(block.number);
        if (r >= entry.exitEffectiveL1) return;

        entry.exitEffectiveL1 = r;
        _save($, bond, entry);
        emit ExitForced(_bondId, r);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function topUp(uint256 _bondId, uint256 _amount) external nonReentrant {
        _checkInboxUnlocked();
        RegistryStorage storage $ = _registryStorage();
        Bond storage bond = _unwithdrawnBond($, _bondId);
        require(_ownersStorage().owners[_bondId] == msg.sender, NotBondOwner());
        Entry storage entry = bond.entry;
        require(block.number >= entry.activeFromL1 && entry.effStake != 0, TopUpNotAllowed());
        require(entry.exitEffectiveL1 == NO_EXIT, ExitAlreadySet());
        // Admission gives a bond its slot and displacement sets its exit, so a bond without an
        // exit holds its slot; checked so the slot write below cannot reach another bond's slot.
        require(bond.holdsSlot, TopUpNotAllowed());
        require(_amount != 0, InvalidTopUpAmount());
        TopUp storage pending = _topUpsStorage().topUps[_bondId];
        require(pending.pendingTopUp == 0, TopUpPending());
        // The eventual combined balance must remain representable as uint256.
        require(_amount <= type(uint256).max - entry.effStake, InvalidTopUpAmount());
        uint48 readyAt = _toEventBlock(block.number + activationDelay);
        pending.pendingTopUp = _amount;
        pending.readyAtL1 = readyAt;
        _setSlotValue($, bond.slot, entry.effStake + _amount);
        token.safeTransferFrom(msg.sender, address(this), _amount);
        emit TopUpDeposited(_bondId, _amount, readyAt);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function activateTopUp(uint256 _bondId) external nonReentrant {
        _checkInboxUnlocked();
        RegistryStorage storage $ = _registryStorage();
        Bond storage bond = _unwithdrawnBond($, _bondId);
        Entry memory entry = bond.entry;
        require(entry.exitEffectiveL1 == NO_EXIT, ExitAlreadySet());
        TopUp memory pending = _topUpsStorage().topUps[_bondId];
        require(pending.pendingTopUp != 0 && block.number >= pending.readyAtL1, TopUpNotReady());
        entry.effStake += pending.pendingTopUp;
        delete _topUpsStorage().topUps[_bondId];
        _save($, bond, entry);
        emit TopUpActivated(_bondId, pending.pendingTopUp);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function forfeit(
        uint256 _bondId,
        bytes32 _entryKey,
        bytes32 _incidentId,
        uint256 _validUntil
    )
        external
        onlyOwner
        nonReentrant
    {
        _checkInboxUnlocked();
        require(IEtnaInbox(inbox).isInitialized(), InboxNotInitialized());
        require(block.timestamp <= _validUntil, AuthorizationExpired());
        RegistryStorage storage $ = _registryStorage();
        Bond storage bond = _unwithdrawnBond($, _bondId);
        Entry memory entry = bond.entry;
        require(_entryKey == LibEtnaKeys.entryKey(entry.ckPrefix, entry.ckX), EntryKeyMismatch());
        ForfeituresStorage storage flags = _forfeituresStorage();
        require(!flags.forfeitures[_entryKey], AlreadyForfeited());
        TopUp storage pending = _topUpsStorage().topUps[_bondId];
        uint256 balance = entry.effStake + pending.pendingTopUp;
        require(balance != 0, NothingToSlash());
        uint256 penalty = Math.mulDiv(balance, forfeitBps, _BPS, Math.Rounding.Up);
        uint256 fromEffective = Math.min(penalty, entry.effStake);
        entry.effStake -= fromEffective;
        pending.pendingTopUp -= penalty - fromEffective;
        if (pending.pendingTopUp == 0) pending.readyAtL1 = 0;
        flags.forfeitures[_entryKey] = true;
        uint48 exit = uint48(Math.min(entry.exitEffectiveL1, _toEventBlock(block.number)));
        if (fromEffective != 0 || exit != entry.exitEffectiveL1) {
            entry.exitEffectiveL1 = exit;
            _save($, bond, entry);
        }
        if (bond.holdsSlot) _setSlotValue($, bond.slot, balance - penalty);
        token.safeTransfer(slashSink, penalty);
        emit Forfeited(_bondId, _entryKey, _incidentId, balance, penalty);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function topUpOf(uint256 _bondId)
        external
        view
        returns (uint256 pendingTopUp_, uint48 readyAtL1_)
    {
        TopUp storage pending = _topUpsStorage().topUps[_bondId];
        return (pending.pendingTopUp, pending.readyAtL1);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function forfeited(bytes32 _entryKey) external view returns (bool forfeited_) {
        return _forfeituresStorage().forfeitures[_entryKey];
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
    function entryAt(uint256 _slot) external view returns (Entry memory entry_) {
        require(_slot < MAX_ENTRIES, UnknownSlot());
        RegistryStorage storage $ = _registryStorage();
        if (_slot < $.entries.length) entry_ = $.entries[_slot];
    }

    /// @inheritdoc IEtnaStakingRegistry
    function entriesRoot() external view returns (bytes32) {
        RegistryStorage storage $ = _registryStorage();
        return LibEntriesTree.root($.tree, $.entries.length);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function bondCount() external view returns (uint256) {
        return _registryStorage().bondCount;
    }

    /// @inheritdoc IEtnaStakingRegistry
    function bondAt(uint256 _bondId) external view returns (Bond memory) {
        return _issuedBond(_registryStorage(), _bondId);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function bondForKey(address _ckAddr) external view returns (bool registered_, uint256 bondId_) {
        return _lookup(_registryStorage().keyBond[_ckAddr]);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function bondInSlot(uint256 _slot) external view returns (bool occupied_, uint256 bondId_) {
        require(_slot < MAX_ENTRIES, UnknownSlot());
        return _lookup(_registryStorage().slotBond[_slot]);
    }

    /// @inheritdoc IEtnaStakingRegistry
    function slotOfBond(uint256 _bondId) external view returns (bool holdsSlot_, uint256 slot_) {
        RegistryStorage storage $ = _registryStorage();
        if (_bondId < $.bondCount && $.bonds[_bondId].holdsSlot) {
            return (true, $.bonds[_bondId].slot);
        }
    }

    /// @inheritdoc IEtnaStakingRegistry
    function admissionThreshold() external view returns (uint256 slot_, uint256 value_) {
        return _admissionThreshold(_registryStorage());
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
    function registerDigest(address _owner) public view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this))
        );
        bytes32 structHash = keccak256(abi.encode(_REGISTER_TYPEHASH, _owner));
        return keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Returns an issued bond.
    /// @param $ The registry storage.
    /// @param _bondId The bond id.
    /// @return bond_ The bond; reverts with `UnknownBond` unless `_bondId` was issued.
    function _issuedBond(
        RegistryStorage storage $,
        uint256 _bondId
    )
        private
        view
        returns (Bond storage bond_)
    {
        require(_bondId < $.bondCount, UnknownBond());
        bond_ = $.bonds[_bondId];
    }

    /// @dev Returns an issued bond that was not withdrawn.
    /// @param $ The registry storage.
    /// @param _bondId The bond id.
    /// @return bond_ The bond; reverts with `UnknownBond` for an unissued id and with
    /// `BondWithdrawn` for a withdrawn bond.
    function _unwithdrawnBond(
        RegistryStorage storage $,
        uint256 _bondId
    )
        private
        view
        returns (Bond storage bond_)
    {
        bond_ = _issuedBond($, _bondId);
        require(!bond_.withdrawn, BondWithdrawn());
    }

    /// @dev Gives a new bond the slot of the admission threshold and sets the slot's value,
    /// displacing the bond holding it: that bond leaves the slot and its exit becomes min(its
    /// exit, the current block). The caller writes the slot's entry.
    /// @param $ The registry storage.
    /// @param _bondId The new bond.
    /// @param _amount The new bond's stake, which must exceed the slot's value.
    function _takeSlot(
        RegistryStorage storage $,
        uint256 _bondId,
        uint256 _amount
    )
        private
    {
        (uint256 slot, uint256 value) = _admissionThreshold($);
        require(_amount > value, StakeTooLow());
        uint256 occupant = $.slotBond[slot];
        if (occupant != 0) {
            Bond storage displaced = $.bonds[occupant - 1];
            displaced.holdsSlot = false;
            // At most the stored exit, so it fits in 48 bits.
            displaced.entry.exitEffectiveL1 =
                uint48(Math.min(displaced.entry.exitEffectiveL1, block.number));
            emit BondDisplaced(occupant - 1, slot, _bondId);
        } else if (slot == $.entries.length) {
            // An empty slot below `entries.length` would have been taken first.
            $.entries.push();
        }
        $.slotBond[slot] = _bondId + 1;
        Bond storage bond = $.bonds[_bondId];
        bond.slot = uint16(slot);
        bond.holdsSlot = true;
        _setSlotValue($, slot, _amount);
    }

    /// @dev Writes a bond's entry fields and, if it holds a slot, the slot's entry, its tree leaf
    /// and the current block's checkpoint.
    /// @param $ The registry storage.
    /// @param _bond The bond.
    /// @param _entry The bond's new entry fields.
    function _save(
        RegistryStorage storage $,
        Bond storage _bond,
        Entry memory _entry
    )
        private
    {
        _bond.entry = _entry;
        if (_bond.holdsSlot) _commit($, _bond.slot, _entry);
    }

    /// @dev Writes the entry of `_slot`, its tree leaf and the current block's checkpoint. The
    /// checkpoint overwrites the last one if that is from this block and is appended otherwise,
    /// so every L1 block that changes the entry in a slot ends with exactly one checkpoint.
    /// @param $ The registry storage.
    /// @param _slot The slot, below `entries.length`.
    /// @param _entry The slot's new entry.
    function _commit(
        RegistryStorage storage $,
        uint256 _slot,
        Entry memory _entry
    )
        private
    {
        $.entries[_slot] = _entry;
        uint256 count = $.entries.length;
        bytes32 root =
            LibEntriesTree.update($.tree, count, _slot, LibEntriesTree.leaf(_slot, _entry));

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

    /// @dev Sets a slot's admission value and updates its ancestors, stopping at the first node
    /// whose key does not change.
    /// @param $ The registry storage.
    /// @param _slot The slot.
    /// @param _value The slot's new value: its bond's effStake + pendingTopUp, or 0 if empty.
    function _setSlotValue(
        RegistryStorage storage $,
        uint256 _slot,
        uint256 _value
    )
        private
    {
        require(_value < _VALUE_BOUND, BalanceTooLarge());
        uint256 node = MAX_ENTRIES + _slot;
        uint256 key = _value << LibEntriesTree.DEPTH | _slot;
        for (uint256 level;; ++level) {
            if (_minKey($, node, level) == key) return;
            $.minIndex[node] = key;
            if (node == 1) return;
            uint256 sibling = _minKey($, node ^ 1, level);
            if (sibling < key) key = sibling;
            node >>= 1;
        }
    }

    /// @dev Returns the key of an admission index node.
    /// @param $ The registry storage.
    /// @param _node The node, in [1, 2 * MAX_ENTRIES).
    /// @param _level The node's height above the leaves.
    /// @return key_ The smallest `value << 12 | slot` under the node; value 0 at the node's
    /// leftmost slot if the node was never written.
    function _minKey(
        RegistryStorage storage $,
        uint256 _node,
        uint256 _level
    )
        private
        view
        returns (uint256 key_)
    {
        key_ = $.minIndex[_node];
        if (key_ == 0) key_ = (_node << _level) - MAX_ENTRIES;
    }

    /// @dev Returns the slot a registration takes and its value.
    /// @param $ The registry storage.
    /// @return slot_ The slot with the smallest value, the lowest one on a tie.
    /// @return value_ Its value.
    function _admissionThreshold(RegistryStorage storage $)
        private
        view
        returns (uint256 slot_, uint256 value_)
    {
        uint256 key = _minKey($, 1, LibEntriesTree.DEPTH);
        return (key & (MAX_ENTRIES - 1), key >> LibEntriesTree.DEPTH);
    }

    /// @dev Decodes a stored bond id + 1.
    /// @param _bondIdPlusOne The stored value; 0 if none.
    /// @return found_ Whether it names a bond.
    /// @return bondId_ The bond id; 0 if none.
    function _lookup(uint256 _bondIdPlusOne) private pure returns (bool found_, uint256 bondId_) {
        if (_bondIdPlusOne != 0) return (true, _bondIdPlusOne - 1);
    }

    /// @dev Recovers the signer of a vote from its signature over keccak256 of its CometBFT sign
    /// bytes (appendix A). Reverts with `InvalidSignature` if `LibEtnaKeys.recoverSigner` rejects
    /// the signature: V, R or S out of range, or no address recovered.
    /// @param _vote The vote.
    /// @param _cometChainId The CometBFT chain id the vote is checked under.
    /// @return The recovered address.
    function _voteSigner(
        Vote memory _vote,
        bytes memory _cometChainId
    )
        private
        pure
        returns (address)
    {
        return LibEtnaKeys.recoverSigner(
            keccak256(LibCometVote.signBytes(_vote, _cometChainId)), _vote.signature
        );
    }

    /// @dev Reverts with `InboxLocked` while any Inbox entry point that takes its reentrancy lock
    /// is executing, its transfers included, so registry mutations cannot run inside Inbox
    /// execution. Only the Inbox-authorized forceExit deliberately skips this reciprocal check.
    function _checkInboxUnlocked() private view {
        require(!EssentialContract(inbox).inNonReentrant(), InboxLocked());
    }

    /// @dev Returns an L1 block as a 48-bit value below the no-exit sentinel.
    /// @param _block The L1 block.
    /// @return The block; reverts with `InvalidEventBlock` unless it is below `NO_EXIT`.
    function _toEventBlock(uint256 _block) private pure returns (uint48) {
        require(_block < NO_EXIT, InvalidEventBlock());
        return uint48(_block);
    }

    /// @dev Returns whether a delay is in [1, 2^32), the bound that keeps an oversized delay from
    /// making every registration or exit request revert.
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

    /// @dev Returns delayed principal in its independent namespace.
    /// @return $ The top-up storage.
    function _topUpsStorage() private pure returns (TopUpsStorage storage $) {
        assembly {
            $.slot := _TOP_UPS_STORAGE_SLOT
        }
    }

    /// @dev Returns lifetime flags in their independent namespace; flags are never deleted.
    /// @return $ The forfeiture storage.
    function _forfeituresStorage() private pure returns (ForfeituresStorage storage $) {
        assembly {
            $.slot := _FORFEITURES_STORAGE_SLOT
        }
    }
}
