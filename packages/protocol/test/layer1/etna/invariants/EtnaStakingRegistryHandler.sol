// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestKeys } from "../EtnaTestKeys.sol";
import { MockEtnaInbox } from "../MockEtnaInbox.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title EtnaStakingRegistryHandler
/// @notice Drives an `EtnaStakingRegistry` fixed to a `MockEtnaInbox` through registrations with
/// real secp256k1 keys and proofs of possession, exit requests, exit confirmations, withdrawals,
/// double-sign slashing with real vote signatures, recovery exclusions, landed snapshots and L1
/// time, and keeps an independent model of the entries, owners, confirmations, used keys, free
/// slots, stake and checkpoints the registry must hold.
/// @dev Every call is valid or broken in exactly one named way. The handler predicts the outcome
/// from its model, success or the exact revert data, runs the call in try/catch and records a
/// violation when the registry disagrees, so the handler itself never reverts and
/// `fail_on_revert` stays meaningful. It checks per call what the invariants cannot see
/// afterwards (the bond id taken, token movements, checkpoints a call must not write); the
/// invariants compare the registry's storage with the model after every call.
contract EtnaStakingRegistryHandler is CommonBase {
    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    /// @dev The invariant a recorded violation breaks.
    enum Property {
        Root,
        History,
        Snapshots,
        Reuse,
        Keys,
        Balance,
        Timing,
        Cap
    }

    /// @dev The model of one slot: the entry the registry must hold and its current occupant's
    /// bookkeeping. A released slot keeps only `occupancies` and `formerEntryKey`.
    struct Slot {
        IEtnaStakingRegistry.Entry entry;
        address owner;
        /// @dev The occupant's consensus private key.
        uint256 pk;
        uint256 registeredAt;
        /// @dev The block of the exit request and the exit it set; 0 and `NO_EXIT` without one.
        uint256 requestedAt;
        uint256 requestedExit;
        /// @dev The block of the slash; 0 if not slashed.
        uint256 slashedAt;
        /// @dev The lowest exit a recovery exclusion forced; `NO_EXIT` if none.
        uint256 forcedExit;
        /// @dev The confirmation block and the landed snapshot at that block; 0 if unconfirmed.
        uint256 confirmedAt;
        uint256 snapshotAtConfirmation;
        /// @dev The registrations this slot has taken so far.
        uint256 occupancies;
        /// @dev The entry key of the last occupant released from this slot.
        bytes32 formerEntryKey;
    }

    /// @dev The entry count and the root over the modelled entries at the end of one
    /// checkpoint's block: refreshed after every change in that block, frozen once it is over.
    struct Snapshot {
        uint48 count;
        bytes32 root;
    }

    /// @dev One registration attempt.
    struct RegisterAttempt {
        uint256 defect;
        address caller;
        uint256 pk;
        uint256 amount;
        bytes publicKey;
        bytes popSig;
        bytes expectedError;
        uint256 expectedId;
    }

    /// @dev One slashing attempt.
    struct SlashAttempt {
        uint256 defect;
        uint256 bondId;
        address reporter;
        uint256 signerPk;
        bool locked;
        bool uninitialized;
        bool signaturesValid;
        IEtnaStakingRegistry.Vote voteA;
        IEtnaStakingRegistry.Vote voteB;
        bytes expectedError;
    }

    /// @dev Balances one call may move.
    struct Balances {
        uint256 registry;
        uint256 to;
        uint256 reporter;
        uint256 sink;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint48 internal constant NO_EXIT = type(uint48).max;
    uint256 internal constant TREE_DEPTH = 12;
    uint256 internal constant POOL_SIZE = 64;
    /// @dev The longest single block advance to a pending activation, exit or withdrawal.
    uint256 internal constant MAX_JUMP = 2000;
    uint256 internal constant BPS = 10_000;

    /// @dev CometBFT's Timestamp range [MIN_SECONDS, END_SECONDS) and the vote field bounds.
    int64 internal constant MIN_SECONDS = -62_135_596_800;
    int64 internal constant END_SECONDS = 253_402_300_800;
    uint64 internal constant HEIGHT_LIMIT = uint64(1) << 63;
    uint32 internal constant ROUND_LIMIT = uint32(1) << 31;
    uint32 internal constant NANOS_LIMIT = 1e9;

    /// @dev The actions, for `rejections`.
    uint256 internal constant REGISTER = 0;
    uint256 internal constant REQUEST_EXIT = 1;
    uint256 internal constant CONFIRM_EXIT = 2;
    uint256 internal constant WITHDRAW = 3;
    uint256 internal constant SLASH = 4;
    uint256 internal constant FORCE_EXIT = 5;

    /// @dev Every action's valid mode.
    uint256 internal constant VALID = 0;

    /// @dev `register` defects.
    uint256 internal constant STAKE_TOO_LOW = 1;
    uint256 internal constant MALFORMED_KEY = 2;
    uint256 internal constant WRONG_POP = 3;
    uint256 internal constant KEY_USED = 4;
    uint256 internal constant REGISTER_MODES = 5;

    /// @dev `requestExit` defects.
    uint256 internal constant EXIT_UNKNOWN_BOND = 1;
    uint256 internal constant EXIT_RELEASED = 2;
    uint256 internal constant EXIT_NOT_OWNER = 3;
    uint256 internal constant EXIT_ALREADY_SET = 4;
    uint256 internal constant EXIT_MODES = 5;

    /// @dev `confirmExit` defects.
    uint256 internal constant CONFIRM_LOCKED = 1;
    uint256 internal constant CONFIRM_UNINITIALIZED = 2;
    uint256 internal constant CONFIRM_UNKNOWN_BOND = 3;
    uint256 internal constant CONFIRM_RELEASED = 4;
    uint256 internal constant CONFIRM_NOT_SET = 5;
    uint256 internal constant CONFIRM_NOT_COVERED = 6;
    uint256 internal constant CONFIRM_MODES = 7;

    /// @dev `withdraw` defects.
    uint256 internal constant WITHDRAW_LOCKED = 1;
    uint256 internal constant WITHDRAW_NOT_CONFIRMED = 2;
    uint256 internal constant WITHDRAW_NOT_READY = 3;
    uint256 internal constant WITHDRAW_NOT_OWNER = 4;
    uint256 internal constant WITHDRAW_ZERO_RECIPIENT = 5;
    uint256 internal constant WITHDRAW_MODES = 6;

    /// @dev `slash` defects.
    uint256 internal constant SLASH_UNINITIALIZED = 1;
    uint256 internal constant SLASH_INVALID_VOTE = 2;
    uint256 internal constant SLASH_NOT_DOUBLE_SIGN = 3;
    uint256 internal constant SLASH_FUTURE_GENERATION = 4;
    uint256 internal constant SLASH_UNKNOWN_BOND = 5;
    uint256 internal constant SLASH_RELEASED = 6;
    uint256 internal constant SLASH_NOTHING_TO_SLASH = 7;
    uint256 internal constant SLASH_WRONG_SIGNATURE = 8;
    uint256 internal constant SLASH_MODES = 9;

    /// @dev `forceExit` defects.
    uint256 internal constant FORCE_NOT_INBOX = 1;
    uint256 internal constant FORCE_UNKNOWN_BOND = 2;
    uint256 internal constant FORCE_RELEASED = 3;
    uint256 internal constant FORCE_WRONG_KEY = 4;
    uint256 internal constant FORCE_BLOCK_OVERFLOW = 5;
    uint256 internal constant FORCE_MODES = 6;

    /// @dev Bond picks: which slots a pick may return.
    uint256 internal constant ANY_UNRELEASED = 0;
    uint256 internal constant NO_EXIT_SET = 1;
    uint256 internal constant STAKED = 2;
    uint256 internal constant UNCONFIRMED = 3;
    uint256 internal constant EXITING = 4;
    uint256 internal constant COVERED = 5;
    uint256 internal constant UNCOVERED = 6;
    uint256 internal constant CONFIRMED = 7;
    uint256 internal constant READY = 8;
    uint256 internal constant UNREADY = 9;
    uint256 internal constant READY_STAKED = 10;
    uint256 internal constant SLASHED = 11;

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    EtnaStakingRegistry public immutable registry;
    MockEtnaInbox public immutable inbox;
    IERC20 public immutable token;
    uint256 public immutable minStake;
    uint256 public immutable maxEntries;
    uint256 public immutable activationDelay;
    uint256 public immutable exitDelay;
    uint256 public immutable withdrawalDelay;
    uint256 public immutable slashBountyBps;
    address public immutable slashSink;
    uint64 public immutable l2ChainId;
    /// @notice Whether every snapshot keeps all its leaves, not only their root; for campaigns
    /// with few slots.
    bool public immutable keepSnapshotLeaves;
    /// @notice The only non-owner that receives withdrawals.
    address public immutable recipient;
    /// @dev The span of a block advance with nothing pending.
    uint256 internal immutable _idleSpan;

    address[] internal _stakers;
    /// @dev Reporters receive only bounties.
    address[] internal _reporters;
    /// @dev The consensus private keys registrations draw from: `[1]` is `n - [0]` (the same X
    /// with the other parity) and `[2]` has a leading zero byte in X.
    uint256[] internal _poolKeys;
    /// @notice The stakers' TAIKO when the handler was deployed.
    uint256 public initialStakerBalance;

    // ---------------------------------------------------------------
    // Model
    // ---------------------------------------------------------------

    mapping(uint256 bondId => Slot) internal _slots;
    uint256 public slotCount;
    /// @dev The released slots, most recently released last.
    uint256[] internal _freeSlots;
    /// @dev The unreleased slots with an exit set, and each one's index + 1.
    uint256[] internal _exiting;
    mapping(uint256 bondId => uint256 position) internal _exitingPosition;

    /// @dev Every consensus private key ever registered, in order, and their addresses.
    uint256[] internal _usedPks;
    mapping(address ckAddr => bool) internal _keyUsed;

    uint256 public staked;
    uint256 public deposited;
    uint256 public paidToOwners;
    uint256 public paidToRecipient;
    uint256 public slashedTotal;
    uint256 public bountiesPaid;
    uint256 public sinkPaid;

    uint256 public ghostSnapshot;
    uint48 public ghostGeneration;

    /// @dev A full depth-12 tree over the modelled leaves, node `(level, index)` at
    /// `(level << 32) | index`; an unwritten node is the level's zero hash.
    mapping(uint256 node => bytes32 hash) internal _nodes;
    bytes32[TREE_DEPTH + 1] internal _zeros;

    /// @dev The registry's checkpoints as read when their block last changed an entry, one
    /// snapshot each and, with `keepSnapshotLeaves`, the modelled leaves of each snapshot.
    IEtnaStakingRegistry.Checkpoint[] internal _checkpoints;
    Snapshot[] internal _snapshots;
    bytes32[][] internal _snapshotLeaves;

    /// @dev The slots and key addresses a call outside the prefill touched.
    uint256[] internal _touchedSlots;
    mapping(uint256 bondId => bool) internal _isTouchedSlot;
    address[] internal _touchedKeys;
    bool internal _prefilling;

    mapping(Property => uint256) public violations;
    mapping(Property => string) public firstViolation;

    // ---------------------------------------------------------------
    // Statistics
    // ---------------------------------------------------------------

    uint256 public registrations;
    uint256 public reuses;
    /// @dev Registrations that took the last free slot (the 4096th) and reuses with all slots used.
    uint256 public capFills;
    uint256 public reusesAtCap;
    uint256 public exitRequests;
    uint256 public exitsBeforeActivation;
    uint256 public confirmations;
    uint256 public repeatedConfirmations;
    uint256 public withdrawals;
    uint256 public releasesWithoutPayment;
    uint256 public releasesByOthers;
    uint256 public slashes;
    uint256 public slashesAfterConfirmation;
    uint256 public slashesUnderLock;
    uint256 public historicalSlashes;
    uint256 public forcedExits;
    uint256 public forcedNoOps;
    uint256 public recoveries;
    uint256 public settlements;
    /// @notice Rejections by action and expected error selector.
    mapping(uint256 action => mapping(bytes4 selector => uint256)) public rejections;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @dev `_stakers` must have approved the registry for their whole balance.
    constructor(
        EtnaStakingRegistry _registry,
        MockEtnaInbox _inbox,
        address[] memory _stakerPool,
        bool _keepSnapshotLeaves
    ) {
        registry = _registry;
        inbox = _inbox;
        token = _registry.token();
        minStake = _registry.minStake();
        maxEntries = _registry.MAX_ENTRIES();
        activationDelay = _registry.activationDelay();
        exitDelay = _registry.exitDelay();
        withdrawalDelay = _registry.withdrawalDelay();
        slashBountyBps = _registry.slashBountyBps();
        slashSink = _registry.slashSink();
        l2ChainId = _registry.l2ChainId();
        keepSnapshotLeaves = _keepSnapshotLeaves;
        recipient = vm.addr(0xE7A2EC);
        _idleSpan = activationDelay + exitDelay + withdrawalDelay;
        ghostSnapshot = _inbox.activeCommitteeSnapshot();
        ghostGeneration = _inbox.recoveryGeneration();

        _stakers = _stakerPool;
        for (uint256 i; i < _stakerPool.length; ++i) {
            initialStakerBalance += token.balanceOf(_stakerPool[i]);
        }
        for (uint256 i; i < 3; ++i) {
            _reporters.push(vm.addr(0xE7A9E0 + i));
        }
        for (uint256 i; i < POOL_SIZE; ++i) {
            _poolKeys.push(_keyFrom("etna registry invariant key", i));
        }
        _poolKeys[1] = LibEtnaKeys.N - _poolKeys[0];
        for (uint256 i;; ++i) {
            uint256 pk = _keyFrom("etna registry leading zero key", i);
            if (vm.createWallet(pk).publicKeyX >> 248 == 0) {
                _poolKeys[2] = pk;
                break;
            }
        }

        for (uint256 level = 1; level <= TREE_DEPTH; ++level) {
            _zeros[level] = _hashPair(_zeros[level - 1], _zeros[level - 1]);
        }
    }

    // ---------------------------------------------------------------
    // Fuzzed actions
    // ---------------------------------------------------------------

    /// @notice A burst of one to three registrations (one for a staker seed below 256). Each is
    /// by a pool staker of an unused pool key with a real proof of possession and one to three
    /// minimum stakes, sometimes off a multiple. One registration in four is broken instead: a
    /// stake below the minimum, a malformed public key, a wrong proof of possession or a key
    /// already used. Bursts keep enough entries alive for exits to complete beside slashing.
    function register(uint256 _stakerSeed, uint256 _keySeed, uint256 _amountSeed) external {
        uint256 burst = 1 + (_stakerSeed >> 8) % 3;
        for (uint256 i; i < burst; ++i) {
            if (i == 0) _registerOne(_stakerSeed, _keySeed, _amountSeed);
            else _registerOne(_stakerSeed + i, _rand(_keySeed, i), _rand(_amountSeed, i));
        }
    }

    /// @dev One registration of `register`'s burst.
    function _registerOne(uint256 _stakerSeed, uint256 _keySeed, uint256 _amountSeed) internal {
        RegisterAttempt memory a;
        a.caller = _staker(_stakerSeed);
        a.defect = _mode(_keySeed, REGISTER_MODES);
        a.amount = (1 + _amountSeed % 3) * minStake;
        if ((_amountSeed >> 2) % 4 == 0) a.amount += (_amountSeed >> 4) % minStake;

        if (a.defect == KEY_USED && _usedPks.length != 0) {
            a.pk = _usedPks[_rand(_keySeed, "used key") % _usedPks.length];
        } else {
            if (a.defect == KEY_USED) a.defect = WRONG_POP;
            a.pk = _unusedPoolKey(_keySeed);
            if (a.pk == 0) {
                // Every pool key is used, so a used key is the only choice.
                a.defect = KEY_USED;
                a.pk = _usedPks[_rand(_keySeed, "used key") % _usedPks.length];
            }
        }
        a.publicKey = EtnaTestKeys.publicKey(a.pk);
        a.popSig = EtnaTestKeys.popSig(a.pk, registry, a.caller);

        uint256 seed = _rand(_keySeed, "break");
        if (a.defect == STAKE_TOO_LOW) {
            a.amount = seed % minStake;
        } else if (a.defect == MALFORMED_KEY) {
            a.publicKey = _malformedKey(a.pk, a.publicKey, seed);
        } else if (a.defect == WRONG_POP) {
            _breakPop(a, seed);
        }
        _register(a);
    }

    /// @notice The bond owner requests the exit of an entry with none set. One call in four is
    /// broken instead: an unknown bond, a released slot, another caller or an exit already set.
    function requestExit(uint256 _seed) external {
        uint256 defect = _mode(_seed, EXIT_MODES);
        bool found;
        uint256 bondId;
        if (defect == EXIT_ALREADY_SET) {
            (found, bondId) = _pick(_seed, EXITING);
        } else if (defect == EXIT_RELEASED) {
            (found, bondId) = _pickReleased(_seed);
        } else if (defect != EXIT_UNKNOWN_BOND) {
            (found, bondId) = _pick(_seed, NO_EXIT_SET);
        }
        if (!found) bondId = _unknownBond(_seed);
        address caller = _slots[bondId].owner;
        if (defect == EXIT_NOT_OWNER || caller == address(0)) caller = _other(caller, _seed);
        _requestExit(bondId, caller);
    }

    /// @notice Anyone confirms the exit of an entry, mostly one a landed snapshot covers (a
    /// repeat leaves the clock). One call in four is broken instead: the Inbox lock held, the
    /// Inbox uninitialized, an unknown bond, a released slot, no exit set or an uncovered exit.
    function confirmExit(uint256 _seed) external {
        uint256 defect = _mode(_seed, CONFIRM_MODES);
        bool found;
        uint256 bondId;
        if (defect == CONFIRM_RELEASED) {
            (found, bondId) = _pickReleased(_seed);
        } else if (defect == CONFIRM_NOT_SET) {
            (found, bondId) = _pick(_seed, NO_EXIT_SET);
        } else if (defect == CONFIRM_NOT_COVERED) {
            (found, bondId) = _pick(_seed, UNCOVERED);
        } else if (defect != CONFIRM_UNKNOWN_BOND) {
            (found, bondId) = _pick(_seed, COVERED);
            if (!found) (found, bondId) = _pick(_seed, EXITING);
        }
        if (!found) bondId = _unknownBond(_seed);
        _confirmExit(
            bondId, _anyone(_seed), defect == CONFIRM_LOCKED, defect == CONFIRM_UNINITIALIZED
        );
    }

    /// @notice Releases an entry whose confirmed exit has waited out the withdrawal delay: the
    /// owner takes a positive stake to itself or the recipient, and anyone releases a slashed
    /// entry. One call in four is broken instead: the Inbox lock held, no confirmation (an
    /// unconfirmed, released or unknown bond), the delay not over, another caller or a zero
    /// recipient for a positive stake.
    function withdraw(uint256 _seed) external {
        uint256 defect = _mode(_seed, WITHDRAW_MODES);
        bool found;
        uint256 bondId;
        if (defect == WITHDRAW_NOT_CONFIRMED) {
            uint256 kind = _rand(_seed, "unconfirmed") % 3;
            if (kind == 0) (found, bondId) = _pick(_seed, UNCONFIRMED);
            else if (kind == 1) (found, bondId) = _pickReleased(_seed);
        } else if (defect == WITHDRAW_NOT_READY) {
            (found, bondId) = _pick(_seed, UNREADY);
        } else if (defect == WITHDRAW_NOT_OWNER || defect == WITHDRAW_ZERO_RECIPIENT) {
            (found, bondId) = _pick(_seed, READY_STAKED);
        } else {
            (found, bondId) = _pick(_seed, READY);
            if (!found) (found, bondId) = _pick(_seed, CONFIRMED);
            if (!found) (found, bondId) = _pick(_seed, EXITING);
        }
        if (!found) bondId = _unknownBond(_seed);

        Slot storage s = _slots[bondId];
        address caller = s.owner;
        address to = _rand(_seed, "to") % 2 == 0 ? caller : recipient;
        if (caller == address(0) || (s.entry.effStake == 0 && _rand(_seed, "caller") % 2 == 0)) {
            caller = _anyone(_seed);
        }
        if (s.entry.effStake == 0) {
            // Anyone releases a slashed entry, to any address.
            uint256 toKind = _rand(_seed, "to kind") % 3;
            to = toKind == 0 ? address(0) : toKind == 1 ? recipient : caller;
        }
        if (defect == WITHDRAW_NOT_OWNER) caller = _other(s.owner, _seed);
        if (defect == WITHDRAW_ZERO_RECIPIENT) to = address(0);
        _withdraw(bondId, caller, to, defect == WITHDRAW_LOCKED);
    }

    /// @notice A reporter submits two conflicting votes of the same type, height, round and
    /// generation, each signed with the bond's key under this deployment's chain id for a past or
    /// the current generation, against an entry with stake: three times in four one with no exit
    /// set, otherwise any, confirmed ones included. Sometimes the Inbox lock is held, which
    /// slashing ignores. One call in four is broken instead: the Inbox uninitialized, a vote
    /// field out of range, no double sign, a future generation, an unknown bond, a released slot,
    /// a slashed entry or a wrong signature.
    function slash(uint256 _seed) external {
        SlashAttempt memory a;
        a.defect = _mode(_seed, SLASH_MODES);
        a.reporter = _reporters[_rand(_seed, "reporter") % _reporters.length];
        bool found;
        if (a.defect == SLASH_RELEASED) {
            (found, a.bondId) = _pickReleased(_seed);
        } else if (a.defect == SLASH_NOTHING_TO_SLASH) {
            (found, a.bondId) = _pick(_seed, SLASHED);
        } else if (a.defect != SLASH_UNKNOWN_BOND) {
            // Mostly an entry with no exit set, so exits can still complete with their stake.
            if (_rand(_seed, "target") % 4 != 0) (found, a.bondId) = _pick(_seed, NO_EXIT_SET);
            if (!found) (found, a.bondId) = _pick(_seed, STAKED);
        }
        if (!found) a.bondId = _unknownBond(_seed);
        // A slot without an occupant has no key; any key gives evidence its entry check rejects.
        a.signerPk = _slots[a.bondId].pk;
        if (a.signerPk == 0) a.signerPk = _poolKeys[_rand(_seed, "signer") % POOL_SIZE];
        a.signaturesValid = true;
        _shapeVotes(a, _seed);
        _slash(a);
    }

    /// @notice A recovery exclusion through the Inbox: about half of the calls start a new
    /// recovery generation, then the Inbox moves one entry's exit to R (mostly the current block,
    /// sometimes another block, a no-op when not earlier). One call in four is broken instead:
    /// a caller other than the Inbox, an unknown bond, a released slot, a wrong entry key or
    /// R at or above 2^48 - 1.
    function forceExit(uint256 _seed) external {
        if (_rand(_seed, "recovery") % 2 == 0) {
            ++ghostGeneration;
            inbox.setRecoveryGeneration(ghostGeneration);
            ++recoveries;
        }
        uint256 defect = _mode(_seed, FORCE_MODES);
        bool found;
        uint256 bondId;
        if (defect == FORCE_RELEASED) {
            (found, bondId) = _pickReleased(_seed);
        } else if (defect != FORCE_UNKNOWN_BOND) {
            (found, bondId) = _pick(_seed, ANY_UNRELEASED);
        }
        if (!found) bondId = _unknownBond(_seed);

        Slot storage s = _slots[bondId];
        bytes32 entryKey = s.entry.ckPrefix != 0
            ? _entryKeyOf(s.entry.ckPrefix, s.entry.ckX)
            : bytes32(_rand(_seed, "entry key"));
        if (defect == FORCE_WRONG_KEY) entryKey = _wrongEntryKey(bondId, entryKey, _seed);

        uint256 r = block.number;
        if (defect == FORCE_BLOCK_OVERFLOW) {
            uint256 kind = _rand(_seed, "overflow") % 3;
            r = kind == 0 ? NO_EXIT : kind == 1 ? uint256(NO_EXIT) + 1 : type(uint256).max;
        } else if (_rand(_seed, "r") % 4 == 0) {
            r = _rand(_seed, "r value") % (block.number + 2 * exitDelay + 1);
        }
        _forceExit(bondId, entryKey, r, defect == FORCE_NOT_INBOX);
    }

    /// @notice Raises the Inbox's landed snapshot, never above the current block: to the current
    /// block, to a block in between, or to the exit of a random unconfirmed entry.
    function settle(uint256 _seed) external {
        uint256 target = block.number;
        uint256 mode = _seed % 3;
        if (mode == 1) {
            target = ghostSnapshot + (_seed >> 2) % (block.number - ghostSnapshot + 1);
        } else if (mode == 2 && _exiting.length != 0) {
            uint256 exit = _slots[_exiting[(_seed >> 2) % _exiting.length]].entry.exitEffectiveL1;
            if (exit <= block.number) target = exit;
        }
        if (target < ghostSnapshot) target = ghostSnapshot;
        inbox.setActiveCommitteeSnapshot(target);
        ghostSnapshot = target;
        ++settlements;
    }

    /// @notice Advances the L1 block: not at all (so several actions share a block), by one, by
    /// up to a dozen, or to a random entry's pending activation or exit (within the delays if it
    /// has none).
    function advanceBlocks(uint256 _seed) external {
        uint256 mode = _seed % 4;
        uint256 target = block.number;
        if (mode == 1) {
            target += 1;
        } else if (mode == 2) {
            target += 1 + (_seed >> 2) % 12;
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
                : target + 1 + (_seed >> 3) % _idleSpan;
        }
        vm.roll(target);
    }

    /// @notice Advances the L1 block to where the earliest (or a random) confirmed exit can be
    /// withdrawn or, with none confirmed, to the earliest (or a random) pending exit, so slots
    /// are released and reused within a run.
    function advanceToWithdrawal(uint256 _seed) external {
        uint256 target = type(uint256).max;
        uint256 count = _exiting.length;
        uint256 start = count == 0 ? 0 : (_seed >> 1) % count;
        for (uint256 i; i < count; ++i) {
            Slot storage s = _slots[_exiting[(start + i) % count]];
            if (s.confirmedAt != 0) {
                target = _min(target, s.confirmedAt + withdrawalDelay);
                if (_seed % 2 != 0) break;
            }
        }
        for (uint256 i; i < count && target == type(uint256).max; ++i) {
            target = _min(target, _slots[_exiting[(start + i) % count]].entry.exitEffectiveL1);
            if (_seed % 2 != 0) break;
        }
        if (target == type(uint256).max) target = block.number + 1 + _seed % _idleSpan;
        if (target > block.number) vm.roll(_min(target, block.number + MAX_JUMP));
    }

    // ---------------------------------------------------------------
    // Setup helpers (not fuzzed)
    // ---------------------------------------------------------------

    /// @notice Registers `_count` minimum stakes in the current block with the consensus keys
    /// `_firstKey`, `_firstKey + 1`, ... round-robin over the stakers, through the same checks
    /// as `register`. The slots are not tracked as touched.
    function prefill(uint256 _count, uint256 _firstKey) external {
        _prefilling = true;
        for (uint256 i; i < _count; ++i) {
            RegisterAttempt memory a;
            a.caller = _stakers[i % _stakers.length];
            a.pk = _firstKey + i;
            a.amount = minStake;
            a.publicKey = EtnaTestKeys.publicKey(a.pk);
            a.popSig = EtnaTestKeys.popSig(a.pk, registry, a.caller);
            _register(a);
        }
        _prefilling = false;
    }

    /// @notice The owner of `_bondId` requests its exit, through the same checks as
    /// `requestExit`.
    function requestExitOf(uint256 _bondId) external {
        _requestExit(_bondId, _slots[_bondId].owner);
    }

    /// @notice Confirms the exit of `_bondId`, through the same checks as `confirmExit`.
    function confirmExitOf(uint256 _bondId) external {
        _confirmExit(_bondId, _reporters[0], false, false);
    }

    // ---------------------------------------------------------------
    // Views for the invariants
    // ---------------------------------------------------------------

    function slotAt(uint256 _bondId) external view returns (Slot memory) {
        return _slots[_bondId];
    }

    function freeSlots() external view returns (uint256[] memory) {
        return _freeSlots;
    }

    function usedPks() external view returns (uint256[] memory) {
        return _usedPks;
    }

    function poolKeys() external view returns (uint256[] memory) {
        return _poolKeys;
    }

    function stakers() external view returns (address[] memory) {
        return _stakers;
    }

    function reporters() external view returns (address[] memory) {
        return _reporters;
    }

    function isKeyUsed(address _ckAddr) external view returns (bool) {
        return _keyUsed[_ckAddr];
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

    function touchedSlots() external view returns (uint256[] memory) {
        return _touchedSlots;
    }

    function touchedKeys() external view returns (address[] memory) {
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

    function _register(RegisterAttempt memory _a) internal {
        _a.expectedError = _expectRegister(_a);
        _a.expectedId = _freeSlots.length != 0 ? _freeSlots[_freeSlots.length - 1] : slotCount;
        uint256 callerBefore = token.balanceOf(_a.caller);
        uint256 registryBefore = token.balanceOf(address(registry));

        vm.prank(_a.caller);
        try registry.register(_a.publicKey, _a.amount, _a.popSig) returns (uint256 bondId) {
            if (_a.expectedError.length != 0) {
                _violate(Property.Keys, "register accepted where the model rejects it");
            } else if (bondId != _a.expectedId) {
                _violate(Property.Cap, "register took another slot than the last released one");
            } else {
                if (
                    token.balanceOf(_a.caller) != callerBefore - _a.amount
                        || token.balanceOf(address(registry)) != registryBefore + _a.amount
                ) {
                    _violate(Property.Balance, "register pulled another amount than the stake");
                }
                _recordRegistration(_a, bondId);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Keys, _a.expectedError, reason, "register");
            _countRejection(REGISTER, _a.expectedError);
        }
    }

    /// @dev The registration's expected revert data in the registry's check order (stake, key
    /// encoding, proof of possession, key reuse, capacity), or empty.
    function _expectRegister(RegisterAttempt memory _a) internal view returns (bytes memory) {
        if (_a.amount < minStake) return _err(IEtnaStakingRegistry.StakeTooLow.selector);
        if (_a.defect == MALFORMED_KEY) {
            return _err(IEtnaStakingRegistry.InvalidPublicKey.selector);
        }
        if (_a.defect == WRONG_POP) return _err(IEtnaStakingRegistry.InvalidSignature.selector);
        if (_keyUsed[vm.addr(_a.pk)]) return _err(IEtnaStakingRegistry.KeyAlreadyUsed.selector);
        if (_freeSlots.length == 0 && slotCount >= maxEntries) {
            return _err(IEtnaStakingRegistry.RegistryFull.selector);
        }
        return "";
    }

    function _recordRegistration(RegisterAttempt memory _a, uint256 _bondId) internal {
        Slot storage s = _slots[_bondId];
        if (_bondId < slotCount) {
            _freeSlots.pop();
            ++reuses;
            if (slotCount == maxEntries) ++reusesAtCap;
        } else {
            ++slotCount;
            if (slotCount == maxEntries) ++capFills;
        }
        Vm.Wallet memory wallet = vm.createWallet(_a.pk);
        s.entry = IEtnaStakingRegistry.Entry({
            ckX: bytes32(wallet.publicKeyX),
            effStake: _a.amount,
            ckPrefix: uint8(2 + (wallet.publicKeyY & 1)),
            activeFromL1: uint48(block.number + activationDelay),
            exitEffectiveL1: NO_EXIT
        });
        s.owner = _a.caller;
        s.pk = _a.pk;
        s.registeredAt = block.number;
        s.requestedAt = 0;
        s.requestedExit = NO_EXIT;
        s.slashedAt = 0;
        s.forcedExit = NO_EXIT;
        s.confirmedAt = 0;
        s.snapshotAtConfirmation = 0;
        ++s.occupancies;

        if (registry.entryAt(_bondId).activeFromL1 != block.number + activationDelay) {
            _violate(Property.Timing, "activation is not exactly its delay after registration");
        }
        if (registry.ownerOf(_bondId) != _a.caller) {
            _violate(Property.Reuse, "the registrant is not the bond owner");
        }
        if (registry.exitConfirmedAtL1(_bondId) != 0) {
            _violate(Property.Reuse, "a new occupant inherited an exit confirmation");
        }
        address ckAddr = wallet.addr;
        _keyUsed[ckAddr] = true;
        _usedPks.push(_a.pk);
        if (!_prefilling) _touchedKeys.push(ckAddr);
        if (!registry.keyUsed(ckAddr)) _violate(Property.Keys, "a registered key is not used");

        staked += _a.amount;
        deposited += _a.amount;
        ++registrations;
        _commit(_bondId, Property.Keys);
    }

    /// @dev Replaces a valid compressed key with a malformed encoding: truncated, extended,
    /// uncompressed, an invalid prefix, X at or above p, or an X with no curve point.
    function _malformedKey(
        uint256 _pk,
        bytes memory _publicKey,
        uint256 _seed
    )
        internal
        returns (bytes memory)
    {
        bytes32 x = _xOf(_publicKey);
        uint256 kind = _seed % 6;
        if (kind == 0) return abi.encodePacked(_publicKey[0], bytes31(x));
        if (kind == 1) return abi.encodePacked(_publicKey, bytes1(uint8(_seed >> 8)));
        if (kind == 2) {
            return abi.encodePacked(uint8(4), x, bytes32(vm.createWallet(_pk).publicKeyY));
        }
        uint8 prefix = 2 + uint8((_seed >> 8) % 2);
        if (kind == 3) {
            uint8[5] memory bad = [0, 1, 4, 5, 0xff];
            return abi.encodePacked(bad[(_seed >> 16) % 5], x);
        }
        if (kind == 4) {
            return abi.encodePacked(
                prefix, LibEtnaKeys.P + (_seed >> 16) % (type(uint256).max - LibEtnaKeys.P + 1)
            );
        }
        // x^3 + 7 is not a square modulo p for these X.
        uint256[4] memory offCurve = [uint256(0), 5, 7, 9];
        return abi.encodePacked(prefix, offCurve[(_seed >> 16) % 4]);
    }

    /// @dev Breaks the proof of possession of a valid registration: signed for another owner or
    /// by another key, the key's parity flipped (the negated point), a high S, V not in {0, 1} or
    /// another length.
    function _breakPop(RegisterAttempt memory _a, uint256 _seed) internal view {
        uint256 kind = _seed % 6;
        if (kind == 0) {
            _a.popSig = EtnaTestKeys.popSig(_a.pk, registry, _other(_a.caller, _seed >> 8));
        } else if (kind == 1) {
            _a.popSig = EtnaTestKeys.popSig(_otherKey(_a.pk, _seed), registry, _a.caller);
        } else if (kind == 2) {
            _a.publicKey[0] = bytes1(uint8(_a.publicKey[0]) ^ 1);
        } else {
            (bytes32 r, bytes32 s, uint8 v) = _split(_a.popSig);
            if (kind == 3) {
                _a.popSig = abi.encodePacked(r, bytes32(LibEtnaKeys.N - uint256(s)), 1 - v);
            } else if (kind == 4) {
                _a.popSig = abi.encodePacked(r, s, v + 27);
            } else {
                _a.popSig = abi.encodePacked(r, s);
            }
        }
    }

    // ---------------------------------------------------------------
    // Exit request, confirmation and withdrawal
    // ---------------------------------------------------------------

    function _requestExit(uint256 _bondId, address _caller) internal {
        Slot storage s = _slots[_bondId];
        uint256 exit = _max(block.number, s.entry.activeFromL1) + exitDelay;
        bytes memory expected;
        if (_bondId >= slotCount) {
            expected = _err(IEtnaStakingRegistry.UnknownBond.selector);
        } else if (s.entry.ckPrefix == 0) {
            expected = _err(IEtnaStakingRegistry.SlotReleased.selector);
        } else if (s.owner != _caller) {
            expected = _err(IEtnaStakingRegistry.NotBondOwner.selector);
        } else if (s.entry.exitEffectiveL1 != NO_EXIT) {
            expected = _err(IEtnaStakingRegistry.ExitAlreadySet.selector);
        } else if (exit >= NO_EXIT) {
            expected = _err(IEtnaStakingRegistry.InvalidEventBlock.selector);
        }

        vm.prank(_caller);
        try registry.requestExit(_bondId) {
            if (expected.length != 0) {
                _violate(Property.Timing, "requestExit accepted where the model rejects it");
                return;
            }
            if (block.number < s.entry.activeFromL1) ++exitsBeforeActivation;
            s.requestedAt = block.number;
            s.requestedExit = exit;
            _setExit(_bondId, exit);
            ++exitRequests;
            _commit(_bondId, Property.Timing);
        } catch (bytes memory reason) {
            _checkRevert(Property.Timing, expected, reason, "requestExit");
            _countRejection(REQUEST_EXIT, expected);
        }
    }

    function _confirmExit(
        uint256 _bondId,
        address _caller,
        bool _locked,
        bool _uninitialized
    )
        internal
    {
        Slot storage s = _slots[_bondId];
        bytes memory expected;
        if (_locked) {
            expected = _err(IEtnaStakingRegistry.InboxLocked.selector);
        } else if (_uninitialized) {
            expected = _err(IEtnaStakingRegistry.InboxNotInitialized.selector);
        } else if (_bondId >= slotCount) {
            expected = _err(IEtnaStakingRegistry.UnknownBond.selector);
        } else if (s.entry.ckPrefix == 0) {
            expected = _err(IEtnaStakingRegistry.SlotReleased.selector);
        } else if (s.entry.exitEffectiveL1 == NO_EXIT) {
            expected = _err(IEtnaStakingRegistry.ExitNotSet.selector);
        } else if (ghostSnapshot < s.entry.exitEffectiveL1) {
            expected = _err(IEtnaStakingRegistry.ExitNotCovered.selector);
        }
        uint256 checkpointsBefore = registry.checkpointCount();

        if (_locked) inbox.setInNonReentrant(true);
        if (_uninitialized) inbox.setInitialized(false);
        vm.prank(_caller);
        try registry.confirmExit(_bondId) {
            if (expected.length != 0) {
                _violate(Property.Reuse, "confirmExit accepted where the model rejects it");
            } else {
                _recordConfirmation(_bondId, checkpointsBefore);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Reuse, expected, reason, "confirmExit");
            _countRejection(CONFIRM_EXIT, expected);
        }
        if (_locked) inbox.setInNonReentrant(false);
        if (_uninitialized) inbox.setInitialized(true);
    }

    function _recordConfirmation(uint256 _bondId, uint256 _checkpointsBefore) internal {
        Slot storage s = _slots[_bondId];
        if (registry.checkpointCount() != _checkpointsBefore) {
            _violate(Property.History, "confirmExit wrote a checkpoint");
        }
        if (!_sameEntry(registry.entryAt(_bondId), s.entry)) {
            _violate(Property.Reuse, "confirmExit changed the entry");
        }
        if (s.confirmedAt == 0) {
            s.confirmedAt = block.number;
            s.snapshotAtConfirmation = ghostSnapshot;
            ++confirmations;
        } else {
            ++repeatedConfirmations;
        }
        if (registry.exitConfirmedAtL1(_bondId) != s.confirmedAt) {
            _violate(Property.Reuse, "the confirmation is not the block of the first confirmExit");
        }
    }

    function _withdraw(uint256 _bondId, address _caller, address _to, bool _locked) internal {
        Slot storage s = _slots[_bondId];
        uint256 amount = s.entry.effStake;
        bytes memory expected;
        if (_locked) {
            expected = _err(IEtnaStakingRegistry.InboxLocked.selector);
        } else if (s.confirmedAt == 0) {
            // Unknown and released slots have no confirmation either.
            expected = _err(IEtnaStakingRegistry.ExitNotConfirmed.selector);
        } else if (block.number < s.confirmedAt + withdrawalDelay) {
            expected = _err(IEtnaStakingRegistry.WithdrawalNotReady.selector);
        } else if (amount != 0 && s.owner != _caller) {
            expected = _err(IEtnaStakingRegistry.NotBondOwner.selector);
        } else if (amount != 0 && _to == address(0)) {
            expected = _err(EssentialContract.ZERO_ADDRESS.selector);
        }
        Balances memory before = _balances(_to, address(0));

        if (_locked) inbox.setInNonReentrant(true);
        vm.prank(_caller);
        try registry.withdraw(_bondId, _to) {
            if (expected.length != 0) {
                _violate(Property.Balance, "withdraw accepted where the model rejects it");
            } else {
                _recordWithdrawal(_bondId, _caller, _to, before);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Balance, expected, reason, "withdraw");
            _countRejection(WITHDRAW, expected);
        }
        if (_locked) inbox.setInNonReentrant(false);
    }

    function _recordWithdrawal(
        uint256 _bondId,
        address _caller,
        address _to,
        Balances memory _before
    )
        internal
    {
        Slot storage s = _slots[_bondId];
        uint256 amount = s.entry.effStake;
        if (token.balanceOf(address(registry)) != _before.registry - amount) {
            _violate(Property.Balance, "withdraw moved another amount out of the registry");
        }
        if (_to != address(0) && token.balanceOf(_to) != _before.to + amount) {
            _violate(Property.Balance, "withdraw paid the recipient another amount than the stake");
        }
        if (registry.ownerOf(_bondId) != address(0)) {
            _violate(Property.Reuse, "a released slot kept its owner");
        }
        if (registry.exitConfirmedAtL1(_bondId) != 0) {
            _violate(Property.Reuse, "a released slot kept its confirmation");
        }
        if (registry.freeSlotCount() != _freeSlots.length + 1) {
            _violate(Property.Cap, "withdraw did not free exactly one slot");
        }

        if (amount == 0) {
            ++releasesWithoutPayment;
            if (_caller != s.owner) ++releasesByOthers;
        } else {
            ++withdrawals;
            if (_to == recipient) paidToRecipient += amount;
            else paidToOwners += amount;
        }
        staked -= amount;
        _removeExiting(_bondId);
        _freeSlots.push(_bondId);

        s.formerEntryKey = _entryKeyOf(s.entry.ckPrefix, s.entry.ckX);
        delete s.entry;
        s.owner = address(0);
        s.pk = 0;
        s.registeredAt = 0;
        s.requestedAt = 0;
        s.requestedExit = 0;
        s.slashedAt = 0;
        s.forcedExit = 0;
        s.confirmedAt = 0;
        s.snapshotAtConfirmation = 0;
        _commit(_bondId, Property.Reuse);
    }

    // ---------------------------------------------------------------
    // Slashing
    // ---------------------------------------------------------------

    /// @dev Builds the two votes of `_a` and signs them with `_a.signerPk`, then applies the
    /// drawn defect.
    function _shapeVotes(SlashAttempt memory _a, uint256 _seed) internal view {
        uint48 generation = uint48(_rand(_seed, "generation") % (uint256(ghostGeneration) + 1));
        if (_a.defect == SLASH_FUTURE_GENERATION) {
            generation = ghostGeneration + 1 + uint48(_rand(_seed, "future") % 3);
        }
        IEtnaStakingRegistry.Vote memory base;
        base.voteType = uint8(1 + _rand(_seed, "type") % 2);
        base.height = uint64(1 + _rand(_seed, "height") % 1e12);
        base.round = uint32(_rand(_seed, "round") % 8);
        base.timestampSeconds = uint64(1_700_000_000 + _rand(_seed, "seconds") % 1e8);
        base.timestampNanos = uint32(_rand(_seed, "nanos") % NANOS_LIMIT);
        base.generation = generation;
        _a.voteA = _copyVote(base);
        _a.voteB = _copyVote(base);
        _setBlockIds(_a.voteA, _a.voteB, _rand(_seed, "block ids"));

        uint256 seed = _rand(_seed, "break");
        if (_a.defect == SLASH_UNINITIALIZED) _a.uninitialized = true;
        else if (_a.defect == SLASH_INVALID_VOTE) _breakRange(_a, seed);
        else if (_a.defect == SLASH_NOT_DOUBLE_SIGN) _breakPair(_a, seed);

        bytes memory chainId = _cometChainId(block.chainid, l2ChainId, address(inbox), generation);
        _a.voteA = EtnaTestKeys.signVote(_a.signerPk, _a.voteA, chainId);
        _a.voteB = EtnaTestKeys.signVote(_a.signerPk, _a.voteB, chainId);
        if (_a.defect == SLASH_INVALID_VOTE && seed % 7 == 6) {
            // A signature of another length is a range error, before any recovery.
            IEtnaStakingRegistry.Vote memory v = (seed >> 8) % 2 == 0 ? _a.voteA : _a.voteB;
            v.signature = (seed >> 9) % 2 == 0 ? new bytes(64) : new bytes(66);
        } else if (_a.defect == SLASH_WRONG_SIGNATURE) {
            _breakSignature(_a, chainId, seed);
        } else if (_a.defect == VALID && _rand(_seed, "lock") % 4 == 0) {
            _a.locked = true;
        }
    }

    /// @dev Gives the two votes different block ids: two blocks, a block against nil, or the same
    /// hash with another part set total or hash.
    function _setBlockIds(
        IEtnaStakingRegistry.Vote memory _voteA,
        IEtnaStakingRegistry.Vote memory _voteB,
        uint256 _seed
    )
        internal
        pure
    {
        bytes32 hashA = keccak256(abi.encode("block a", _seed));
        _voteA.blockHash = hashA;
        _voteA.partsTotal = uint32(1 + (_seed >> 8) % 4);
        _voteA.partsHash = keccak256(abi.encode(hashA));
        uint256 kind = _seed % 4;
        if (kind == 0) {
            _voteB.blockHash = keccak256(abi.encode("block b", _seed));
            _voteB.partsTotal = _voteA.partsTotal;
            _voteB.partsHash = keccak256(abi.encode(_voteB.blockHash));
        } else if (kind == 1) {
            // Nil: the block id is all zero.
        } else {
            _voteB.blockHash = hashA;
            _voteB.partsTotal = kind == 2 ? _voteA.partsTotal + 1 : _voteA.partsTotal;
            _voteB.partsHash = kind == 2 ? _voteA.partsHash : keccak256("other parts");
        }
        if ((_seed >> 16) % 2 == 0) {
            (_voteA.blockHash, _voteB.blockHash) = (_voteB.blockHash, _voteA.blockHash);
            (_voteA.partsTotal, _voteB.partsTotal) = (_voteB.partsTotal, _voteA.partsTotal);
            (_voteA.partsHash, _voteB.partsHash) = (_voteB.partsHash, _voteA.partsHash);
        }
    }

    /// @dev Puts one field of one vote out of range: the type, the height, the round, the
    /// timestamp seconds or nanos; the seventh case (a signature length) is set after signing.
    function _breakRange(SlashAttempt memory _a, uint256 _seed) internal pure {
        IEtnaStakingRegistry.Vote memory v = (_seed >> 8) % 2 == 0 ? _a.voteA : _a.voteB;
        uint256 kind = _seed % 7;
        uint256 pick = _seed >> 16;
        if (kind == 0) {
            v.voteType = pick % 2 == 0 ? 0 : uint8(3 + pick % 253);
        } else if (kind == 1) {
            v.height = pick % 2 == 0 ? 0 : HEIGHT_LIMIT + uint64(pick % HEIGHT_LIMIT);
        } else if (kind == 2) {
            v.round = ROUND_LIMIT + uint32(pick % ROUND_LIMIT);
        } else if (kind == 3) {
            v.timestampSeconds = uint64(END_SECONDS + int64(uint64(pick % 1e9)));
        } else if (kind == 4) {
            v.timestampSeconds = uint64(MIN_SECONDS - 1 - int64(uint64(pick % 1e9)));
        } else if (kind == 5) {
            v.timestampNanos = NANOS_LIMIT + uint32(pick % 1e9);
        }
    }

    /// @dev Breaks the pair: the same block id, or another type, height, round or generation.
    function _breakPair(SlashAttempt memory _a, uint256 _seed) internal view {
        IEtnaStakingRegistry.Vote memory b = _a.voteB;
        uint256 kind = _seed % 5;
        if (kind == 0) {
            b.blockHash = _a.voteA.blockHash;
            b.partsTotal = _a.voteA.partsTotal;
            b.partsHash = _a.voteA.partsHash;
        } else if (kind == 1) {
            b.voteType = 3 - b.voteType;
        } else if (kind == 2) {
            b.height = b.height + 1;
        } else if (kind == 3) {
            b.round = b.round + 1;
        } else {
            b.generation =
                b.generation == 0 || ghostGeneration == 0 ? b.generation + 1 : b.generation - 1;
        }
    }

    /// @dev Breaks the signatures of a valid pair: one vote signed by another key, both signed
    /// under another generation's or another deployment's chain id, or a malformed signature
    /// (a high S, V not in {0, 1}, or R zero).
    function _breakSignature(
        SlashAttempt memory _a,
        bytes memory _chainId,
        uint256 _seed
    )
        internal
        view
    {
        _a.signaturesValid = false;
        IEtnaStakingRegistry.Vote memory v = (_seed >> 8) % 2 == 0 ? _a.voteA : _a.voteB;
        uint256 kind = _seed % 4;
        if (kind == 0) {
            EtnaTestKeys.signVote(_otherKey(_a.signerPk, _seed), v, _chainId);
        } else if (kind == 1) {
            uint48 generation = v.generation;
            uint256 which = (_seed >> 16) % 4;
            bytes memory otherId = which == 0
                ? _cometChainId(block.chainid, l2ChainId, address(inbox), generation + 1)
                : which == 1
                    ? _cometChainId(block.chainid, l2ChainId, address(registry), generation)
                    : which == 2
                        ? _cometChainId(block.chainid, l2ChainId + 1, address(inbox), generation)
                        : _cometChainId(block.chainid + 1, l2ChainId, address(inbox), generation);
            EtnaTestKeys.signVote(_a.signerPk, _a.voteA, otherId);
            EtnaTestKeys.signVote(_a.signerPk, _a.voteB, otherId);
        } else {
            (bytes32 r, bytes32 s, uint8 recoveryId) = _split(v.signature);
            uint256 malformed = (_seed >> 16) % 3;
            if (malformed == 0) {
                v.signature =
                    abi.encodePacked(r, bytes32(LibEtnaKeys.N - uint256(s)), 1 - recoveryId);
            } else if (malformed == 1) {
                v.signature = abi.encodePacked(r, s, recoveryId + 2);
            } else {
                v.signature = abi.encodePacked(bytes32(0), s, recoveryId);
            }
        }
    }

    function _slash(SlashAttempt memory _a) internal {
        _a.expectedError = _expectSlash(_a);
        Balances memory before = _balances(address(0), _a.reporter);

        if (_a.locked) inbox.setInNonReentrant(true);
        if (_a.uninitialized) inbox.setInitialized(false);
        vm.prank(_a.reporter);
        try registry.slashDoubleSign(_a.bondId, _a.voteA, _a.voteB) {
            if (_a.expectedError.length != 0) {
                _violate(Property.Balance, "slashDoubleSign accepted where the model rejects it");
            } else {
                _recordSlash(_a, before);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Balance, _a.expectedError, reason, "slashDoubleSign");
            _countRejection(SLASH, _a.expectedError);
        }
        if (_a.locked) inbox.setInNonReentrant(false);
        if (_a.uninitialized) inbox.setInitialized(true);
    }

    /// @dev The slash's expected revert data in the registry's check order (Inbox, vote ranges,
    /// pair, generation, entry, stake, signatures), or empty.
    function _expectSlash(SlashAttempt memory _a) internal view returns (bytes memory) {
        if (_a.uninitialized) return _err(IEtnaStakingRegistry.InboxNotInitialized.selector);
        if (!_inRange(_a.voteA) || !_inRange(_a.voteB)) {
            return _err(IEtnaStakingRegistry.InvalidVote.selector);
        }
        IEtnaStakingRegistry.Vote memory a = _a.voteA;
        IEtnaStakingRegistry.Vote memory b = _a.voteB;
        bool sameBlockId = a.blockHash == b.blockHash && a.partsTotal == b.partsTotal
            && a.partsHash == b.partsHash;
        if (
            a.voteType != b.voteType || a.height != b.height || a.round != b.round
                || a.generation != b.generation || sameBlockId
        ) {
            return _err(IEtnaStakingRegistry.NotDoubleSign.selector);
        }
        if (a.generation > ghostGeneration) {
            return _err(IEtnaStakingRegistry.FutureGeneration.selector);
        }
        Slot storage s = _slots[_a.bondId];
        if (_a.bondId >= slotCount) return _err(IEtnaStakingRegistry.UnknownBond.selector);
        if (s.entry.ckPrefix == 0) return _err(IEtnaStakingRegistry.SlotReleased.selector);
        if (s.entry.effStake == 0) return _err(IEtnaStakingRegistry.NothingToSlash.selector);
        if (!_a.signaturesValid) return _err(IEtnaStakingRegistry.InvalidSignature.selector);
        return "";
    }

    function _recordSlash(SlashAttempt memory _a, Balances memory _before) internal {
        Slot storage s = _slots[_a.bondId];
        uint256 amount = s.entry.effStake;
        uint256 bounty = amount * slashBountyBps / BPS;
        if (
            token.balanceOf(_a.reporter) != _before.reporter + bounty
                || token.balanceOf(slashSink) != _before.sink + amount - bounty
                || token.balanceOf(address(registry)) != _before.registry - amount
        ) {
            _violate(Property.Balance, "the slash did not pay the bounty and the sink the stake");
        }
        if (registry.ownerOf(_a.bondId) != s.owner) {
            _violate(Property.Reuse, "the slash changed the owner");
        }
        if (registry.exitConfirmedAtL1(_a.bondId) != s.confirmedAt) {
            _violate(Property.Reuse, "the slash changed the confirmation");
        }

        ++slashes;
        if (s.confirmedAt != 0) ++slashesAfterConfirmation;
        if (_a.locked) ++slashesUnderLock;
        if (_a.voteA.generation < ghostGeneration) ++historicalSlashes;
        staked -= amount;
        slashedTotal += amount;
        bountiesPaid += bounty;
        sinkPaid += amount - bounty;

        s.entry.effStake = 0;
        s.slashedAt = block.number;
        _setExit(_a.bondId, _min(s.entry.exitEffectiveL1, block.number));
        _commit(_a.bondId, Property.Balance);
    }

    /// @dev Whether a vote's fields are in range, written out from appendix A's bounds.
    function _inRange(IEtnaStakingRegistry.Vote memory _v) internal pure returns (bool) {
        int64 seconds_ = int64(_v.timestampSeconds);
        return (_v.voteType == 1 || _v.voteType == 2) && _v.height != 0 && _v.height < HEIGHT_LIMIT
            && _v.round < ROUND_LIMIT && seconds_ >= MIN_SECONDS && seconds_ < END_SECONDS
            && _v.timestampNanos < NANOS_LIMIT && _v.signature.length == 65;
    }

    // ---------------------------------------------------------------
    // Recovery exclusion
    // ---------------------------------------------------------------

    function _forceExit(uint256 _bondId, bytes32 _entryKey, uint256 _r, bool _notInbox) internal {
        Slot storage s = _slots[_bondId];
        bytes memory expected;
        if (_notInbox) {
            expected = _err(IEtnaStakingRegistry.NotInbox.selector);
        } else if (_bondId >= slotCount) {
            expected = _err(IEtnaStakingRegistry.UnknownBond.selector);
        } else if (s.entry.ckPrefix == 0) {
            expected = _err(IEtnaStakingRegistry.SlotReleased.selector);
        } else if (_entryKey != _entryKeyOf(s.entry.ckPrefix, s.entry.ckX)) {
            expected = _err(IEtnaStakingRegistry.EntryKeyMismatch.selector);
        } else if (_r >= NO_EXIT) {
            expected = _err(IEtnaStakingRegistry.InvalidEventBlock.selector);
        }
        uint256 checkpointsBefore = registry.checkpointCount();

        bool ok;
        bytes memory reason;
        if (_notInbox) {
            vm.prank(_reporters[0]);
            try registry.forceExit(_bondId, _entryKey, _r) {
                ok = true;
            } catch (bytes memory err) {
                reason = err;
            }
        } else {
            try inbox.forceExit(registry, _bondId, _entryKey, _r) {
                ok = true;
            } catch (bytes memory err) {
                reason = err;
            }
        }

        if (!ok) {
            _checkRevert(Property.Timing, expected, reason, "forceExit");
            _countRejection(FORCE_EXIT, expected);
        } else if (expected.length != 0) {
            _violate(Property.Timing, "forceExit accepted where the model rejects it");
        } else if (_r >= s.entry.exitEffectiveL1) {
            // An exit at or before R is kept and nothing is written.
            if (registry.checkpointCount() != checkpointsBefore) {
                _violate(Property.History, "a forceExit that keeps the exit wrote a checkpoint");
            }
            if (!_sameEntry(registry.entryAt(_bondId), s.entry)) {
                _violate(Property.Timing, "a forceExit that keeps the exit changed the entry");
            }
            ++forcedNoOps;
        } else {
            s.forcedExit = _min(s.forcedExit, _r);
            _setExit(_bondId, _r);
            ++forcedExits;
            _commit(_bondId, Property.Timing);
        }
    }

    /// @dev Another entry key than `_bondId`'s: its former occupant's, another bond's, the
    /// flipped prefix, or another X.
    function _wrongEntryKey(
        uint256 _bondId,
        bytes32 _key,
        uint256 _seed
    )
        internal
        view
        returns (bytes32)
    {
        Slot storage s = _slots[_bondId];
        uint256 kind = _rand(_seed, "wrong key") % 4;
        if (kind == 0 && s.formerEntryKey != 0) return s.formerEntryKey;
        if (kind == 1 && slotCount > 1) {
            Slot storage other = _slots[(_bondId + 1 + _seed % (slotCount - 1)) % slotCount];
            if (other.entry.ckPrefix != 0) {
                return _entryKeyOf(other.entry.ckPrefix, other.entry.ckX);
            }
        }
        if (kind == 2 && s.entry.ckPrefix != 0) {
            return _entryKeyOf(s.entry.ckPrefix ^ 1, s.entry.ckX);
        }
        bytes32 wrong = _entryKeyOf(s.entry.ckPrefix, bytes32(uint256(s.entry.ckX) ^ 1));
        return wrong == _key ? bytes32(uint256(_key) ^ 1) : wrong;
    }

    // ---------------------------------------------------------------
    // Model, tree and checkpoints
    // ---------------------------------------------------------------

    /// @dev Sets the modelled exit of `_bondId`, which must never move later, and tracks the
    /// slot as exiting.
    function _setExit(uint256 _bondId, uint256 _exit) internal {
        IEtnaStakingRegistry.Entry storage entry = _slots[_bondId].entry;
        if (_exit > entry.exitEffectiveL1) _violate(Property.Timing, "an exit moved later");
        if (_exitingPosition[_bondId] == 0) {
            _exiting.push(_bondId);
            _exitingPosition[_bondId] = _exiting.length;
        }
        entry.exitEffectiveL1 = uint48(_exit);
    }

    function _removeExiting(uint256 _bondId) internal {
        uint256 position = _exitingPosition[_bondId];
        if (position == 0) return;
        uint256 last = _exiting[_exiting.length - 1];
        _exiting[position - 1] = last;
        _exitingPosition[last] = position;
        _exiting.pop();
        delete _exitingPosition[_bondId];
    }

    /// @dev After a successful call that changed entry `_bondId`: checks the entry against the
    /// model, folds its leaf into the ghost tree, then checks that exactly the current block's
    /// checkpoint was written with the modelled count and root, and refreshes that block's
    /// checkpoint copy and snapshot.
    function _commit(uint256 _bondId, Property _property) internal {
        Slot storage s = _slots[_bondId];
        if (!_sameEntry(registry.entryAt(_bondId), s.entry)) {
            _violate(_property, "the changed entry differs from the model");
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
        Snapshot memory snapshot = Snapshot({ count: uint48(slotCount), root: ghostRoot() });
        if (latest.l1Block != block.number) {
            _violate(Property.History, "the block's checkpoint names another block");
        }
        if (latest.count != slotCount) {
            _violate(Property.Snapshots, "the block's checkpoint counts another number of slots");
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
    // Picks
    // ---------------------------------------------------------------

    /// @dev A mode: valid three calls in four, otherwise one of the `_modes - 1` defects.
    function _mode(uint256 _seed, uint256 _modes) internal pure returns (uint256) {
        return _seed % 4 == 3 ? 1 + _rand(_seed, "defect") % (_modes - 1) : VALID;
    }

    /// @dev A slot of the kind `_want`, from a random start. Exiting kinds scan the exiting
    /// slots; the others scan every slot of a small registry or probe 32 random ones.
    function _pick(uint256 _seed, uint256 _want) internal view returns (bool, uint256) {
        uint256 start = _rand(_seed, "pick");
        if (_want >= EXITING) {
            uint256 count = _exiting.length;
            for (uint256 i; i < count; ++i) {
                uint256 bondId = _exiting[(start + i) % count];
                if (_matches(bondId, _want)) return (true, bondId);
            }
            return (false, 0);
        }
        if (slotCount <= 64) {
            for (uint256 i; i < slotCount; ++i) {
                uint256 bondId = (start + i) % slotCount;
                if (_matches(bondId, _want)) return (true, bondId);
            }
            return (false, 0);
        }
        for (uint256 i; i < 32; ++i) {
            uint256 bondId = _rand(start, i) % slotCount;
            if (_matches(bondId, _want)) return (true, bondId);
        }
        return (false, 0);
    }

    function _matches(uint256 _bondId, uint256 _want) internal view returns (bool) {
        Slot storage s = _slots[_bondId];
        if (s.entry.ckPrefix == 0) return false;
        uint256 exit = s.entry.exitEffectiveL1;
        bool ready = s.confirmedAt != 0 && block.number >= s.confirmedAt + withdrawalDelay;
        if (_want == ANY_UNRELEASED) return true;
        if (_want == NO_EXIT_SET) return exit == NO_EXIT;
        if (_want == STAKED) return s.entry.effStake != 0;
        if (_want == UNCONFIRMED) return s.confirmedAt == 0;
        if (_want == EXITING) return exit != NO_EXIT;
        if (_want == COVERED) return exit <= ghostSnapshot;
        if (_want == UNCOVERED) return exit > ghostSnapshot;
        if (_want == CONFIRMED) return s.confirmedAt != 0;
        if (_want == READY) return ready;
        if (_want == UNREADY) return s.confirmedAt != 0 && !ready;
        if (_want == READY_STAKED) return ready && s.entry.effStake != 0;
        return s.entry.effStake == 0; // SLASHED
    }

    function _pickReleased(uint256 _seed) internal view returns (bool, uint256) {
        if (_freeSlots.length == 0) return (false, 0);
        return (true, _freeSlots[_rand(_seed, "released") % _freeSlots.length]);
    }

    /// @dev A bond id no slot has used yet.
    function _unknownBond(uint256 _seed) internal view returns (uint256) {
        return slotCount + _rand(_seed, "unknown") % 3;
    }

    /// @dev An unused pool key, scanning from a random start; zero once every pool key is used.
    function _unusedPoolKey(uint256 _seed) internal view returns (uint256) {
        uint256 start = _rand(_seed, "pool");
        for (uint256 i; i < POOL_SIZE; ++i) {
            uint256 pk = _poolKeys[(start + i) % POOL_SIZE];
            if (!_keyUsed[vm.addr(pk)]) return pk;
        }
        return 0;
    }

    function _otherKey(uint256 _pk, uint256 _seed) internal view returns (uint256) {
        uint256 pk = _poolKeys[_rand(_seed, "other key") % POOL_SIZE];
        return pk == _pk ? _poolKeys[(_rand(_seed, "other key") + 3) % POOL_SIZE] : pk;
    }

    function _staker(uint256 _seed) internal view returns (address) {
        return _stakers[_seed % _stakers.length];
    }

    /// @dev Any staker or reporter.
    function _anyone(uint256 _seed) internal view returns (address) {
        uint256 pick = _rand(_seed, "anyone") % (_stakers.length + _reporters.length);
        return pick < _stakers.length ? _stakers[pick] : _reporters[pick - _stakers.length];
    }

    /// @dev A staker or reporter other than `_account`.
    function _other(address _account, uint256 _seed) internal view returns (address) {
        address other = _anyone(_seed);
        return other == _account ? _reporters[0] : other;
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _balances(address _to, address _reporter) internal view returns (Balances memory b_) {
        b_.registry = token.balanceOf(address(registry));
        if (_to != address(0)) b_.to = token.balanceOf(_to);
        if (_reporter != address(0)) b_.reporter = token.balanceOf(_reporter);
        b_.sink = token.balanceOf(slashSink);
    }

    function _countRejection(uint256 _action, bytes memory _expected) internal {
        if (_expected.length >= 4) ++rejections[_action][bytes4(_expected)];
    }

    function _checkRevert(
        Property _property,
        bytes memory _expected,
        bytes memory _reason,
        string memory _call
    )
        internal
    {
        if (_expected.length == 0) {
            _violate(
                _property,
                string.concat(
                    _call, " reverted where the model expects success: ", vm.toString(_reason)
                )
            );
        } else if (keccak256(_reason) != keccak256(_expected)) {
            _violate(
                _property,
                string.concat(
                    _call,
                    " reverted with ",
                    vm.toString(_reason),
                    " instead of ",
                    vm.toString(_expected)
                )
            );
        }
    }

    function _violate(Property _property, string memory _reason) internal {
        if (violations[_property]++ != 0) return;
        string[8] memory names =
            ["root", "history", "snapshots", "reuse", "keys", "balance", "timing", "cap"];
        firstViolation[_property] = string.concat(names[uint8(_property)], ": ", _reason);
    }

    function _err(bytes4 _selector) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(_selector);
    }

    function _sameEntry(
        IEtnaStakingRegistry.Entry memory _a,
        IEtnaStakingRegistry.Entry memory _b
    )
        internal
        pure
        returns (bool)
    {
        return _a.ckX == _b.ckX && _a.effStake == _b.effStake && _a.ckPrefix == _b.ckPrefix
            && _a.activeFromL1 == _b.activeFromL1 && _a.exitEffectiveL1 == _b.exitEffectiveL1;
    }

    function _copyVote(IEtnaStakingRegistry.Vote memory _v)
        internal
        pure
        returns (IEtnaStakingRegistry.Vote memory c_)
    {
        c_.voteType = _v.voteType;
        c_.height = _v.height;
        c_.round = _v.round;
        c_.timestampSeconds = _v.timestampSeconds;
        c_.timestampNanos = _v.timestampNanos;
        c_.generation = _v.generation;
        c_.signature = new bytes(65);
    }

    function _cometChainId(
        uint256 _l1ChainId,
        uint256 _l2ChainId,
        address _inbox,
        uint48 _generation
    )
        internal
        pure
        returns (bytes memory)
    {
        return LibCometVote.chainId(
            LibCometVote.chainDomain(_l1ChainId, _l2ChainId, _inbox, _generation)
        );
    }

    /// @dev The occupant identity recovery exclusions name: keccak256(abi.encode(uint256(prefix),
    /// X)) (appendix A).
    function _entryKeyOf(uint8 _prefix, bytes32 _x) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(_prefix), _x));
    }

    function _xOf(bytes memory _publicKey) internal pure returns (bytes32 x_) {
        assembly ("memory-safe") {
            x_ := mload(add(_publicKey, 0x21))
        }
    }

    function _split(bytes memory _sig) internal pure returns (bytes32 r_, bytes32 s_, uint8 v_) {
        assembly ("memory-safe") {
            r_ := mload(add(_sig, 0x20))
            s_ := mload(add(_sig, 0x40))
            v_ := byte(0, mload(add(_sig, 0x60)))
        }
    }

    function _keyFrom(string memory _tag, uint256 _index) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_tag, _index))) % (LibEtnaKeys.N - 1) + 1;
    }

    function _hashPair(bytes32 _left, bytes32 _right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_left, _right));
    }

    function _rand(uint256 _seed, string memory _tag) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_seed, _tag)));
    }

    function _rand(uint256 _seed, uint256 _index) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_seed, "probe", _index)));
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
