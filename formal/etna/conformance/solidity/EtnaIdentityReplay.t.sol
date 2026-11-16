// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EtnaInboxTestBase, MockLandProofVerifier} from "../EtnaInboxTestBase.sol";
import {EtnaReplayTestBase} from "./EtnaReplayTestBase.sol";
import {IEtnaInbox} from "src/layer1/etna/iface/IEtnaInbox.sol";
import {IEtnaStakingRegistry} from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import {ICheckpointStore} from "src/shared/signal/ICheckpointStore.sol";

/// @notice Replays actual frozen identity actions with explicit contract/proof responsibilities.
/// @dev Frontier negatives accept the candidate statement, so only the real contract guard
/// can reject them. Origin/generation binding uses separately labeled strict proof mocks.
contract EtnaIdentityReplayTest is EtnaReplayTestBase {
    string private constant FILE = "/test/layer1/etna/conformance/vectors/identity_cases.json";
    IEtnaInbox.LandInput private prepared;
    bytes32[] private preparedLeaves;
    bytes32 private approvedStatement;
    IEtnaInbox.Origin private firstOrigin;

    /// @notice Initializes the symbolic genesis and one real queued FI, then fixes L1 reference.
    function setUp() public override {
        vm.warp(1000);
        EtnaInboxTestBase.setUp();
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisBlockHash = keccak256(abi.encode("EL", uint256(0), uint256(0), "Shared"));
        _upgradeAndInit(inboxImpl, params);
        firstOrigin = _inbox().origins(0);
        vm.deal(Alice, 1 ether);
        uint256 fee = uint256(_inbox().getCurrentForcedInclusionFee()) * 1 gwei;
        vm.prank(Alice);
        _inbox().saveForcedInclusion{value: fee}("Pending");
        vm.roll(11);
        _setReference(10, bytes32(uint256(999)));
        _setBlobCount(2);
    }

    /// @notice Replays20 actual model scenarios, including all88 intermediate observations.
    function test_conformance_identityReplay() external {
        vm.pauseGasMetering();
        string memory j = vm.readFile(string.concat(vm.projectRoot(), FILE));
        assertEq(vm.parseJsonString(j, ".schema"), "etna-identity-replay-1");
        assertEq(vm.parseJsonUint(j, ".grid"), K);
        assertTrue(vm.keyExistsJson(j, ".cases[19].id"));
        assertFalse(vm.keyExistsJson(j, ".cases[20].id"));
        uint256 snapshot = vm.snapshotState();
        for (uint256 i; i < 20; ++i) {
            emit log_string(vm.parseJsonString(j, string.concat(".cases[", vm.toString(i), "].id")));
            this.runCase(j, i);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    /// @notice Executes one original scenario in a bounded external memory frame.
    /// @param j Original actual model receipts.
    /// @param index Selected case index.
    function runCase(string memory j, uint256 index) external {
        require(msg.sender == address(this), "test only");
        string memory prefix = string.concat(".cases[", vm.toString(index), "]");
        string memory kind = vm.parseJsonString(j, string.concat(prefix, ".kind"));
        uint256 length = _same(kind, "Recovery") ? 7 : _same(kind, "Origin") ? 3 : 4;
        for (uint256 step; step < length; ++step) {
            string memory p = string.concat(prefix, ".steps[", vm.toString(step), "]");
            _assertState(j, string.concat(p, ".before"));
            bytes32 beforeState = _rawDigest();
            uint256 op = _u(j, p, ".op");
            bool ok = true;
            if (op == 1) {
                (prepared, preparedLeaves) = _candidate(j, p);
                approvedStatement =
                    _statement(prepared, _inbox().landings(prepared.parentHeight), _cutHash(prepared, preparedLeaves));
            } else if (op == 2 || op == 3 || op == 4 || op == 7) {
                ok = _replayLand(j, p, kind, op);
            } else if (op == 6) {
                vm.roll(12);
                vm.warp(1012);
                _setReference(11, bytes32(uint256(999)));
                vm.resumeGasMetering();
                _inbox()
                    .recover(
                        0,
                        _inbox().lastCheckpoint().height,
                        0,
                        block.timestamp,
                        new IEtnaInbox.Exclusion[](0),
                        new uint256[](0),
                        0
                    );
                vm.pauseGasMetering();
            } else {
                assertTrue(op == 0 || op == 5, "known script operation"); // Init/offchain authorization.
            }
            assertEq(ok, vm.parseJsonBool(j, string.concat(p, ".accepted")), p);
            if (!ok || op == 0 || op == 1 || op == 5) {
                assertEq(_rawDigest(), beforeState, "complete selected abort/offchain equality");
            }
            _assertState(j, string.concat(p, ".after"));
        }
        assertFalse(
            vm.keyExistsJson(j, string.concat(prefix, ".steps[", vm.toString(length), "]")), "unexpected model step"
        );
    }

    /// @dev Original actual land attempt, with responsibility-specific mock approval.
    function _replayLand(string memory j, string memory p, string memory kind, uint256 op) private returns (bool ok) {
        IEtnaInbox.LandInput memory input;
        bytes32[] memory leaves;
        if (op == 3) {
            input = prepared;
            leaves = preparedLeaves;
        } else {
            (input, leaves) = _candidate(j, p);
        }
        bytes32 acceptedStatement = _acceptedStatement(j, p, kind, op, input, leaves);
        bool expected = vm.parseJsonBool(j, string.concat(p, ".accepted"));
        landVerifier.setExpectedStatementHash(acceptedStatement);
        if (expected) _expectLanded(input, leaves);
        bytes memory reason;
        vm.blobhashes(blobHashes);
        vm.resumeGasMetering();
        (ok, reason) = inboxProxy.call(abi.encodeCall(IEtnaInbox.land, (input, leaves, PROOF)));
        vm.pauseGasMetering();
        if (ok) _assertSuccessfulPublication(input);
        bytes4 error = reason.length >= 4 ? bytes4(reason) : bytes4(0);
        if (!expected && _same(kind, "Frontier")) {
            assertEq(
                acceptedStatement,
                _statement(input, _inbox().landings(input.parentHeight), _cutHash(input, leaves)),
                "candidate accepted by verifier"
            );
            assertEq(error, IEtnaInbox.FrontierLeafMismatch.selector, "real frontier guard");
        } else if (!expected) {
            assertEq(error, MockLandProofVerifier.ProofRejected.selector, "labeled strict statement mock");
        }
    }

    /// @dev Keeps contract-frontier tests candidate-accepting and proof tests strict.
    function _acceptedStatement(
        string memory j,
        string memory p,
        string memory kind,
        uint256 op,
        IEtnaInbox.LandInput memory input,
        bytes32[] memory leaves
    ) private view returns (bytes32 statement) {
        statement = _statement(input, _inbox().landings(input.parentHeight), _cutHash(input, leaves));
        if (op == 3 && _same(kind, "Recovery")) {
            assertEq(keccak256(abi.encode(input)), keccak256(abi.encode(prepared)), "original proof input");
            assertEq(keccak256(abi.encode(leaves)), keccak256(abi.encode(preparedLeaves)), "original proof cuts");
            return approvedStatement;
        }
        if (op == 4) {
            // Alternative parent fields are hypothetical proof inputs, not caller-supplied ABI fields.
            bytes32 alternative =
                _statement(input, _modelOrigin(j, string.concat(p, ".identity.publicOrigin")), _cutHash(input, leaves));
            assertNotEq(alternative, statement, "strict alternative-origin premise");
            return alternative;
        }
        if (op == 7) _assertRecoveryGenesis(j, p, input.parentHeight);
    }

    /// @dev Historical public parentVal differs from fresh model-only execution genesis.
    function _assertRecoveryGenesis(string memory j, string memory p, uint256 parent) private view {
        bytes32 publicVal = _token(j, string.concat(p, ".identity.publicOrigin.val"));
        bytes32 executionVal = _token(j, string.concat(p, ".identity.executionOrigin.val"));
        assertEq(_inbox().landings(parent).valStateHash, publicVal);
        assertNotEq(publicVal, executionVal, "fresh genesis is not historical public parentVal");
        assertEq(vm.parseJsonString(j, string.concat(p, ".identity.executionOrigin.val[0]")), "Genesis");
    }

    /// @notice Exercises actual ABI guard granularity absent from the abstract identity model.
    function test_identity_concreteRangeLeafAndOriginGuards() external {
        IEtnaInbox.LandInput memory input = _input(0, 2 * K);
        input.forcedInclusionHead = 0;
        _expectGuard(input, new bytes32[](0), IEtnaInbox.LeafCountMismatch.selector);
        input.parentHeight = K;
        _expectGuard(input, new bytes32[](0), IEtnaInbox.InvalidRange.selector);
        input.parentHeight = 0;
        input.lastHeight = K + 1;
        _expectGuard(input, new bytes32[](0), IEtnaInbox.OffGrid.selector);
        input.lastHeight = 2 * K;
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = bytes32(uint256(777)); // No frontier at c=p=0; guest cuts are mocked.
        landVerifier.setExpectedStatementHash(_statement(input, _inbox().landings(0), _cutHash(input, leaves)));
        vm.blobhashes(blobHashes);
        _inbox().land(input, leaves, PROOF);
        _assertSuccessfulPublication(input);
        input.parentHeight = K;
        input.lastHeight = 3 * K;
        _expectGuard(input, new bytes32[](1), IEtnaInbox.MissingOrigin.selector);
        _inbox().recover(0, 2 * K, 0, block.timestamp, new IEtnaInbox.Exclusion[](0), new uint256[](0), 0);
        input.parentHeight = 0;
        _expectGuard(input, new bytes32[](2), IEtnaInbox.InvalidRange.selector);
    }

    /// @notice Publishes a real activated registry snapshot and the original input's complete checkpoint.
    /// @dev Registration at L1 1 is eligible at 11; public topUp11/activate21 produces snapshot21.
    /// The initial committee/cutoff1 is an imported fixture premise, preceding eligibility11.
    /// Guest validity, committee selection and the anchor witness remain statement-bound mock premises.
    /// This dedicated concrete probe does not alter the frozen identity receipt mapping.
    function test_identity_publicHistoryPublication() external {
        assertEq(block.number, 11);
        assertEq(registryCheckpointBlock, 1);
        assertEq(registry.bondAt(0).entry.activeFromL1, 11);
        assertEq(_inbox().activeCommitteeSnapshot(), 1);
        assertEq(registry.checkpointCount(), 1);
        IEtnaStakingRegistry.Checkpoint memory original = registry.checkpointAt(0);
        assertEq(original.l1Block, 1);
        assertEq(original.entriesRoot, registry.entriesRoot());

        taikoToken.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        taikoToken.approve(address(registry), MIN_STAKE);
        vm.prank(Alice);
        registry.topUp(0, MIN_STAKE);
        (uint256 pending, uint48 readyAt) = registry.topUpOf(0);
        assertEq(pending, MIN_STAKE);
        assertEq(readyAt, 21);
        assertEq(registry.bondAt(0).entry.effStake, MIN_STAKE);
        assertEq(registry.checkpointCount(), 1);
        assertEq(registry.entriesRoot(), original.entriesRoot);

        vm.roll(21);
        vm.warp(1120);
        vm.prank(Bob);
        registry.activateTopUp(0);
        assertEq(registry.bondAt(0).entry.effStake, 2 * MIN_STAKE);
        (pending, readyAt) = registry.topUpOf(0);
        assertEq(pending, 0);
        assertEq(readyAt, 0);
        assertEq(registry.checkpointCount(), 2);
        IEtnaStakingRegistry.Checkpoint memory activated = registry.checkpointAt(1);
        assertEq(activated.l1Block, 21);
        assertEq(activated.entriesRoot, registry.entriesRoot());
        assertNotEq(activated.entriesRoot, original.entriesRoot);
        assertEq(keccak256(abi.encode(registry.checkpointAt(0))), keccak256(abi.encode(original)));
        assertEq(_inbox().activeCommitteeSnapshot(), 1, "activation precedes publication");

        vm.roll(22);
        vm.warp(1132);
        _setReference(21, bytes32(uint256(999)));
        IEtnaInbox.LandInput memory input = _input(0, 2 * K);
        input.activeCommitteeSnapshot = 21;
        input.forcedInclusionHead = 1; // The one real C06 queue item, also committed by the cut at6.
        bytes32[] memory leaves = _leaves(0, 2 * K);
        landVerifier.setExpectedStatementHash(_statement(input, _inbox().landings(0), _cutHash(input, leaves)));
        _land(input, leaves);
        _assertSuccessfulPublication(input);
        _assertCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertQueue(1, 1);
        assertEq(registry.entriesRoot(), activated.entriesRoot, "landing preserves activated registry");
    }

    /// @dev Reads original exported supplied cuts and terminal; never recreates model guards.
    function _candidate(string memory j, string memory p)
        private
        view
        returns (IEtnaInbox.LandInput memory input, bytes32[] memory leaves)
    {
        uint256 parent = _u(j, p, ".proof.parent");
        uint256 terminal = _u(j, p, ".proof.terminal");
        string memory t = string.concat(p, ".terminal");
        input = IEtnaInbox.LandInput({
            parentHeight: parent * K,
            lastHeight: terminal * K,
            lastBlockHash: _token(j, string.concat(t, ".el")),
            lastCometHash: _token(j, string.concat(t, ".comet")),
            lastValStateHash: _token(j, string.concat(t, ".val")),
            lastStateRoot: bytes32(900 + terminal + 100 * _u(j, p, ".proof.generation")),
            l1ReferenceBlockNumber: l1ReferenceBlockNumber,
            forcedInclusionHead: _u(j, t, ".fi"),
            activeCommitteeSnapshot: 4
        });
        leaves = new bytes32[](terminal - parent - 1);
        for (uint256 i = parent + 1; i < terminal; ++i) {
            string memory cut = string.concat(p, ".cuts.", vm.toString(i));
            leaves[i - parent - 1] = _cutLeaf(j, cut);
        }
    }

    /// @dev Concrete canonical leaf for one original model cut.
    function _cutLeaf(string memory j, string memory p) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _u(j, p, ".height") * K,
                _token(j, string.concat(p, ".el")),
                _token(j, string.concat(p, ".comet")),
                _u(j, p, ".fi"),
                _token(j, string.concat(p, ".val"))
            )
        );
    }

    /// @dev Maps injective symbolic hash tokens; physical genesis Comet/Val are zero.
    function _token(string memory j, string memory p) private view returns (bytes32) {
        string memory kind = vm.parseJsonString(j, string.concat(p, "[0]"));
        uint256 generation = _u(j, p, "[1]");
        if (_same(kind, "Genesis")) return keccak256(abi.encode(kind, generation));
        uint256 height = _u(j, p, "[2]");
        string memory tag = vm.parseJsonString(j, string.concat(p, "[3]"));
        if (generation == 0 && height == 0 && _same(tag, "Shared") && (_same(kind, "Comet") || _same(kind, "Val"))) {
            return bytes32(0);
        }
        return keccak256(abi.encode(kind, generation, height, tag));
    }

    /// @dev The hypothetical proof's parent cut; generation/parent metadata are not statement words.
    function _modelOrigin(string memory j, string memory p) private view returns (IEtnaInbox.Landing memory r) {
        r.elHash = _token(j, string.concat(p, ".el"));
        r.cometHash = _token(j, string.concat(p, ".comet"));
        r.valStateHash = _token(j, string.concat(p, ".val"));
        r.head = uint48(_u(j, p, ".fi"));
    }

    /// @dev Compares every bounded retained record and mapped checkpoint/origin/queue identity.
    function _assertState(string memory j, string memory p) private view {
        uint256 c = _u(j, p, ".checkpoint");
        _assertCheckpoint(c * K, _token(j, string.concat(p, ".records.", vm.toString(c), ".cut.el")));
        uint256 generation = _u(j, p, ".generation");
        assertEq(_inbox().recoveryGeneration(), generation);
        assertEq(_inbox().recoveryNonce(), _u(j, p, ".nonce"));
        assertEq(_inbox().origins(generation).startHeight, _u(j, p, ".start") * K);
        assertEq(keccak256(abi.encode(_inbox().origins(0))), keccak256(abi.encode(firstOrigin)));
        IEtnaInbox.Origin memory recovered = _inbox().origins(1);
        assertEq(recovered.startHeight, generation == 0 ? 0 : K);
        assertEq(recovered.l1BlockNumber, generation == 0 ? 0 : 12);
        assertEq(recovered.l1Timestamp, generation == 0 ? 0 : 1012);
        for (uint256 h; h <= 3; ++h) {
            string memory r = string.concat(p, ".records.", vm.toString(h));
            IEtnaInbox.Landing memory expected;
            if (vm.parseJsonBool(j, string.concat(r, ".present"))) {
                expected = _modelOrigin(j, string.concat(r, ".cut"));
                expected.parentHeight = uint48(_u(j, r, ".parent") * K);
                expected.generation = uint48(_u(j, r, ".generation"));
            }
            _assertLanding(h * K, expected);
        }
        _assertQueue(_u(j, p, string.concat(".records.", vm.toString(c), ".cut.fi")), 1);
        IEtnaInbox.ForcedInclusion memory fi = _inbox().getForcedInclusion(0);
        assertEq(fi.txHash, keccak256("Pending"));
        assertEq(fi.timestamp, 1000);
        assertEq(fi.l1Block, firstOrigin.l1BlockNumber);
    }

    /// @dev Success event binds original proof parent and actual latest checkpoint parent.
    function _expectLanded(IEtnaInbox.LandInput memory input, bytes32[] memory leaves) private {
        bytes32 cutHash = _cutHash(input, leaves);
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.Landed(
            input.parentHeight,
            _inbox().lastCheckpoint().height,
            input.lastHeight,
            cutHash,
            input.activeCommitteeSnapshot,
            1
        );
    }

    /// @dev Candidate-accepting mock makes exact early guard rejection observable.
    function _expectGuard(IEtnaInbox.LandInput memory input, bytes32[] memory leaves, bytes4 error) private {
        landVerifier.setExpectedStatementHash(
            _statement(input, _inbox().landings(input.parentHeight), _cutHash(input, leaves))
        );
        bytes32 beforeState = _rawDigest();
        vm.blobhashes(blobHashes);
        vm.expectRevert(error);
        _inbox().land(input, leaves, PROOF);
        assertEq(_rawDigest(), beforeState, "concrete guard abort equality");
    }

    /// @dev All selected raw public state, fee/custody and bounded SignalService records.
    function _rawDigest() private view returns (bytes32 value) {
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        value = keccak256(
            abi.encode(
                _inbox().lastCheckpoint(),
                _inbox().recoveryGeneration(),
                _inbox().recoveryNonce(),
                _inbox().rulesSchedule(),
                _inbox().activeCommitteeSnapshot(),
                head,
                tail,
                _inbox().genesis(),
                address(inboxProxy).balance,
                taikoToken.balanceOf(address(registry)),
                registry.entriesRoot()
            )
        );
        for (uint256 g; g < 2; ++g) {
            value = keccak256(abi.encode(value, _inbox().origins(g)));
        }
        for (uint256 h; h <= 3; ++h) {
            (bool exists, bytes memory checkpoint) =
                address(signalService).staticcall(abi.encodeCall(ICheckpointStore.getCheckpoint, (uint48(h * K))));
            value = keccak256(
                abi.encode(value, _inbox().landings(h * K), exists, checkpoint, _inbox().getForcedInclusion(uint48(h)))
            );
        }
    }

    /// @dev Reads one original numeric observation.
    function _u(string memory j, string memory p, string memory f) private view returns (uint256) {
        return vm.parseJsonUint(j, string.concat(p, f));
    }

    /// @dev Exact symbolic label equality, without protocol predicates.
    function _same(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
