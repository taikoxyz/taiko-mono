// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { Vm, VmSafe } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @notice Supplies deliberately controlled history-interface outcomes, not authentic L1 history.
contract LeanHistoryFixture {
    bytes32 private immutable _hash;
    uint256 private immutable _length;
    bool private immutable _success;

    /// @dev Pins the exact response bytes and call outcome for one isolated environment row.
    /// @param _value The raw history hash word.
    /// @param _size The exact returned byte length.
    /// @param _accepts Whether the raw history call returns normally.
    constructor(bytes32 _value, uint256 _size, bool _accepts) {
        _hash = _value;
        _length = _size;
        _success = _accepts;
    }

    /// @dev Returns a raw padded/truncated word, matching EIP-2935's non-ABI interface shape.
    fallback() external {
        bytes32 value = _hash;
        uint256 size = _length;
        require(_success, "history fixture rejection");
        assembly {
            mstore(0, value)
            return(0, size)
        }
    }
}

/// @notice A void, static verifier boundary that can test the actual same-proxy guard.
/// @dev This fixture makes no guest-soundness claim.
contract LeanVerifierFixture is IProofVerifier {
    EtnaInbox private immutable _inbox;
    bool private immutable _accepts;
    uint8 private immutable _mode;

    /// @dev Mode 1 attempts land, mode 2 save; both catch and assert the real guard rejection.
    /// @param _target The actual Inbox proxy to call statically.
    /// @param _allowed Whether proof verification returns normally.
    /// @param _callbackMode The selected same-proxy nested operation.
    constructor(EtnaInbox _target, bool _allowed, uint8 _callbackMode) {
        _inbox = _target;
        _accepts = _allowed;
        _mode = _callbackMode;
    }

    /// @inheritdoc IProofVerifier
    function verifyProof(uint256, bytes32, bytes calldata) external view {
        if (_mode != 0) {
            IEtnaInbox.LandInput memory input;
            bytes memory data = _mode == 1
                ? abi.encodeCall(EtnaInbox.land, (input, bytes("nested")))
                : abi.encodeCall(EtnaInbox.saveForcedInclusion, (bytes("nested")));
            (bool ok, bytes memory reason) = address(_inbox).staticcall(data);
            require(
                // Only the four-byte ABI selector is compared; returndata suffix is irrelevant.
                // forge-lint: disable-next-line(unsafe-typecast)
                !ok && bytes4(reason) == EssentialContract.REENTRANT_CALL.selector,
                "static nested guard witness"
            );
        }
        require(_accepts, ProofRejected());
    }

    error ProofRejected();
}

/// @notice Controls recipient call outcomes and records the actual nested guard result.
contract LeanRecipientFixture {
    EtnaInbox private immutable _inbox;
    bool private immutable _accepts;
    uint8 private immutable _mode;
    bytes4 public nestedError;

    /// @dev Modes 1/2 catch land/save; modes 3/4 propagate their rejection.
    /// @param _target The actual Inbox proxy to call from receipt.
    /// @param _allowed Whether the recipient accepts payment.
    /// @param _callbackMode The selected nested operation and propagation behavior.
    constructor(EtnaInbox _target, bool _allowed, uint8 _callbackMode) {
        _inbox = _target;
        _accepts = _allowed;
        _mode = _callbackMode;
    }

    /// @dev The outer payment is the only value transfer; nested calls send zero value.
    receive() external payable {
        require(_accepts, "recipient fixture rejection");
        if (_mode == 0) return;
        IEtnaInbox.LandInput memory input;
        bytes memory data = _mode == 1 || _mode == 3
            ? abi.encodeCall(EtnaInbox.land, (input, bytes("nested")))
            : abi.encodeCall(EtnaInbox.saveForcedInclusion, (bytes("nested")));
        (bool ok, bytes memory reason) = address(_inbox).call(data);
        require(
            // Only the four-byte ABI selector is compared; returndata suffix is irrelevant.
            // forge-lint: disable-next-line(unsafe-typecast)
            !ok && bytes4(reason) == EssentialContract.REENTRANT_CALL.selector,
            "recipient nested guard witness"
        );
        // The preceding exact selector assertion authenticates this four-byte prefix.
        // forge-lint: disable-next-line(unsafe-typecast)
        nestedError = bytes4(reason);
        if (_mode >= 3) {
            assembly { revert(add(reason, 32), mload(reason)) }
        }
    }
}

/// @title EtnaInboxLeanConformanceTest
/// @notice Executes canonical LAND rows through the actual EtnaInbox implementation and proxy.
/// @dev Storage seeding creates typed boundary worlds, not a proof they arose through admission.
/// Raw logs/state accesses expose tentative effects; committed log flags apply the EVM journal
/// rule to the observed call result, and are not presented as independently queried receipts.
contract EtnaInboxLeanConformanceTest is EtnaInboxTestBase {
    address private constant _HISTORY = 0x0000F90827F1C53a10cb7A02335B175320002935;
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant _GUARD_SLOT =
        0xa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721b;
    bytes32 private constant _BATCH_EVENT =
        keccak256("BatchLanded(uint64,uint64,bytes32,bytes32,uint64,bytes32,address)");
    bytes32 private constant _CONSUMED_EVENT =
        keccak256("ForcedInclusionsConsumed(uint48,uint48,uint256,address)");
    bytes32 private constant _CHECKPOINT_EVENT =
        keccak256("CheckpointSaved(uint48,bytes32,bytes32)");
    bytes32 private constant _REWARD_EVENT = keccak256(
        "BatchRewardRecorded(bytes32,address,uint256,uint64,uint64,bytes32,uint64,bytes32)"
    );

    struct Row {
        string id;
        uint64 parentHeight;
        uint64 lastHeight;
        uint48 beforeHead;
        uint48 afterHead;
        uint48 tail;
        uint64 maxBatch;
        bool active;
        bool locked;
        address recipient;
        address rewardRecipient;
        uint256 baseFeeAmount;
        bytes32 rewardSeed;
        uint64 snapshotBefore;
        uint64 activeSnapshot;
        address caller;
        uint64 referenceBlock;
        uint256 currentBlock;
        bytes32 referenceHash;
        bool historySuccess;
        uint256 historyLength;
        bytes32[] blobs;
        bytes32 lastHash;
        bytes32 lastRoot;
        bool signalAuthorized;
        bool verifierAccepts;
        bool paymentAccepts;
        string reentry;
        uint256 balance;
        uint256[] fees;
    }

    struct Observation {
        bool ok;
        bytes4 selector;
        string errorName;
        uint48 head;
        uint48 tail;
        uint64 height;
        bytes32 checkpointHash;
        bool signalPresent;
        ICheckpointStore.Checkpoint signal;
        address paidTo;
        uint256 paidWei;
        bool batch;
        bool consumed;
        uint256 rawLogCount;
        bool tentativeBatch;
        bool tentativeSignal;
        uint48 tentativeHead;
        uint64 tentativeHeight;
        bool headWrite;
        bool checkpointWrite;
        bytes4 nestedError;
        bytes preimage;
        uint64 statementDepth;
        uint256 verifierCalls;
        bytes32 rewardSlot;
        uint64 committeeSnapshot;
        uint64 tentativeCommitteeSnapshot;
        bytes32 rewardCommitment;
        bytes32 tentativeRewardCommitment;
        bytes32 actualRewardId;
        bool rewardEvent;
    }

    /// @notice Runs all rows staged by the portable adapter; prints machine-readable observations.
    function test_land_LeanCorpus() external {
        vm.pauseGasMetering();
        string memory path = vm.envOr("ETNA_LANDING_CORPUS", string(""));
        if (bytes(path).length == 0) return;
        string memory json = vm.readFile(path);
        uint256 count;
        while (vm.keyExistsJson(json, string.concat("$[", vm.toString(count), "]"))) {
            uint256 snapshot = vm.snapshotState();
            string memory key = string.concat("$[", vm.toString(count), "]");
            this.executeLeanRow(json, key);
            assertTrue(vm.revertToStateAndDelete(snapshot), "isolated row restore");
            ++count;
        }
        assertGt(count, 0, "nonempty canonical LAND corpus");
        console2.log("LAND_CASE_COUNT", count);
    }

    /// @notice Isolates instrumentation memory per row; only this harness may enter it.
    /// @dev Metering is resumed exclusively around the actual production call below. Large debug
    /// arrays are test instrumentation and must not consume the production transaction gas budget.
    /// @param _json The complete staged JSON array.
    /// @param _key The JSON path identifying this isolated row.
    function executeLeanRow(string calldata _json, string calldata _key) external {
        require(msg.sender == address(this), "self-only fixture");
        Row memory row = _readRow(_json, _key);
        _execute(row);
    }

    /// @dev Reads all frozen-schema fields explicitly; uint ranges are the adapter boundary.
    /// @param _json The complete staged JSON array.
    /// @param _key The path to the mandatory row fields.
    /// @return row_ The typed fixture row.
    function _readRow(
        string memory _json,
        string memory _key
    )
        private
        pure
        returns (Row memory row_)
    {
        require(vm.parseJsonUint(_json, string.concat(_key, ".schemaVersion")) == 1, "schema");
        row_.id = vm.parseJsonString(_json, string.concat(_key, ".id"));
        row_.parentHeight = uint64(_uint(_json, _key, "parentHeight"));
        row_.lastHeight = uint64(_uint(_json, _key, "lastHeight"));
        row_.beforeHead = uint48(_uint(_json, _key, "headBefore"));
        row_.afterHead = uint48(_uint(_json, _key, "headAfter"));
        row_.tail = uint48(_uint(_json, _key, "tail"));
        row_.maxBatch = uint64(_uint(_json, _key, "maxBatchBlocks"));
        row_.active = _bool(_json, _key, "active");
        row_.locked = _bool(_json, _key, "guardLocked");
        row_.recipient = vm.parseJsonAddress(_json, string.concat(_key, ".recipient"));
        row_.rewardRecipient = vm.parseJsonAddress(_json, string.concat(_key, ".l2RewardRecipient"));
        row_.baseFeeAmount = _uint(_json, _key, "baseFeeAmount");
        row_.rewardSeed = vm.parseJsonBytes32(_json, string.concat(_key, ".rewardSeed"));
        row_.snapshotBefore = uint64(_uint(_json, _key, "committeeSnapshotBefore"));
        row_.activeSnapshot = uint64(_uint(_json, _key, "activeCommitteeSnapshot"));
        row_.caller = vm.parseJsonAddress(_json, string.concat(_key, ".caller"));
        row_.referenceBlock = uint64(_uint(_json, _key, "reference"));
        row_.currentBlock = _uint(_json, _key, "currentBlock");
        row_.referenceHash = vm.parseJsonBytes32(_json, string.concat(_key, ".referenceHash"));
        row_.historySuccess = _bool(_json, _key, "historySuccess");
        row_.historyLength = _uint(_json, _key, "historyLength");
        row_.blobs = vm.parseJsonBytes32Array(_json, string.concat(_key, ".blobs"));
        row_.lastHash = vm.parseJsonBytes32(_json, string.concat(_key, ".lastBlockHash"));
        row_.lastRoot = vm.parseJsonBytes32(_json, string.concat(_key, ".lastStateRoot"));
        row_.signalAuthorized = _bool(_json, _key, "signalAuthorized");
        row_.verifierAccepts = _bool(_json, _key, "verifierAccepts");
        row_.paymentAccepts = _bool(_json, _key, "paymentAccepts");
        row_.reentry = vm.parseJsonString(_json, string.concat(_key, ".reentryMode"));
        row_.balance = _uint(_json, _key, "inboxBalanceWei");
        row_.fees = vm.parseJsonUintArray(_json, string.concat(_key, ".feesGwei"));
    }

    /// @dev Numeric decimal strings are parsed losslessly by Foundry, with no JavaScript hop.
    /// @param _json The staged JSON document.
    /// @param _key The containing row path.
    /// @param _field The mandatory numeric field name.
    /// @return value_ The exactly parsed unsigned value.
    function _uint(
        string memory _json,
        string memory _key,
        string memory _field
    )
        private
        pure
        returns (uint256 value_)
    {
        return vm.parseJsonUint(_json, string.concat(_key, ".", _field));
    }

    /// @dev Reads one mandatory boolean field.
    /// @param _json The staged JSON document.
    /// @param _key The containing row path.
    /// @param _field The mandatory boolean field name.
    /// @return value_ The parsed boolean value.
    function _bool(
        string memory _json,
        string memory _key,
        string memory _field
    )
        private
        pure
        returns (bool value_)
    {
        return vm.parseJsonBool(_json, string.concat(_key, ".", _field));
    }

    /// @dev Sets typed test state while preserving the production proxy and implementation code.
    /// @param _row The typed initial state and controlled external outcomes.
    function _configure(Row memory _row) private {
        vm.roll(_row.currentBlock);
        etnaConfig.maxBatchBlocks = _row.maxBatch;
        EtnaInbox implementation = new EtnaInbox(etnaConfig);
        vm.store(
            address(etnaInbox),
            _IMPLEMENTATION_SLOT,
            bytes32(uint256(uint160(address(implementation))))
        );
        vm.store(address(etnaInbox), bytes32(STATUS_SLOT), bytes32(uint256(_row.active ? 3 : 0)));
        vm.store(
            address(etnaInbox), bytes32(LAST_CHECKPOINT_SLOT), bytes32(uint256(_row.parentHeight))
        );
        vm.store(address(etnaInbox), bytes32(LAST_CHECKPOINT_SLOT + 1), genesisBlockHash);
        vm.store(
            address(etnaInbox),
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(_row.beforeHead) | (uint256(_row.tail) << 48))
        );
        for (uint256 i; i < _row.fees.length; ++i) {
            require(_row.fees[i] <= type(uint64).max, "typed fee");
            uint256 index = uint256(_row.beforeHead) + i;
            bytes32 slot = keccak256(abi.encode(index, FORCED_INCLUSION_QUEUE_SLOT));
            vm.store(address(etnaInbox), bytes32(uint256(slot) + 1), bytes32(_row.fees[i] << 112));
        }
        vm.deal(address(etnaInbox), _row.balance);
        vm.store(
            address(etnaInbox),
            bytes32(ACTIVE_COMMITTEE_SNAPSHOT_SLOT),
            bytes32(uint256(_row.snapshotBefore))
        );
        if (_row.rewardSeed != bytes32(0)) {
            vm.store(address(etnaInbox), _rewardSlot(_row), _row.rewardSeed);
        }
        if (!_row.signalAuthorized) {
            SignalService unauthorized =
                new SignalService(address(0xbad), REMOTE_SIGNAL_SERVICE, address(0));
            address serviceImplementation =
                address(uint160(uint256(vm.load(address(signalService), _IMPLEMENTATION_SLOT))));
            vm.etch(serviceImplementation, address(unauthorized).code);
        }
        LeanHistoryFixture history =
            new LeanHistoryFixture(_row.referenceHash, _row.historyLength, _row.historySuccess);
        vm.etch(_HISTORY, address(history).code);
        if (
            _row.referenceBlock < _row.currentBlock
                && _row.currentBlock - _row.referenceBlock <= 256
        ) {
            vm.setBlockhash(_row.referenceBlock, _row.referenceHash);
        }
        vm.blobhashes(_row.blobs);
        uint8 verifierMode = _same(_row.reentry, "verifier-land")
            ? 1
            : (_same(_row.reentry, "verifier-save") ? 2 : 0);
        LeanVerifierFixture verifier =
            new LeanVerifierFixture(etnaInbox, _row.verifierAccepts, verifierMode);
        vm.etch(address(landVerifier), address(verifier).code);
        uint8 recipientMode = _recipientMode(_row.reentry);
        if (_row.recipient != address(0) && (recipientMode != 0 || !_row.paymentAccepts)) {
            LeanRecipientFixture recipient =
                new LeanRecipientFixture(etnaInbox, _row.paymentAccepts, recipientMode);
            vm.etch(_row.recipient, address(recipient).code);
        }
        if (_row.locked) {
            // Seed the actual execution account's transient slot, then restore byte-identical proxy
            // runtime before calling land. No production runtime instruction is replaced in trace.
            bytes memory original = address(etnaInbox).code;
            vm.etch(address(etnaInbox), abi.encodePacked(hex"60027f", _GUARD_SLOT, hex"5d00"));
            (bool seeded,) = address(etnaInbox).call("");
            require(seeded, "transient seed");
            vm.etch(address(etnaInbox), original);
        }
    }

    /// @dev Records actual instructions, call/storage journals and executed logs around land only.
    /// @param _row The isolated case to execute and observe.
    function _execute(Row memory _row) private {
        _configure(_row);
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: _row.lastHeight,
            lastBlockHash: _row.lastHash,
            lastStateRoot: _row.lastRoot,
            l1ReferenceBlockNumber: _row.referenceBlock,
            forcedInclusionHead: _row.afterHead,
            feeRecipient: _row.recipient,
            l2RewardRecipient: _row.rewardRecipient,
            baseFeeAmount: _row.baseFeeAmount,
            activeCommitteeSnapshot: _row.activeSnapshot
        });
        vm.recordLogs();
        vm.startStateDiffRecording();
        vm.startDebugTraceRecording();
        vm.resumeGasMetering();
        vm.prank(_row.caller);
        (bool ok, bytes memory reason) = address(etnaInbox)
            .call(abi.encodeCall(EtnaInbox.land, (input, bytes("lean conformance boundary proof"))));
        vm.pauseGasMetering();
        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Observation memory o;
        o.ok = ok;
        // Deliberately extract the ABI selector; unknown/short errors fail classification below.
        // forge-lint: disable-next-line(unsafe-typecast)
        o.selector = bytes4(reason);
        o.errorName = _classify(o.selector, ok);
        (o.head, o.tail) = etnaInbox.getForcedInclusionState();
        o.height = uint64(uint256(vm.load(address(etnaInbox), bytes32(LAST_CHECKPOINT_SLOT))));
        o.checkpointHash = vm.load(address(etnaInbox), bytes32(LAST_CHECKPOINT_SLOT + 1));
        (o.signalPresent, o.signal) = _signal(_row.lastHeight);
        o.rewardSlot = _rewardSlot(_row);
        o.rewardCommitment = vm.load(address(etnaInbox), o.rewardSlot);
        o.committeeSnapshot = etnaInbox.activeCommitteeSnapshot();
        _trace(_row, o, steps, accesses, logs);
        _assertBusiness(_row, o);
        _print(_row, o);
    }

    /// @dev Captures real production SHA3 input and tentative writes even when the outer call reverts.
    /// @param _row The original typed fixture inputs.
    /// @param _observation The observation populated in memory.
    /// @param _steps The actual recorded EVM instruction steps.
    /// @param _accesses The actual call and storage journal.
    /// @param _logs The raw executed logs, including reverted-frame logs.
    function _trace(
        Row memory _row,
        Observation memory _observation,
        Vm.DebugStep[] memory _steps,
        Vm.AccountAccess[] memory _accesses,
        Vm.Log[] memory _logs
    )
        private
        view
    {
        uint256 statementCount;
        for (uint256 i; i < _steps.length; ++i) {
            Vm.DebugStep memory step = _steps[i];
            if (
                step.contractAddr == address(etnaInbox) && step.opcode == 0x20
                    && step.memoryInput.length == 672
            ) {
                ++statementCount;
                _observation.preimage = step.memoryInput;
                _observation.statementDepth = step.depth;
            }
            if (
                step.contractAddr == address(etnaInbox) && step.opcode == 0xfd
                    && step.memoryInput.length >= 4
                    && bytes4(step.memoryInput) == EssentialContract.REENTRANT_CALL.selector
            ) {
                _observation.nestedError = bytes4(step.memoryInput);
            }
        }
        require(statementCount <= 1, "unique real Inbox 672-byte SHA3");
        if (statementCount == 1) {
            bytes32[] memory words = _statementWords(_row);
            assertEq(
                _observation.preimage,
                abi.encodePacked(words),
                string.concat(_row.id, ": real statement bytes")
            );
        }
        _observation.tentativeHead = _row.beforeHead;
        _observation.tentativeHeight = _row.parentHeight;
        _observation.tentativeCommitteeSnapshot = _row.snapshotBefore;
        for (uint256 i; i < _accesses.length; ++i) {
            Vm.AccountAccess memory access = _accesses[i];
            if (
                access.account == address(landVerifier) && access.accessor == address(etnaInbox)
                    && uint256(access.kind) <= uint256(VmSafe.AccountAccessKind.StaticCall)
            ) {
                assertEq(
                    uint256(access.kind),
                    uint256(VmSafe.AccountAccessKind.StaticCall),
                    "actual void verifier STATICCALL"
                );
                ++_observation.verifierCalls;
            }
            if (
                access.kind == VmSafe.AccountAccessKind.Call
                    && access.accessor == address(etnaInbox) && access.account == _row.recipient
                    && access.value > 0 && !access.reverted
            ) {
                _observation.paidTo = access.account;
                _observation.paidWei += access.value;
            }
            for (uint256 j; j < access.storageAccesses.length; ++j) {
                Vm.StorageAccess memory write = access.storageAccesses[j];
                if (!write.isWrite || write.account != address(etnaInbox)) continue;
                if (write.slot == bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT)) {
                    _observation.headWrite = true;
                    _observation.tentativeHead = uint48(uint256(write.newValue));
                }
                if (write.slot == bytes32(LAST_CHECKPOINT_SLOT)) {
                    _observation.checkpointWrite = true;
                    _observation.tentativeHeight = uint64(uint256(write.newValue));
                }
                if (write.slot == bytes32(ACTIVE_COMMITTEE_SNAPSHOT_SLOT)) {
                    _observation.tentativeCommitteeSnapshot = uint64(uint256(write.newValue));
                }
                if (write.slot == _observation.rewardSlot) {
                    _observation.tentativeRewardCommitment = write.newValue;
                }
            }
        }
        _observation.rawLogCount = _logs.length;
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].topics.length == 0) continue;
            if (_logs[i].emitter == address(etnaInbox) && _logs[i].topics[0] == _BATCH_EVENT) {
                _observation.tentativeBatch = true;
                if (_observation.ok) {
                    assertEq(
                        _logs[i].topics[1],
                        bytes32(uint256(uint160(_row.caller))),
                        "actual indexed lander"
                    );
                    assertEq(
                        _logs[i].data,
                        abi.encode(
                            uint64(_row.parentHeight + 1),
                            _row.lastHeight,
                            _row.lastHash,
                            _row.lastRoot,
                            _row.referenceBlock,
                            keccak256(_observation.preimage)
                        ),
                        "actual batch event data"
                    );
                    _observation.batch = true;
                }
            }
            if (
                _logs[i].emitter == address(signalService)
                    && _logs[i].topics[0] == _CHECKPOINT_EVENT
            ) {
                _observation.tentativeSignal = true;
            }
            if (_logs[i].emitter == address(etnaInbox) && _logs[i].topics[0] == _REWARD_EVENT) {
                // Raw logs are in execution order: one receipt, recorded after BatchLanded.
                assertEq(_observation.actualRewardId, bytes32(0), "unique reward event");
                assertTrue(_observation.tentativeBatch, "batch event precedes reward event");
                _observation.actualRewardId = _logs[i].topics[1];
                if (_observation.ok) {
                    assertEq(
                        _logs[i].topics[2],
                        bytes32(uint256(uint160(_row.rewardRecipient))),
                        "actual indexed L2 reward recipient"
                    );
                    assertEq(
                        _logs[i].data,
                        abi.encode(
                            _row.baseFeeAmount,
                            uint64(
                                uint256(
                                    vm.load(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT))
                                )
                            ),
                            _row.parentHeight,
                            genesisBlockHash,
                            _row.lastHeight,
                            _row.lastHash
                        ),
                        "actual reward event data"
                    );
                    _observation.rewardEvent = true;
                }
            }
            if (
                _logs[i].emitter == address(etnaInbox) && _logs[i].topics[0] == _CONSUMED_EVENT
                    && _observation.ok
            ) {
                // The receipt is recorded before the fee transfer and its consumption event.
                assertTrue(_observation.rewardEvent, "reward event precedes consumption event");
                assertEq(
                    _logs[i].topics[1],
                    bytes32(uint256(uint160(_row.recipient))),
                    "actual consumed recipient"
                );
                assertEq(
                    _logs[i].data,
                    abi.encode(_row.beforeHead, _row.afterHead, _expectedFee(_row)),
                    "actual consumed interval/fee"
                );
                _observation.consumed = true;
            }
        }
        if (_observation.tentativeBatch) {
            assertEq(_observation.verifierCalls, 1, "verifier call after tentative batch");
        }
        if (!_observation.ok) {
            assertEq(_observation.paidWei, 0, "no committed transfer after outer revert");
            _observation.paidTo = address(0);
        }
    }

    /// @dev Verifies actual rollback state and emitted/transfer observations against row data.
    /// @param _row The original typed fixture inputs.
    /// @param _observation The actual business state and recorded effects.
    function _assertBusiness(Row memory _row, Observation memory _observation) private view {
        assertEq(_observation.tail, _row.tail, string.concat(_row.id, ": retained tail"));
        if (!_observation.ok) {
            assertEq(_observation.head, _row.beforeHead, string.concat(_row.id, ": rollback head"));
            assertEq(
                _observation.height,
                _row.parentHeight,
                string.concat(_row.id, ": rollback checkpoint")
            );
            assertEq(
                _observation.checkpointHash,
                genesisBlockHash,
                string.concat(_row.id, ": rollback checkpoint hash")
            );
            // Fixtures never prepopulate the requested target (genesis-height rows are excluded
            // from this particular absence assertion because the real base has block zero).
            if (_row.lastHeight != 0) {
                assertFalse(_observation.signalPresent, string.concat(_row.id, ": rollback signal"));
            }
            assertEq(
                _observation.rewardCommitment,
                _row.rewardSeed,
                string.concat(_row.id, ": rollback reward slot")
            );
            assertEq(
                _observation.committeeSnapshot,
                _row.snapshotBefore,
                string.concat(_row.id, ": rollback committee snapshot")
            );
            return;
        }
        assertTrue(_row.verifierAccepts, "successful land requires normal verifier return");
        assertEq(_row.rewardSeed, bytes32(0), "successful land requires an empty reward slot");
        assertGe(
            _row.activeSnapshot,
            _row.snapshotBefore,
            "successful land never regresses the committee snapshot"
        );
        assertLe(
            _row.activeSnapshot, _row.referenceBlock, "successful snapshot within the reference"
        );
        if (_sameEpoch(_row)) {
            assertEq(
                _row.activeSnapshot,
                _row.snapshotBefore,
                "successful same-epoch land keeps the committee snapshot"
            );
        }
        assertEq(
            _observation.committeeSnapshot,
            _row.activeSnapshot,
            "actual committed committee snapshot"
        );
        assertGt(_row.lastHeight, _row.parentHeight, "successful strict progress");
        assertLe(
            uint256(_row.lastHeight) - _row.parentHeight, _row.maxBatch, "successful batch bound"
        );
        assertLe(_row.lastHeight, type(uint48).max, "successful height width");
        assertLe(_row.beforeHead, _row.afterHead, "successful head monotonicity");
        assertLe(_row.afterHead, _row.tail, "successful head tail bound");
        assertLe(
            uint256(_row.afterHead) - _row.beforeHead,
            uint256(_row.lastHeight) - _row.parentHeight,
            "successful consumption block bound"
        );
        assertEq(_observation.head, _row.afterHead, string.concat(_row.id, ": landed head"));
        assertEq(_observation.height, _row.lastHeight, string.concat(_row.id, ": landed height"));
        assertEq(
            _observation.checkpointHash, _row.lastHash, string.concat(_row.id, ": landed hash")
        );
        assertTrue(_observation.signalPresent, "real service checkpoint");
        assertEq(_observation.signal.blockHash, _row.lastHash, "real service hash");
        assertEq(_observation.signal.stateRoot, _row.lastRoot, "real service root");
        assertTrue(_observation.batch, "committed batch event under journal rule");
        assertEq(
            _observation.consumed, _row.afterHead != _row.beforeHead, "consumption event condition"
        );
        assertEq(_observation.paidWei, _expectedFee(_row), "actual committed CALL amount");
        assertEq(
            _observation.paidTo,
            _observation.paidWei == 0 ? address(0) : _row.recipient,
            "actual committed CALL target"
        );
        assertEq(_observation.preimage.length, 672, "actual successful statement captured");
        assertTrue(_observation.rewardEvent, "committed reward event under journal rule");
        assertEq(
            _observation.actualRewardId,
            LibEtnaRewards.batchId(_receipt(_row)),
            "actual indexed reward batch id"
        );
        assertEq(
            _observation.rewardCommitment,
            LibEtnaRewards.commitment(_receipt(_row)),
            "actual committed reward commitment"
        );
    }

    /// @dev The receipt `_recordReward` builds from the seeded parent, generation and identities.
    /// @param _row The original fixture inputs.
    /// @return receipt_ The receipt for this row's landing.
    function _receipt(Row memory _row)
        private
        view
        returns (LibEtnaRewards.Receipt memory receipt_)
    {
        receipt_ = LibEtnaRewards.Receipt({
            l1ChainId: block.chainid,
            l2ChainId: L2_CHAIN_ID,
            inbox: address(etnaInbox),
            generation: uint64(
                uint256(vm.load(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT)))
            ),
            parentHeight: _row.parentHeight,
            parentHash: genesisBlockHash,
            lastHeight: _row.lastHeight,
            lastBlockHash: _row.lastHash,
            l2RewardRecipient: _row.rewardRecipient,
            baseFeeAmount: _row.baseFeeAmount
        });
    }

    /// @dev The mapping slot of this row's receipt; seeding and observation use the same slot.
    /// @param _row The original fixture inputs.
    /// @return slot_ The `rewardCommitments[batchId]` storage slot.
    function _rewardSlot(Row memory _row) private view returns (bytes32 slot_) {
        return LibEtnaRewards.receiptSlot(LibEtnaRewards.batchId(_receipt(_row)));
    }

    /// @dev Reads the concrete service rather than inferring its storage from Inbox success.
    /// @param _height The requested target height.
    /// @return present_ Whether the concrete service has this checkpoint.
    /// @return checkpoint_ The stored checkpoint, or the zero-initialized value when absent.
    function _signal(uint64 _height)
        private
        view
        returns (bool present_, ICheckpointStore.Checkpoint memory checkpoint_)
    {
        if (_height > type(uint48).max) {
            return (false, checkpoint_);
        }
        // The preceding uint48 bound makes this narrowing lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        try signalService.getCheckpoint(uint48(_height)) returns (
            ICheckpointStore.Checkpoint memory found
        ) {
            return (true, found);
        } catch {
            return (false, checkpoint_);
        }
    }

    /// @dev Whether the batch ends in its parent's epoch, from the actual activation length.
    /// @param _row The original fixture inputs.
    /// @return same_ Whether parent and last heights share an epoch.
    function _sameEpoch(Row memory _row) private view returns (bool same_) {
        uint64 length = etnaInbox.activation().epochLenL2;
        uint64 parentEpoch = _row.parentHeight == 0 ? 0 : (_row.parentHeight - 1) / length;
        return (_row.lastHeight - 1) / length == parentEpoch;
    }

    /// @dev Independently forms twenty-one field words; actual byte observation comes only from trace.
    /// @param _row The original inputs supplying the statement fields.
    /// @return words_ The twenty-one canonical words in production wire order.
    function _statementWords(Row memory _row) private view returns (bytes32[] memory words_) {
        words_ = new bytes32[](21);
        // The 18-byte ASCII domain fits in 32 bytes; zero right-padding is the wire format.
        // forge-lint: disable-next-line(unsafe-typecast)
        words_[0] = bytes32("TAIKO_ETNA_LAND_V9");
        words_[1] = bytes32(block.chainid);
        words_[2] = bytes32(uint256(L2_CHAIN_ID));
        words_[3] = bytes32(uint256(uint160(address(etnaInbox))));
        words_[4] = bytes32(uint256(uint160(address(registry))));
        words_[5] = vm.load(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT));
        words_[6] = bytes32(uint256(_row.parentHeight));
        words_[7] = genesisBlockHash;
        words_[8] = COMMITTEE_CONFIG_HASH;
        words_[9] = bytes32(uint256(_row.lastHeight));
        words_[10] = _row.lastHash;
        words_[11] = _row.lastRoot;
        words_[12] = bytes32(uint256(_row.referenceBlock));
        words_[13] = _row.referenceHash;
        uint256 count;
        while (count < _row.blobs.length && _row.blobs[count] != bytes32(0)) ++count;
        bytes32[] memory prefix = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            prefix[i] = _row.blobs[i];
        }
        words_[14] = keccak256(abi.encodePacked(prefix));
        words_[15] = bytes32(uint256(_row.beforeHead));
        words_[16] = bytes32(uint256(_row.afterHead));
        words_[17] = bytes32(uint256(uint160(_row.recipient)));
        words_[18] = bytes32(uint256(uint160(_row.rewardRecipient)));
        words_[19] = bytes32(_row.baseFeeAmount);
        words_[20] = bytes32(uint256(_row.activeSnapshot));
    }

    /// @dev Fees are relative to the seeded pre-head; missing queue entries have zero fee.
    /// @param _row The original queue interval and stored fee values.
    /// @return fee_ The interval fee converted from gwei to wei.
    function _expectedFee(Row memory _row) private pure returns (uint256 fee_) {
        for (uint256 i; i < uint256(_row.afterHead) - _row.beforeHead && i < _row.fees.length; ++i) {
            fee_ += _row.fees[i];
        }
        return fee_ * 1 gwei;
    }

    /// @dev Maps the exact observed top-level selector without hiding unknown failures.
    /// @param _selector The actual top-level error selector.
    /// @param _ok Whether the actual call returned successfully.
    /// @return error_ The frozen schema error classification.
    function _classify(bytes4 _selector, bool _ok) private pure returns (string memory error_) {
        if (_ok) return "none";
        if (_selector == EssentialContract.REENTRANT_CALL.selector) return "reentrant";
        if (_selector == EtnaInbox.EtnaNotActive.selector) return "inactive";
        if (_selector == EtnaInbox.NoProgress.selector) return "no-progress";
        if (_selector == EtnaInbox.BatchTooLarge.selector) return "batch-too-large";
        if (_selector == EtnaInbox.HeightOverflow.selector) return "height-overflow";
        if (_selector == EtnaInbox.ZeroFeeRecipient.selector) return "zero-recipient";
        if (_selector == EtnaInbox.ZeroRewardRecipient.selector) return "zero-reward-recipient";
        if (_selector == EtnaInbox.InvalidCommitteeSnapshot.selector) {
            return "invalid-committee-snapshot";
        }
        if (_selector == EtnaInbox.RewardAlreadyRecorded.selector) {
            return "reward-already-recorded";
        }
        if (_selector == EtnaInbox.InvalidForcedInclusionHead.selector) return "invalid-head";
        if (_selector == EtnaInbox.AnchorUnavailable.selector) return "anchor-unavailable";
        if (_selector == EtnaInbox.BlobsRequired.selector) return "blobs-required";
        if (_selector == SignalService.SS_UNAUTHORIZED.selector) return "signal-unauthorized";
        if (_selector == SignalService.SS_INVALID_CHECKPOINT.selector) return "signal-invalid";
        if (_selector == LeanVerifierFixture.ProofRejected.selector) return "verifier";
        if (_selector == LibAddress.ETH_TRANSFER_FAILED.selector) return "payment";
        revert("unclassified actual LAND selector");
    }

    /// @dev Emits canonical scalar observations plus actual encoding context for independent Lean.
    /// @param _row The original fixture inputs and identifier.
    /// @param _observation The actual observations to serialize.
    function _print(Row memory _row, Observation memory _observation) private {
        string memory k = string.concat("land-", _row.id);
        vm.serializeUint(k, "schemaVersion", 1);
        vm.serializeString(k, "id", _row.id);
        vm.serializeString(k, "status", _observation.ok ? "ok" : "revert");
        vm.serializeString(k, "error", _observation.errorName);
        vm.serializeUint(k, "head", _observation.head);
        vm.serializeUint(k, "tail", _observation.tail);
        vm.serializeUint(k, "checkpointHeight", _observation.height);
        vm.serializeBytes32(k, "checkpointHash", _observation.checkpointHash);
        vm.serializeBool(k, "signalPresent", _observation.signalPresent);
        vm.serializeUint(
            k, "signalHeight", _observation.signalPresent ? _observation.signal.blockNumber : 0
        );
        vm.serializeBytes32(k, "signalHash", _observation.signal.blockHash);
        vm.serializeBytes32(k, "signalRoot", _observation.signal.stateRoot);
        vm.serializeAddress(k, "paidTo", _observation.paidTo);
        vm.serializeString(k, "paidWei", vm.toString(_observation.paidWei));
        vm.serializeBool(k, "batchEvent", _observation.batch);
        vm.serializeBool(k, "consumedEvent", _observation.consumed);
        vm.serializeUint(k, "committeeSnapshot", _observation.committeeSnapshot);
        vm.serializeUint(k, "tentativeCommitteeSnapshot", _observation.tentativeCommitteeSnapshot);
        vm.serializeBool(k, "rewardEvent", _observation.rewardEvent);
        vm.serializeBytes32(k, "rewardCommitment", _observation.rewardCommitment);
        vm.serializeBytes32(k, "tentativeRewardCommitment", _observation.tentativeRewardCommitment);
        vm.serializeBytes32(k, "actualRewardId", _observation.actualRewardId);
        vm.serializeUint(k, "tentativeHead", _observation.tentativeHead);
        vm.serializeUint(k, "tentativeCheckpointHeight", _observation.tentativeHeight);
        vm.serializeBool(k, "headWriteObserved", _observation.headWrite);
        vm.serializeBool(k, "checkpointWriteObserved", _observation.checkpointWrite);
        vm.serializeBool(k, "tentativeSignalPresent", _observation.tentativeSignal);
        vm.serializeBool(k, "tentativeBatchEvent", _observation.tentativeBatch);
        vm.serializeString(k, "failureStage", _observation.errorName);
        vm.serializeBytes(k, "rawSelector", abi.encodePacked(_observation.selector));
        vm.serializeBytes(k, "nestedError", abi.encodePacked(_observation.nestedError));
        vm.serializeUint(k, "rawLogCount", _observation.rawLogCount);
        vm.serializeUint(k, "statementDepth", _observation.statementDepth);
        vm.serializeUint(k, "verifierStaticCalls", _observation.verifierCalls);
        vm.serializeString(k, "committedLogEvidence", "call-result-plus-EVM-journal-law");
        string memory contextJson;
        if (_observation.preimage.length != 0) {
            vm.serializeBytes32(k, "statementWords", _statementWords(_row));
            vm.serializeBytes(k, "actualPreimage", _observation.preimage);
            vm.serializeBytes32(k, "actualDigest", keccak256(_observation.preimage));
        }
        {
            string memory contextKey = string.concat(k, "-context");
            vm.serializeUint(contextKey, "chainid", block.chainid);
            vm.serializeUint(contextKey, "l2chainid", L2_CHAIN_ID);
            vm.serializeAddress(contextKey, "proxy", address(etnaInbox));
            vm.serializeAddress(contextKey, "registry", address(registry));
            vm.serializeUint(
                contextKey,
                "generation",
                uint256(vm.load(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT)))
            );
            vm.serializeBytes32(contextKey, "parentHash", genesisBlockHash);
            vm.serializeBytes32(contextKey, "config", COMMITTEE_CONFIG_HASH);
            vm.serializeUint(contextKey, "epochLenL2", etnaInbox.activation().epochLenL2);
            contextJson = vm.serializeAddress(contextKey, "recipient", _row.recipient);
        }
        string memory output = vm.serializeString(
            k,
            "fixtureBoundary",
            "typed-storage-seeded-world;real-Inbox-proxy;real-SignalService;controlled-verifier-history-recipient"
        );
        if (bytes(contextJson).length != 0) {
            bytes memory prefix = bytes(output);
            assembly { mstore(prefix, sub(mload(prefix), 1)) }
            output = string.concat(string(prefix), ',"context":', contextJson, "}");
        }
        console2.log(string.concat("LAND_OBSERVATION ", output));
    }

    /// @dev Returns the callback behavior encoded by the frozen schema enum.
    /// @param _mode The frozen recipient callback enum string.
    /// @return mode_ The numeric recipient fixture behavior.
    function _recipientMode(string memory _mode) private pure returns (uint8 mode_) {
        if (_same(_mode, "land-caught")) return 1;
        if (_same(_mode, "save-caught")) return 2;
        if (_same(_mode, "land-uncaught")) return 3;
        if (_same(_mode, "save-uncaught")) return 4;
        return 0;
    }

    /// @dev Compares a schema enum string.
    /// @param _a The first enum string.
    /// @param _b The second enum string.
    /// @return equal_ Whether the strings have matching hashes.
    function _same(string memory _a, string memory _b) private pure returns (bool equal_) {
        return keccak256(bytes(_a)) == keccak256(bytes(_b));
    }
}
