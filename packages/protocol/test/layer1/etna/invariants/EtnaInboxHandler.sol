// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "../EtnaInboxTestBase.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaRewardPool } from "src/layer1/etna/iface/IEtnaRewardPool.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaRewardPool } from "src/layer1/etna/impl/EtnaRewardPool.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title EtnaInboxHandler
/// @notice Drives an initialized `EtnaInbox` and its reward pool through `saveForcedInclusion`,
/// `land`, donations to the pool, withdrawals of its credits and L1 block advances for the
/// invariant campaign, and keeps ghost copies of the forced inclusion queue, the landed
/// checkpoints, the pool's signed counts, reservations and credits, and every wei moved.
/// @dev Every landing carries the participation of its commit range, one part per epoch, with
/// each member's count the range's heights in that epoch or fewer and proposer scores summing to
/// at most 10,000 per such height, and the committee of each epoch it completes, shaped as
/// `land` requires; about one landing in eight also funds the prover reward ledger with
/// `msg.value`. The handler models each freeze (the shares of the free balance, the split of the
/// validator share into base and proposer bonus, the base by effective stake times signed heights
/// and the bonus by proposer score, each rounded down) and the landing reward (per block, capped
/// at the ledger) independently of the pool and the Inbox.
/// Each call's outcome is predicted before it runs in try/catch: a save or landing is
/// either valid or broken in exactly one way, whose custom error is then expected. A landing
/// mode picks the break: no progress, too many blocks, a zero fee recipient, a queue head
/// behind the stored head, past the tail or past one entry per block, an unavailable or zero
/// reference hash, no blobs, a zero block hash or state root, or a proof the verifier rejects.
/// A mismatch or a broken property is recorded as a violation that the invariants assert never
/// happened, so the handler never reverts.
contract EtnaInboxHandler is CommonBase {
    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    /// @dev The invariant a recorded violation breaks.
    enum Property {
        Checkpoint,
        Queue,
        Fees,
        Rewards
    }

    /// @dev A saved forced inclusion as the handler expects the Inbox to store it.
    struct SavedInclusion {
        bytes32 txHash;
        uint48 timestamp;
        uint64 l1Block;
        uint64 feeInGwei;
    }

    /// @dev A landed L2 block, genesis first.
    struct LandedBlock {
        uint64 height;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    /// @dev One landing attempt and the state it starts from.
    struct Landing {
        IEtnaInbox.LandInput input;
        IEtnaInbox.EpochParticipation[] participation;
        IEtnaInbox.CommitteeMember[][] settlements;
        bytes32[] blobHashes;
        bytes32 referenceHash;
        address lander;
        uint256 value;
        uint256 countSeed;
        uint256 mode;
        bytes4 expectedError;
        IEtnaInbox.LandedCheckpoint parent;
        uint48 head;
        uint48 tail;
    }

    /// @dev The ETH balances a landing may move, and the prover reward ledger.
    struct Balances {
        uint256 inbox;
        uint256 lander;
        uint256 recipient;
        uint256 pool;
        uint256 ledger;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The landing modes: valid, or broken in exactly one way.
    uint256 internal constant VALID = 0;
    uint256 internal constant NO_PROGRESS = 1;
    uint256 internal constant TOO_MANY_BLOCKS = 2;
    uint256 internal constant ZERO_RECIPIENT = 3;
    uint256 internal constant HEAD_BEHIND = 4;
    uint256 internal constant HEAD_PAST_TAIL = 5;
    uint256 internal constant HEAD_PAST_BLOCKS = 6;
    uint256 internal constant FUTURE_REFERENCE = 7;
    uint256 internal constant ZERO_REFERENCE_HASH = 8;
    uint256 internal constant EXPIRED_REFERENCE = 9;
    uint256 internal constant NO_BLOBS = 10;
    uint256 internal constant ZERO_CHECKPOINT_HASH = 11;
    uint256 internal constant REJECTED_PROOF = 12;
    uint256 internal constant WRONG_STATEMENT = 13;
    uint256 internal constant MODES = 14;

    /// @dev The EIP-2935 history storage contract and its runtime code.
    address internal constant HISTORY_STORAGE = 0x0000F90827F1C53a10cb7A02335B175320002935;
    bytes internal constant HISTORY_STORAGE_CODE =
        hex"3373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500";

    bytes internal constant PROOF = "etna proof";
    uint256 internal constant MAX_TX_BYTES = 8192;
    uint256 internal constant PPM = 1_000_000;
    uint256 internal constant MAX_BLOCK_SCORE = 10_000;

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    EtnaInbox public immutable inbox;
    SignalService public immutable signalService;
    MockLandProofVerifier public immutable verifier;
    uint64 public immutable maxBatchBlocks;
    uint64 public immutable baseFeeInGwei;
    uint64 public immutable feeDoubleThreshold;
    uint64 public immutable epochLenL2;
    EtnaRewardPool public immutable pool;
    uint128 public immutable landingRewardPerBlock;
    bytes32 public immutable committeeHash;
    address internal immutable _donor;
    address internal immutable _payee;

    /// @dev The committee of every epoch, and the registration owner of each member.
    IEtnaInbox.CommitteeMember[] internal _committee;
    address[] internal _memberOwners;
    address[] internal _owners;

    address[] internal _senders;
    address[] internal _landers;
    address[] internal _recipients;

    // ---------------------------------------------------------------
    // Ghost state
    // ---------------------------------------------------------------

    uint48 public ghostHead;
    uint48 public ghostTail;
    mapping(uint256 index => SavedInclusion) internal _saved;
    LandedBlock[] internal _landed;

    /// @dev Wei accepted by successful saves, refunded to their senders, and paid to fee
    /// recipients by successful landings.
    uint256 public valueAccepted;
    uint256 public refunded;
    uint256 public paidToRecipients;

    /// @dev Wei donated to the pool, sent by it to the Inbox as proving shares and withdrawn as
    /// credits; landing `msg.value` and landing rewards paid from the ledger.
    uint256 public donated;
    uint256 public provingSharesSent;
    uint256 public withdrawn;
    uint256 public landingValue;
    uint256 public rewardsPaid;

    /// @dev The pool's reservations, each owner's credits and each epoch's signed counts and
    /// proposer scores as the model expects them, and the number of frozen epochs (always a
    /// prefix).
    uint256 public ghostReserved;
    mapping(address owner => uint256) internal _ghostCredits;
    mapping(uint256 epoch => mapping(uint256 index => uint256)) internal _ghostSigned;
    mapping(uint256 epoch => mapping(uint256 index => uint256)) internal _ghostScores;
    uint256 public frozenEpochs;

    mapping(Property => uint256) public violations;
    mapping(Property => string) public firstViolation;

    // ---------------------------------------------------------------
    // Statistics
    // ---------------------------------------------------------------

    uint256 public saves;
    uint256 public rejectedSaves;
    uint256 public largestSave;
    uint256 public landings;
    uint256 public consumingLandings;
    uint256 public consumed;
    mapping(uint256 mode => uint256) public rejectedLandings;
    uint256 public donations;
    uint256 public withdrawals;
    uint256 public rewardedLandings;
    uint256 public settledEpochs;
    uint256 public bonusesPaid;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        EtnaInbox _inbox,
        SignalService _signalService,
        MockLandProofVerifier _verifier,
        IEtnaInbox.Config memory _config,
        bytes32 _genesisStateRoot,
        IEtnaInbox.CommitteeMember[] memory _committeeMembers
    ) {
        inbox = _inbox;
        signalService = _signalService;
        verifier = _verifier;
        maxBatchBlocks = _config.maxBatchBlocks;
        baseFeeInGwei = _config.forcedInclusionFeeInGwei;
        feeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;
        epochLenL2 = _inbox.activation().epochLenL2;
        pool = EtnaRewardPool(payable(_config.rewardPool));
        landingRewardPerBlock = _config.landingRewardPerBlock;
        committeeHash = keccak256(abi.encode(_committeeMembers));
        for (uint256 i; i < _committeeMembers.length; ++i) {
            IEtnaInbox.CommitteeMember memory member = _committeeMembers[i];
            _committee.push(member);
            address owner = IEtnaStakingRegistry(_config.stakingRegistry)
                .registrationOwnerOf(member.bondId, member.activeFromL1);
            _memberOwners.push(owner);
            if (owner != address(0) && !_isOwner(owner)) _owners.push(owner);
        }
        _donor = vm.addr(0xe7ad0e);
        _payee = vm.addr(0xe7a9ee);
        vm.deal(_donor, 1_000_000 ether);

        for (uint256 i; i < 3; ++i) {
            _senders.push(vm.addr(0xe7a5e0 + i));
            _recipients.push(vm.addr(0xe7a4ec + i));
            vm.deal(_senders[i], 1_000_000 ether);
        }
        for (uint256 i; i < 2; ++i) {
            _landers.push(vm.addr(0xe7a1a0 + i));
            vm.deal(_landers[i], 1_000_000 ether);
        }
        IEtnaInbox.LandedCheckpoint memory genesis = _inbox.lastCheckpoint();
        _landed.push(LandedBlock(genesis.height, genesis.blockHash, _genesisStateRoot));
    }

    // ---------------------------------------------------------------
    // Fuzzed actions
    // ---------------------------------------------------------------

    /// @notice Saves forced transaction bytes from one of three senders: empty, short, up to
    /// 8192 bytes or exactly 8192, rarely over the limit; paying the exact fee, overpaying, or
    /// about one call in eight underpaying.
    function saveForcedInclusion(
        uint256 _senderSeed,
        uint256 _lengthSeed,
        uint256 _valueSeed
    )
        external
    {
        address sender = _senders[_senderSeed % _senders.length];
        bytes memory txBytes = _txBytes(_lengthSeed);
        uint64 fee = inbox.getCurrentForcedInclusionFee();
        if (fee != _expectedFee()) {
            _violate(Property.Fees, "the fee is not base * (threshold + pending) / threshold");
        }
        uint256 required = uint256(fee) * 1 gwei;
        uint256 value = required + (_valueSeed >> 3) % 1 ether;
        bytes4 expected;
        if (_valueSeed % 8 == 1) value = required;
        if (_valueSeed % 8 == 0) {
            value = required - 1 - (_valueSeed >> 3) % required;
            expected = EtnaInbox.InsufficientFee.selector;
        }
        if (txBytes.length > MAX_TX_BYTES) expected = EtnaInbox.ForcedTransactionTooLarge.selector;
        uint256 senderBefore = sender.balance;
        uint256 inboxBefore = address(inbox).balance;

        vm.prank(sender);
        try inbox.saveForcedInclusion{ value: value }(txBytes) {
            if (expected != 0) {
                _violate(Property.Queue, "a save the model rejects was accepted");
            } else {
                _recordSave(sender, txBytes, fee, value, senderBefore, inboxBefore);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Queue, expected, reason, "saveForcedInclusion");
            ++rejectedSaves;
            (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
            if (head != ghostHead || tail != ghostTail) {
                _violate(Property.Queue, "a failed save moved the queue");
            }
            if (sender.balance != senderBefore || address(inbox).balance != inboxBefore) {
                _violate(Property.Fees, "a failed save moved ETH");
            }
        }
    }

    /// @notice Lands a batch of one to four or up to `maxBatchBlocks` blocks after the last
    /// checkpoint, consuming a random legal number of pending forced inclusions (the most
    /// allowed every third call) for one of three recipients or the lander itself, with a
    /// planted reference hash from `blockhash` or EIP-2935 and one to three blobs. About one
    /// call in three is broken in exactly one way instead.
    function land(
        uint256 _shapeSeed,
        uint256 _headSeed,
        uint256 _referenceSeed,
        uint256 _actorSeed,
        uint256 _modeSeed
    )
        external
    {
        Landing memory landing;
        landing.parent = inbox.lastCheckpoint();
        (landing.head, landing.tail) = inbox.getForcedInclusionState();
        landing.mode = _pickMode(_modeSeed, landing.head, landing.tail);

        uint256 blocks = _shapeSeed % 2 == 0
            ? 1 + (_shapeSeed >> 1) % 4
            : 1 + (_shapeSeed >> 1) % maxBatchBlocks;
        if (landing.mode == HEAD_PAST_BLOCKS) {
            blocks = 1 + (_shapeSeed >> 1) % (landing.tail - landing.head - 1);
        }
        landing.input.lastHeight = landing.parent.height + uint64(blocks);
        landing.input.lastBlockHash = keccak256(abi.encode("etna l2 block", _shapeSeed));
        landing.input.lastStateRoot = keccak256(abi.encode("etna l2 state", _shapeSeed));
        uint256 maxHead = _min(landing.tail, landing.head + blocks);
        landing.input.forcedInclusionHead = uint48(
            _headSeed % 3 == 0
                ? maxHead
                : landing.head + (_headSeed >> 2) % (maxHead - landing.head + 1)
        );
        landing.lander = _landers[_actorSeed % _landers.length];
        landing.input.feeRecipient = (_actorSeed >> 8) % 4 == 0
            ? landing.lander
            : _recipients[(_actorSeed >> 10) % _recipients.length];
        (landing.input.l1ReferenceBlockNumber, landing.referenceHash) =
            _plantReference(_referenceSeed);
        landing.blobHashes = _blobHashes(1 + (_actorSeed >> 16) % 3, _actorSeed);
        landing.countSeed = uint256(keccak256(abi.encode(_shapeSeed, _actorSeed, _modeSeed)));
        if (landing.countSeed % 8 == 0) landing.value = (landing.countSeed >> 3) % 0.01 ether;

        _breakLanding(landing, _modeSeed >> 8);
        _shapeParticipation(landing);
        _expectStatement(landing);
        _land(landing);
    }

    /// @notice Donates up to 100 ether to the reward pool, nothing about one call in eight; the
    /// donation joins the pool's free balance.
    function donate(uint256 _seed) external {
        uint256 amount = _seed % 8 == 0 ? 0 : (_seed >> 3) % 100 ether;
        uint256 freeBefore = pool.freeBalance();
        uint256 reservedBefore = pool.reservedTotal();
        vm.prank(_donor);
        (bool success,) = address(pool).call{ value: amount }("");
        if (!success) {
            _violate(Property.Rewards, "the pool refused a donation");
            return;
        }
        if (pool.freeBalance() != freeBefore + amount || pool.reservedTotal() != reservedBefore) {
            _violate(Property.Rewards, "a donation did not join the free balance");
        }
        donated += amount;
        ++donations;
    }

    /// @notice Withdraws one registration owner's credits to a fixed payee.
    function withdrawRewards(uint256 _seed) external {
        if (_owners.length == 0) return;
        address owner = _owners[_seed % _owners.length];
        uint256 credits = _ghostCredits[owner];
        uint256 payeeBefore = _payee.balance;
        uint256 poolBefore = address(pool).balance;
        vm.prank(owner);
        try pool.withdrawRewards(_payee) returns (uint256 amount) {
            if (
                amount != credits || pool.creditsOf(owner) != 0
                    || _payee.balance != payeeBefore + amount
                    || address(pool).balance + amount != poolBefore || credits > ghostReserved
            ) {
                _violate(Property.Rewards, "a withdrawal paid other than the owner's credits");
                return;
            }
            _ghostCredits[owner] = 0;
            ghostReserved -= amount;
            withdrawn += amount;
            if (amount != 0) ++withdrawals;
        } catch (bytes memory reason) {
            _violate(
                Property.Rewards, string.concat("withdrawRewards reverted: ", vm.toString(reason))
            );
        }
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

    function savedAt(uint256 _index) external view returns (SavedInclusion memory) {
        return _saved[_index];
    }

    function landedBlocks() external view returns (LandedBlock[] memory) {
        return _landed;
    }

    function owners() external view returns (address[] memory) {
        return _owners;
    }

    // ---------------------------------------------------------------
    // Saves
    // ---------------------------------------------------------------

    function _recordSave(
        address _sender,
        bytes memory _txBytes,
        uint64 _fee,
        uint256 _value,
        uint256 _senderBefore,
        uint256 _inboxBefore
    )
        internal
    {
        uint48 index = ghostTail;
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        if (head != ghostHead || tail != index + 1) {
            _violate(Property.Queue, "a save did not append exactly one entry");
        }
        SavedInclusion memory saved = SavedInclusion({
            txHash: keccak256(_txBytes),
            timestamp: uint48(block.timestamp),
            l1Block: uint64(block.number),
            feeInGwei: _fee
        });
        IEtnaInbox.ForcedInclusion[] memory stored = inbox.getForcedInclusions(index, 1);
        if (
            stored.length != 1 || stored[0].txHash != saved.txHash
                || stored[0].timestamp != saved.timestamp || stored[0].l1Block != saved.l1Block
                || stored[0].feeInGwei != saved.feeInGwei
        ) {
            _violate(Property.Queue, "the saved entry differs from the submission");
        }

        uint256 required = uint256(_fee) * 1 gwei;
        uint256 refund = _sender.balance + _value - _senderBefore;
        if (refund != _value - required) {
            _violate(Property.Fees, "the sender was refunded other than the excess");
        }
        if (address(inbox).balance != _inboxBefore + required) {
            _violate(Property.Fees, "the Inbox kept other than the fee");
        }

        _saved[index] = saved;
        ghostTail = index + 1;
        valueAccepted += _value;
        refunded += refund;
        ++saves;
        if (_txBytes.length > largestSave) largestSave = _txBytes.length;
    }

    /// @dev `baseFee * (threshold + pending) / threshold`, capped at `type(uint64).max`.
    function _expectedFee() internal view returns (uint64) {
        uint256 pending = uint256(ghostTail) - ghostHead;
        uint256 fee =
            uint256(baseFeeInGwei) * (uint256(feeDoubleThreshold) + pending) / feeDoubleThreshold;
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

    /// @dev Two calls in three are valid. A break that the queue cannot express falls back to a
    /// head past the tail.
    function _pickMode(uint256 _seed, uint48 _head, uint48 _tail) internal pure returns (uint256) {
        if (_seed % 3 != 0) return VALID;
        uint256 mode = 1 + (_seed >> 2) % (MODES - 1);
        if (mode == HEAD_BEHIND && _head == 0) return HEAD_PAST_TAIL;
        if (mode == HEAD_PAST_BLOCKS && _tail - _head < 2) return HEAD_PAST_TAIL;
        return mode;
    }

    /// @dev Breaks the landing in the way its mode names and sets the expected custom error.
    function _breakLanding(Landing memory _landing, uint256 _seed) internal {
        uint256 mode = _landing.mode;
        IEtnaInbox.LandInput memory input = _landing.input;
        if (mode == NO_PROGRESS) {
            input.lastHeight =
                _landing.parent.height - uint64(_seed % (uint256(_landing.parent.height) + 1));
            _landing.expectedError = EtnaInbox.NoProgress.selector;
        } else if (mode == TOO_MANY_BLOCKS) {
            input.lastHeight = _landing.parent.height + maxBatchBlocks + 1 + uint64(_seed % 8);
            _landing.expectedError = EtnaInbox.BatchTooLarge.selector;
        } else if (mode == ZERO_RECIPIENT) {
            input.feeRecipient = address(0);
            _landing.expectedError = EtnaInbox.ZeroFeeRecipient.selector;
        } else if (mode == HEAD_BEHIND) {
            input.forcedInclusionHead = uint48(_seed % _landing.head);
            _landing.expectedError = EtnaInbox.InvalidForcedInclusionHead.selector;
        } else if (mode == HEAD_PAST_TAIL) {
            input.forcedInclusionHead = _landing.tail + 1 + uint48(_seed % 4);
            _landing.expectedError = EtnaInbox.InvalidForcedInclusionHead.selector;
        } else if (mode == HEAD_PAST_BLOCKS) {
            // `land` chose fewer blocks than pending entries; consume more than one per block.
            uint256 blocks = input.lastHeight - _landing.parent.height;
            input.forcedInclusionHead = uint48(
                _landing.head + blocks + 1 + _seed % (_landing.tail - _landing.head - blocks)
            );
            _landing.expectedError = EtnaInbox.InvalidForcedInclusionHead.selector;
        } else if (mode == FUTURE_REFERENCE) {
            input.l1ReferenceBlockNumber = uint64(block.number + _seed % 3);
            _landing.expectedError = EtnaInbox.AnchorUnavailable.selector;
        } else if (mode == ZERO_REFERENCE_HASH) {
            input.l1ReferenceBlockNumber = uint64(block.number - 1 - _seed % 256);
            vm.setBlockhash(input.l1ReferenceBlockNumber, bytes32(0));
            _landing.expectedError = EtnaInbox.AnchorUnavailable.selector;
        } else if (mode == EXPIRED_REFERENCE) {
            input.l1ReferenceBlockNumber = uint64(block.number - 8192 - _seed % 64);
            _landing.expectedError = EtnaInbox.AnchorUnavailable.selector;
        } else if (mode == NO_BLOBS) {
            _landing.blobHashes = new bytes32[](0);
            _landing.expectedError = EtnaInbox.BlobsRequired.selector;
        } else if (mode == ZERO_CHECKPOINT_HASH) {
            if (_seed % 2 == 0) input.lastBlockHash = 0;
            else input.lastStateRoot = 0;
            _landing.expectedError = SignalService.SS_INVALID_CHECKPOINT.selector;
        } else if (mode == REJECTED_PROOF || mode == WRONG_STATEMENT) {
            _landing.expectedError = MockLandProofVerifier.ProofRejected.selector;
        }
    }

    /// @dev The participation of the batch `(parent, lastHeight]`: one part per epoch of its
    /// commit range `[max(parent, 1), lastHeight - 1]`, each member counting the range's heights
    /// in that epoch or, about one member in two, fewer, and scoring a random part of what the
    /// earlier members left of the bound, 10,000 per height (a quarter of the parts spend all of
    /// it); and the committee once per epoch whose last height the range reaches. Both stay
    /// empty when the range is empty.
    function _shapeParticipation(Landing memory _landing) internal view {
        uint256 first = _max(_landing.parent.height, 1);
        uint256 lastHeight = _landing.input.lastHeight;
        if (lastHeight == 0 || first > lastHeight - 1) return;
        uint256 last = lastHeight - 1;
        uint256 epochLen = epochLenL2;
        uint256 firstEpoch = (first - 1) / epochLen;
        uint256 parts = (last - 1) / epochLen - firstEpoch + 1;
        IEtnaInbox.CommitteeMember[] memory committee = _committee;

        _landing.participation = new IEtnaInbox.EpochParticipation[](parts);
        for (uint256 k; k < parts; ++k) {
            uint256 epoch = firstEpoch + k;
            uint256 heights =
                _min(last, (epoch + 1) * epochLen) - _max(first, epoch * epochLen + 1) + 1;
            uint32[] memory counts = new uint32[](committee.length);
            uint32[] memory scores = new uint32[](committee.length);
            uint256 budget = heights * MAX_BLOCK_SCORE;
            for (uint256 i; i < counts.length; ++i) {
                uint256 r = uint256(keccak256(abi.encode(_landing.countSeed, epoch, i)));
                counts[i] = uint32(r % 2 == 0 ? heights : (r >> 1) % (heights + 1));
                uint256 score = (r >> 128) % (budget + 1);
                scores[i] = uint32(score);
                budget -= score;
            }
            // About one part in four spends the whole bound, as when every block's last commit
            // carries the whole committee.
            if ((_landing.countSeed >> (k % 64)) % 4 == 0) scores[0] += uint32(budget);
            _landing.participation[k] = IEtnaInbox.EpochParticipation({
                epoch: uint64(epoch),
                committeeHash: committeeHash,
                signedCounts: counts,
                proposerScores: scores
            });
        }

        uint256 complete = last / epochLen; // epochs [0, complete) end at or before `last`
        uint256 settlements = complete > firstEpoch ? complete - firstEpoch : 0;
        _landing.settlements = new IEtnaInbox.CommitteeMember[][](settlements);
        for (uint256 k; k < settlements; ++k) {
            _landing.settlements[k] = committee;
        }
    }

    /// @dev Makes the verifier accept exactly the statement the handler derives from the stored
    /// parent, generation and queue head, so a valid landing that verifies anything else fails;
    /// or makes it reject, for the two proof modes.
    function _expectStatement(Landing memory _landing) internal {
        bytes32 statementHash = inbox.hashLandStatement(
            inbox.recoveryGeneration(),
            _landing.parent.height,
            _landing.parent.blockHash,
            _landing.head,
            _landing.input,
            _landing.participation,
            _landing.referenceHash,
            _landing.blobHashes
        );
        if (_landing.mode == WRONG_STATEMENT) statementHash = keccak256(abi.encode(statementHash));
        verifier.setExpectedStatementHash(statementHash);
        verifier.setRejects(_landing.mode == REJECTED_PROOF);
    }

    function _land(Landing memory _landing) internal {
        Balances memory before = _balances(_landing);
        vm.blobhashes(_landing.blobHashes);
        vm.prank(_landing.lander);
        try inbox.land{ value: _landing.value }(
            _landing.input, _landing.participation, _landing.settlements, PROOF
        ) {
            if (_landing.expectedError != 0) {
                _violate(Property.Checkpoint, "a landing the model rejects was accepted");
            } else {
                _recordLanding(_landing, before);
            }
        } catch (bytes memory reason) {
            _checkRevert(Property.Checkpoint, _landing.expectedError, reason, "land");
            _checkNothingLanded(_landing, before);
        }
        verifier.setRejects(false);
        verifier.setExpectedStatementHash(0);
    }

    function _recordLanding(Landing memory _landing, Balances memory _before) internal {
        IEtnaInbox.LandInput memory input = _landing.input;
        IEtnaInbox.LandedCheckpoint memory checkpoint = inbox.lastCheckpoint();
        if (
            checkpoint.height != input.lastHeight || checkpoint.blockHash != input.lastBlockHash
                || checkpoint.height <= _landing.parent.height
        ) {
            _violate(Property.Checkpoint, "the checkpoint is not the landed block");
        }
        try signalService.getCheckpoint(uint48(input.lastHeight)) returns (
            ICheckpointStore.Checkpoint memory saved
        ) {
            if (saved.blockHash != input.lastBlockHash || saved.stateRoot != input.lastStateRoot) {
                _violate(Property.Checkpoint, "the SignalService holds another checkpoint");
            }
        } catch {
            _violate(Property.Checkpoint, "the SignalService lacks the landed checkpoint");
        }

        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        if (head != input.forcedInclusionHead || tail != _landing.tail) {
            _violate(Property.Queue, "the head is not the batch's forced inclusion head");
        }
        uint256 fees;
        for (uint256 i = _landing.head; i < input.forcedInclusionHead; ++i) {
            fees += uint256(_saved[i].feeInGwei) * 1 gwei;
        }
        uint256 provingShares = _recordParticipation(_landing, _before.pool);
        uint256 funded = _before.ledger + provingShares + _landing.value;
        uint256 reward = _min(
            uint256(landingRewardPerBlock) * (input.lastHeight - _landing.parent.height), funded
        );
        Balances memory afterwards = _balances(_landing);
        if (afterwards.inbox + fees + reward != _before.inbox + provingShares + _landing.value) {
            _violate(Property.Fees, "the Inbox paid out other than the consumed fees and reward");
        }
        if (afterwards.ledger != funded - reward) {
            _violate(Property.Rewards, "the ledger is not its funding less the landing reward");
        }
        if (afterwards.pool + provingShares != _before.pool) {
            _violate(Property.Rewards, "the pool sent other than the proving shares");
        }
        // The caller pays `msg.value`; a caller that is also the recipient nets both.
        uint256 spent = input.feeRecipient == _landing.lander ? _landing.value : 0;
        if (afterwards.recipient + spent != _before.recipient + fees + reward) {
            _violate(Property.Fees, "the fee recipient was paid other than the fees and reward");
        }
        if (
            input.feeRecipient != _landing.lander
                && afterwards.lander + _landing.value != _before.lander
        ) {
            _violate(Property.Fees, "the caller was paid instead of the fee recipient");
        }

        ghostHead = input.forcedInclusionHead;
        _landed.push(LandedBlock(input.lastHeight, input.lastBlockHash, input.lastStateRoot));
        paidToRecipients += fees;
        provingSharesSent += provingShares;
        landingValue += _landing.value;
        rewardsPaid += reward;
        ++landings;
        if (fees != 0) ++consumingLandings;
        if (reward != 0) ++rewardedLandings;
        consumed += input.forcedInclusionHead - _landing.head;
    }

    /// @dev After a failed landing: no checkpoint, queue pointer or wei moved, and the
    /// SignalService holds nothing at the batch's height.
    function _checkNothingLanded(Landing memory _landing, Balances memory _before) internal {
        ++rejectedLandings[_landing.mode];
        IEtnaInbox.LandedCheckpoint memory checkpoint = inbox.lastCheckpoint();
        if (
            checkpoint.height != _landing.parent.height
                || checkpoint.blockHash != _landing.parent.blockHash
        ) {
            _violate(Property.Checkpoint, "a failed landing moved the checkpoint");
        }
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        if (head != _landing.head || tail != _landing.tail) {
            _violate(Property.Queue, "a failed landing moved the queue");
        }
        Balances memory afterwards = _balances(_landing);
        if (
            afterwards.inbox != _before.inbox || afterwards.lander != _before.lander
                || afterwards.recipient != _before.recipient || afterwards.pool != _before.pool
                || afterwards.ledger != _before.ledger
        ) {
            _violate(Property.Fees, "a failed landing moved ETH");
        }
        if (_landing.input.lastHeight > _landing.parent.height) {
            try signalService.getCheckpoint(uint48(_landing.input.lastHeight)) {
                _violate(Property.Checkpoint, "a failed landing saved a checkpoint");
            } catch { }
        }
    }

    /// @dev Plants a non-zero hash for a past L1 block: through `blockhash` for the last 256
    /// blocks, or about one call in four through the EIP-2935 contract for up to 8191 blocks.
    function _plantReference(uint256 _seed) internal returns (uint64 number_, bytes32 hash_) {
        bool history = _seed % 4 == 0;
        uint256 age = history ? 257 + (_seed >> 2) % (8191 - 256) : 1 + (_seed >> 2) % 256;
        number_ = uint64(block.number - age);
        hash_ = keccak256(abi.encode("etna l1 block", number_, _seed));
        if (history) {
            vm.etch(HISTORY_STORAGE, HISTORY_STORAGE_CODE);
            vm.store(HISTORY_STORAGE, bytes32(uint256(number_) % 8191), hash_);
        } else {
            vm.setBlockhash(number_, hash_);
        }
    }

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
            hashes_[i] = keccak256(abi.encode("etna blob", _seed, i));
        }
    }

    function _balances(Landing memory _landing) internal view returns (Balances memory) {
        return Balances({
            inbox: address(inbox).balance,
            lander: _landing.lander.balance,
            recipient: _landing.input.feeRecipient.balance,
            pool: address(pool).balance,
            ledger: inbox.proverRewardLedger()
        });
    }

    // ---------------------------------------------------------------
    // Reward pool model
    // ---------------------------------------------------------------

    /// @dev After a successful landing: adds its counts to the model and checks the pool's
    /// counts, then freezes in order every epoch whose last commit the batch carries, starting
    /// from `_poolBefore`, and checks that no later epoch froze and the credits and reservations
    /// match. Returns the proving shares the freezes sent to the Inbox.
    function _recordParticipation(
        Landing memory _landing,
        uint256 _poolBefore
    )
        internal
        returns (uint256 provingShares_)
    {
        IEtnaInbox.EpochParticipation[] memory parts = _landing.participation;
        for (uint256 k; k < parts.length; ++k) {
            uint64 epoch = parts[k].epoch;
            uint32[] memory counts = parts[k].signedCounts;
            uint32[] memory scores = parts[k].proposerScores;
            for (uint256 i; i < counts.length; ++i) {
                _ghostSigned[epoch][i] += counts[i];
                _ghostScores[epoch][i] += scores[i];
                if (pool.signedCountOf(epoch, i) != _ghostSigned[epoch][i]) {
                    _violate(Property.Rewards, "a signed count is not the reported total");
                }
                if (pool.proposerScoreOf(epoch, i) != _ghostScores[epoch][i]) {
                    _violate(Property.Rewards, "a proposer score is not the reported total");
                }
            }
        }

        // Epoch e is complete once the batch carries the commit of height (e + 1) * epochLenL2.
        uint256 complete = (uint256(_landing.input.lastHeight) - 1) / epochLenL2;
        for (uint256 epoch = frozenEpochs; epoch < complete; ++epoch) {
            provingShares_ += _freeze(epoch, _poolBefore - provingShares_);
        }
        if (complete > frozenEpochs) frozenEpochs = complete;
        if (pool.epochRecord(uint64(complete)).frozenAtL1 != 0) {
            _violate(Property.Rewards, "an epoch froze before its last commit landed");
        }
        if (pool.reservedTotal() != ghostReserved) {
            _violate(Property.Rewards, "the pool reserves other than the credits it owes");
        }
        for (uint256 j; j < _owners.length; ++j) {
            if (pool.creditsOf(_owners[j]) != _ghostCredits[_owners[j]]) {
                _violate(Property.Rewards, "an owner's credits differ from the model");
            }
        }
    }

    /// @dev Freezes `_epoch` in the model with the pool holding `_poolBalance`: the validator and
    /// proving shares of the free balance, the validator share split into `proposerBonusPpm`
    /// bonus and the rest base, and for each member with a registration owner its base
    /// `base * weight / totalWeight` (none without weight) plus its bonus
    /// `bonus * score / max(10_000 * epochLenL2, totalScore)`, each rounded down; then checks the
    /// pool's record.
    function _freeze(uint256 _epoch, uint256 _poolBalance)
        internal
        returns (uint256 provingShare_)
    {
        uint256 free = _poolBalance - ghostReserved;
        uint256 alloc = free * pool.allocValidatorPpm() / PPM;
        provingShare_ = free * pool.allocProverPpm() / PPM;
        uint256 bonusAlloc = alloc * pool.proposerBonusPpm() / PPM;
        uint256 baseAlloc = alloc - bonusAlloc;

        uint256 totalWeight;
        uint256 totalScore;
        for (uint256 i; i < _committee.length; ++i) {
            totalWeight += _committee[i].effStake * _ghostSigned[_epoch][i];
            totalScore += _ghostScores[_epoch][i];
        }
        uint256 scoreDenominator = Math.max(MAX_BLOCK_SCORE * epochLenL2, totalScore);
        uint256 paid;
        for (uint256 i; i < _committee.length; ++i) {
            paid += _creditMember(_epoch, i, baseAlloc, bonusAlloc, totalWeight, scoreDenominator);
        }
        if (paid > alloc) _violate(Property.Rewards, "a freeze credited more than its share");
        ghostReserved += paid;

        IEtnaRewardPool.EpochRecord memory record = pool.epochRecord(uint64(_epoch));
        if (
            record.frozenAtL1 != block.number || record.committeeHash != committeeHash
                || record.alloc != alloc || record.paid != paid
                || record.provingShare != provingShare_
        ) {
            _violate(Property.Rewards, "an epoch froze other than the model");
        }
        ++settledEpochs;
    }

    /// @dev Credits member `_index` of `_epoch` in the model and returns what it credited:
    /// `_baseAlloc * weight / _totalWeight` (none without weight) plus
    /// `_bonusAlloc * score / _scoreDenominator`, each rounded down; nothing without a
    /// registration owner.
    function _creditMember(
        uint256 _epoch,
        uint256 _index,
        uint256 _baseAlloc,
        uint256 _bonusAlloc,
        uint256 _totalWeight,
        uint256 _scoreDenominator
    )
        internal
        returns (uint256 credited_)
    {
        uint256 weight = _committee[_index].effStake * _ghostSigned[_epoch][_index];
        uint256 bonus = Math.mulDiv(_bonusAlloc, _ghostScores[_epoch][_index], _scoreDenominator);
        credited_ = bonus + (weight == 0 ? 0 : Math.mulDiv(_baseAlloc, weight, _totalWeight));
        address owner = _memberOwners[_index];
        if (credited_ == 0 || owner == address(0)) return 0;
        _ghostCredits[owner] += credited_;
        bonusesPaid += bonus;
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

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
        }
    }

    function _violate(Property _property, string memory _reason) internal {
        if (violations[_property]++ != 0) return;
        string[4] memory names = ["checkpoint", "queue", "fees", "rewards"];
        firstViolation[_property] = string.concat(names[uint8(_property)], ": ", _reason);
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }

    function _isOwner(address _account) internal view returns (bool) {
        for (uint256 j; j < _owners.length; ++j) {
            if (_owners[j] == _account) return true;
        }
        return false;
    }
}
