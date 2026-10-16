// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "../EtnaInboxTestBase.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title EtnaInboxHandler
/// @notice Independently models checkpoint progress, forced-inclusion escrow and immutable receipts.
/// @dev Each attempted landing is valid or violates one named guard. Reverts must preserve all state.
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
        bytes32[] blobHashes;
        bytes32 referenceHash;
        address lander;
        uint256 mode;
        bytes4 expectedError;
        IEtnaInbox.LandedCheckpoint parent;
        uint48 head;
        uint48 tail;
    }

    /// @dev ETH balances touched by a landing.
    struct Balances {
        uint256 inbox;
        uint256 lander;
        uint256 recipient;
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

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    EtnaInbox public immutable inbox;
    SignalService public immutable signalService;
    MockLandProofVerifier public immutable verifier;
    uint64 public immutable maxBatchBlocks;
    uint64 public immutable baseFeeInGwei;
    uint64 public immutable feeDoubleThreshold;

    address[] internal _senders;
    address[] internal _landers;
    address[] internal _recipients;

    // ---------------------------------------------------------------
    // Ghost state
    // ---------------------------------------------------------------

    mapping(bytes32 batchId => bytes32 commitment) public ghostReceipts;
    bytes32[] public receiptIds;
    uint48 public ghostHead;
    uint48 public ghostTail;
    mapping(uint256 index => SavedInclusion) internal _saved;
    LandedBlock[] internal _landed;

    /// @dev Wei accepted by successful saves, refunded to their senders, and paid to fee
    /// recipients by successful landings.
    uint256 public valueAccepted;
    uint256 public refunded;
    uint256 public paidToRecipients;

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

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        EtnaInbox _inbox,
        SignalService _signalService,
        MockLandProofVerifier _verifier,
        IEtnaInbox.Config memory _config,
        bytes32 _genesisStateRoot
    ) {
        inbox = _inbox;
        signalService = _signalService;
        verifier = _verifier;
        maxBatchBlocks = _config.maxBatchBlocks;
        baseFeeInGwei = _config.forcedInclusionFeeInGwei;
        feeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;

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
        landing.input.l2RewardRecipient = _recipients[(_actorSeed >> 20) % _recipients.length];
        landing.input.baseFeeAmount = _shapeSeed;

        _breakLanding(landing, _modeSeed >> 8);
        _expectStatement(landing);
        _land(landing);
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
        try inbox.land(_landing.input, PROOF) {
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
        Balances memory afterwards = _balances(_landing);
        if (afterwards.inbox + fees != _before.inbox) {
            _violate(Property.Fees, "the Inbox paid other than consumed fees");
        }
        if (afterwards.recipient != _before.recipient + fees) {
            _violate(Property.Fees, "fees went to another recipient");
        }
        if (input.feeRecipient != _landing.lander && afterwards.lander != _before.lander) {
            _violate(Property.Fees, "the caller received fees");
        }
        (bytes32 id, bytes32 commitment) = _receipt(_landing);
        if (ghostReceipts[id] != 0 || inbox.rewardCommitments(id) != commitment) {
            _violate(Property.Rewards, "receipt differs or was overwritten");
        }
        ghostReceipts[id] = commitment;
        receiptIds.push(id);
        ghostHead = input.forcedInclusionHead;
        _landed.push(LandedBlock(input.lastHeight, input.lastBlockHash, input.lastStateRoot));
        paidToRecipients += fees;
        ++landings;
        if (fees != 0) ++consumingLandings;
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
                || afterwards.recipient != _before.recipient
        ) {
            _violate(Property.Fees, "a failed landing moved ETH");
        }
        (bytes32 id,) = _receipt(_landing);
        if (inbox.rewardCommitments(id) != ghostReceipts[id]) {
            _violate(Property.Rewards, "failed landing recorded a receipt");
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
            recipient: _landing.input.feeRecipient.balance
        });
    }

    // ---------------------------------------------------------------
    // Receipt model
    // ---------------------------------------------------------------

    /// @dev Independently commits actual chain identity and the checkpoint before the attempt.
    function _receipt(Landing memory _landing) internal view returns (bytes32 id_, bytes32 hash_) {
        IEtnaInbox.LandInput memory input = _landing.input;
        id_ = keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_BATCH_V1"),
                block.chainid,
                uint64(167_001),
                address(inbox),
                inbox.recoveryGeneration(),
                _landing.parent.height,
                _landing.parent.blockHash,
                input.lastHeight,
                input.lastBlockHash
            )
        );
        hash_ = keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_RECEIPT_V1"),
                id_,
                input.l2RewardRecipient,
                input.baseFeeAmount
            )
        );
    }

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
}
