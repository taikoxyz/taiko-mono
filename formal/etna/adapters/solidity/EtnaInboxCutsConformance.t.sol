// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { Vm, VmSafe } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxCutsConformanceTest
/// @notice Compares actual consecutive landing cuts over one shared set of real admissions.
/// @dev This finite sampled runtime test does not establish guest soundness or prove arbitrary
/// cut invariance. The independent Lean composition theorem supplies the quantified statement.
contract EtnaInboxCutsConformanceTest is EtnaInboxTestBase {
    address private constant _RECIPIENT = address(0xbeef);
    address private constant _LANDER = address(0xcafe);
    uint64 private constant _REFERENCE = 19_999;
    bytes32 private constant _REFERENCE_HASH = bytes32(uint256(0xabc));
    bytes32 private constant _CONSUMED =
        keccak256("ForcedInclusionsConsumed(uint48,uint48,uint256,address)");
    bytes32 private constant _BATCH =
        keccak256("BatchLanded(uint64,uint64,bytes32,bytes32,uint64,bytes32,address)");

    struct Interval {
        uint48 beforeHead;
        uint48 afterHead;
        uint256 paidWei;
        uint64 lastHeight;
    }

    struct PlanResult {
        uint48 finalHead;
        uint64 finalHeight;
        bytes32 finalHash;
        bytes32 finalRoot;
        uint256 paidWei;
        Interval[] intervals;
    }

    /// @notice Replays four contiguous cut plans from the identical admitted queue and proxy.
    function test_land_ContiguousCuts() external {
        vm.pauseGasMetering();
        vm.roll(20_000);
        vm.setBlockhash(_REFERENCE, _REFERENCE_HASH);
        vm.deal(address(this), 1 ether);
        uint256[] memory fees = new uint256[](4);
        for (uint256 i; i < fees.length; ++i) {
            fees[i] = etnaInbox.getCurrentForcedInclusionFee();
            vm.resumeGasMetering();
            etnaInbox.saveForcedInclusion{ value: fees[i] * 1 gwei }(abi.encode(i));
            vm.pauseGasMetering();
        }
        IEtnaInbox.ForcedInclusion[] memory entries = etnaInbox.getForcedInclusions(0, 4);
        assertEq(entries.length, 4, "four actual admitted entries");
        for (uint256 i; i < entries.length; ++i) {
            assertEq(entries[i].feeInGwei, fees[i], "actual retained admission fee");
        }
        (uint48 initialHead, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(initialHead, 0, "initial queue head");
        assertEq(tail, 4, "actual admitted queue tail");
        assertEq(etnaInbox.lastCheckpoint().height, 0, "authenticated genesis parent");

        PlanResult memory combined;
        for (uint256 plan; plan < 4; ++plan) {
            uint256 snapshot = vm.snapshotState();
            (string memory id, uint256[] memory cuts) = _plan(plan);
            PlanResult memory result = this.executeCutPlan(cuts, fees);
            if (plan == 0) {
                combined = result;
            } else {
                assertEq(result.finalHead, combined.finalHead, "cut-invariant actual queue head");
                assertEq(result.paidWei, combined.paidWei, "cut-invariant actual transferred fees");
                assertEq(result.finalHeight, combined.finalHeight, "cut-invariant terminal height");
                assertEq(result.finalHash, combined.finalHash, "cut-invariant terminal hash");
                assertEq(result.finalRoot, combined.finalRoot, "cut-invariant service state root");
            }
            _print(id, cuts, fees, result);
            assertTrue(vm.revertToStateAndDelete(snapshot), "restore same admitted world");
        }
    }

    /// @notice Isolates journal decoding memory per plan while retaining state across its cuts.
    /// @dev Only the test itself can invoke this helper; actual land calls are metered.
    function executeCutPlan(
        uint256[] calldata _cuts,
        uint256[] calldata _fees
    )
        external
        returns (PlanResult memory result)
    {
        require(msg.sender == address(this), "self-only plan");
        uint256[] memory steps = _steps();
        result.intervals = new Interval[](_cuts.length);
        uint48 expectedHead;
        uint64 priorHeight;
        uint256 covered;
        for (uint256 i; i < _cuts.length; ++i) {
            uint64 height = uint64(_cuts[i]);
            assertGt(height, priorHeight, "strict contiguous cut progress");
            assertLe(height, steps.length, "cut within frozen block trace");
            uint48 afterHead = expectedHead;
            for (uint256 blockIndex = priorHeight; blockIndex < height; ++blockIndex) {
                afterHead += uint48(steps[blockIndex]);
            }
            uint256 expectedFee;
            for (uint256 entryIndex = expectedHead; entryIndex < afterHead; ++entryIndex) {
                expectedFee += _fees[entryIndex] * 1 gwei;
                ++covered;
            }
            Interval memory interval = this.executeCut(expectedHead, afterHead, height, expectedFee);
            result.intervals[i] = interval;
            result.paidWei += interval.paidWei;
            expectedHead = afterHead;
            priorHeight = height;
        }
        assertEq(priorHeight, 6, "complete frozen trace");
        assertEq(covered, 4, "each consumed entry covered once");
        (result.finalHead,) = etnaInbox.getForcedInclusionState();
        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        // The preceding terminal-height assertion fixes priorHeight to 6, within uint48.
        // forge-lint: disable-next-line(unsafe-typecast)
        ICheckpointStore.Checkpoint memory signal = signalService.getCheckpoint(uint48(priorHeight));
        result.finalHeight = checkpoint.height;
        result.finalHash = checkpoint.blockHash;
        result.finalRoot = signal.stateRoot;
        assertEq(result.finalHead, 4, "all four admissions consumed exactly once");
        assertEq(result.finalHeight, 6, "actual terminal checkpoint");
        assertEq(address(etnaInbox).balance, 0, "all admitted fees transferred once");
    }

    /// @notice Lands one batch through the real Inbox/proxy and records actual effects.
    /// @dev Empty intervals must skip value transfer and consumption events.
    function executeCut(
        uint48 _before,
        uint48 _after,
        uint64 _height,
        uint256 _expectedFee
    )
        external
        returns (Interval memory interval)
    {
        require(msg.sender == address(this), "self-only cut");
        (uint48 observedBefore, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(observedBefore, _before, "consecutive actual head before");
        uint64 parentHeight = etnaInbox.lastCheckpoint().height;
        interval = Interval(_before, _after, _expectedFee, _height);
        bytes32[] memory blobs = new bytes32[](2);
        blobs[0] = bytes32(uint256(1));
        blobs[1] = bytes32(uint256(2));
        vm.blobhashes(blobs);
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: _height,
            lastBlockHash: bytes32(uint256(0x1000) + _height),
            lastStateRoot: bytes32(uint256(0x2000) + _height),
            l1ReferenceBlockNumber: _REFERENCE,
            forcedInclusionHead: _after,
            feeRecipient: _RECIPIENT
        });
        vm.recordLogs();
        vm.startStateDiffRecording();
        vm.resumeGasMetering();
        vm.prank(_LANDER);
        etnaInbox.land(input, "sampled cut boundary proof");
        vm.pauseGasMetering();
        uint256 actualPaid = _assertPayment(vm.stopAndReturnStateDiff(), interval);
        _assertCutEvents(vm.getRecordedLogs(), interval, parentHeight);
        _assertCutState(interval, tail);
        interval.paidWei = actualPaid;
    }

    /// @dev Measures only actual committed value CALL instructions from this Inbox.
    function _assertPayment(
        Vm.AccountAccess[] memory _accesses,
        Interval memory _interval
    )
        private
        view
        returns (uint256 paid)
    {
        uint256 paymentCalls;
        for (uint256 i; i < _accesses.length; ++i) {
            Vm.AccountAccess memory access = _accesses[i];
            if (
                access.kind != VmSafe.AccountAccessKind.Call
                    || access.accessor != address(etnaInbox) || access.value == 0
            ) continue;
            assertFalse(access.reverted, "actual committed cut payment");
            assertEq(access.account, _RECIPIENT, "actual bound cut payment target");
            paid += access.value;
            ++paymentCalls;
        }
        assertEq(paid, _interval.paidWei, "actual journal payment matches stored fee interval");
        assertEq(
            paymentCalls,
            _interval.beforeHead == _interval.afterHead ? 0 : 1,
            "zero interval skips payment CALL"
        );
    }

    /// @dev Validates actual consumption and batch logs for each contiguous landing.
    function _assertCutEvents(
        Vm.Log[] memory _logs,
        Interval memory _interval,
        uint64 _parent
    )
        private
        view
    {
        uint256 consumedEvents;
        uint256 batchEvents;
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].emitter != address(etnaInbox) || _logs[i].topics.length == 0) continue;
            if (_logs[i].topics[0] == _CONSUMED) {
                ++consumedEvents;
                assertEq(
                    _logs[i].topics[1],
                    bytes32(uint256(uint160(_RECIPIENT))),
                    "indexed payment recipient"
                );
                assertEq(
                    _logs[i].data,
                    abi.encode(_interval.beforeHead, _interval.afterHead, _interval.paidWei),
                    "actual cut interval and fee event"
                );
            }
            if (_logs[i].topics[0] == _BATCH) {
                ++batchEvents;
                assertEq(
                    _logs[i].topics[1], bytes32(uint256(uint160(_LANDER))), "indexed cut lander"
                );
                (uint64 first, uint64 last,,,,) =
                    abi.decode(_logs[i].data, (uint64, uint64, bytes32, bytes32, uint64, bytes32));
                assertEq(first, _parent + 1, "contiguous first block");
                assertEq(last, _interval.lastHeight, "actual terminal event height");
            }
        }
        assertEq(
            consumedEvents,
            _interval.beforeHead == _interval.afterHead ? 0 : 1,
            "consumption event condition"
        );
        assertEq(batchEvents, 1, "one batch event per actual landing");
    }

    /// @dev Reads the actual Inbox and concrete service after every cut.
    function _assertCutState(Interval memory _interval, uint48 _tail) private view {
        (uint48 observedAfter, uint48 observedTail) = etnaInbox.getForcedInclusionState();
        assertEq(observedAfter, _interval.afterHead, "consecutive actual head after");
        assertEq(observedTail, _tail, "queue tail retained across cuts");
        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        ICheckpointStore.Checkpoint memory signal =
            signalService.getCheckpoint(uint48(_interval.lastHeight));
        assertEq(checkpoint.height, _interval.lastHeight, "actual Inbox terminal height");
        assertEq(
            checkpoint.blockHash,
            bytes32(uint256(0x1000) + _interval.lastHeight),
            "actual Inbox terminal hash"
        );
        assertEq(signal.blockHash, checkpoint.blockHash, "actual SignalService hash");
        assertEq(
            signal.stateRoot,
            bytes32(uint256(0x2000) + _interval.lastHeight),
            "actual SignalService root"
        );
    }

    /// @dev Emits one distinct sampled-plan record without touching existing LAND IDs.
    function _print(
        string memory _id,
        uint256[] memory _cuts,
        uint256[] memory _fees,
        PlanResult memory _result
    )
        private
    {
        string memory key = string.concat("cut-", _id);
        vm.serializeUint(key, "schemaVersion", 1);
        vm.serializeString(key, "id", _id);
        vm.serializeUint(key, "steps", _steps());
        vm.serializeUint(key, "cuts", _cuts);
        vm.serializeUint(key, "initialHead", 0);
        vm.serializeUint(key, "finalHead", _result.finalHead);
        vm.serializeUint(key, "initialHeight", 0);
        vm.serializeUint(key, "finalHeight", _result.finalHeight);
        string[] memory fees = new string[](_fees.length);
        for (uint256 i; i < fees.length; ++i) {
            fees[i] = vm.toString(_fees[i]);
        }
        vm.serializeString(key, "feesGwei", fees);
        vm.serializeString(key, "paidWei", vm.toString(_result.paidWei));
        vm.serializeBytes32(key, "finalHash", _result.finalHash);
        vm.serializeBytes32(key, "finalRoot", _result.finalRoot);
        vm.serializeAddress(key, "proxy", address(etnaInbox));
        string memory output = vm.serializeAddress(key, "registry", address(registry));
        bytes memory prefix = bytes(output);
        assembly { mstore(prefix, sub(mload(prefix), 1)) }
        output = string.concat(string(prefix), ',"intervals":[');
        for (uint256 i; i < _result.intervals.length; ++i) {
            Interval memory interval = _result.intervals[i];
            if (i > 0) output = string.concat(output, ",");
            output = string.concat(
                output,
                '{"before":',
                vm.toString(interval.beforeHead),
                ',"after":',
                vm.toString(interval.afterHead),
                ',"paidWei":"',
                vm.toString(interval.paidWei),
                '","lastHeight":',
                vm.toString(interval.lastHeight),
                "}"
            );
        }
        console2.log(string.concat("ETNA_CUT ", output, "]}"));
    }

    /// @dev The shared sampled trace contains a mixture of consuming and non-consuming blocks.
    function _steps() private pure returns (uint256[] memory steps) {
        steps = new uint256[](6);
        steps[0] = 1;
        steps[2] = 1;
        steps[3] = 1;
        steps[5] = 1;
    }

    /// @dev Returns each frozen finite plan; the last endpoint always covers the full trace.
    function _plan(uint256 _index) private pure returns (string memory id, uint256[] memory cuts) {
        if (_index == 0) {
            id = "cut-6";
            cuts = new uint256[](1);
            cuts[0] = 6;
        } else if (_index == 1) {
            id = "cut-1-6";
            cuts = new uint256[](2);
            cuts[0] = 1;
            cuts[1] = 6;
        } else if (_index == 2) {
            id = "cut-2-4-6";
            cuts = new uint256[](3);
            cuts[0] = 2;
            cuts[1] = 4;
            cuts[2] = 6;
        } else {
            id = "cut-every";
            cuts = new uint256[](6);
            for (uint256 i; i < 6; ++i) {
                cuts[i] = i + 1;
            }
        }
    }
}
