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
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @notice Supplies deliberately controlled history-interface outcomes, not authentic L1 history.
contract LeanHistoryFixture {
    bytes32 private immutable _hash;
    uint256 private immutable _length;
    bool private immutable _success;

    /// @dev Pins the exact response bytes and call outcome for one isolated environment row.
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
    function executeLeanRow(string calldata _json, string calldata _key) external {
        require(msg.sender == address(this), "self-only fixture");
        Row memory row = _readRow(_json, _key);
        _execute(row);
    }

    /// @dev Reads all frozen-schema fields explicitly; uint ranges are the adapter boundary.
    function _readRow(string memory _json, string memory _key) private pure returns (Row memory r) {
        require(vm.parseJsonUint(_json, string.concat(_key, ".schemaVersion")) == 1, "schema");
        r.id = vm.parseJsonString(_json, string.concat(_key, ".id"));
        r.parentHeight = uint64(_uint(_json, _key, "parentHeight"));
        r.lastHeight = uint64(_uint(_json, _key, "lastHeight"));
        r.beforeHead = uint48(_uint(_json, _key, "headBefore"));
        r.afterHead = uint48(_uint(_json, _key, "headAfter"));
        r.tail = uint48(_uint(_json, _key, "tail"));
        r.maxBatch = uint64(_uint(_json, _key, "maxBatchBlocks"));
        r.active = _bool(_json, _key, "active");
        r.locked = _bool(_json, _key, "guardLocked");
        r.recipient = vm.parseJsonAddress(_json, string.concat(_key, ".recipient"));
        r.caller = vm.parseJsonAddress(_json, string.concat(_key, ".caller"));
        r.referenceBlock = uint64(_uint(_json, _key, "reference"));
        r.currentBlock = _uint(_json, _key, "currentBlock");
        r.referenceHash = vm.parseJsonBytes32(_json, string.concat(_key, ".referenceHash"));
        r.historySuccess = _bool(_json, _key, "historySuccess");
        r.historyLength = _uint(_json, _key, "historyLength");
        r.blobs = vm.parseJsonBytes32Array(_json, string.concat(_key, ".blobs"));
        r.lastHash = vm.parseJsonBytes32(_json, string.concat(_key, ".lastBlockHash"));
        r.lastRoot = vm.parseJsonBytes32(_json, string.concat(_key, ".lastStateRoot"));
        r.signalAuthorized = _bool(_json, _key, "signalAuthorized");
        r.verifierAccepts = _bool(_json, _key, "verifierAccepts");
        r.paymentAccepts = _bool(_json, _key, "paymentAccepts");
        r.reentry = vm.parseJsonString(_json, string.concat(_key, ".reentryMode"));
        r.balance = _uint(_json, _key, "inboxBalanceWei");
        r.fees = vm.parseJsonUintArray(_json, string.concat(_key, ".feesGwei"));
    }

    /// @dev Numeric decimal strings are parsed losslessly by Foundry, with no JavaScript hop.
    function _uint(
        string memory _json,
        string memory _key,
        string memory _field
    )
        private
        pure
        returns (uint256)
    {
        return vm.parseJsonUint(_json, string.concat(_key, ".", _field));
    }

    /// @dev Reads one mandatory boolean field.
    function _bool(
        string memory _json,
        string memory _key,
        string memory _field
    )
        private
        pure
        returns (bool)
    {
        return vm.parseJsonBool(_json, string.concat(_key, ".", _field));
    }

    /// @dev Sets typed test state while preserving the production proxy and implementation code.
    function _configure(Row memory r) private {
        vm.roll(r.currentBlock);
        etnaConfig.maxBatchBlocks = r.maxBatch;
        EtnaInbox implementation = new EtnaInbox(etnaConfig);
        vm.store(
            address(etnaInbox),
            _IMPLEMENTATION_SLOT,
            bytes32(uint256(uint160(address(implementation))))
        );
        vm.store(address(etnaInbox), bytes32(STATUS_SLOT), bytes32(uint256(r.active ? 3 : 0)));
        vm.store(
            address(etnaInbox), bytes32(LAST_CHECKPOINT_SLOT), bytes32(uint256(r.parentHeight))
        );
        vm.store(address(etnaInbox), bytes32(LAST_CHECKPOINT_SLOT + 1), genesisBlockHash);
        vm.store(
            address(etnaInbox),
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(r.beforeHead) | (uint256(r.tail) << 48))
        );
        for (uint256 i; i < r.fees.length; ++i) {
            require(r.fees[i] <= type(uint64).max, "typed fee");
            uint256 index = uint256(r.beforeHead) + i;
            bytes32 slot = keccak256(abi.encode(index, FORCED_INCLUSION_QUEUE_SLOT));
            vm.store(address(etnaInbox), bytes32(uint256(slot) + 1), bytes32(r.fees[i] << 112));
        }
        vm.deal(address(etnaInbox), r.balance);
        if (!r.signalAuthorized) {
            SignalService unauthorized =
                new SignalService(address(0xbad), REMOTE_SIGNAL_SERVICE, address(0));
            address serviceImplementation =
                address(uint160(uint256(vm.load(address(signalService), _IMPLEMENTATION_SLOT))));
            vm.etch(serviceImplementation, address(unauthorized).code);
        }
        LeanHistoryFixture history =
            new LeanHistoryFixture(r.referenceHash, r.historyLength, r.historySuccess);
        vm.etch(_HISTORY, address(history).code);
        if (r.referenceBlock < r.currentBlock && r.currentBlock - r.referenceBlock <= 256) {
            vm.setBlockhash(r.referenceBlock, r.referenceHash);
        }
        vm.blobhashes(r.blobs);
        uint8 verifierMode =
            _same(r.reentry, "verifier-land") ? 1 : (_same(r.reentry, "verifier-save") ? 2 : 0);
        LeanVerifierFixture verifier =
            new LeanVerifierFixture(etnaInbox, r.verifierAccepts, verifierMode);
        vm.etch(address(landVerifier), address(verifier).code);
        uint8 recipientMode = _recipientMode(r.reentry);
        if (r.recipient != address(0) && (recipientMode != 0 || !r.paymentAccepts)) {
            LeanRecipientFixture recipient =
                new LeanRecipientFixture(etnaInbox, r.paymentAccepts, recipientMode);
            vm.etch(r.recipient, address(recipient).code);
        }
        if (r.locked) {
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
    function _execute(Row memory r) private {
        _configure(r);
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: r.lastHeight,
            lastBlockHash: r.lastHash,
            lastStateRoot: r.lastRoot,
            l1ReferenceBlockNumber: r.referenceBlock,
            forcedInclusionHead: r.afterHead,
            feeRecipient: r.recipient
        });
        vm.recordLogs();
        vm.startStateDiffRecording();
        vm.startDebugTraceRecording();
        vm.resumeGasMetering();
        vm.prank(r.caller);
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
        (o.signalPresent, o.signal) = _signal(r.lastHeight);
        _trace(r, o, steps, accesses, logs);
        _assertBusiness(r, o);
        _print(r, o);
    }

    /// @dev Captures real production SHA3 input and tentative writes even when the outer call reverts.
    function _trace(
        Row memory r,
        Observation memory o,
        Vm.DebugStep[] memory steps,
        Vm.AccountAccess[] memory accesses,
        Vm.Log[] memory logs
    )
        private
        view
    {
        uint256 statementCount;
        for (uint256 i; i < steps.length; ++i) {
            Vm.DebugStep memory step = steps[i];
            if (
                step.contractAddr == address(etnaInbox) && step.opcode == 0x20
                    && step.memoryInput.length == 576
            ) {
                ++statementCount;
                o.preimage = step.memoryInput;
                o.statementDepth = step.depth;
            }
            if (
                step.contractAddr == address(etnaInbox) && step.opcode == 0xfd
                    && step.memoryInput.length >= 4
                    && bytes4(step.memoryInput) == EssentialContract.REENTRANT_CALL.selector
            ) {
                o.nestedError = bytes4(step.memoryInput);
            }
        }
        require(statementCount <= 1, "unique real Inbox 576-byte SHA3");
        if (statementCount == 1) {
            bytes32[] memory words = _statementWords(r);
            assertEq(
                o.preimage, abi.encodePacked(words), string.concat(r.id, ": real statement bytes")
            );
        }
        o.tentativeHead = r.beforeHead;
        o.tentativeHeight = r.parentHeight;
        for (uint256 i; i < accesses.length; ++i) {
            Vm.AccountAccess memory access = accesses[i];
            if (
                access.account == address(landVerifier) && access.accessor == address(etnaInbox)
                    && uint256(access.kind) <= uint256(VmSafe.AccountAccessKind.StaticCall)
            ) {
                assertEq(
                    uint256(access.kind),
                    uint256(VmSafe.AccountAccessKind.StaticCall),
                    "actual void verifier STATICCALL"
                );
                ++o.verifierCalls;
            }
            if (
                access.kind == VmSafe.AccountAccessKind.Call
                    && access.accessor == address(etnaInbox) && access.account == r.recipient
                    && access.value > 0 && !access.reverted
            ) {
                o.paidTo = access.account;
                o.paidWei += access.value;
            }
            for (uint256 j; j < access.storageAccesses.length; ++j) {
                Vm.StorageAccess memory write = access.storageAccesses[j];
                if (!write.isWrite || write.account != address(etnaInbox)) continue;
                if (write.slot == bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT)) {
                    o.headWrite = true;
                    o.tentativeHead = uint48(uint256(write.newValue));
                }
                if (write.slot == bytes32(LAST_CHECKPOINT_SLOT)) {
                    o.checkpointWrite = true;
                    o.tentativeHeight = uint64(uint256(write.newValue));
                }
            }
        }
        o.rawLogCount = logs.length;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            if (logs[i].emitter == address(etnaInbox) && logs[i].topics[0] == _BATCH_EVENT) {
                o.tentativeBatch = true;
                if (o.ok) {
                    assertEq(
                        logs[i].topics[1],
                        bytes32(uint256(uint160(r.caller))),
                        "actual indexed lander"
                    );
                    assertEq(
                        logs[i].data,
                        abi.encode(
                            uint64(r.parentHeight + 1),
                            r.lastHeight,
                            r.lastHash,
                            r.lastRoot,
                            r.referenceBlock,
                            keccak256(o.preimage)
                        ),
                        "actual batch event data"
                    );
                    o.batch = true;
                }
            }
            if (logs[i].emitter == address(signalService) && logs[i].topics[0] == _CHECKPOINT_EVENT)
            {
                o.tentativeSignal = true;
            }
            if (
                logs[i].emitter == address(etnaInbox) && logs[i].topics[0] == _CONSUMED_EVENT
                    && o.ok
            ) {
                assertEq(
                    logs[i].topics[1],
                    bytes32(uint256(uint160(r.recipient))),
                    "actual consumed recipient"
                );
                assertEq(
                    logs[i].data,
                    abi.encode(r.beforeHead, r.afterHead, _expectedFee(r)),
                    "actual consumed interval/fee"
                );
                o.consumed = true;
            }
        }
        if (o.tentativeBatch) assertEq(o.verifierCalls, 1, "verifier call after tentative batch");
        if (!o.ok) {
            assertEq(o.paidWei, 0, "no committed transfer after outer revert");
            o.paidTo = address(0);
        }
    }

    /// @dev Verifies actual rollback state and emitted/transfer observations against row data.
    function _assertBusiness(Row memory r, Observation memory o) private view {
        assertEq(o.tail, r.tail, string.concat(r.id, ": retained tail"));
        if (!o.ok) {
            assertEq(o.head, r.beforeHead, string.concat(r.id, ": rollback head"));
            assertEq(o.height, r.parentHeight, string.concat(r.id, ": rollback checkpoint"));
            assertEq(
                o.checkpointHash,
                genesisBlockHash,
                string.concat(r.id, ": rollback checkpoint hash")
            );
            // Fixtures never prepopulate the requested target (genesis-height rows are excluded
            // from this particular absence assertion because the real base has block zero).
            if (r.lastHeight != 0) {
                assertFalse(o.signalPresent, string.concat(r.id, ": rollback signal"));
            }
            return;
        }
        assertTrue(r.verifierAccepts, "successful land requires normal verifier return");
        assertGt(r.lastHeight, r.parentHeight, "successful strict progress");
        assertLe(uint256(r.lastHeight) - r.parentHeight, r.maxBatch, "successful batch bound");
        assertLe(r.lastHeight, type(uint48).max, "successful height width");
        assertLe(r.beforeHead, r.afterHead, "successful head monotonicity");
        assertLe(r.afterHead, r.tail, "successful head tail bound");
        assertLe(
            uint256(r.afterHead) - r.beforeHead,
            uint256(r.lastHeight) - r.parentHeight,
            "successful consumption block bound"
        );
        assertEq(o.head, r.afterHead, string.concat(r.id, ": landed head"));
        assertEq(o.height, r.lastHeight, string.concat(r.id, ": landed height"));
        assertEq(o.checkpointHash, r.lastHash, string.concat(r.id, ": landed hash"));
        assertTrue(o.signalPresent, "real service checkpoint");
        assertEq(o.signal.blockHash, r.lastHash, "real service hash");
        assertEq(o.signal.stateRoot, r.lastRoot, "real service root");
        assertTrue(o.batch, "committed batch event under journal rule");
        assertEq(o.consumed, r.afterHead != r.beforeHead, "consumption event condition");
        assertEq(o.paidWei, _expectedFee(r), "actual committed CALL amount");
        assertEq(
            o.paidTo, o.paidWei == 0 ? address(0) : r.recipient, "actual committed CALL target"
        );
        assertEq(o.preimage.length, 576, "actual successful statement captured");
    }

    /// @dev Reads the concrete service rather than inferring its storage from Inbox success.
    function _signal(uint64 _height)
        private
        view
        returns (bool present, ICheckpointStore.Checkpoint memory checkpoint)
    {
        if (_height > type(uint48).max) {
            return (false, checkpoint);
        }
        // The preceding uint48 bound makes this narrowing lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        try signalService.getCheckpoint(uint48(_height)) returns (
            ICheckpointStore.Checkpoint memory found
        ) {
            return (true, found);
        } catch {
            return (false, checkpoint);
        }
    }

    /// @dev Independently forms eighteen field words; actual byte observation comes only from trace.
    function _statementWords(Row memory r) private view returns (bytes32[] memory w) {
        w = new bytes32[](18);
        // The 18-byte ASCII domain fits in 32 bytes; zero right-padding is the wire format.
        // forge-lint: disable-next-line(unsafe-typecast)
        w[0] = bytes32("TAIKO_ETNA_LAND_V6");
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(L2_CHAIN_ID));
        w[3] = bytes32(uint256(uint160(address(etnaInbox))));
        w[4] = bytes32(uint256(uint160(address(registry))));
        w[5] = vm.load(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT));
        w[6] = bytes32(uint256(r.parentHeight));
        w[7] = genesisBlockHash;
        w[8] = COMMITTEE_CONFIG_HASH;
        w[9] = bytes32(uint256(r.lastHeight));
        w[10] = r.lastHash;
        w[11] = r.lastRoot;
        w[12] = bytes32(uint256(r.referenceBlock));
        w[13] = r.referenceHash;
        uint256 count;
        while (count < r.blobs.length && r.blobs[count] != bytes32(0)) ++count;
        bytes32[] memory prefix = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            prefix[i] = r.blobs[i];
        }
        w[14] = keccak256(abi.encodePacked(prefix));
        w[15] = bytes32(uint256(r.beforeHead));
        w[16] = bytes32(uint256(r.afterHead));
        w[17] = bytes32(uint256(uint160(r.recipient)));
    }

    /// @dev Fees are relative to the seeded pre-head; missing queue entries have zero fee.
    function _expectedFee(Row memory r) private pure returns (uint256 fee) {
        for (uint256 i; i < uint256(r.afterHead) - r.beforeHead && i < r.fees.length; ++i) {
            fee += r.fees[i];
        }
        return fee * 1 gwei;
    }

    /// @dev Maps the exact observed top-level selector without hiding unknown failures.
    function _classify(bytes4 selector, bool ok) private pure returns (string memory) {
        if (ok) return "none";
        if (selector == EssentialContract.REENTRANT_CALL.selector) return "reentrant";
        if (selector == EtnaInbox.EtnaNotActive.selector) return "inactive";
        if (selector == EtnaInbox.NoProgress.selector) return "no-progress";
        if (selector == EtnaInbox.BatchTooLarge.selector) return "batch-too-large";
        if (selector == EtnaInbox.HeightOverflow.selector) return "height-overflow";
        if (selector == EtnaInbox.ZeroFeeRecipient.selector) return "zero-recipient";
        if (selector == EtnaInbox.InvalidForcedInclusionHead.selector) return "invalid-head";
        if (selector == EtnaInbox.AnchorUnavailable.selector) return "anchor-unavailable";
        if (selector == EtnaInbox.BlobsRequired.selector) return "blobs-required";
        if (selector == SignalService.SS_UNAUTHORIZED.selector) return "signal-unauthorized";
        if (selector == SignalService.SS_INVALID_CHECKPOINT.selector) return "signal-invalid";
        if (selector == LeanVerifierFixture.ProofRejected.selector) return "verifier";
        if (selector == LibAddress.ETH_TRANSFER_FAILED.selector) return "payment";
        revert("unclassified actual LAND selector");
    }

    /// @dev Emits canonical scalar observations plus actual encoding context for independent Lean.
    function _print(Row memory r, Observation memory o) private {
        string memory k = string.concat("land-", r.id);
        vm.serializeUint(k, "schemaVersion", 1);
        vm.serializeString(k, "id", r.id);
        vm.serializeString(k, "status", o.ok ? "ok" : "revert");
        vm.serializeString(k, "error", o.errorName);
        vm.serializeUint(k, "head", o.head);
        vm.serializeUint(k, "tail", o.tail);
        vm.serializeUint(k, "checkpointHeight", o.height);
        vm.serializeBytes32(k, "checkpointHash", o.checkpointHash);
        vm.serializeBool(k, "signalPresent", o.signalPresent);
        vm.serializeUint(k, "signalHeight", o.signalPresent ? o.signal.blockNumber : 0);
        vm.serializeBytes32(k, "signalHash", o.signal.blockHash);
        vm.serializeBytes32(k, "signalRoot", o.signal.stateRoot);
        vm.serializeAddress(k, "paidTo", o.paidTo);
        vm.serializeString(k, "paidWei", vm.toString(o.paidWei));
        vm.serializeBool(k, "batchEvent", o.batch);
        vm.serializeBool(k, "consumedEvent", o.consumed);
        vm.serializeUint(k, "tentativeHead", o.tentativeHead);
        vm.serializeUint(k, "tentativeCheckpointHeight", o.tentativeHeight);
        vm.serializeBool(k, "headWriteObserved", o.headWrite);
        vm.serializeBool(k, "checkpointWriteObserved", o.checkpointWrite);
        vm.serializeBool(k, "tentativeSignalPresent", o.tentativeSignal);
        vm.serializeBool(k, "tentativeBatchEvent", o.tentativeBatch);
        vm.serializeString(k, "failureStage", o.errorName);
        vm.serializeBytes(k, "rawSelector", abi.encodePacked(o.selector));
        vm.serializeBytes(k, "nestedError", abi.encodePacked(o.nestedError));
        vm.serializeUint(k, "rawLogCount", o.rawLogCount);
        vm.serializeUint(k, "statementDepth", o.statementDepth);
        vm.serializeUint(k, "verifierStaticCalls", o.verifierCalls);
        vm.serializeString(k, "committedLogEvidence", "call-result-plus-EVM-journal-law");
        string memory contextJson;
        if (o.preimage.length != 0) {
            vm.serializeBytes32(k, "statementWords", _statementWords(r));
            vm.serializeBytes(k, "actualPreimage", o.preimage);
            vm.serializeBytes32(k, "actualDigest", keccak256(o.preimage));
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
            contextJson = vm.serializeAddress(contextKey, "recipient", r.recipient);
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
    function _recipientMode(string memory mode) private pure returns (uint8) {
        if (_same(mode, "land-caught")) return 1;
        if (_same(mode, "save-caught")) return 2;
        if (_same(mode, "land-uncaught")) return 3;
        if (_same(mode, "save-uncaught")) return 4;
        return 0;
    }

    /// @dev Compares a schema enum string.
    function _same(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
