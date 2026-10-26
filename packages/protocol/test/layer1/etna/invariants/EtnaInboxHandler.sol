// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "../EtnaInboxTestBase.sol";
import { LibEtnaLandStatement } from "../LibEtnaLandStatement.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title EtnaInboxHandler
/// @notice Drives the Etna Inbox through forced inclusion saves, grid landings, governance
/// recoveries, fee sweeps, force-sent ETH and L1 time, and keeps an independent model of the
/// state each action must leave behind.
/// @dev Every landing and recovery is valid or broken in exactly one named way. The handler
/// predicts the outcome, success or the exact revert data, and records a violation when the Inbox
/// disagrees. It checks only what an action changes outside the model (the saver's refund, the
/// lander's balance, the SignalService at a rejected height); the invariants compare the Inbox's
/// storage with the model after every call. The honest chain is a ghost cut table: a landing
/// attempt draws the cuts of its new grid points and the table keeps them once it lands.
contract EtnaInboxHandler is CommonBase {
    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    /// @dev The invariant a recorded violation breaks.
    enum Property {
        Checkpoint,
        Records,
        Generations,
        Fees,
        Queue,
        Snapshot
    }

    /// @dev The deployment the handler drives and the model parameters it derives the expected
    /// state from.
    struct Deployment {
        EtnaInbox inbox;
        SignalService signalService;
        MockLandProofVerifier verifier;
        IEtnaStakingRegistry registry;
        address owner;
        uint64 l2ChainId;
        uint64 maxBatchBlocks;
        uint64 forcedInclusionFeeInGwei;
        uint64 forcedInclusionFeeDoubleThreshold;
        bytes32 committeeConfigHash;
        bytes32 genesisBlockHash;
        bytes32 genesisStateRoot;
        uint256 genesisCutoff;
    }

    /// @dev The honest chain at a grid point: EL hash, Comet hash, forced inclusion cursor and
    /// state root.
    struct Cut {
        bytes32 elHash;
        bytes32 cometHash;
        uint48 head;
        bytes32 stateRoot;
    }

    /// @dev A saved forced inclusion as the model expects the queue to hold it.
    struct SavedInclusion {
        bytes32 txHash;
        uint48 timestamp;
        uint48 l1Block;
        bool blanked;
    }

    /// @dev One landing attempt and the state it starts from.
    struct LandAttempt {
        uint256 defect;
        uint256 c;
        uint256 startHeight;
        uint48 head;
        uint48 tail;
        address lander;
        IEtnaInbox.LandInput input;
        bytes32[] leaves;
        bytes32[] blobHashes;
        bytes32 referenceHash;
        Cut[] newCuts;
        bytes expectedError;
    }

    /// @dev One recovery attempt.
    struct RecoveryAttempt {
        uint256 defect;
        address caller;
        uint48 expectedGeneration;
        uint256 expectedC;
        IEtnaInbox.Exclusion[] exclusions;
        uint256[] fiToClear;
        bytes expectedError;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev `K`, the landing grid interval.
    uint256 internal constant K = 6;

    /// @dev The landing defects: valid, or broken in exactly one way.
    uint256 internal constant VALID = 0;
    uint256 internal constant ALREADY_SETTLED = 1;
    uint256 internal constant OUT_OF_RANGE = 2;
    uint256 internal constant OFF_GRID = 3;
    uint256 internal constant TOO_LONG = 4;
    uint256 internal constant MISSING_ORIGIN = 5;
    uint256 internal constant LEAF_COUNT = 6;
    uint256 internal constant FRONTIER_LEAF = 7;
    uint256 internal constant HEAD_BOUND = 8;
    uint256 internal constant REFERENCE = 9;
    uint256 internal constant BLOB_COUNT = 10;
    uint256 internal constant INTERIOR_LEAF = 11;
    uint256 internal constant FALSE_INPUT = 12;
    uint256 internal constant REJECTED_PROOF = 13;
    uint256 internal constant LAND_MODES = 14;

    /// @dev The recovery defects: valid, or broken in exactly one way.
    uint256 internal constant NOT_OWNER = 1;
    uint256 internal constant GENERATION_MISMATCH = 2;
    uint256 internal constant CHECKPOINT_MISMATCH = 3;
    uint256 internal constant EXCLUSIONS_UNSORTED = 4;
    uint256 internal constant FI_UNSORTED = 5;
    uint256 internal constant FI_OUT_OF_RANGE = 6;
    uint256 internal constant ENTRY_KEY_MISMATCH = 7;
    uint256 internal constant UNKNOWN_BOND = 8;
    uint256 internal constant RECOVERY_MODES = 9;

    /// @dev The EIP-2935 history storage contract and its runtime code.
    address internal constant HISTORY_STORAGE = 0x0000F90827F1C53a10cb7A02335B175320002935;
    bytes internal constant HISTORY_STORAGE_CODE = hex"3373fffffffffffffffffffffffffffffffffffffffe"
        hex"14604657602036036042575f35600143038111"
        hex"604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500";
    uint256 internal constant HISTORY_SERVE_WINDOW = 8191;

    bytes internal constant PROOF = "etna proof";
    uint256 internal constant MAX_TX_BYTES = 8192;
    uint256 internal constant MAX_BLOBS = 6;
    uint256 internal constant HEIGHT_LIMIT = 2 ** 48;
    bytes32 internal constant BLANK_TX_HASH = keccak256("");

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    EtnaInbox public immutable inbox;
    SignalService public immutable signalService;
    MockLandProofVerifier public immutable verifier;
    IEtnaStakingRegistry public immutable registry;
    address public immutable owner;
    uint64 public immutable l2ChainId;
    uint64 public immutable forcedInclusionFeeInGwei;
    uint64 public immutable forcedInclusionFeeDoubleThreshold;
    bytes32 public immutable committeeConfigHash;
    /// @dev The longest grid-aligned `h - p`, the largest multiple of K within `maxBatchBlocks`.
    uint256 public immutable maxSpan;

    address[] internal _senders;
    address[] internal _landers;
    address internal immutable _sweeper;
    /// @dev The entry key of every registered bond, by bond id.
    bytes32[] internal _entryKeys;

    // ---------------------------------------------------------------
    // Ghost state
    // ---------------------------------------------------------------

    /// @dev Every landed checkpoint height in order, genesis first.
    uint256[] internal _checkpoints;
    mapping(uint256 height => IEtnaInbox.Landing) internal _records;
    /// @dev The honest chain at every settled grid point.
    mapping(uint256 height => Cut) internal _cuts;

    uint48 public ghostGeneration;
    mapping(uint256 generation => IEtnaInbox.Origin) internal _origins;

    uint48 public ghostHead;
    uint48 public ghostTail;
    mapping(uint256 index => SavedInclusion) internal _saved;

    uint256 public ghostSnapshot;
    mapping(uint256 bondId => uint256) public ghostExit;

    /// @dev Wei charged by successful saves, force-sent into the Inbox and swept to the treasury.
    uint256 public feesCharged;
    uint256 public forcedEther;
    uint256 public swept;

    mapping(Property => uint256) public violations;
    mapping(Property => string) public firstViolation;

    // ---------------------------------------------------------------
    // Statistics
    // ---------------------------------------------------------------

    uint256 public saves;
    uint256 public rejectedSaves;
    uint256 public landings;
    uint256 public landingsBelowCheckpoint;
    uint256 public landingsFromForeignOrigin;
    /// @dev Landings from a generation origin whose record an earlier generation wrote, with a
    /// checkpoint of the current generation above it.
    uint256 public overlapsFromForeignOrigin;
    uint256 public consumed;
    mapping(uint256 defect => uint256) public rejectedLandings;
    uint256 public recoveries;
    uint256 public blanked;
    uint256 public exclusionsApplied;
    mapping(uint256 defect => uint256) public rejectedRecoveries;
    uint256 public sweeps;
    uint256 public forcedTransfers;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @dev Must run in the block of the Inbox's `init`: generation 0's origin is this block.
    constructor(Deployment memory _deployment) {
        inbox = _deployment.inbox;
        signalService = _deployment.signalService;
        verifier = _deployment.verifier;
        registry = _deployment.registry;
        owner = _deployment.owner;
        l2ChainId = _deployment.l2ChainId;
        forcedInclusionFeeInGwei = _deployment.forcedInclusionFeeInGwei;
        forcedInclusionFeeDoubleThreshold = _deployment.forcedInclusionFeeDoubleThreshold;
        committeeConfigHash = _deployment.committeeConfigHash;
        maxSpan = _deployment.maxBatchBlocks / K * K;

        for (uint256 i; i < 3; ++i) {
            _senders.push(vm.addr(0xe7a5e0 + i));
            vm.deal(_senders[i], 1_000_000 ether);
        }
        for (uint256 i; i < 2; ++i) {
            _landers.push(vm.addr(0xe7a1a0 + i));
        }
        _sweeper = vm.addr(0xe7a5ee);

        uint256 bonds = _deployment.registry.entryCount();
        for (uint256 b; b < bonds; ++b) {
            IEtnaStakingRegistry.Entry memory entry = _deployment.registry.entryAt(b);
            _entryKeys.push(keccak256(abi.encode(uint256(entry.ckPrefix), entry.ckX)));
            ghostExit[b] = entry.exitEffectiveL1;
        }

        _checkpoints.push(0);
        _records[0].elHash = _deployment.genesisBlockHash;
        _cuts[0] = Cut({
            elHash: _deployment.genesisBlockHash,
            cometHash: 0,
            head: 0,
            stateRoot: _deployment.genesisStateRoot
        });
        _origins[0] = IEtnaInbox.Origin({
            startHeight: 0, l1BlockNumber: block.number, l1Timestamp: block.timestamp
        });
        ghostSnapshot = _deployment.genesisCutoff;
    }

    // ---------------------------------------------------------------
    // Fuzzed actions
    // ---------------------------------------------------------------

    /// @notice Saves a burst of one to four forced transactions, each from one of three senders:
    /// empty, short, up to 8192 bytes or exactly 8192, rarely over the limit; paying the exact
    /// fee, overpaying, or about one save in eight underpaying. Bursts let the queue hold more
    /// pending entries than one landing may consume.
    function saveForcedInclusion(uint256 _seed) external {
        uint256 burst = 1 + _rand(_seed, "burst") % 4;
        for (uint256 i; i < burst; ++i) {
            _save(_rand(_seed, i));
        }
    }

    /// @notice Lands the honest chain from an origin p of the current generation (its start
    /// height or a later checkpoint) to a later grid point h within `maxBatchBlocks`, consuming
    /// a legal number of pending forced inclusions, with a planted reference block and one to six
    /// blobs. About one call in three is broken in exactly one way instead.
    function land(uint256 _seed) external {
        LandAttempt memory attempt;
        attempt.c = _checkpoints[_checkpoints.length - 1];
        attempt.startHeight = _origins[ghostGeneration].startHeight;
        (attempt.head, attempt.tail) = (ghostHead, ghostTail);
        attempt.lander = _landers[_rand(_seed, "lander") % _landers.length];
        attempt.defect =
            _rand(_seed, "mode") % 3 == 0 ? 1 + _rand(_seed, "defect") % (LAND_MODES - 1) : VALID;

        _shapeLanding(attempt, _seed);
        bytes32 statement = _honestStatement(attempt);
        if (!_breakLanding(attempt, _rand(_seed, "break"))) {
            // The state cannot express the drawn defect; a leaf count is always breakable.
            attempt.defect = LEAF_COUNT;
            _breakLanding(attempt, _rand(_seed, "break"));
        }

        // The mock accepts only the honest statement, so a valid landing whose statement the
        // Inbox builds differently fails.
        verifier.setExpectedStatementHash(statement);
        verifier.setRejects(attempt.defect == REJECTED_PROOF);
        _submitLanding(attempt);
        verifier.setRejects(false);
        verifier.setExpectedStatementHash(0);
    }

    /// @notice The owner recovers at the current generation and checkpoint, forcing out a subset
    /// of the registered bonds and blanking a few pending forced inclusions. About two calls in
    /// three are broken in exactly one way instead, which keeps generations long enough for
    /// landings to reach back over several checkpoints.
    function recover(uint256 _seed) external {
        RecoveryAttempt memory attempt;
        attempt.caller = owner;
        attempt.expectedGeneration = ghostGeneration;
        attempt.expectedC = _checkpoints[_checkpoints.length - 1];
        attempt.exclusions = _validExclusions(_rand(_seed, "exclusions"));
        attempt.fiToClear = _validFiToClear(_rand(_seed, "fiToClear"));
        attempt.defect = _rand(_seed, "mode") % 3 != 0
            ? 1 + _rand(_seed, "defect") % (RECOVERY_MODES - 1)
            : VALID;
        if (!_breakRecovery(attempt, _rand(_seed, "break"))) {
            // The queue cannot express the drawn defect; a generation is always mismatchable.
            attempt.defect = GENERATION_MISMATCH;
            _breakRecovery(attempt, _rand(_seed, "break"));
        }

        vm.prank(attempt.caller);
        try inbox.recover(
            attempt.expectedGeneration, attempt.expectedC, attempt.exclusions, attempt.fiToClear
        ) {
            if (attempt.expectedError.length != 0) {
                _violate(Property.Generations, "a recovery the model rejects was accepted");
                return;
            }
            _recordRecovery(attempt);
        } catch (bytes memory reason) {
            _checkRevert(Property.Generations, attempt.expectedError, reason, "recover");
            ++rejectedRecoveries[attempt.defect];
        }
    }

    /// @notice Anyone sweeps the Inbox's whole balance to the treasury.
    function sweep() external {
        uint256 amount = address(inbox).balance;
        vm.prank(_sweeper);
        try inbox.sweepProtocolFees() {
            swept += amount;
            ++sweeps;
        } catch (bytes memory reason) {
            _checkRevert(Property.Fees, "", reason, "sweepProtocolFees");
        }
    }

    /// @notice Force-sends up to 10 ether into the Inbox without a call.
    function forceEther(uint256 _seed) external {
        uint256 amount = _seed % 10 ether;
        vm.deal(address(inbox), address(inbox).balance + amount);
        forcedEther += amount;
        ++forcedTransfers;
    }

    /// @notice Advances the L1 block and time: not at all, by one block, by up to a dozen, or
    /// by up to 400.
    function advanceBlocks(uint256 _seed) external {
        uint256 mode = _seed % 4;
        uint256 blocks;
        if (mode == 1) blocks = 1;
        else if (mode == 2) blocks = 1 + (_seed >> 2) % 12;
        else if (mode == 3) blocks = 13 + (_seed >> 2) % 400;
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + 12 * blocks);
    }

    // ---------------------------------------------------------------
    // Views for the invariants
    // ---------------------------------------------------------------

    function checkpointCount() external view returns (uint256) {
        return _checkpoints.length;
    }

    function checkpointAt(uint256 _index) external view returns (uint256) {
        return _checkpoints[_index];
    }

    function recordAt(uint256 _height) external view returns (IEtnaInbox.Landing memory) {
        return _records[_height];
    }

    function cutAt(uint256 _height) external view returns (Cut memory) {
        return _cuts[_height];
    }

    function originAt(uint256 _generation) external view returns (IEtnaInbox.Origin memory) {
        return _origins[_generation];
    }

    function savedAt(uint256 _index) external view returns (SavedInclusion memory) {
        return _saved[_index];
    }

    function bondCount() external view returns (uint256) {
        return _entryKeys.length;
    }

    // ---------------------------------------------------------------
    // Saves
    // ---------------------------------------------------------------

    /// @dev One save with its predicted outcome; a success appends the model's entry.
    function _save(uint256 _seed) internal {
        address sender = _senders[_rand(_seed, "sender") % _senders.length];
        bytes memory txBytes = _txBytes(_rand(_seed, "length"));
        uint64 fee = _expectedFee();
        if (inbox.getCurrentForcedInclusionFee() != fee) {
            _violate(Property.Fees, "the fee is not base * (threshold + pending) / threshold");
        }
        uint256 required = uint256(fee) * 1 gwei;
        uint256 valueSeed = _rand(_seed, "value");
        uint256 value = required + (valueSeed >> 3) % 1 ether;
        bytes memory expected;
        if (valueSeed % 8 == 1) value = required;
        if (valueSeed % 8 == 0) {
            value = required - 1 - (valueSeed >> 3) % required;
            expected = abi.encodeWithSelector(IEtnaInbox.InsufficientFee.selector);
        }
        if (txBytes.length > MAX_TX_BYTES) {
            expected = abi.encodeWithSelector(IEtnaInbox.ForcedTransactionTooLarge.selector);
        }
        uint256 senderBefore = sender.balance;

        vm.prank(sender);
        try inbox.saveForcedInclusion{ value: value }(txBytes) {
            if (expected.length != 0) {
                _violate(Property.Queue, "a save the model rejects was accepted");
                return;
            }
            if (senderBefore - sender.balance != required) {
                _violate(Property.Fees, "the sender paid other than the fee");
            }
            _saved[ghostTail] = SavedInclusion({
                txHash: keccak256(txBytes),
                timestamp: uint48(block.timestamp),
                l1Block: uint48(block.number),
                blanked: false
            });
            ++ghostTail;
            feesCharged += required;
            ++saves;
        } catch (bytes memory reason) {
            _checkRevert(Property.Queue, expected, reason, "saveForcedInclusion");
            if (sender.balance != senderBefore) {
                _violate(Property.Fees, "a rejected save moved the sender's ETH");
            }
            ++rejectedSaves;
        }
    }

    /// @dev `baseFee * (threshold + pending) / threshold`, capped at `type(uint64).max`.
    function _expectedFee() internal view returns (uint64) {
        uint256 pending = uint256(ghostTail) - ghostHead;
        uint256 fee = uint256(forcedInclusionFeeInGwei)
            * (uint256(forcedInclusionFeeDoubleThreshold) + pending)
            / forcedInclusionFeeDoubleThreshold;
        return fee > type(uint64).max ? type(uint64).max : uint64(fee);
    }

    /// @dev Transaction bytes: empty, short, up to 8192 bytes, exactly 8192, or rarely over the
    /// limit; filled with a hash chain and zero past their length.
    function _txBytes(uint256 _seed) internal pure returns (bytes memory txBytes_) {
        uint256 mode = _seed % 8;
        uint256 length;
        if (mode == 1) length = MAX_TX_BYTES;
        else if (mode == 2) length = MAX_TX_BYTES + 1 + (_seed >> 3) % 64;
        else if (mode < 6 && mode != 0) length = (_seed >> 3) % 256;
        else if (mode >= 6) length = (_seed >> 3) % (MAX_TX_BYTES + 1);
        txBytes_ = new bytes(length);
        bytes32 word = keccak256(abi.encode(_seed));
        for (uint256 i; i < length; i += 32) {
            uint256 rest = length - i;
            bytes32 chunk = rest >= 32 ? word : word & ~bytes32(type(uint256).max >> (8 * rest));
            assembly {
                mstore(add(add(txBytes_, 32), i), chunk)
            }
            word = keccak256(abi.encode(word));
        }
    }

    // ---------------------------------------------------------------
    // Landings
    // ---------------------------------------------------------------

    /// @dev Draws the honest landing: origin, terminal height, new queue head, the cuts of the
    /// new grid points (c, h], the leaves of (p, h), a planted reference block, the snapshot and
    /// the blobs.
    function _shapeLanding(LandAttempt memory _attempt, uint256 _seed) internal {
        uint256 c = _attempt.c;
        // A frontier leaf exists only below c; the head bound h - c differs from h - p only
        // there, and a one-segment batch leaves the most pending entries above it.
        bool headBound = _attempt.defect == HEAD_BOUND;
        uint256 p = _pickOrigin(
            _rand(_seed, "origin"),
            c,
            _attempt.startHeight,
            headBound || _attempt.defect == FRONTIER_LEAF
        );
        uint256 h = c + (headBound ? K : K * (1 + _rand(_seed, "height") % ((p + maxSpan - c) / K)));
        uint256 room = _min(_attempt.tail - _attempt.head, h - c);
        uint256 headSeed = _rand(_seed, "head");
        uint256 headAfter =
            _attempt.head + (headSeed % 3 == 0 ? room : (headSeed >> 2) % (room + 1));

        _attempt.newCuts = new Cut[]((h - c) / K);
        for (uint256 i; i < _attempt.newCuts.length; ++i) {
            _attempt.newCuts[i] = _newCut(c + K * (i + 1), c, _attempt.head, headAfter);
        }
        _attempt.leaves = new bytes32[]((h - p) / K - 1);
        for (uint256 i; i < _attempt.leaves.length; ++i) {
            uint256 x = p + K * (i + 1);
            Cut memory cut = _cutAt(_attempt, x);
            _attempt.leaves[i] = LibEtnaLandStatement.leaf(x, cut.elHash, cut.cometHash, cut.head);
        }

        Cut memory last = _attempt.newCuts[_attempt.newCuts.length - 1];
        uint256 referenceNumber;
        (referenceNumber, _attempt.referenceHash) = _plantReference(_rand(_seed, "reference"));
        _attempt.input = IEtnaInbox.LandInput({
            parentHeight: p,
            lastHeight: h,
            lastBlockHash: last.elHash,
            lastCometHash: last.cometHash,
            lastStateRoot: last.stateRoot,
            l1ReferenceBlockNumber: referenceNumber,
            forcedInclusionHead: headAfter,
            activeCommitteeSnapshot: _snapshot(referenceNumber, _rand(_seed, "snapshot"))
        });
        _attempt.blobHashes = _blobHashes(1 + _rand(_seed, "blobs") % MAX_BLOBS, _seed);
    }

    /// @dev An origin of the current generation within `maxSpan` of `c + K`: about one call in
    /// four the generation's start height when in reach, otherwise any reachable checkpoint
    /// from the start height on, below c if `_belowC` and one is in reach. Every checkpoint at
    /// or above the start height is the origin or was landed in the current generation.
    function _pickOrigin(
        uint256 _seed,
        uint256 _c,
        uint256 _startHeight,
        bool _belowC
    )
        internal
        view
        returns (uint256)
    {
        uint256 lowest = _c + K > maxSpan ? _c + K - maxSpan : 0;
        if (lowest < _startHeight) lowest = _startHeight;
        if (_seed % 4 == 0 && _startHeight >= lowest && (!_belowC || _startHeight < _c)) {
            return _startHeight;
        }
        uint256 n = _checkpoints.length;
        uint256 reachable;
        while (reachable < n && _checkpoints[n - 1 - reachable] >= lowest) {
            ++reachable;
        }
        if (_belowC && reachable > 1) return _checkpoints[n - 2 - (_seed >> 2) % (reachable - 1)];
        return _checkpoints[n - 1 - (_seed >> 2) % reachable];
    }

    /// @dev The generation's honest cut at the new grid point `_x` in (c, h]: hashes that differ
    /// per generation, and a cursor that advances at most once per block towards `_headAfter`.
    function _newCut(
        uint256 _x,
        uint256 _c,
        uint256 _head,
        uint256 _headAfter
    )
        internal
        view
        returns (Cut memory)
    {
        return Cut({
            elHash: keccak256(abi.encode("etna el", ghostGeneration, _x)),
            cometHash: keccak256(abi.encode("etna comet", ghostGeneration, _x)),
            head: uint48(_min(_headAfter, _head + (_x - _c))),
            stateRoot: keccak256(abi.encode("etna state", ghostGeneration, _x))
        });
    }

    /// @dev A copy of the honest cut at grid point `_x`: settled at or below c, drawn by this
    /// attempt above it.
    function _cutAt(LandAttempt memory _attempt, uint256 _x) internal view returns (Cut memory) {
        if (_x <= _attempt.c) return _cuts[_x];
        Cut memory drawn = _attempt.newCuts[(_x - _attempt.c) / K - 1];
        return Cut({
            elHash: drawn.elHash,
            cometHash: drawn.cometHash,
            head: drawn.head,
            stateRoot: drawn.stateRoot
        });
    }

    /// @dev The statement the honest landing proves, built from the model: the ghost generation,
    /// the ghost record at p and the independently derived committee configuration hash.
    function _honestStatement(LandAttempt memory _attempt) internal returns (bytes32) {
        IEtnaInbox.LandInput memory input = _attempt.input;
        bytes memory preimage = LibEtnaLandStatement.preimage(
            LibEtnaLandStatement.Context({
                l2ChainId: l2ChainId,
                inbox: address(inbox),
                stakingRegistry: address(registry),
                generation: ghostGeneration,
                committeeConfigHash: committeeConfigHash
            }),
            input,
            _records[input.parentHeight],
            _attempt.referenceHash,
            _attempt.blobHashes,
            LibEtnaLandStatement.cutHash(
                ghostGeneration, input.parentHeight, input.lastHeight, _attempt.leaves
            )
        );
        if (preimage.length != 672) _violate(Property.Checkpoint, "the statement is not 21 words");
        return keccak256(preimage);
    }

    /// @dev Breaks the landing in the way its defect names and sets the predicted revert data;
    /// returns false if the state cannot express the defect. Every break leaves the checks before
    /// the broken one passing, so the predicted error is the first one the Inbox raises.
    function _breakLanding(LandAttempt memory _attempt, uint256 _seed) internal returns (bool) {
        uint256 defect = _attempt.defect;
        IEtnaInbox.LandInput memory input = _attempt.input;
        uint256 c = _attempt.c;
        bytes4 selector;
        if (defect == VALID) {
            return true;
        } else if (defect == ALREADY_SETTLED) {
            input.lastHeight = c - K * (_seed % (c / K + 1));
            selector = IEtnaInbox.AlreadySettled.selector;
        } else if (defect == OUT_OF_RANGE) {
            _breakRange(_attempt, _seed);
            selector = IEtnaInbox.InvalidRange.selector;
        } else if (defect == OFF_GRID) {
            if (_seed % 2 == 0 && input.parentHeight < c) {
                input.parentHeight += 1 + (_seed >> 1) % (K - 1);
            } else {
                input.lastHeight -= 1 + (_seed >> 1) % (K - 1);
            }
            selector = IEtnaInbox.OffGrid.selector;
        } else if (defect == TOO_LONG) {
            input.lastHeight = input.parentHeight + maxSpan + K * (1 + _seed % 3);
            selector = IEtnaInbox.BatchTooLarge.selector;
        } else if (defect == MISSING_ORIGIN) {
            if (!_breakOrigin(_attempt, _seed)) return false;
            selector = IEtnaInbox.MissingOrigin.selector;
        } else if (defect == LEAF_COUNT) {
            _breakLeafCount(_attempt, _seed);
            selector = IEtnaInbox.LeafCountMismatch.selector;
        } else if (defect == FRONTIER_LEAF) {
            if (c == input.parentHeight) return false;
            _breakLeaf(_attempt, (c - input.parentHeight) / K - 1, _seed);
            selector = IEtnaInbox.FrontierLeafMismatch.selector;
        } else if (defect == HEAD_BOUND) {
            _breakHead(_attempt, _seed);
            selector = IEtnaInbox.InvalidForcedInclusionHead.selector;
        } else if (defect == REFERENCE) {
            input.l1ReferenceBlockNumber = _breakReference(_seed);
            selector = IEtnaInbox.ReferenceBlockUnavailable.selector;
        } else if (defect == BLOB_COUNT) {
            _attempt.blobHashes = _blobHashes(_seed % 2 == 0 ? 0 : MAX_BLOBS + 1, _seed);
            selector = IEtnaInbox.InvalidBlobCount.selector;
        } else if (defect == INTERIOR_LEAF) {
            if (!_breakInteriorLeaf(_attempt, _seed)) return false;
            selector = MockLandProofVerifier.ProofRejected.selector;
        } else if (defect == FALSE_INPUT) {
            _breakInput(input, _seed);
            selector = MockLandProofVerifier.ProofRejected.selector;
        } else {
            selector = MockLandProofVerifier.ProofRejected.selector;
        }
        _attempt.expectedError = abi.encodeWithSelector(selector);
        return true;
    }

    /// @dev p above c, p a checkpoint below the generation's start height, or h at 2^48 or above.
    function _breakRange(LandAttempt memory _attempt, uint256 _seed) internal view {
        IEtnaInbox.LandInput memory input = _attempt.input;
        uint256 mode = _seed % 3;
        if (mode == 1 && _attempt.startHeight != 0) {
            // Checkpoints below the start height belong to earlier generations.
            uint256 below;
            while (_checkpoints[below] < _attempt.startHeight) {
                ++below;
            }
            input.parentHeight = _checkpoints[(_seed >> 2) % below];
        } else if (mode == 2) {
            input.lastHeight = HEIGHT_LIMIT + K * ((_seed >> 2) % 3);
        } else {
            input.parentHeight = _attempt.c + K * (1 + (_seed >> 2) % 3);
        }
    }

    /// @dev Moves p to a grid point of the current generation in reach of h that has no landing
    /// record; false if there is none.
    function _breakOrigin(LandAttempt memory _attempt, uint256 _seed) internal view returns (bool) {
        IEtnaInbox.LandInput memory input = _attempt.input;
        uint256 lowest = input.lastHeight > maxSpan ? input.lastHeight - maxSpan : 0;
        if (lowest < _attempt.startHeight) lowest = _attempt.startHeight;
        uint256 candidates;
        for (uint256 x = lowest; x <= _attempt.c; x += K) {
            if (_records[x].elHash == 0) ++candidates;
        }
        if (candidates == 0) return false;
        uint256 pick = _seed % candidates;
        for (uint256 x = lowest; x <= _attempt.c; x += K) {
            if (_records[x].elHash != 0) continue;
            if (pick == 0) {
                input.parentHeight = x;
                return true;
            }
            --pick;
        }
        return false;
    }

    /// @dev One leaf more, or one fewer when there is one.
    function _breakLeafCount(LandAttempt memory _attempt, uint256 _seed) internal pure {
        bytes32[] memory leaves = _attempt.leaves;
        uint256 length = leaves.length;
        if (_seed % 2 == 0 && length != 0) {
            assembly {
                mstore(leaves, sub(length, 1))
            }
            return;
        }
        bytes32[] memory longer = new bytes32[](length + 1);
        for (uint256 i; i < length; ++i) {
            longer[i] = leaves[i];
        }
        longer[length] = keccak256(abi.encode("etna extra leaf", _seed));
        _attempt.leaves = longer;
    }

    /// @dev Replaces leaf `_index` with the leaf of a wrong height, EL hash, Comet hash or
    /// cursor at the same grid point.
    function _breakLeaf(LandAttempt memory _attempt, uint256 _index, uint256 _seed) internal view {
        uint256 x = _attempt.input.parentHeight + K * (_index + 1);
        Cut memory cut = _cutAt(_attempt, x);
        uint256 mode = _seed % 4;
        if (mode == 0) x += 1 + (_seed >> 2) % (K - 1);
        else if (mode == 1) cut.elHash = keccak256(abi.encode(cut.elHash));
        else if (mode == 2) cut.cometHash = keccak256(abi.encode(cut.cometHash));
        else cut.head += 1;
        _attempt.leaves[_index] = LibEtnaLandStatement.leaf(x, cut.elHash, cut.cometHash, cut.head);
    }

    /// @dev Breaks a leaf other than the one at c; false if there is none.
    function _breakInteriorLeaf(
        LandAttempt memory _attempt,
        uint256 _seed
    )
        internal
        view
        returns (bool)
    {
        uint256 length = _attempt.leaves.length;
        uint256 p = _attempt.input.parentHeight;
        bool frontier = _attempt.c > p;
        if (length == 0 || (frontier && length == 1)) return false;
        uint256 index = _seed % length;
        if (frontier && index == (_attempt.c - p) / K - 1) index = (index + 1) % length;
        _breakLeaf(_attempt, index, _seed >> 8);
        return true;
    }

    /// @dev A new queue head past the tail, behind the head, or more than h - c past the head.
    function _breakHead(LandAttempt memory _attempt, uint256 _seed) internal pure {
        uint256 head = _attempt.head;
        uint256 tail = _attempt.tail;
        uint256 blocks = _attempt.input.lastHeight - _attempt.c;
        uint256 mode = _seed % 3;
        uint256 headAfter;
        if (mode == 1 && head != 0) {
            headAfter = (_seed >> 2) % head;
        } else if (mode == 2 && tail - head > blocks) {
            // Half the time exactly one entry more than h - c allows.
            headAfter = head + blocks + 1;
            if ((_seed >> 2) % 2 == 0) headAfter += (_seed >> 3) % (tail - head - blocks);
        } else {
            headAfter = tail + 1 + (_seed >> 2) % 3;
        }
        _attempt.input.forcedInclusionHead = headAfter;
    }

    /// @dev An L1 block that is not in the past, older than the EIP-2935 window, or within a
    /// window but with a zero hash.
    function _breakReference(uint256 _seed) internal returns (uint256 number_) {
        uint256 mode = _seed % 4;
        if (mode == 0) {
            number_ = block.number + (_seed >> 2) % 3;
        } else if (mode == 1) {
            number_ = block.number - HISTORY_SERVE_WINDOW - 1 - (_seed >> 2) % 64;
        } else if (mode == 2) {
            number_ = block.number - 1 - (_seed >> 2) % 256;
            vm.setBlockhash(number_, 0);
        } else {
            number_ = block.number - 257 - (_seed >> 2) % (HISTORY_SERVE_WINDOW - 256);
            vm.etch(HISTORY_STORAGE, HISTORY_STORAGE_CODE);
            vm.store(HISTORY_STORAGE, bytes32(number_ % HISTORY_SERVE_WINDOW), 0);
        }
    }

    /// @dev A public input other than the proven one: the state root, Comet hash or snapshot.
    function _breakInput(IEtnaInbox.LandInput memory _input, uint256 _seed) internal pure {
        uint256 mode = _seed % 3;
        if (mode == 0) _input.lastStateRoot = keccak256(abi.encode(_input.lastStateRoot));
        else if (mode == 1) _input.lastCometHash = keccak256(abi.encode(_input.lastCometHash));
        else _input.activeCommitteeSnapshot += 1;
    }

    function _submitLanding(LandAttempt memory _attempt) internal {
        uint256 landerBefore = _attempt.lander.balance;
        vm.blobhashes(_attempt.blobHashes);
        vm.prank(_attempt.lander);
        try inbox.land(_attempt.input, _attempt.leaves, PROOF) {
            if (_attempt.expectedError.length != 0) {
                _violate(Property.Checkpoint, "a landing the model rejects was accepted");
            } else {
                _recordLanding(_attempt);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Checkpoint, _attempt.expectedError, reason, "land");
            _checkNothingSaved(_attempt);
        }
        if (_attempt.lander.balance != landerBefore) {
            _violate(Property.Fees, "a landing moved the lander's ETH");
        }
    }

    /// @dev Keeps the landed cuts and the record at h, and moves the checkpoint, queue head and
    /// snapshot as the landing did.
    function _recordLanding(LandAttempt memory _attempt) internal {
        IEtnaInbox.LandInput memory input = _attempt.input;
        uint256 p = input.parentHeight;
        if (p < _attempt.c) ++landingsBelowCheckpoint;
        if (_records[p].generation != ghostGeneration) {
            ++landingsFromForeignOrigin;
            if (p < _attempt.c) ++overlapsFromForeignOrigin;
        }

        for (uint256 i; i < _attempt.newCuts.length; ++i) {
            _cuts[_attempt.c + K * (i + 1)] = _attempt.newCuts[i];
        }
        _records[input.lastHeight] = IEtnaInbox.Landing({
            parentHeight: uint48(_attempt.c),
            generation: ghostGeneration,
            head: uint48(input.forcedInclusionHead),
            elHash: input.lastBlockHash,
            cometHash: input.lastCometHash
        });
        _checkpoints.push(input.lastHeight);
        ghostHead = uint48(input.forcedInclusionHead);
        ghostSnapshot = input.activeCommitteeSnapshot;
        consumed += input.forcedInclusionHead - _attempt.head;
        ++landings;
    }

    /// @dev After a rejected landing the SignalService holds nothing at an unsettled h; the
    /// invariants check every other slot.
    function _checkNothingSaved(LandAttempt memory _attempt) internal {
        ++rejectedLandings[_attempt.defect];
        uint256 h = _attempt.input.lastHeight;
        if (h <= _attempt.c || h >= HEIGHT_LIMIT) return;
        try signalService.getCheckpoint(uint48(h)) {
            _violate(Property.Checkpoint, "a rejected landing saved a SignalService checkpoint");
        } catch { }
    }

    /// @dev Plants a non-zero hash for a past L1 block: through `blockhash` for the last 256
    /// blocks, or about one call in four through the EIP-2935 contract for up to 8191 blocks.
    function _plantReference(uint256 _seed) internal returns (uint256 number_, bytes32 hash_) {
        bool history = _seed % 4 == 0;
        uint256 age =
            history ? 257 + (_seed >> 2) % (HISTORY_SERVE_WINDOW - 256) : 1 + (_seed >> 2) % 256;
        number_ = block.number - age;
        hash_ = keccak256(abi.encode("etna l1 block", number_, _seed));
        if (history) {
            vm.etch(HISTORY_STORAGE, HISTORY_STORAGE_CODE);
            vm.store(HISTORY_STORAGE, bytes32(number_ % HISTORY_SERVE_WINDOW), hash_);
        } else {
            vm.setBlockhash(number_, hash_);
        }
    }

    /// @dev A selection snapshot between the current one and the reference block; the Inbox only
    /// binds it into the statement.
    function _snapshot(uint256 _referenceNumber, uint256 _seed) internal view returns (uint256) {
        if (ghostSnapshot > _referenceNumber) return ghostSnapshot;
        return ghostSnapshot + _seed % (_referenceNumber - ghostSnapshot + 1);
    }

    /// @dev `_count` distinct versioned (0x01-prefixed) blob hashes.
    function _blobHashes(
        uint256 _count,
        uint256 _seed
    )
        internal
        pure
        returns (bytes32[] memory hashes_)
    {
        hashes_ = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            hashes_[i] = bytes32(
                (uint256(1) << 248) | (uint256(keccak256(abi.encode("etna blob", _seed, i))) >> 8)
            );
        }
    }

    // ---------------------------------------------------------------
    // Recoveries
    // ---------------------------------------------------------------

    /// @dev A subset of the registered bonds, sorted by bond id, with their entry keys.
    function _validExclusions(uint256 _seed)
        internal
        view
        returns (IEtnaInbox.Exclusion[] memory list_)
    {
        uint256 bonds = _entryKeys.length;
        uint256 mask = _seed % (1 << bonds);
        list_ = new IEtnaInbox.Exclusion[](_popCount(mask));
        uint256 n;
        for (uint256 b; b < bonds; ++b) {
            if (mask & (1 << b) == 0) continue;
            list_[n++] = IEtnaInbox.Exclusion({ bondId: b, entryKey: _entryKeys[b] });
        }
    }

    /// @dev Up to three strictly increasing pending queue indices; none about one call in four.
    function _validFiToClear(uint256 _seed) internal view returns (uint256[] memory list_) {
        uint256 pending = ghostTail - ghostHead;
        if (pending == 0 || _seed % 4 == 0) return new uint256[](0);
        list_ = new uint256[](1 + (_seed >> 2) % _min(pending, 3));
        uint256 next = ghostHead + (_seed >> 8) % pending;
        uint256 n;
        while (n < list_.length && next < ghostTail) {
            list_[n] = next;
            next += 1 + (_seed >> (16 + 2 * n)) % 3;
            ++n;
        }
        assembly {
            mstore(list_, n)
        }
    }

    /// @dev Breaks the recovery in the way its defect names and sets the predicted revert data;
    /// returns false if the queue cannot express the defect.
    function _breakRecovery(
        RecoveryAttempt memory _attempt,
        uint256 _seed
    )
        internal
        view
        returns (bool)
    {
        uint256 defect = _attempt.defect;
        if (defect == VALID) return true;
        if (defect == NOT_OWNER) {
            _attempt.caller = _landers[_seed % _landers.length];
            _attempt.expectedError =
                abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner");
            return true;
        }
        bytes4 selector;
        if (defect == GENERATION_MISMATCH) {
            _attempt.expectedGeneration = _seed % 2 == 0 || ghostGeneration == 0
                ? ghostGeneration + 1 + uint48((_seed >> 1) % 3)
                : uint48((_seed >> 1) % ghostGeneration);
            selector = IEtnaInbox.GenerationMismatch.selector;
        } else if (defect == CHECKPOINT_MISMATCH) {
            uint256 c = _attempt.expectedC;
            _attempt.expectedC =
                _seed % 2 == 0 || c == 0 ? c + 1 + (_seed >> 1) % (3 * K) : (_seed >> 1) % c;
            selector = IEtnaInbox.CheckpointMismatch.selector;
        } else if (defect == EXCLUSIONS_UNSORTED) {
            _unsortExclusions(_attempt, _seed);
            selector = IEtnaInbox.ExclusionsNotSorted.selector;
        } else if (defect == FI_UNSORTED) {
            if (ghostTail == ghostHead) return false;
            _unsortIndices(_attempt, _seed);
            selector = IEtnaInbox.FiToClearNotSorted.selector;
        } else if (defect == FI_OUT_OF_RANGE) {
            _attempt.fiToClear = _seed % 2 == 0 && ghostHead != 0
                ? _prepend(_attempt.fiToClear, (_seed >> 1) % ghostHead)
                : _append(_attempt.fiToClear, ghostTail + (_seed >> 1) % 3);
            selector = IEtnaInbox.FiIndexOutOfRange.selector;
        } else if (defect == ENTRY_KEY_MISMATCH) {
            _breakEntryKey(_attempt, _seed);
            selector = IEtnaStakingRegistry.EntryKeyMismatch.selector;
        } else {
            _attempt.exclusions = _appendExclusion(
                _attempt.exclusions,
                IEtnaInbox.Exclusion({
                    bondId: _entryKeys.length + _seed % 3,
                    entryKey: keccak256(abi.encode("etna unknown bond", _seed))
                })
            );
            selector = IEtnaStakingRegistry.UnknownBond.selector;
        }
        _attempt.expectedError = abi.encodeWithSelector(selector);
        return true;
    }

    /// @dev Swaps the first two exclusions, or lists one bond twice.
    function _unsortExclusions(RecoveryAttempt memory _attempt, uint256 _seed) internal view {
        IEtnaInbox.Exclusion[] memory list = _attempt.exclusions;
        if (list.length >= 2) {
            (list[0], list[1]) = (list[1], list[0]);
            return;
        }
        uint256 bondId = _seed % _entryKeys.length;
        IEtnaInbox.Exclusion memory exclusion =
            IEtnaInbox.Exclusion({ bondId: bondId, entryKey: _entryKeys[bondId] });
        _attempt.exclusions = new IEtnaInbox.Exclusion[](2);
        (_attempt.exclusions[0], _attempt.exclusions[1]) = (exclusion, exclusion);
    }

    /// @dev Swaps the first two indices, or lists one pending index twice.
    function _unsortIndices(RecoveryAttempt memory _attempt, uint256 _seed) internal view {
        uint256[] memory list = _attempt.fiToClear;
        if (list.length >= 2) {
            (list[0], list[1]) = (list[1], list[0]);
            return;
        }
        uint256 index = ghostHead + _seed % (ghostTail - ghostHead);
        _attempt.fiToClear = new uint256[](2);
        (_attempt.fiToClear[0], _attempt.fiToClear[1]) = (index, index);
    }

    /// @dev Gives one listed exclusion, or a single new one, a key other than its entry's.
    function _breakEntryKey(RecoveryAttempt memory _attempt, uint256 _seed) internal view {
        bytes32 wrongKey = keccak256(abi.encode("etna wrong key", _seed));
        if (_attempt.exclusions.length != 0) {
            _attempt.exclusions[_seed % _attempt.exclusions.length].entryKey = wrongKey;
            return;
        }
        _attempt.exclusions = new IEtnaInbox.Exclusion[](1);
        _attempt.exclusions[0] =
            IEtnaInbox.Exclusion({ bondId: _seed % _entryKeys.length, entryKey: wrongKey });
    }

    /// @dev Starts the next generation at c with origin (c, R, R's timestamp), blanks the listed
    /// entries and moves each excluded bond's exit to min(existing, R).
    function _recordRecovery(RecoveryAttempt memory _attempt) internal {
        uint48 generation = ghostGeneration + 1;
        _origins[generation] = IEtnaInbox.Origin({
            startHeight: _attempt.expectedC,
            l1BlockNumber: block.number,
            l1Timestamp: block.timestamp
        });
        ghostGeneration = generation;
        for (uint256 i; i < _attempt.fiToClear.length; ++i) {
            _saved[_attempt.fiToClear[i]].blanked = true;
        }
        for (uint256 i; i < _attempt.exclusions.length; ++i) {
            uint256 bondId = _attempt.exclusions[i].bondId;
            if (block.number < ghostExit[bondId]) ghostExit[bondId] = block.number;
        }
        ++recoveries;
        blanked += _attempt.fiToClear.length;
        exclusionsApplied += _attempt.exclusions.length;
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

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
        string[6] memory names =
            ["checkpoint", "records", "generations", "fees", "queue", "snapshot"];
        firstViolation[_property] = string.concat(names[uint8(_property)], ": ", _reason);
    }

    function _rand(uint256 _seed, string memory _tag) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_seed, _tag)));
    }

    function _rand(uint256 _seed, uint256 _index) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_seed, "burst save", _index)));
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }

    function _popCount(uint256 _x) internal pure returns (uint256 count_) {
        for (; _x != 0; _x &= _x - 1) {
            ++count_;
        }
    }

    function _append(
        uint256[] memory _list,
        uint256 _value
    )
        internal
        pure
        returns (uint256[] memory list_)
    {
        list_ = new uint256[](_list.length + 1);
        for (uint256 i; i < _list.length; ++i) {
            list_[i] = _list[i];
        }
        list_[_list.length] = _value;
    }

    function _prepend(
        uint256[] memory _list,
        uint256 _value
    )
        internal
        pure
        returns (uint256[] memory list_)
    {
        list_ = new uint256[](_list.length + 1);
        list_[0] = _value;
        for (uint256 i; i < _list.length; ++i) {
            list_[i + 1] = _list[i];
        }
    }

    function _appendExclusion(
        IEtnaInbox.Exclusion[] memory _list,
        IEtnaInbox.Exclusion memory _exclusion
    )
        internal
        pure
        returns (IEtnaInbox.Exclusion[] memory list_)
    {
        list_ = new IEtnaInbox.Exclusion[](_list.length + 1);
        for (uint256 i; i < _list.length; ++i) {
            list_[i] = _list[i];
        }
        list_[_list.length] = _exclusion;
    }
}
