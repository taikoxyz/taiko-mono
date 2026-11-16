// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EtnaInboxTestBase} from "../EtnaInboxTestBase.sol";
import {EtnaLandTestBase} from "../EtnaLandTestBase.sol";
import {MockUnzenInbox} from "../MockUnzenInbox.sol";
import {IEtnaInbox} from "src/layer1/etna/iface/IEtnaInbox.sol";
import {EssentialContract} from "src/shared/common/EssentialContract.sol";
import {ICheckpointStore} from "src/shared/signal/ICheckpointStore.sol";
import {Vm} from "forge-std/src/Vm.sol";

/// @notice Replays 38 actual M11 calls from 23 programs against pinned real Inbox methods.
/// @dev Times T(t)=100000+1152t; stored0 and cancellation99 are distinct sentinels.
/// Unzen finalization and strict statement-bound setup proof remain explicit premises.
contract EtnaRulesReplayTest is EtnaLandTestBase {
    uint256 private constant S = 6;
    uint256 private constant TIME_BASE = 100000;
    uint256 private constant NOTICE = 1152;
    string private constant FILE = "/test/layer1/etna/conformance/vectors/rules_cases.json";
    bytes32 private constant EVENT = keccak256("RulesScheduleUpdated(uint256)");

    /// @notice Creates an uninitialized public bootstrap with its registry registration at98.
    function setUp() public override {
        vm.roll(98);
        vm.warp(TIME_BASE - 1);
        EtnaInboxTestBase.setUp();
    }

    /// @notice Applies every original call in order, resetting only between independent programs.
    function test_conformance_rulesReplay() external {
        vm.pauseGasMetering();
        string memory j = vm.readFile(string.concat(vm.projectRoot(), FILE));
        assertEq(vm.parseJsonString(j, ".schema"), "etna-rules-replay-1");
        assertEq(_u(j, ".mapping", ".timestamp_scale"), NOTICE);
        assertEq(_u(j, ".mapping", ".timestamp_base"), TIME_BASE);
        assertTrue(vm.keyExistsJson(j, ".cases[37].id"));
        assertFalse(vm.keyExistsJson(j, ".cases[38].id"));
        uint256 blank = vm.snapshotState();
        bytes32 previous;
        uint256 programs;
        uint256 nextIndex;
        for (uint256 i; i < 38; ++i) {
            string memory p = string.concat(".cases[", vm.toString(i), "].attempt");
            bytes32 program = keccak256(bytes(vm.parseJsonString(j, string.concat(p, ".program"))));
            bool newProgram = program != previous;
            if (newProgram) {
                assertTrue(vm.revertToState(blank));
                previous = program;
                nextIndex = 1;
                ++programs;
            }
            assertEq(_u(j, p, ".index"), nextIndex++);
            this.runAttempt(j, i, newProgram);
        }
        assertEq(programs, 23);
    }

    /// @notice Parses one receipt in a bounded memory frame, preserving public program state.
    /// @param j The actual M11 receipt collection.
    /// @param index The selected receipt index.
    /// @param newProgram Whether this receipt begins an independent program.
    function runAttempt(string memory j, uint256 index, bool newProgram) external {
        require(msg.sender == address(this), "test only");
        string memory p = string.concat(".cases[", vm.toString(index), "].attempt");
        if (newProgram) {
            _setup(_b(j, p, ".setup.initialized"), _b(j, p, ".setup.startWritten"), _b(j, p, ".setup.seededLanding"));
        }
        _attempt(j, p);
    }

    /// @dev Deploys a switching implementation and uses public initialization/origin/landing APIs.
    function _setup(bool initialized, bool startWritten, bool seeded) private {
        MockUnzenInbox unzen = new MockUnzenInbox();
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.originWriter = address(this);
        cfg.unzenInbox = address(unzen);
        cfg.etnaForkTime = uint48(TIME_BASE);
        inboxImpl = _newInboxImpl(cfg);
        if (!initialized) {
            EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
            return;
        }
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisBlockHash = 0;
        params.genesisStateRoot = 0;
        params.maxAnchorAge = NOTICE;
        _upgradeAndInit(inboxImpl, params);
        vm.roll(100);
        vm.warp(TIME_BASE);
        if (!startWritten) return;
        _inbox().setOrigin(S, bytes32(100 + S), _stateRoot(S));
        if (!seeded) return;
        // Imported legacy finalization boundary, not an Etna storage override.
        unzen.setCoreState(2, 1, bytes32(100 + S));
        vm.prank(inboxProxy);
        signalService.saveCheckpoint(ICheckpointStore.Checkpoint(uint48(S), bytes32(100 + S), _stateRoot(S)));
        vm.roll(101);
        vm.warp(_time(1));
        _setReference(100, bytes32(uint256(999)));
        _setBlobCount(1);
        IEtnaInbox.LandInput memory input = _input(S, S + K);
        input.activeCommitteeSnapshot = registryCheckpointBlock;
        bytes32[] memory leaves = _leaves(S, S + K);
        landVerifier.setExpectedStatementHash(_statement(input, _inbox().landings(S), _cutHash(input, leaves)));
        _land(input, leaves);
        assertEq(_inbox().lastCheckpoint().height, S + K);
    }

    /// @dev Calls original arguments and independently observes state, event and failure atomicity.
    function _attempt(string memory j, string memory p) private {
        emit log_string(string.concat(
                vm.parseJsonString(j, string.concat(p, ".program")), "/", vm.toString(_u(j, p, ".index"))
            ));
        vm.roll(_u(j, p, ".context.l1Block"));
        vm.warp(_time(_u(j, p, ".context.timestamp")));
        assertTrue(_b(j, p, ".context.registryUnlocked"));
        assertEq(_inbox().isInitialized(), _b(j, p, ".context.initialized"));
        _assertState(j, string.concat(p, ".before"));
        bytes32 raw = _rawDigest();
        bytes32 preserved = _preservedDigest();
        bytes memory input = _encode(j, p);
        vm.recordLogs();
        bool ownerCall = _b(j, p, ".context.owner");
        vm.resumeGasMetering();
        if (!ownerCall) vm.prank(address(0xBEEF));
        (bool ok,) = inboxProxy.call(input);
        vm.pauseGasMetering();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(ok, _b(j, p, ".accepted"), "actual acceptance");
        if (!ok) assertEq(_rawDigest(), raw, "complete selected abort state");
        _assertState(j, string.concat(p, ".after"));
        assertEq(_preservedDigest(), preserved, "checkpoint/old origin/registry preserved");
        _assertEvent(j, p, logs);
    }

    /// @dev Encodes the original operation without a local acceptance oracle.
    function _encode(string memory j, string memory p) private view returns (bytes memory) {
        bytes32 op = keccak256(bytes(vm.parseJsonString(j, string.concat(p, ".operation"))));
        string memory a = string.concat(p, ".args");
        if (op == keccak256("Rules")) {
            return abi.encodeCall(
                IEtnaInbox.scheduleRules, (uint48(_u(j, a, ".rules")), uint48(_rulesTime(_u(j, a, ".time"))))
            );
        }
        if (op == keccak256("Stop")) {
            return
                abi.encodeCall(
                    IEtnaInbox.scheduleStop, (uint48(_stopTime(_u(j, a, ".time"))), uint48(_u(j, a, ".grid")))
                );
        }
        assertEq(op, keccak256("Recover"));
        return abi.encodeCall(
            IEtnaInbox.recover,
            (
                uint48(_u(j, a, ".expectedGeneration")),
                _u(j, a, ".expectedC"),
                _u(j, a, ".expectedRecoveryNonce"),
                _time(_u(j, a, ".validUntil")),
                new IEtnaInbox.Exclusion[](0),
                new uint256[](0),
                uint48(_u(j, a, ".rules"))
            )
        );
    }

    /// @dev Compares all five public fields, raw packed storage, counters and current origin.
    function _assertState(string memory j, string memory p) private view {
        string memory s = string.concat(p, ".schedule");
        IEtnaInbox.RulesSchedule memory actual = _inbox().rulesSchedule();
        assertEq(actual.activeRules, _u(j, s, ".activeRules"));
        assertEq(actual.nextRules, _u(j, s, ".nextRules"));
        assertEq(actual.rulesTime, _rulesTime(_u(j, s, ".rulesTime")));
        assertEq(actual.stopTime, _stopTime(_u(j, s, ".stopTime")));
        assertEq(actual.stopGrid, _u(j, s, ".stopGrid"));
        uint256 packed = _u(j, s, ".activeRules") | (_u(j, s, ".nextRules") << 48)
            | (_rulesTime(_u(j, s, ".rulesTime")) << 96) | (_stopTime(_u(j, s, ".stopTime")) << 144)
            | (_u(j, s, ".stopGrid") << 192);
        assertEq(uint256(vm.load(inboxProxy, bytes32(uint256(293)))), packed, "raw five fields/reserved bits");
        uint256 g = _u(j, p, ".generation");
        assertEq(_inbox().recoveryGeneration(), g);
        assertEq(_inbox().recoveryNonce(), _u(j, p, ".nonce"));
        assertEq(_inbox().lastCheckpoint().height, _u(j, p, ".checkpoint"));
        IEtnaInbox.Origin memory o = _inbox().origins(g);
        string memory origin = string.concat(p, ".origin");
        assertEq(o.startHeight, _u(j, origin, ".height"));
        assertEq(o.startHeight, _u(j, p, ".originHeight"));
        assertEq(o.l1BlockNumber, _u(j, origin, ".l1Block"));
        assertEq(o.l1Timestamp, _b(j, origin, ".present") ? _time(_u(j, origin, ".timestamp")) : 0);
    }

    /// @dev Matches only the Inbox event and independently packs its exported raw limbs.
    function _assertEvent(string memory j, string memory p, Vm.Log[] memory logs) private view {
        uint256 count;
        uint256 value;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == inboxProxy && logs[i].topics.length == 1 && logs[i].topics[0] == EVENT) {
                ++count;
                value = abi.decode(logs[i].data, (uint256));
            }
        }
        bool emitted = _b(j, p, ".scheduleEvent.present");
        assertEq(count, emitted ? 1 : 0, "selected schedule event count");
        if (!emitted) return;
        uint256[] memory limbs = vm.parseJsonUintArray(j, string.concat(p, ".scheduleEvent.limbs"));
        assertEq(limbs.length, 5);
        assertEq(_u(j, p, ".scheduleEvent.reserved16"), 0);
        uint256 expected = limbs[0] | (limbs[1] << 48) | (_rulesTime(limbs[2]) << 96) | (_stopTime(limbs[3]) << 144)
            | (limbs[4] << 192);
        assertEq(value, expected, "raw RulesScheduleUpdated payload");
    }

    /// @notice Concrete 48-bit notice/time checks supplement, rather than impersonate, tiny M11.
    function test_rules_concreteUint48Boundaries() external {
        _setup(true, true, false);
        uint256 clean = vm.snapshotState();
        uint48 high = type(uint48).max;
        vm.warp(uint256(high) - NOTICE);
        _inbox().scheduleRules(1, high);
        _inbox().scheduleStop(high, 6);
        assertEq(_inbox().rulesSchedule().rulesTime, high);
        assertEq(_inbox().rulesSchedule().stopTime, high);
        vm.expectRevert(IEtnaInbox.StopLocked.selector);
        _inbox().scheduleStop(0, 0);
        assertTrue(vm.revertToState(clean));
        vm.warp(uint256(high) - NOTICE + 1);
        bytes32 beforeState = _rawDigest();
        vm.expectRevert(IEtnaInbox.InvalidScheduleTime.selector);
        _inbox().scheduleRules(1, high);
        vm.expectRevert(IEtnaInbox.InvalidStop.selector);
        _inbox().scheduleStop(high, 6);
        assertEq(_rawDigest(), beforeState);
    }

    /// @notice Noncanonical ABI words above uint48 are rejected before a public schedule write.
    function test_rules_concreteAbiRangeRejection() external {
        _setup(true, true, false);
        bytes32 beforeState = _rawDigest();
        (bool ok, bytes memory reason) = inboxProxy.call(
            abi.encodeWithSelector(IEtnaInbox.scheduleRules.selector, uint256(1), uint256(type(uint48).max) + 1)
        );
        assertFalse(ok);
        assertEq(reason.length, 0, "ABI decoder rejection");
        assertEq(_rawDigest(), beforeState);
    }

    /// @dev All fixed Inbox slots and selected mapping records are observed, never planted.
    function _rawDigest() private view returns (bytes32 result) {
        result = keccak256(abi.encode(vm.load(inboxProxy, bytes32(uint256(258))), _preservedDigest()));
        for (uint256 i = 268; i <= 293; ++i) {
            result = keccak256(abi.encode(result, vm.load(inboxProxy, bytes32(i))));
        }
        for (uint256 g; g < 3; ++g) {
            result = keccak256(abi.encode(result, _inbox().origins(g)));
        }
    }

    /// @dev None of the three public schedule operations may rewrite these selected records.
    function _preservedDigest() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _inbox().lastCheckpoint(),
                _inbox().landings(S),
                _inbox().landings(S + K),
                _inbox().origins(0),
                _inbox().activeCommitteeSnapshot(),
                registry.bondAt(0),
                taikoToken.balanceOf(address(registry))
            )
        );
    }

    /// @dev Public L2 fixture cuts have no forced-inclusion effects in C05.
    function _cut(uint256 x) internal pure override returns (bytes32, bytes32, uint256) {
        return (bytes32(100 + x), x == S ? bytes32(0) : bytes32(200 + x), 0);
    }

    /// @dev Only the switching origin has the zero validator commitment.
    function _valStateHash(uint256 x) internal pure override returns (bytes32) {
        return x == S ? bytes32(0) : bytes32(400 + x);
    }

    /// @dev Affine time for contexts, deadlines and present-origin timestamps, including zero.
    function _time(uint256 t) private pure returns (uint256) {
        return TIME_BASE + NOTICE * t;
    }

    /// @dev Stored rule time zero/cancel sentinels are distinct from real Unix time.
    function _rulesTime(uint256 t) private pure returns (uint256) {
        return t == 0 ? 0 : t == 99 ? type(uint48).max : _time(t);
    }

    /// @dev Only a zero stop time is a sentinel.
    function _stopTime(uint256 t) private pure returns (uint256) {
        return t == 0 ? 0 : _time(t);
    }

    /// @dev Reads one exact exported integer.
    function _u(string memory j, string memory p, string memory f) private pure returns (uint256) {
        return vm.parseJsonUint(j, string.concat(p, f));
    }

    /// @dev Reads one exact exported Boolean.
    function _b(string memory j, string memory p, string memory f) private pure returns (bool) {
        return vm.parseJsonBool(j, string.concat(p, f));
    }
}
