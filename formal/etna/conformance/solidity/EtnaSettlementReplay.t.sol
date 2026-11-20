// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EtnaInboxTestBase, MockLandProofVerifier} from "../EtnaInboxTestBase.sol";
import {EtnaReplayTestBase} from "./EtnaReplayTestBase.sol";
import {IEtnaInbox} from "src/layer1/etna/iface/IEtnaInbox.sol";

/// @notice Replays TLC-produced public settlement/auth attempts on the actual Inbox.
/// @dev K6 grid, same compatible chain, empty FI/exclusions and rules zero. The strict
/// statement-bound mock models proof validity; this does not execute a proving guest.
contract EtnaSettlementReplayTest is EtnaReplayTestBase {
    string private constant FILE = "/test/layer1/etna/conformance/vectors/settlement_cases.json";
    IEtnaInbox.LandInput private prepared;
    bytes32[] private preparedLeaves;
    bytes32 private preparedStatement;
    bytes4 private lastProofRevert;
    uint256[4] private authorizationArgs;
    IEtnaInbox.Origin private initialOrigin;

    /// @notice Initializes the same grid chain without the helper's forced-inclusion fixture.
    function setUp() public override {
        vm.warp(1000);
        EtnaInboxTestBase.setUp();
        _upgradeAndInit(inboxImpl, _leanInitParams());
        initialOrigin = _inbox().origins(0);
        vm.roll(11);
        _setReference(10, bytes32(uint256(999)));
        _setBlobCount(2);
    }

    /// @dev All fixture cuts use the empty queue.
    function _cut(uint256 x) internal pure override returns (bytes32, bytes32, uint256) {
        return (bytes32(100 + x), x == 0 ? bytes32(0) : bytes32(200 + x), 0);
    }

    /// @notice Runs all eight TLC-executed scenarios and every intermediate retained record.
    function test_conformance_settlementReplay() external {
        string memory j = vm.readFile(string.concat(vm.projectRoot(), FILE));
        assertEq(vm.parseJsonString(j, ".schema"), "etna-settlement-replay-1");
        assertEq(vm.parseJsonUint(j, ".grid"), K);
        assertTrue(vm.keyExistsJson(j, ".cases[7].id"));
        assertFalse(vm.keyExistsJson(j, ".cases[8].id"));
        uint256 snapshot = vm.snapshotState();
        for (uint256 i; i < 8; ++i) {
            emit log_string(vm.parseJsonString(j, string.concat(".cases[", vm.toString(i), "].id")));
            this.runCase(j, i);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    /// @notice Replays one fixture; exposed only for test-call isolation.
    /// @param j The TLC-produced JSON fixture.
    /// @param index The selected case index.
    function runCase(string memory j, uint256 index) external {
        require(msg.sender == address(this), "test only");
        string memory prefix = string.concat(".cases[", vm.toString(index), "].steps[");
        uint256[8] memory lengths = [uint256(4), 4, 4, 5, 6, 7, 8, 7];
        for (uint256 step; step < lengths[index]; ++step) {
            string memory path = string.concat(prefix, vm.toString(step), "]");
            assertTrue(vm.keyExistsJson(j, path), "missing model step");
            uint256 op = _uint(j, path, ".op");
            uint256 arg = _uint(j, path, ".arg");
            bytes32 beforeState = _publicDigest();
            uint256 beforeSnapshot = _inbox().activeCommitteeSnapshot();
            bool ok = true;
            if (op == 1) {
                authorizationArgs = [
                    uint256(_inbox().recoveryGeneration()),
                    _inbox().lastCheckpoint().height,
                    _inbox().recoveryNonce(),
                    1000 + 12 * arg
                ];
            } else if (op == 2) {
                (prepared, preparedLeaves, preparedStatement) = _capture(arg * K);
            } else if (op == 3) {
                ok = _submit(prepared, preparedLeaves, preparedStatement);
            } else if (op == 4) {
                (IEtnaInbox.LandInput memory input, bytes32[] memory leaves, bytes32 statement) = _capture(arg * K);
                ok = _submit(input, leaves, statement);
            } else if (op == 5) {
                (ok,) = inboxProxy.call(
                    abi.encodeCall(
                        IEtnaInbox.recover,
                        (
                            uint48(authorizationArgs[0]),
                            authorizationArgs[1],
                            authorizationArgs[2],
                            authorizationArgs[3],
                            _noExclusions(),
                            new uint256[](0),
                            uint48(0)
                        )
                    )
                );
            } else if (op == 6) {
                (ok,) = inboxProxy.call(abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (_inbox().recoveryNonce())));
            } else if (op == 7) {
                vm.roll(11 + _uint(j, path, ".now"));
                vm.warp(1000 + 12 * _uint(j, path, ".now"));
                _setReference(block.number - 1, bytes32(uint256(999)));
            } else {
                assertEq(op, 0, "known operation");
            }
            if (op == 5 && ok) {
                assertEq(_inbox().activeCommitteeSnapshot(), beforeSnapshot, "recovery preserves snapshot");
            }
            assertEq(ok, vm.parseJsonBool(j, string.concat(path, ".accepted")), path);
            if (!ok || op == 0 || op == 1 || op == 2 || op == 7) {
                assertEq(_publicDigest(), beforeState, "failed/offchain attempt is atomic");
            }
            if (op == 3 && !ok && _uint(j, path, ".proof[1]") < _uint(j, path, ".generation")) {
                assertEq(
                    lastProofRevert, MockLandProofVerifier.ProofRejected.selector, "original proof statement rejected"
                );
            }
            _assertState(j, path);
        }
        assertFalse(
            vm.keyExistsJson(j, string.concat(prefix, vm.toString(lengths[index]), "]")), "unexpected model step"
        );
    }

    /// @dev Captures immutable original proof calldata and its current public statement.
    function _capture(uint256 h)
        private
        view
        returns (IEtnaInbox.LandInput memory input, bytes32[] memory leaves, bytes32 statement)
    {
        input = _input(_inbox().lastCheckpoint().height, h);
        leaves = _leaves(input.parentHeight, h);
        statement = _statement(input, _inbox().landings(input.parentHeight), _cutHash(input, leaves));
        require(statement != bytes32(0), "strict proof binding");
    }

    /// @dev Submits exact original artifacts; binding is never rebuilt from post-recovery state.
    function _submit(IEtnaInbox.LandInput memory input, bytes32[] memory leaves, bytes32 statement)
        private
        returns (bool ok)
    {
        landVerifier.setExpectedStatementHash(statement);
        vm.blobhashes(blobHashes);
        vm.prank(Bob);
        bytes memory result;
        (ok, result) = inboxProxy.call(abi.encodeCall(IEtnaInbox.land, (input, leaves, PROOF)));
        lastProofRevert = result.length >= 4 ? bytes4(result) : bytes4(0);
        if (ok) _assertSuccessfulPublication(input);
    }

    /// @dev Compares actual getters/raw retained records against every TLC receipt.
    function _assertState(string memory j, string memory path) private view {
        uint256 gen = _uint(j, path, ".generation");
        _assertCheckpoint(_uint(j, path, ".checkpoint") * K, bytes32(100 + _uint(j, path, ".checkpoint") * K));
        assertEq(_inbox().recoveryGeneration(), gen, "generation");
        assertEq(_inbox().recoveryNonce(), _uint(j, path, ".nonce"), "nonce");
        assertEq(_inbox().origins(gen).startHeight, _uint(j, path, ".origin") * K, "origin");
        _assertQueue(0, 0);
        for (uint256 g; g <= 2; ++g) {
            string memory originPath = string.concat(path, ".origins[", vm.toString(g), "]");
            IEtnaInbox.Origin memory actual = _inbox().origins(g);
            if (vm.parseJsonBool(j, string.concat(originPath, "[0]"))) {
                assertEq(actual.startHeight, _uint(j, originPath, "[1]") * K, "retained origin height");
                uint256 observedAt = _uint(j, originPath, "[2]");
                assertEq(
                    actual.l1BlockNumber,
                    g == 0 ? initialOrigin.l1BlockNumber : 11 + observedAt,
                    "retained origin L1 block"
                );
                assertEq(
                    actual.l1Timestamp,
                    g == 0 ? initialOrigin.l1Timestamp : 1000 + 12 * observedAt,
                    "retained origin timestamp"
                );
            } else {
                assertEq(
                    keccak256(abi.encode(actual)), keccak256(abi.encode(IEtnaInbox.Origin(0, 0, 0))), "unwritten origin"
                );
            }
        }
        for (uint256 h; h <= 4; ++h) {
            string memory record = string.concat(path, ".landings[", vm.toString(h), "]");
            bool exists = vm.parseJsonBool(j, string.concat(record, "[0]"));
            if (exists) {
                _assertLanding(h * K, _record(_uint(j, record, "[2]") * K, _uint(j, record, "[1]"), 0, h * K));
            } else {
                IEtnaInbox.Landing memory empty;
                _assertLanding(h * K, empty);
            }
        }
    }

    /// @dev Captures full bounded public projections, including every origin/record and queue.
    function _publicDigest() private view returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                _inbox().recoveryGeneration(),
                _inbox().recoveryNonce(),
                _inbox().lastCheckpoint(),
                _inbox().activeCommitteeSnapshot()
            )
        );
        for (uint256 h; h <= 4; ++h) {
            digest = keccak256(abi.encode(digest, _inbox().landings(h * K)));
        }
        for (uint256 g; g <= 2; ++g) {
            digest = keccak256(abi.encode(digest, _inbox().origins(g)));
        }
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        return keccak256(abi.encode(digest, head, tail));
    }

    /// @dev Reads a numeric field without reimplementing protocol predicates.
    function _uint(string memory j, string memory path, string memory field) private view returns (uint256) {
        return vm.parseJsonUint(j, string.concat(path, field));
    }
}
