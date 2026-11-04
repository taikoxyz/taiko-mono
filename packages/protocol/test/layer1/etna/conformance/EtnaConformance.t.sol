// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "../EtnaInboxTestBase.sol";
import { EtnaTestConstants } from "../EtnaTestConstants.sol";
import { EtnaTestKeys } from "../EtnaTestKeys.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/src/Test.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

/// @notice A contract without `receive`: an ETH transfer to it fails.
contract ConformanceEtherRejecter { }

/// @notice Submits a forced inclusion and rejects the refund (it has no `receive`).
contract ConformanceRefundRejecter {
    function save(address _inbox, bytes calldata _tx) external payable {
        IEtnaInbox(_inbox).saveForcedInclusion{ value: msg.value }(_tx);
    }
}

/// @title EtnaConformanceTest
/// @notice Replays the historical forced-inclusion and landing vectors from the Etna Lean model
/// against the current contracts.
/// @dev These two historical families retain compatible behavior. They do not establish current
/// lifetime-bond, rules-schedule or Unzen-switch conformance. Current registry admission vectors
/// run separately in `EtnaCurrentRegistryConformance.t.sol`; see `README.md` for the pinned source.
/// @dev The vectors are this suite's own copy, `vectors/*.json` next to this file, schema
/// `etna-conformance-2`. The Etna formal PR (#22292) generates and documents them (`formal/etna`,
/// schema in `testdata/etna_conformance/README.md` there); refresh the copy in `formal/etna` with
/// `lake exe etna-vectors --write <this directory>/vectors --families forced,land --provenance
/// <pushed formal commit>`, which adds only `provenance.formalCommit`. The files record only what
/// the model decides.
///
/// For each vector: deploy the stack with the vector's immutables (keys and owners 1 to
/// `registrySize` registered at block 10, key 1 by account 1 first; Inbox initialized at block
/// 11), replay the setup calls (each must succeed, since the model accepted it), make the call and
/// compare the revert flag, the call's results and the observable state with the model's. The
/// Inbox is read through its getters; landing records and SignalService checkpoints are compared
/// at every grid point up to the highest landed height, so one the model does not have fails too.
/// Every vector runs from the same EVM snapshot. The model's recoveries are owner calls with no
/// exclusions, sent with `rules` 0.
///
/// Mapping: hash atom `n` is `bytes32(n)`; registry key `k` is the consensus key of private key
/// `k`; account `n` is the address `0x10000 + n` (0 is the zero address); the Inbox and registry
/// owner is this contract.
contract EtnaConformanceTest is Test, EtnaTestConstants {
    // ---------------------------------------------------------------
    // JSON shapes (decoded with `parseJsonType`, which matches keys by name). Forge checks a type
    // description against every compiled struct of that name, so each name must be unique in the
    // package (hence the `J` suffix).
    // ---------------------------------------------------------------

    struct DeploymentJ {
        uint256 activationDelay;
        uint256 bountyBps;
        uint256 exitDelay;
        uint256 feeGwei;
        uint256 forfeitBps;
        bool initialized;
        uint256 maxBatchBlocks;
        uint256 minStake;
        bool recipientAccepts;
        uint256 recoveryNonce;
        uint256 registrySize;
        uint256 threshold;
        uint256 unsettled;
        uint256 withdrawalDelay;
    }

    struct LeafJ {
        uint256 comet;
        bool cut;
        uint256 el;
        uint256 head;
        uint256 height;
        uint256 word;
    }

    struct RecordJ {
        uint256 cometHash;
        uint256 elHash;
        uint256 generation;
        uint256 head;
        uint256 height;
        uint256 parentHeight;
    }

    struct SignalJ {
        uint256 hash;
        uint256 height;
        uint256 stateRoot;
    }

    struct OriginJ {
        uint256 generation;
        uint256 height;
        uint256 l1Block;
        uint256 timestamp;
    }

    struct QueueJ {
        bool blank;
        uint256 index;
        uint256 l1Block;
        uint256 timestamp;
    }

    /// @dev The Inbox's scalar observables.
    struct InboxState {
        uint256 checkpointHeight;
        uint256 checkpointHash;
        uint256 generation;
        uint256 recoveryNonce;
        uint256 head;
        uint256 tail;
        uint256 snapshot;
        uint256 feeGwei;
    }

    // ---------------------------------------------------------------
    // The fixed deployment (the vectors' `constants`)
    // ---------------------------------------------------------------

    /// @dev The vector copy, relative to the protocol package root (`foundry.toml` grants read
    /// access to `./test`).
    string private constant _DIR = "/test/layer1/etna/conformance/vectors/";
    string private constant _SCHEMA = "etna-conformance-2";

    string private constant _DEPLOYMENT_TYPE = "DeploymentJ(uint256 activationDelay,uint256 bountyBps,"
        "uint256 exitDelay,uint256 feeGwei,uint256 forfeitBps,bool initialized,uint256 maxBatchBlocks,"
        "uint256 minStake,bool recipientAccepts,uint256 recoveryNonce,uint256 registrySize,"
        "uint256 threshold,uint256 unsettled,uint256 withdrawalDelay)";
    string private constant _LEAF_TYPE =
        "LeafJ(uint256 comet,bool cut,uint256 el,uint256 head,uint256 height,uint256 word)";
    string private constant _RECORD_TYPE = "RecordJ(uint256 cometHash,uint256 elHash,"
        "uint256 generation,uint256 head,uint256 height,uint256 parentHeight)";
    string private constant _SIGNAL_TYPE = "SignalJ(uint256 hash,uint256 height,uint256 stateRoot)";
    string private constant _ORIGIN_TYPE =
        "OriginJ(uint256 generation,uint256 height,uint256 l1Block,uint256 timestamp)";
    string private constant _QUEUE_TYPE =
        "QueueJ(bool blank,uint256 index,uint256 l1Block,uint256 timestamp)";
    uint256 private constant _GRID_INTERVAL = 6;
    uint256 private constant _REGISTERED_AT = 10;
    uint256 private constant _INIT_AT = 11;
    uint256 private constant _TIMESTAMP_BASE = 1_700_000_000;
    uint256 private constant _TIMESTAMP_STEP = 12;
    uint256 private constant _GENESIS_KEY = 1;
    uint256 private constant _GENESIS_OWNER = 1;
    uint256 private constant _EPOCH_LEN_L2 = 10;
    uint256 private constant _FORCED_INCLUSION_DELAY = 3600;
    uint256 private constant _MAX_ANCHOR_AGE = 7200;
    uint256 private constant _VP_UNIT = 1_000_000_000;
    uint256 private constant _N_MAX = 128;
    uint256 private constant _REFERENCE_HASH = 7;
    /// @dev The genesis block hash and state root atoms (`elAtom 0 0`, `rootAtom 0 0`).
    uint256 private constant _GENESIS_HASH = 10_000;
    uint256 private constant _GENESIS_ROOT = 30_000;

    address private constant _FEE_RECIPIENT = address(0xfee);
    address private constant _REMOTE_SIGNAL_SERVICE = address(0xdead);
    /// @dev The account that lands.
    uint256 private constant _LANDER = 20;

    /// @dev Indices of the measured call results.
    uint256 private constant _FEE_WEI = 0;
    uint256 private constant _REFUND = 1;
    uint256 private constant _SWEPT = 2;

    // ---------------------------------------------------------------
    // The current vector's deployment
    // ---------------------------------------------------------------

    MockLandProofVerifier internal verifier;
    ConformanceRefundRejecter internal rejecter;
    TestERC20 internal token;
    address internal inbox;
    EtnaStakingRegistry internal registry;
    SignalService internal signalService;
    address internal recipient;
    /// @dev The highest `lastHeight` this vector landed, which bounds the record and signal checks.
    uint256 internal maxLanded;

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------

    function test_conformance_forced() external {
        _runFamily("forced");
    }

    function test_conformance_land() external {
        _runFamily("land");
    }

    // ---------------------------------------------------------------
    // Driver
    // ---------------------------------------------------------------

    /// @dev Gas metering is paused: a family deploys a fresh stack per vector, far beyond the
    /// block gas limit a test runs under, and no checked rule depends on gas. Memory expansion is
    /// still checked against that limit, which caps this frame near 6 MB, so every loop over
    /// vectors and registrations releases what an iteration allocated (`_release`) unless it
    /// keeps a problem to report.
    function _runFamily(string memory _family) private {
        vm.pauseGasMetering();
        string memory j = vm.readFile(string.concat(vm.projectRoot(), _DIR, _family, ".json"));
        assertEq(vm.parseJsonString(j, ".schema"), _SCHEMA, "schema");
        assertEq(vm.parseJsonString(j, ".family"), _family, "family");
        _checkProvenance(vm.parseJsonString(j, ".provenance.formalCommit"));
        _checkConstants(j);

        // The copy holds exactly `vectorCount` vectors, at least one, so the suite cannot pass on
        // an empty or truncated file.
        uint256 count = vm.parseJsonUint(j, ".vectorCount");
        assertGt(count, 0, "vectorCount");
        assertTrue(_hasVector(j, count - 1), "the last vector is missing");
        assertFalse(_hasVector(j, count), "vectors beyond vectorCount");

        string memory report;
        uint256 failures;
        uint256 base = vm.snapshotState();
        for (uint256 i; i < count; ++i) {
            uint256 mark = _freeMemory();
            string memory v = string.concat(".vectors[", vm.toString(i), "]");
            string memory problem = _runVector(j, v);
            if (bytes(problem).length != 0) {
                ++failures;
                report = string.concat(
                    report, "\n", vm.parseJsonString(j, string.concat(v, ".id")), ":", problem
                );
            } else {
                _release(mark);
            }
            vm.revertToState(base);
        }
        emit log_named_uint(string.concat(_family, " vectors"), count);
        assertEq(
            failures, 0, string.concat(_family, " vectors that differ from the model:", report)
        );
    }

    /// @dev Deploys the vector's stack and replays its setup calls; returns a problem if one
    /// reverts.
    function _setup(string memory _j, string memory _v) private returns (string memory) {
        _deploy(
            abi.decode(
                vm.parseJsonType(_j, string.concat(_v, ".setup.deployment"), _DEPLOYMENT_TYPE),
                (DeploymentJ)
            )
        );
        uint256 count = vm.parseJsonUint(_j, string.concat(_v, ".setup.callCount"));
        for (uint256 k; k < count; ++k) {
            string memory c = string.concat(_v, ".setup.calls[", vm.toString(k), "]");
            (bool setupOk,) = _exec(_j, c);
            if (!setupOk) {
                return string.concat(
                    " setup call ",
                    vm.toString(k),
                    " (",
                    vm.parseJsonString(_j, string.concat(c, ".fn")),
                    ") reverted"
                );
            }
        }
        return "";
    }

    function _runVector(
        string memory _j,
        string memory _v
    )
        private
        returns (string memory problem_)
    {
        problem_ = _setup(_j, _v);
        if (bytes(problem_).length != 0) return problem_;
        (bool ok, uint256[3] memory got) = _exec(_j, string.concat(_v, ".call"));
        string memory e = string.concat(_v, ".expect");
        bool wantRevert = vm.parseJsonBool(_j, string.concat(e, ".revert"));
        if (ok == wantRevert) {
            return wantRevert
                ? " expected a revert, the call succeeded"
                : " expected success, the call reverted";
        }
        problem_ = _checkResult(_j, string.concat(e, ".result"), got);
        string memory o = string.concat(e, ".observable");
        if (vm.keyExistsJson(_j, string.concat(o, ".inbox"))) {
            problem_ = string.concat(problem_, _checkInbox(_j, string.concat(o, ".inbox")));
        }
    }

    function _hasVector(string memory _j, uint256 _i) private view returns (bool) {
        return vm.keyExistsJson(_j, string.concat(".vectors[", vm.toString(_i), "].id"));
    }

    /// @dev The provenance is the 40-digit lowercase hex formal commit the copy was generated at.
    function _checkProvenance(string memory _commit) private pure {
        bytes memory b = bytes(_commit);
        assertEq(b.length, 40, "provenance.formalCommit length");
        for (uint256 i; i < b.length; ++i) {
            bool hex_ = (b[i] >= "0" && b[i] <= "9") || (b[i] >= "a" && b[i] <= "f");
            assertTrue(hex_, "provenance.formalCommit is not lowercase hex");
        }
    }

    function _checkConstants(string memory _j) private pure {
        string memory c = ".constants";
        assertEq(_u(_j, c, ".gridInterval"), _GRID_INTERVAL, "gridInterval");
        assertEq(_u(_j, c, ".registeredAt"), _REGISTERED_AT, "registeredAt");
        assertEq(_u(_j, c, ".initAt"), _INIT_AT, "initAt");
        assertEq(_u(_j, c, ".timestampBase"), _TIMESTAMP_BASE, "timestampBase");
        assertEq(_u(_j, c, ".timestampStep"), _TIMESTAMP_STEP, "timestampStep");
        assertEq(_u(_j, c, ".genesisKey"), _GENESIS_KEY, "genesisKey");
        assertEq(_u(_j, c, ".genesisOwner"), _GENESIS_OWNER, "genesisOwner");
        assertEq(_u(_j, c, ".epochLenL2"), _EPOCH_LEN_L2, "epochLenL2");
        assertEq(_u(_j, c, ".forcedInclusionDelay"), _FORCED_INCLUSION_DELAY, "delay");
        assertEq(_u(_j, c, ".maxAnchorAge"), _MAX_ANCHOR_AGE, "maxAnchorAge");
        assertEq(_u(_j, c, ".vpUnit"), _VP_UNIT, "vpUnit");
        assertEq(_u(_j, c, ".sMin"), _VP_UNIT, "sMin");
        assertEq(_u(_j, c, ".nMax"), _N_MAX, "nMax");
        assertEq(_u(_j, c, ".referenceHash"), _REFERENCE_HASH, "referenceHash");
    }

    // ---------------------------------------------------------------
    // Deployment
    // ---------------------------------------------------------------

    function _deploy(DeploymentJ memory _d) private {
        require(_d.initialized && _d.recoveryNonce == 0, "unsupported deployment");
        vm.roll(_REGISTERED_AT);
        vm.warp(_timestamp(_REGISTERED_AT));
        verifier = new MockLandProofVerifier();
        rejecter = new ConformanceRefundRejecter();
        token = new TestERC20("Taiko Token", "TAIKO");
        inbox = address(
            new ERC1967Proxy(
                address(new EtnaInboxBootstrap()),
                abi.encodeCall(EtnaInboxBootstrap.init, (address(this)))
            )
        );
        registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(new EtnaStakingRegistry(_registryConfigOf(_d))),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
        // Key and owner k take bond k - 1, all in the genesis cutoff block.
        for (uint256 k = _GENESIS_KEY; k <= _d.registrySize; ++k) {
            uint256 mark = _freeMemory();
            _register(_account(k), k, _d.minStake);
            _release(mark);
        }

        vm.roll(_INIT_AT);
        vm.warp(_timestamp(_INIT_AT));
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(new SignalService(inbox, _REMOTE_SIGNAL_SERVICE, address(0))),
                    abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        recipient = _d.recipientAccepts ? _FEE_RECIPIENT : address(new ConformanceEtherRejecter());
        EtnaInbox inboxImpl = new EtnaInbox(
            IEtnaInbox.Config({
                proofVerifier: address(verifier),
                signalService: address(signalService),
                stakingRegistry: address(registry),
                l2ChainId: L2_CHAIN_ID,
                maxBatchBlocks: uint64(_d.maxBatchBlocks),
                forcedInclusionFeeInGwei: uint64(_d.feeGwei),
                forcedInclusionFeeDoubleThreshold: uint64(_d.threshold),
                protocolFeeRecipient: recipient,
                originWriter: address(0),
                unzenInbox: address(0),
                etnaForkTime: 0
            })
        );
        EssentialContract(inbox)
            .upgradeToAndCall(
                address(inboxImpl), abi.encodeCall(EtnaInbox.init, (_initParams(_d.unsettled)))
            );
    }

    function _registryConfigOf(DeploymentJ memory _d)
        private
        view
        returns (IEtnaStakingRegistry.Config memory)
    {
        return IEtnaStakingRegistry.Config({
            token: address(token),
            minStake: _d.minStake,
            activationDelay: _d.activationDelay,
            exitDelay: _d.exitDelay,
            withdrawalDelay: _d.withdrawalDelay,
            slashBountyBps: _d.bountyBps,
            slashSink: SLASH_SINK,
            l2ChainId: L2_CHAIN_ID,
            inbox: inbox,
            forfeitBps: _d.forfeitBps
        });
    }

    function _initParams(uint256 _unsettled) private pure returns (IEtnaInbox.InitParams memory) {
        return IEtnaInbox.InitParams({
            genesisBlockHash: bytes32(_GENESIS_HASH),
            genesisStateRoot: bytes32(_GENESIS_ROOT),
            epochLenL2: _EPOCH_LEN_L2,
            genesisCutoff: _REGISTERED_AT,
            committeeRecordHash: keccak256("etna conformance committee 0"),
            committeeConfig: IEtnaInbox.CommitteeConfig({
                vpUnit: _VP_UNIT, sMin: _VP_UNIT, nMax: _N_MAX, unsettledLimit: _unsettled
            }),
            forcedInclusionDelay: _FORCED_INCLUSION_DELAY,
            maxAnchorAge: _MAX_ANCHOR_AGE
        });
    }

    // ---------------------------------------------------------------
    // Calls
    // ---------------------------------------------------------------

    /// @dev Runs the call at path `_c` at its block and timestamp; returns whether it succeeded
    /// and the measured results.
    function _exec(
        string memory _j,
        string memory _c
    )
        private
        returns (bool ok_, uint256[3] memory got_)
    {
        vm.roll(_u(_j, _c, ".block"));
        vm.warp(_u(_j, _c, ".timestamp"));
        bytes32 fn = keccak256(bytes(vm.parseJsonString(_j, string.concat(_c, ".fn"))));
        string memory a = string.concat(_c, ".args");
        if (fn == keccak256("land")) return (_land(_j, a), got_);
        if (fn == keccak256("saveForcedInclusion")) return _save(_j, a);
        if (fn == keccak256("sweepProtocolFees")) return _sweep(_j, a);
        if (fn == keccak256("forceETH")) {
            vm.deal(inbox, inbox.balance + _u(_j, a, ".amount"));
            return (true, got_);
        }
        if (fn == keccak256("recover")) return (_recover(_j, a), got_);
        revert("unknown fn");
    }

    function _land(string memory _j, string memory _a) private returns (bool ok_) {
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            parentHeight: _u(_j, _a, ".parentHeight"),
            lastHeight: _u(_j, _a, ".lastHeight"),
            lastBlockHash: bytes32(_u(_j, _a, ".lastBlockHash")),
            lastCometHash: bytes32(_u(_j, _a, ".lastCometHash")),
            lastStateRoot: bytes32(_u(_j, _a, ".lastStateRoot")),
            l1ReferenceBlockNumber: _u(_j, _a, ".l1ReferenceBlockNumber"),
            forcedInclusionHead: _u(_j, _a, ".forcedInclusionHead"),
            activeCommitteeSnapshot: _u(_j, _a, ".activeCommitteeSnapshot")
        });
        bytes32[] memory leaves = _leaves(_j, string.concat(_a, ".leaves"));
        require(leaves.length == _u(_j, _a, ".leafCount"), "leafCount");

        uint256 ref = input.l1ReferenceBlockNumber;
        if (ref < block.number && block.number - ref <= 256) {
            vm.setBlockhash(
                ref, _bool(_j, _a, ".refAvailable") ? bytes32(_REFERENCE_HASH) : bytes32(0)
            );
        }
        bytes32[] memory blobs = new bytes32[](_u(_j, _a, ".blobs"));
        for (uint256 i; i < blobs.length; ++i) {
            blobs[i] = bytes32((uint256(1) << 248) | (i + 1));
        }
        vm.blobhashes(blobs);
        verifier.setRejects(!_bool(_j, _a, ".proofsOK"));

        vm.prank(_account(_LANDER));
        ok_ = _call(inbox, abi.encodeCall(IEtnaInbox.land, (input, leaves, bytes("proof"))));
        if (ok_ && input.lastHeight > maxLanded) maxLanded = input.lastHeight;
    }

    /// @dev A cut leaf is cutLeaf(x) = keccak256(abi.encode(x, elHash, cometHash, head)); a word
    /// is `bytes32(word)`.
    function _leaves(
        string memory _j,
        string memory _path
    )
        private
        pure
        returns (bytes32[] memory leaves_)
    {
        LeafJ[] memory raw = abi.decode(vm.parseJsonTypeArray(_j, _path, _LEAF_TYPE), (LeafJ[]));
        leaves_ = new bytes32[](raw.length);
        for (uint256 i; i < raw.length; ++i) {
            leaves_[i] = raw[i].cut
                ? keccak256(
                    abi.encode(
                        raw[i].height, bytes32(raw[i].el), bytes32(raw[i].comet), raw[i].head
                    )
                )
                : bytes32(raw[i].word);
        }
    }

    function _save(
        string memory _j,
        string memory _a
    )
        private
        returns (bool ok_, uint256[3] memory got_)
    {
        address caller = _account(_u(_j, _a, ".caller"));
        uint256 paid = _u(_j, _a, ".paid");
        (, uint48 tail) = IEtnaInbox(inbox).getForcedInclusionState();
        bytes memory txBytes = new bytes(_u(_j, _a, ".rawBytes"));
        for (uint256 i; i < txBytes.length; ++i) {
            txBytes[i] = bytes1(uint8(tail + 1));
        }
        uint256 before = inbox.balance;
        if (_bool(_j, _a, ".refundOK")) {
            vm.deal(caller, paid);
            vm.prank(caller);
            (ok_,) = _call(inbox, paid, abi.encodeCall(IEtnaInbox.saveForcedInclusion, (txBytes)));
            got_[_REFUND] = caller.balance;
        } else {
            vm.deal(address(this), paid);
            (ok_,) = _call(
                address(rejecter),
                paid,
                abi.encodeCall(ConformanceRefundRejecter.save, (inbox, txBytes))
            );
            got_[_REFUND] = address(rejecter).balance;
        }
        got_[_FEE_WEI] = inbox.balance - before;
    }

    function _sweep(
        string memory _j,
        string memory _a
    )
        private
        returns (bool ok_, uint256[3] memory got_)
    {
        uint256 before = recipient.balance;
        vm.prank(_account(_u(_j, _a, ".caller")));
        ok_ = _call(inbox, abi.encodeCall(IEtnaInbox.sweepProtocolFees, ()));
        got_[_SWEPT] = recipient.balance - before;
    }

    /// @dev The model's recoveries are owner calls with no exclusions; `rules` is 0.
    function _recover(string memory _j, string memory _a) private returns (bool ok_) {
        require(_bool(_j, _a, ".owner"), "recover by a non-owner");
        require(!vm.keyExistsJson(_j, string.concat(_a, ".exclusions[0]")), "exclusions");
        ok_ = _call(
            inbox,
            abi.encodeCall(
                IEtnaInbox.recover,
                (
                    uint48(_u(_j, _a, ".expectedGeneration")),
                    _u(_j, _a, ".expectedC"),
                    _u(_j, _a, ".expectedRecoveryNonce"),
                    _u(_j, _a, ".validUntil"),
                    new IEtnaInbox.Exclusion[](0),
                    vm.parseJsonUintArray(_j, string.concat(_a, ".fiToClear")),
                    uint48(0)
                )
            )
        );
    }

    function _register(address _caller, uint256 _key, uint256 _amount) private {
        _fund(_caller, _amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(_key);
        bytes memory pop = EtnaTestKeys.popSig(_key, registry, _caller);
        vm.prank(_caller);
        registry.register(publicKey, _amount, pop);
    }

    function _call(address _target, bytes memory _data) private returns (bool ok_) {
        (ok_,) = _call(_target, 0, _data);
    }

    function _call(
        address _target,
        uint256 _value,
        bytes memory _data
    )
        private
        returns (bool ok_, bytes memory ret_)
    {
        (ok_, ret_) = _target.call{ value: _value }(_data);
    }

    /// @dev Mints `_amount` to `_who`, who approves the registry for it.
    function _fund(address _who, uint256 _amount) private {
        token.mint(_who, _amount);
        vm.prank(_who);
        token.approve(address(registry), _amount);
    }

    // ---------------------------------------------------------------
    // Expectations
    // ---------------------------------------------------------------

    function _checkResult(
        string memory _j,
        string memory _r,
        uint256[3] memory _got
    )
        private
        pure
        returns (string memory p_)
    {
        string[] memory keys = vm.parseJsonKeys(_j, _r);
        for (uint256 i; i < keys.length; ++i) {
            p_ = string.concat(
                p_,
                _cmp(
                    keys[i],
                    vm.parseJsonUint(_j, string.concat(_r, ".", keys[i])),
                    _got[_resultIndex(keys[i])]
                )
            );
        }
    }

    function _resultIndex(string memory _key) private pure returns (uint256) {
        bytes32 k = keccak256(bytes(_key));
        if (k == keccak256("feeWei")) return _FEE_WEI;
        if (k == keccak256("refund")) return _REFUND;
        if (k == keccak256("swept")) return _SWEPT;
        revert("unknown result");
    }

    function _checkInbox(
        string memory _j,
        string memory _o
    )
        private
        view
        returns (string memory p_)
    {
        InboxState memory s = _inboxState();
        p_ = string.concat(
            _cmp("inbox.checkpointHeight", _u(_j, _o, ".checkpointHeight"), s.checkpointHeight),
            _cmp("inbox.checkpointHash", _u(_j, _o, ".checkpointHash"), s.checkpointHash),
            _cmp("inbox.generation", _u(_j, _o, ".generation"), s.generation),
            _cmp("inbox.recoveryNonce", _u(_j, _o, ".recoveryNonce"), s.recoveryNonce),
            _cmp("inbox.head", _u(_j, _o, ".head"), s.head),
            _cmp("inbox.tail", _u(_j, _o, ".tail"), s.tail)
        );
        p_ = string.concat(
            p_,
            _cmp("inbox.snapshot", _u(_j, _o, ".snapshot"), s.snapshot),
            _cmp("inbox.ethBalance", _u(_j, _o, ".ethBalance"), inbox.balance),
            _cmp("inbox.swept", _u(_j, _o, ".swept"), recipient.balance),
            _cmp("inbox.feeGwei", _u(_j, _o, ".feeGwei"), s.feeGwei)
        );
        uint256 maxHeight = maxLanded > s.checkpointHeight ? maxLanded : s.checkpointHeight;
        p_ = string.concat(
            p_,
            _checkRecords(_j, string.concat(_o, ".records"), maxHeight),
            _checkSignals(_j, string.concat(_o, ".signals"), maxHeight),
            _checkOrigins(_j, string.concat(_o, ".origins")),
            _checkQueue(_j, string.concat(_o, ".queue"))
        );
    }

    /// @dev The Inbox's scalar observables, from its getters.
    function _inboxState() private view returns (InboxState memory s_) {
        IEtnaInbox ib = IEtnaInbox(inbox);
        IEtnaInbox.LandedCheckpoint memory checkpoint = ib.lastCheckpoint();
        (uint48 head, uint48 tail) = ib.getForcedInclusionState();
        s_ = InboxState({
            checkpointHeight: checkpoint.height,
            checkpointHash: uint256(checkpoint.blockHash),
            generation: ib.recoveryGeneration(),
            recoveryNonce: ib.recoveryNonce(),
            head: head,
            tail: tail,
            snapshot: ib.activeCommitteeSnapshot(),
            feeGwei: ib.getCurrentForcedInclusionFee()
        });
    }

    /// @dev Compares the model's landing records with the contract's, and checks that every
    /// other grid point up to `_maxHeight` has no record.
    function _checkRecords(
        string memory _j,
        string memory _path,
        uint256 _maxHeight
    )
        private
        view
        returns (string memory p_)
    {
        RecordJ[] memory records =
            abi.decode(vm.parseJsonTypeArray(_j, _path, _RECORD_TYPE), (RecordJ[]));
        for (uint256 h; h <= _maxHeight; h += _GRID_INTERVAL) {
            RecordJ memory r;
            for (uint256 i; i < records.length; ++i) {
                if (records[i].height == h) r = records[i];
            }
            IEtnaInbox.Landing memory l = IEtnaInbox(inbox).landings(h);
            string memory at = string.concat("landings[", vm.toString(h), "].");
            p_ = string.concat(
                p_,
                _cmp(string.concat(at, "parentHeight"), r.parentHeight, l.parentHeight),
                _cmp(string.concat(at, "generation"), r.generation, l.generation),
                _cmp(string.concat(at, "head"), r.head, l.head),
                _cmp(string.concat(at, "elHash"), r.elHash, uint256(l.elHash)),
                _cmp(string.concat(at, "cometHash"), r.cometHash, uint256(l.cometHash))
            );
        }
        for (uint256 i; i < records.length; ++i) {
            if (records[i].height > _maxHeight || records[i].height % _GRID_INTERVAL != 0) {
                p_ = string.concat(p_, " record at ", vm.toString(records[i].height), " unchecked;");
            }
        }
    }

    /// @dev Compares the model's SignalService checkpoints with the contract's, and checks that
    /// every other grid point up to `_maxHeight` has none.
    function _checkSignals(
        string memory _j,
        string memory _path,
        uint256 _maxHeight
    )
        private
        view
        returns (string memory p_)
    {
        SignalJ[] memory signals =
            abi.decode(vm.parseJsonTypeArray(_j, _path, _SIGNAL_TYPE), (SignalJ[]));
        for (uint256 h; h <= _maxHeight; h += _GRID_INTERVAL) {
            SignalJ memory g;
            for (uint256 i; i < signals.length; ++i) {
                if (signals[i].height == h) g = signals[i];
            }
            ICheckpointStore.Checkpoint memory c;
            try signalService.getCheckpoint(uint48(h)) returns (
                ICheckpointStore.Checkpoint memory found
            ) {
                c = found;
            } catch { }
            string memory at = string.concat("signal[", vm.toString(h), "].");
            p_ = string.concat(
                p_,
                _cmp(string.concat(at, "hash"), g.hash, uint256(c.blockHash)),
                _cmp(string.concat(at, "stateRoot"), g.stateRoot, uint256(c.stateRoot))
            );
        }
        for (uint256 i; i < signals.length; ++i) {
            if (signals[i].height > _maxHeight || signals[i].height % _GRID_INTERVAL != 0) {
                p_ = string.concat(p_, " signal at ", vm.toString(signals[i].height), " unchecked;");
            }
        }
    }

    /// @dev Compares the model's origins with the contract's; the next generation has none.
    function _checkOrigins(
        string memory _j,
        string memory _path
    )
        private
        view
        returns (string memory p_)
    {
        OriginJ[] memory origins =
            abi.decode(vm.parseJsonTypeArray(_j, _path, _ORIGIN_TYPE), (OriginJ[]));
        for (uint256 i; i <= origins.length; ++i) {
            OriginJ memory want;
            if (i < origins.length) want = origins[i];
            uint256 generation = i < origins.length ? origins[i].generation : i;
            IEtnaInbox.Origin memory o = IEtnaInbox(inbox).origins(generation);
            string memory at = string.concat("origins[", vm.toString(generation), "].");
            p_ = string.concat(
                p_,
                _cmp(string.concat(at, "startHeight"), want.height, o.startHeight),
                _cmp(string.concat(at, "l1BlockNumber"), want.l1Block, o.l1BlockNumber),
                _cmp(string.concat(at, "l1Timestamp"), want.timestamp, o.l1Timestamp)
            );
        }
    }

    function _checkQueue(
        string memory _j,
        string memory _path
    )
        private
        view
        returns (string memory p_)
    {
        QueueJ[] memory queue =
            abi.decode(vm.parseJsonTypeArray(_j, _path, _QUEUE_TYPE), (QueueJ[]));
        for (uint256 i; i < queue.length; ++i) {
            IEtnaInbox.ForcedInclusion memory f =
                IEtnaInbox(inbox).getForcedInclusion(uint48(queue[i].index));
            string memory at = string.concat("queue[", vm.toString(queue[i].index), "].");
            p_ = string.concat(
                p_,
                _cmp(
                    string.concat(at, "blank"),
                    queue[i].blank ? 1 : 0,
                    f.txHash == keccak256("") ? 1 : 0
                ),
                _cmp(string.concat(at, "timestamp"), queue[i].timestamp, f.timestamp),
                _cmp(string.concat(at, "l1Block"), queue[i].l1Block, f.l1Block)
            );
        }
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _cmp(
        string memory _what,
        uint256 _want,
        uint256 _got
    )
        private
        pure
        returns (string memory)
    {
        if (_want == _got) return "";
        return string.concat(
            " ", _what, " model ", vm.toString(_want), " contract ", vm.toString(_got), ";"
        );
    }

    function _u(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (uint256)
    {
        return vm.parseJsonUint(_j, string.concat(_p, _field));
    }

    function _bool(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (bool)
    {
        return vm.parseJsonBool(_j, string.concat(_p, _field));
    }

    /// @dev The free memory pointer, to `_release` back to once what is allocated after it is dead.
    function _freeMemory() private pure returns (uint256 pointer_) {
        assembly {
            pointer_ := mload(0x40)
        }
    }

    /// @dev Moves the free memory pointer back to `_pointer`; nothing allocated after it may be
    /// used again.
    function _release(uint256 _pointer) private pure {
        assembly {
            mstore(0x40, _pointer)
        }
    }

    /// @dev Account `n` is `0x10000 + n`; account 0 is the zero address.
    function _account(uint256 _n) private pure returns (address) {
        return _n == 0 ? address(0) : address(uint160(0x10000 + _n));
    }

    function _timestamp(uint256 _block) private pure returns (uint256) {
        return _TIMESTAMP_BASE + _TIMESTAMP_STEP * _block;
    }
}
