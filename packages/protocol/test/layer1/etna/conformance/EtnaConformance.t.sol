// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "../EtnaInboxTestBase.sol";
import { EtnaTestConstants } from "../EtnaTestConstants.sol";
import { EtnaTestKeys } from "../EtnaTestKeys.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/src/Test.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";
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
/// @notice Runs the behavioral conformance vectors that the Etna Lean model generates against the
/// Etna contracts.
/// @dev The vectors are this suite's own copy, `vectors/*.json` next to this file, schema
/// `etna-conformance-2`. The Etna formal PR (#22292) generates and documents them (`formal/etna`,
/// schema in `testdata/etna_conformance/README.md` there); refresh the copy in `formal/etna` with
/// `lake exe etna-vectors --write <this directory>/vectors --families forced,land,recover,registry
/// --provenance <pushed formal commit>`, which adds only `provenance.formalCommit`. The files
/// record only what the model decides.
///
/// For each vector: deploy the stack with the vector's immutables (keys and owners 1 to
/// `registrySize` registered at block 10, key 1 by account 1 first; Inbox initialized at block 11
/// unless the vector says not; a non-zero `recoveryNonce` is written to slot 292), replay the
/// setup calls (each must succeed, since the model accepted it), make the call and compare the
/// revert flag, the call's results and the observable state with the model's. The Inbox is read
/// through its getters, or before `init` through its appendix B slots, which the bootstrap never
/// writes; landing records and SignalService checkpoints are compared at every grid point up to
/// the highest landed height, so one the model does not have fails too. The registry is compared
/// in full: every checkpoint (its entries root recomputed from the model's election entries),
/// every bond and the forfeiture flags. Every vector runs from the same EVM snapshot.
///
/// A vector in this suite's known-divergence list (`_knownDivergences`) is checked against the
/// contract behaviour recorded there instead and is reported; each entry must name a vector of its
/// family and must differ from the model's decision or observable, so a fixed divergence fails the
/// suite until its entry is removed.
///
/// Mapping: hash atom `n` is `bytes32(n)`; registry key `k` is the consensus key of private key
/// `k` (key 0 is a released slot); account `n` is the address `0x10000 + n` (0 is the zero
/// address); the Inbox and registry owner is this contract. The adapter booleans are
/// established, not assumed: `transferOK = false` leaves the top-up caller without an allowance,
/// `externalOK = false` makes the token's transfer to `slashSink` revert, and
/// `verifierFailureRollback` is the harness's stand-in for the future verifier-replacement
/// upgrade (`_rollback`). An argument that does not fit its ABI type cannot be sent in any
/// transaction; such a call counts as rejected and is logged.
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

    struct ExclusionJ {
        uint256 bondId;
        uint256 key;
    }

    struct VoteJ {
        uint256 blockId;
        bool foreign;
        uint256 generation;
        uint256 height;
        uint256 kind;
        uint256 round;
        uint256 signer;
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

    struct BondJ {
        uint256 activeFrom;
        uint256 confirmedAt;
        uint256 exitAt;
        uint256 id;
        uint256 key;
        uint256 owner;
        uint256 pendingTopUp;
        uint256 stake;
        uint256 topUpReadyAtL1;
    }

    struct EntryJ {
        uint256 activeFrom;
        uint256 exitAt;
        uint256 key;
        uint256 stake;
    }

    struct CheckpointJ {
        uint256 block;
        EntryJ[] entries;
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

    /// @dev A vector on which the contracts are known to differ from the model: the vector id, the
    /// spec rules involved (SPEC.md rule ids), why they differ, and the contract's recorded
    /// behaviour. A decision divergence (`observables` empty) records whether the call reverts,
    /// with which error, or, if `resultKey` is not empty, the one result it returns; observables
    /// are not compared. An observable divergence records the contract's values of the listed
    /// observables (e.g. `inbox.checkpointHash`), each different from the model's; the decision,
    /// the results and every other observable must still match.
    struct KnownDivergence {
        string id;
        string spec;
        string reason;
        bool reverts;
        bytes4 revertSelector;
        string resultKey;
        uint256 resultValue;
        string[] observables;
        uint256[] observedValues;
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
    string private constant _EXCLUSION_TYPE = "ExclusionJ(uint256 bondId,uint256 key)";
    string private constant _VOTE_TYPE = "VoteJ(uint256 blockId,bool foreign,uint256 generation,"
        "uint256 height,uint256 kind,uint256 round,uint256 signer)";
    string private constant _RECORD_TYPE = "RecordJ(uint256 cometHash,uint256 elHash,"
        "uint256 generation,uint256 head,uint256 height,uint256 parentHeight)";
    string private constant _SIGNAL_TYPE = "SignalJ(uint256 hash,uint256 height,uint256 stateRoot)";
    string private constant _ORIGIN_TYPE =
        "OriginJ(uint256 generation,uint256 height,uint256 l1Block,uint256 timestamp)";
    string private constant _QUEUE_TYPE =
        "QueueJ(bool blank,uint256 index,uint256 l1Block,uint256 timestamp)";
    string private constant _BOND_TYPE = "BondJ(uint256 activeFrom,uint256 confirmedAt,"
        "uint256 exitAt,uint256 id,uint256 key,uint256 owner,uint256 pendingTopUp,uint256 stake,"
        "uint256 topUpReadyAtL1)";
    string private constant _CHECKPOINT_TYPE = "CheckpointJ(uint256 block,EntryJ[] entries)"
        "EntryJ(uint256 activeFrom,uint256 exitAt,uint256 key,uint256 stake)";

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
    uint64 private constant _VOTE_SECONDS = 1_700_000_000;
    /// @dev The account that makes the owner-only calls of a vector with `owner = false`.
    uint256 private constant _STRANGER = 21;
    /// @dev The account that lands.
    uint256 private constant _LANDER = 20;

    /// @dev Inbox slots (spec appendix B).
    uint256 private constant _SLOT_GENERATION = 268;
    uint256 private constant _SLOT_CHECKPOINT_HEIGHT = 270;
    uint256 private constant _SLOT_CHECKPOINT_HASH = 271;
    uint256 private constant _SLOT_HEAD_TAIL = 281;
    uint256 private constant _SLOT_SNAPSHOT = 284;
    uint256 private constant _SLOT_LANDINGS = 285;
    uint256 private constant _SLOT_ORIGINS = 290;
    uint256 private constant _SLOT_RECOVERY_NONCE = 292;
    /// @dev SignalService `_checkpoints` (mapping version => block number => record).
    uint256 private constant _SLOT_SIGNAL_CHECKPOINTS = 254;

    /// @dev Indices of the measured call results.
    uint256 private constant _BOND_ID = 0;
    uint256 private constant _FEE_WEI = 1;
    uint256 private constant _REFUND = 2;
    uint256 private constant _SWEPT = 3;
    uint256 private constant _PAID = 4;
    uint256 private constant _BOUNTY = 5;
    uint256 private constant _TO_SINK = 6;

    // ---------------------------------------------------------------
    // The current vector's deployment
    // ---------------------------------------------------------------

    MockLandProofVerifier internal verifier;
    ConformanceRefundRejecter internal rejecter;
    TestERC20 internal token;
    address internal inbox;
    /// @dev The `EtnaInbox` implementation `init` installs; the proxy runs it once initialized.
    EtnaInbox internal inboxImpl;
    EtnaStakingRegistry internal registry;
    SignalService internal signalService;
    address internal recipient;
    /// @dev The highest `lastHeight` this vector landed, which bounds the record and signal checks.
    uint256 internal maxLanded;
    /// @dev The number of calls this family could not encode (see the contract NatSpec).
    uint256 internal unencodable;
    /// @dev The selector of the last call's revert (zero if it succeeded or reverted without one).
    bytes4 internal lastRevert;
    /// @dev The recorded contract values of the observable divergence running now, by name.
    mapping(bytes32 field => bool overridden) internal overridden;
    mapping(bytes32 field => uint256 value) internal overrideValue;

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------

    function test_conformance_forced() external {
        _runFamily("forced");
    }

    function test_conformance_registry() external {
        _runFamily("registry");
    }

    function test_conformance_land() external {
        _runFamily("land");
    }

    function test_conformance_recover() external {
        _runFamily("recover");
    }

    // ---------------------------------------------------------------
    // Known divergences
    // ---------------------------------------------------------------

    /// @dev The vectors of `_family` on which the contracts are known to differ from the model.
    /// Remove an entry once the spec, the model or the contract changes so that the two agree;
    /// the suite fails while a listed vector matches the model.
    function _knownDivergences(string memory _family)
        private
        pure
        returns (KnownDivergence[] memory known_)
    {
        bytes32 family = keccak256(bytes(_family));
        if (family == keccak256("registry")) {
            known_ = new KnownDivergence[](6);
            known_[0] = _returns(
                "registry.hw.free-slot-reuse-order",
                "STAKE-4.1-14",
                "Spec ambiguity: freed slots are reused first, in no stated order. The model's free "
                "list is first in, first out (bond 1, released first, is reused); the contract's "
                "_takeSlot pops the last released id (bond 2).",
                "bondId",
                2
            );
            known_[1] = _reverts(
                "registry.hw.withdraw-to-zero-address",
                "STAKE-4.1-27",
                "Spec ambiguity: the principal is paid to `to`, which the spec does not restrict. "
                "The model's withdraw has no recipient and accepts; the contract reverts "
                "(ZERO_ADDRESS) when the principal is positive.",
                EssentialContract.ZERO_ADDRESS.selector
            );
            known_[2] = _reverts(
                "registry.hw.withdraw-at-block-2pow48-minus1",
                "STAKE-4.1-36, STOR-B-22",
                "Unreachable block: at L1 block 2^48 - 1 the model withdraws; the contract reverts "
                "(InvalidEventBlock) because the withdrawal writes a checkpoint at the current "
                "block and the registry stores no L1 block at or above its no-exit sentinel.",
                IEtnaStakingRegistry.InvalidEventBlock.selector
            );
            known_[3] = _reverts(
                "registry.hw.slash-at-block-2pow48-minus1",
                "STAKE-4.1-34, STOR-B-22",
                "Unreachable block: at L1 block 2^48 - 1 the model slashes and sets exitEffectiveL1 "
                "= min(no exit, 2^48 - 1), the no-exit value; the contract reverts "
                "(InvalidEventBlock) writing that block's checkpoint.",
                IEtnaStakingRegistry.InvalidEventBlock.selector
            );
            known_[4] = _reverts(
                "registry.hw.top-up-ready-block-last-valid",
                "STAKE-4.1-16, STOR-B-30",
                "Unreachable block: a top-up at L1 block 2^48 - 11 with activationDelay 10 is ready "
                "at 2^48 - 1, which fits the uint48 field; the model accepts (only overflow is "
                "rejected), the contract reverts (InvalidEventBlock) because it keeps every stored "
                "block below the no-exit sentinel, readiness included.",
                IEtnaStakingRegistry.InvalidEventBlock.selector
            );
            known_[5] = _observes(
                "registry.hw.pending-only-slash",
                "STAKE-4.1-34, STAKE-4.1-36, STOR-B-33",
                "Spec ambiguity: slashing an entry whose effective stake a forfeiture already "
                "zeroed, and whose exit is already earlier, changes only pending principal. The "
                "model writes no checkpoint for an unchanged entry; the contract's slashDoubleSign "
                "always writes one, so block 22 gets a third checkpoint repeating block 21's count "
                "and root.",
                _pair("registry.checkpointCount", "registry.lastCheckpointBlock"),
                _pair(3, 22)
            );
        } else if (family == keccak256("recover")) {
            known_ = new KnownDivergence[](4);
            known_[0] = _reverts(
                "recover.hw.exclusion-at-block-2pow48-minus1",
                "RECOV-8-41, STAKE-4.1-39, STOR-B-22",
                "Unreachable block: at R = 2^48 - 1 the model accepts and sets the excluded entry's "
                "exitEffectiveL1 to min(no exit, R), the no-exit value, so the entry stays "
                "eligible; the registry's forceExit reverts (InvalidEventBlock), so the whole "
                "recovery reverts.",
                IEtnaStakingRegistry.InvalidEventBlock.selector
            );
            known_[1] = _reverts(
                "recover.hw.origin-timestamp-2pow48",
                "RECOV-8.4-3, STOR-B-13",
                "Spec ambiguity: slot 290 stores R.timestamp as a full word \"with range checks\" "
                "but names no range. The model bounds it only by 2^256; the contract by 2^48 "
                "(ValueOverflow), so a recovery at timestamp 2^48 reverts.",
                IEtnaInbox.ValueOverflow.selector
            );
            known_[2] = _observes(
                "recover.hw.recover-before-initialization",
                "START-10-5, STOR-B-3",
                "Model artifact: before init the model's Inbox already holds the genesis "
                "checkpoint hash (atom 10000), with no record, signal or origin; the proxy still "
                "runs EtnaInboxBootstrap, and slot 271 stays zero until init writes it. Both "
                "reject the call.",
                _one("inbox.checkpointHash"),
                _one(0)
            );
            known_[3] = _observes(
                "recover.hw.invalidation-before-initialization",
                "START-10-5, STOR-B-3",
                "Model artifact: as in recover-before-initialization, the model's uninitialized "
                "Inbox holds the genesis checkpoint hash and slot 271 is zero. Both reject the "
                "call.",
                _one("inbox.checkpointHash"),
                _one(0)
            );
        }
    }

    /// @dev A decision divergence: the contract reverts with `_selector`.
    function _reverts(
        string memory _id,
        string memory _spec,
        string memory _reason,
        bytes4 _selector
    )
        private
        pure
        returns (KnownDivergence memory d_)
    {
        d_.id = _id;
        d_.spec = _spec;
        d_.reason = _reason;
        d_.reverts = true;
        d_.revertSelector = _selector;
    }

    /// @dev A decision divergence: the contract succeeds and its result `_key` is `_value`.
    function _returns(
        string memory _id,
        string memory _spec,
        string memory _reason,
        string memory _key,
        uint256 _value
    )
        private
        pure
        returns (KnownDivergence memory d_)
    {
        d_.id = _id;
        d_.spec = _spec;
        d_.reason = _reason;
        d_.resultKey = _key;
        d_.resultValue = _value;
    }

    /// @dev An observable divergence: the contract's values of `_fields` are `_values`.
    function _observes(
        string memory _id,
        string memory _spec,
        string memory _reason,
        string[] memory _fields,
        uint256[] memory _values
    )
        private
        pure
        returns (KnownDivergence memory d_)
    {
        d_.id = _id;
        d_.spec = _spec;
        d_.reason = _reason;
        d_.observables = _fields;
        d_.observedValues = _values;
    }

    function _one(string memory _a) private pure returns (string[] memory xs_) {
        xs_ = new string[](1);
        xs_[0] = _a;
    }

    function _one(uint256 _a) private pure returns (uint256[] memory xs_) {
        xs_ = new uint256[](1);
        xs_[0] = _a;
    }

    function _pair(string memory _a, string memory _b) private pure returns (string[] memory xs_) {
        xs_ = new string[](2);
        xs_[0] = _a;
        xs_[1] = _b;
    }

    function _pair(uint256 _a, uint256 _b) private pure returns (uint256[] memory xs_) {
        xs_ = new uint256[](2);
        xs_[0] = _a;
        xs_[1] = _b;
    }

    // ---------------------------------------------------------------
    // Driver
    // ---------------------------------------------------------------

    /// @dev Gas metering is paused: a family deploys a fresh stack per vector, far beyond the
    /// block gas limit a test runs under, and no checked rule depends on gas. Memory expansion is
    /// still checked against that limit, which caps this frame near 6 MB, so every loop over
    /// vectors, registrations, bonds and entries releases what an iteration allocated
    /// (`_release`) unless it keeps a problem to report.
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

        KnownDivergence[] memory known = _knownDivergences(_family);
        bool[] memory seen = new bool[](known.length);
        string memory report;
        uint256 failures;
        uint256 divergences;
        uint256 skippedCalls;
        uint256 base = vm.snapshotState();
        for (uint256 i; i < count; ++i) {
            uint256 mark = _freeMemory();
            (string memory id, string memory problem, uint256 index) = _runIndexed(j, i, known);
            if (index < known.length) {
                seen[index] = true;
                ++divergences;
            }
            skippedCalls += unencodable;
            if (bytes(problem).length != 0) {
                ++failures;
                report = string.concat(report, "\n", id, ":", problem);
            } else {
                _release(mark);
            }
            vm.revertToState(base);
        }
        for (uint256 k; k < known.length; ++k) {
            if (!seen[k]) {
                ++failures;
                report = string.concat(report, "\n", known[k].id, ": listed but not in the file");
            }
        }
        emit log_named_uint(string.concat(_family, " vectors"), count);
        emit log_named_uint(string.concat(_family, " known divergences"), divergences);
        emit log_named_uint(
            string.concat(_family, " calls with unencodable arguments"), skippedCalls
        );
        assertEq(
            failures, 0, string.concat(_family, " vectors that differ from the model:", report)
        );
    }

    /// @dev Runs vector `_i`; returns its id, the problems found and its index in `_known`
    /// (`type(uint256).max` if it is not listed).
    function _runIndexed(
        string memory _j,
        uint256 _i,
        KnownDivergence[] memory _known
    )
        private
        returns (string memory id_, string memory problem_, uint256 index_)
    {
        string memory v = string.concat(".vectors[", vm.toString(_i), "]");
        id_ = vm.parseJsonString(_j, string.concat(v, ".id"));
        bool listed;
        (listed, index_) = _findKnown(_known, id_);
        if (!listed) return (id_, _runVector(_j, v), type(uint256).max);
        emit log_named_string(
            "known divergence",
            string.concat(id_, " (", _known[index_].spec, "): ", _known[index_].reason)
        );
        problem_ = _runDivergent(_j, v, _known[index_]);
    }

    /// @dev Runs a vector on the known-divergence list. A decision divergence: the contract must
    /// show exactly the recorded revert (and error) or result, which must differ from the model's
    /// (a record equal to it is stale and must be removed); observables are not compared. An
    /// observable divergence: the vector runs in full with the recorded values in place of the
    /// model's for the listed observables, and the model's value of each must differ.
    function _runDivergent(
        string memory _j,
        string memory _v,
        KnownDivergence memory _d
    )
        private
        returns (string memory problem_)
    {
        if (_d.observables.length != 0) {
            for (uint256 k; k < _d.observables.length; ++k) {
                string memory path = string.concat(_v, ".expect.observable.", _d.observables[k]);
                if (vm.parseJsonUint(_j, path) == _d.observedValues[k]) {
                    return string.concat(
                        " the known divergence records the model's own ", _d.observables[k]
                    );
                }
                bytes32 field = keccak256(bytes(_d.observables[k]));
                overridden[field] = true;
                overrideValue[field] = _d.observedValues[k];
            }
            return _runVector(_j, _v);
        }
        bool modelReverts = vm.parseJsonBool(_j, string.concat(_v, ".expect.revert"));
        string memory modelResult = string.concat(_v, ".expect.result.", _d.resultKey);
        bool sameResult = bytes(_d.resultKey).length == 0
            || (vm.keyExistsJson(_j, modelResult)
                && vm.parseJsonUint(_j, modelResult) == _d.resultValue);
        if (_d.reverts == modelReverts && sameResult) {
            return " the known divergence records the model's own decision";
        }
        problem_ = _setup(_j, _v);
        if (bytes(problem_).length != 0) return problem_;
        (bool ok, uint256[7] memory got) = _exec(_j, string.concat(_v, ".call"));
        if (ok == _d.reverts) {
            return _d.reverts
                ? " the recorded revert is gone: the call succeeded"
                : " the recorded success is gone: the call reverted";
        }
        if (_d.reverts && lastRevert != _d.revertSelector) {
            return string.concat(
                " the call reverted with ",
                vm.toString(abi.encodePacked(lastRevert)),
                ", not the recorded ",
                vm.toString(abi.encodePacked(_d.revertSelector))
            );
        }
        if (!_d.reverts && bytes(_d.resultKey).length != 0) {
            problem_ = _cmp(_d.resultKey, _d.resultValue, got[_resultIndex(_d.resultKey)]);
        }
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
        (bool ok, uint256[7] memory got) = _exec(_j, string.concat(_v, ".call"));
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
        if (vm.keyExistsJson(_j, string.concat(o, ".registry"))) {
            problem_ = string.concat(problem_, _checkRegistry(_j, string.concat(o, ".registry")));
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

    function _findKnown(
        KnownDivergence[] memory _known,
        string memory _id
    )
        private
        pure
        returns (bool found_, uint256 index_)
    {
        for (uint256 k; k < _known.length; ++k) {
            if (keccak256(bytes(_known[k].id)) == keccak256(bytes(_id))) return (true, k);
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
            (bool registered,) = _register(_account(k), k, _d.minStake);
            require(registered, "bootstrap registration");
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
        inboxImpl = new EtnaInbox(
            IEtnaInbox.Config({
                proofVerifier: address(verifier),
                signalService: address(signalService),
                stakingRegistry: address(registry),
                l2ChainId: L2_CHAIN_ID,
                maxBatchBlocks: uint64(_d.maxBatchBlocks),
                forcedInclusionFeeInGwei: uint64(_d.feeGwei),
                forcedInclusionFeeDoubleThreshold: uint64(_d.threshold),
                protocolFeeRecipient: recipient
            })
        );
        if (_d.initialized) {
            EssentialContract(inbox)
                .upgradeToAndCall(
                    address(inboxImpl), abi.encodeCall(EtnaInbox.init, (_initParams(_d.unsettled)))
                );
        }
        // The persistent-state fixture for the nonce's uint256 boundary (slot 292).
        if (_d.recoveryNonce != 0) {
            vm.store(inbox, bytes32(_SLOT_RECOVERY_NONCE), bytes32(_d.recoveryNonce));
        }
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
        returns (bool ok_, uint256[7] memory got_)
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
        if (fn == keccak256("invalidateRecoveryNonce")) return (_invalidate(_j, a), got_);
        if (fn == keccak256("verifierFailureRollback")) return (_rollback(), got_);
        if (fn == keccak256("register")) {
            (ok_, got_[_BOND_ID]) =
                _register(_account(_u(_j, a, ".caller")), _u(_j, a, ".key"), _u(_j, a, ".amount"));
            return (ok_, got_);
        }
        if (fn == keccak256("topUp")) return (_topUp(_j, a), got_);
        if (fn == keccak256("activateTopUp")) {
            return (_registryCall(_j, a, EtnaStakingRegistry.activateTopUp.selector), got_);
        }
        if (fn == keccak256("forfeit")) return _forfeit(_j, a);
        if (fn == keccak256("requestExit")) {
            return (_registryCall(_j, a, EtnaStakingRegistry.requestExit.selector), got_);
        }
        if (fn == keccak256("confirmExit")) {
            return (_registryCall(_j, a, EtnaStakingRegistry.confirmExit.selector), got_);
        }
        if (fn == keccak256("withdraw")) return _withdraw(_j, a);
        if (fn == keccak256("slashDoubleSign")) return _slash(_j, a);
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
        returns (bool ok_, uint256[7] memory got_)
    {
        address caller = _account(_u(_j, _a, ".caller"));
        uint256 paid = _u(_j, _a, ".paid");
        uint48 tail;
        if (IEtnaInbox(inbox).isInitialized()) {
            (, tail) = IEtnaInbox(inbox).getForcedInclusionState();
        }
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
        returns (bool ok_, uint256[7] memory got_)
    {
        uint256 before = recipient.balance;
        vm.prank(_account(_u(_j, _a, ".caller")));
        ok_ = _call(inbox, abi.encodeCall(IEtnaInbox.sweepProtocolFees, ()));
        got_[_SWEPT] = recipient.balance - before;
    }

    function _recover(string memory _j, string memory _a) private returns (bool ok_) {
        // The expected generation (a uint48), nonce and deadline (uint256s).
        uint256[3] memory w;
        bool[2] memory fits;
        w[0] = _u(_j, _a, ".expectedGeneration");
        (fits[0], w[1]) = _word(_j, string.concat(_a, ".expectedRecoveryNonce"));
        (fits[1], w[2]) = _word(_j, string.concat(_a, ".validUntil"));
        if (w[0] > type(uint48).max || !fits[0] || !fits[1]) return _unencodable("recover");
        bytes memory data = abi.encodeCall(
            IEtnaInbox.recover,
            (
                uint48(w[0]),
                _u(_j, _a, ".expectedC"),
                w[1],
                w[2],
                _exclusions(_j, string.concat(_a, ".exclusions")),
                vm.parseJsonUintArray(_j, string.concat(_a, ".fiToClear"))
            )
        );
        if (!_bool(_j, _a, ".owner")) vm.prank(_account(_STRANGER));
        ok_ = _call(inbox, data);
    }

    /// @dev Exclusion `{bondId, key}` names bond `bondId` and the entry key of registry key `key`.
    function _exclusions(
        string memory _j,
        string memory _path
    )
        private
        returns (IEtnaInbox.Exclusion[] memory exclusions_)
    {
        ExclusionJ[] memory raw =
            abi.decode(vm.parseJsonTypeArray(_j, _path, _EXCLUSION_TYPE), (ExclusionJ[]));
        exclusions_ = new IEtnaInbox.Exclusion[](raw.length);
        for (uint256 i; i < raw.length; ++i) {
            exclusions_[i] =
                IEtnaInbox.Exclusion({ bondId: raw[i].bondId, entryKey: _entryKey(raw[i].key) });
        }
    }

    function _invalidate(string memory _j, string memory _a) private returns (bool ok_) {
        (bool fits, uint256 nonce) = _word(_j, string.concat(_a, ".expectedRecoveryNonce"));
        if (!fits) return _unencodable("invalidateRecoveryNonce");
        if (!_bool(_j, _a, ".owner")) vm.prank(_account(_STRANGER));
        ok_ = _call(inbox, abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (nonce)));
    }

    /// @dev The verifier-failure rollback fixture (spec 8): the contracts leave the rollback to
    /// the Inbox upgrade that replaces the verifier, so the harness applies the model's decoded
    /// checked rollback to the target the vectors use, the genesis landing record and the genesis
    /// cutoff. Checks: the Inbox is initialized and its nonce can be incremented (the Inbox lock
    /// is free at the top level). Effects: the checkpoint and the queue head become the record's,
    /// slot 284 the cutoff and the nonce grows by one; landing records and SignalService
    /// checkpoints above the record are voided; every exit confirmation is re-checked against the
    /// restored snapshot and cleared unless that snapshot reaches the entry's exit. Generation,
    /// origins, the queue tail, registry principal and forfeiture flags are untouched.
    function _rollback() private returns (bool) {
        IEtnaInbox ib = IEtnaInbox(inbox);
        if (!ib.isInitialized()) return false;
        uint256 nonce = ib.recoveryNonce();
        if (nonce == type(uint256).max) return false;

        IEtnaInbox.Landing memory trusted = ib.landings(0);
        uint256 snapshot = ib.genesisCutoff();
        uint256 c = ib.lastCheckpoint().height;
        (, uint48 tail) = ib.getForcedInclusionState();
        vm.store(inbox, bytes32(_SLOT_CHECKPOINT_HEIGHT), bytes32(0));
        vm.store(inbox, bytes32(_SLOT_CHECKPOINT_HASH), trusted.elHash);
        vm.store(
            inbox, bytes32(_SLOT_HEAD_TAIL), bytes32((uint256(tail) << 48) | uint256(trusted.head))
        );
        vm.store(inbox, bytes32(_SLOT_SNAPSHOT), bytes32(snapshot));
        vm.store(inbox, bytes32(_SLOT_RECOVERY_NONCE), bytes32(nonce + 1));
        bytes32 signals = keccak256(abi.encode(signalService.VERSION(), _SLOT_SIGNAL_CHECKPOINTS));
        for (uint256 h = _GRID_INTERVAL; h <= c; h += _GRID_INTERVAL) {
            uint256 record = uint256(keccak256(abi.encode(h, _SLOT_LANDINGS)));
            uint256 signal = uint256(keccak256(abi.encode(h, signals)));
            for (uint256 w; w < 3; ++w) {
                vm.store(inbox, bytes32(record + w), 0);
            }
            vm.store(address(signalService), bytes32(signal), 0);
            vm.store(address(signalService), bytes32(signal + 1), 0);
        }
        bytes32 confirmations = _erc7201("taiko.etna.registry.exit-confirmations");
        for (uint256 id; id < registry.entryCount(); ++id) {
            if (
                registry.exitConfirmedAtL1(id) != 0
                    && snapshot < registry.entryAt(id).exitEffectiveL1
            ) {
                vm.store(address(registry), keccak256(abi.encode(id, confirmations)), 0);
            }
        }
        return true;
    }

    function _register(
        address _caller,
        uint256 _key,
        uint256 _amount
    )
        private
        returns (bool ok_, uint256 bondId_)
    {
        _fund(_caller, _amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(_key);
        bytes memory pop = EtnaTestKeys.popSig(_key, registry, _caller);
        vm.prank(_caller);
        bytes memory ret;
        (ok_, ret) = _call(
            address(registry),
            0,
            abi.encodeCall(EtnaStakingRegistry.register, (publicKey, _amount, pop))
        );
        if (ok_) bondId_ = abi.decode(ret, (uint256));
    }

    /// @dev `transferOK = false` leaves the caller without an allowance, so the registry's
    /// token transfer fails.
    function _topUp(string memory _j, string memory _a) private returns (bool ok_) {
        address caller = _account(_u(_j, _a, ".caller"));
        uint256 amount = _u(_j, _a, ".amount");
        if (_bool(_j, _a, ".transferOK")) {
            _fund(caller, amount);
        } else {
            vm.prank(caller);
            token.approve(address(registry), 0);
        }
        vm.prank(caller);
        ok_ = _call(
            address(registry),
            abi.encodeCall(EtnaStakingRegistry.topUp, (_u(_j, _a, ".bondId"), amount))
        );
    }

    /// @dev `externalOK = false` makes the token's transfer to `slashSink` revert. The owner is
    /// this contract.
    function _forfeit(
        string memory _j,
        string memory _a
    )
        private
        returns (bool ok_, uint256[7] memory got_)
    {
        (bool fits, uint256 validUntil) = _word(_j, string.concat(_a, ".validUntil"));
        if (!fits) return (_unencodable("forfeit"), got_);
        bytes memory data = abi.encodeCall(
            EtnaStakingRegistry.forfeit,
            (
                _u(_j, _a, ".bondId"),
                _entryKey(_u(_j, _a, ".entryKey")),
                bytes32(_u(_j, _a, ".incidentId")),
                validUntil
            )
        );
        if (!_bool(_j, _a, ".externalOK")) {
            vm.mockCallRevert(
                address(token),
                abi.encodeWithSelector(IERC20.transfer.selector, SLASH_SINK),
                "slashSink transfer fails"
            );
        }
        uint256 sinkBefore = token.balanceOf(SLASH_SINK);
        if (!_bool(_j, _a, ".owner")) vm.prank(_account(_STRANGER));
        ok_ = _call(address(registry), data);
        vm.clearMockedCalls();
        got_[_TO_SINK] = token.balanceOf(SLASH_SINK) - sinkBefore;
    }

    function _registryCall(
        string memory _j,
        string memory _a,
        bytes4 _selector
    )
        private
        returns (bool ok_)
    {
        vm.prank(_account(_u(_j, _a, ".caller")));
        ok_ = _call(address(registry), abi.encodeWithSelector(_selector, _u(_j, _a, ".bondId")));
    }

    function _withdraw(
        string memory _j,
        string memory _a
    )
        private
        returns (bool ok_, uint256[7] memory got_)
    {
        address to = _account(_u(_j, _a, ".to"));
        uint256 before = token.balanceOf(to);
        vm.prank(_account(_u(_j, _a, ".caller")));
        ok_ = _call(
            address(registry),
            abi.encodeCall(EtnaStakingRegistry.withdraw, (_u(_j, _a, ".bondId"), to))
        );
        got_[_PAID] = token.balanceOf(to) - before;
    }

    function _slash(
        string memory _j,
        string memory _a
    )
        private
        returns (bool ok_, uint256[7] memory got_)
    {
        IEtnaStakingRegistry.Vote memory voteA = _vote(
            abi.decode(vm.parseJsonType(_j, string.concat(_a, ".voteA"), _VOTE_TYPE), (VoteJ))
        );
        IEtnaStakingRegistry.Vote memory voteB = _vote(
            abi.decode(vm.parseJsonType(_j, string.concat(_a, ".voteB"), _VOTE_TYPE), (VoteJ))
        );
        address caller = _account(_u(_j, _a, ".caller"));
        uint256 callerBefore = token.balanceOf(caller);
        uint256 sinkBefore = token.balanceOf(SLASH_SINK);
        bytes memory data = abi.encodeCall(
            EtnaStakingRegistry.slashDoubleSign, (_u(_j, _a, ".bondId"), voteA, voteB)
        );
        vm.prank(caller);
        ok_ = _call(address(registry), data);
        got_[_BOUNTY] = token.balanceOf(caller) - callerBefore;
        got_[_TO_SINK] = token.balanceOf(SLASH_SINK) - sinkBefore;
    }

    /// @dev A vote with a one-part block id (all zero for block id 0), signed by private key
    /// `signer` under this deployment's chain id, or another deployment's if `foreign`.
    function _vote(VoteJ memory _v) private view returns (IEtnaStakingRegistry.Vote memory v_) {
        v_.voteType = uint8(_v.kind);
        v_.height = uint64(_v.height);
        v_.round = uint32(_v.round);
        if (_v.blockId != 0) {
            v_.blockHash = bytes32(_v.blockId);
            v_.partsTotal = 1;
            v_.partsHash = keccak256(abi.encode(_v.blockId));
        }
        v_.timestampSeconds = _VOTE_SECONDS;
        v_.generation = uint48(_v.generation);
        bytes memory chainId = LibCometVote.chainId(
            LibCometVote.chainDomain(
                block.chainid,
                _v.foreign ? L2_CHAIN_ID + 1 : L2_CHAIN_ID,
                inbox,
                uint48(_v.generation)
            )
        );
        v_ = EtnaTestKeys.signVote(_v.signer, v_, chainId);
    }

    /// @dev Calls `_target` and records the selector of its revert in `lastRevert`.
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
        lastRevert = ok_ || ret_.length < 4 ? bytes4(0) : bytes4(ret_);
    }

    /// @dev Mints `_amount` to `_who`, who approves the registry for it. A balance the token's
    /// supply cannot hold (the uint256 boundary vectors) is written directly.
    function _fund(address _who, uint256 _amount) private {
        if (token.totalSupply() <= type(uint256).max - _amount) {
            token.mint(_who, _amount);
        } else {
            deal(address(token), _who, token.balanceOf(_who) + _amount);
        }
        vm.prank(_who);
        token.approve(address(registry), _amount);
    }

    /// @dev Logs a call whose argument does not fit its ABI type and counts it as rejected.
    function _unencodable(string memory _fn) private returns (bool) {
        ++unencodable;
        emit log_named_string("unencodable call, counted as rejected", _fn);
        return false;
    }

    // ---------------------------------------------------------------
    // Expectations
    // ---------------------------------------------------------------

    function _checkResult(
        string memory _j,
        string memory _r,
        uint256[7] memory _got
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
        if (k == keccak256("bondId")) return _BOND_ID;
        if (k == keccak256("feeWei")) return _FEE_WEI;
        if (k == keccak256("refund")) return _REFUND;
        if (k == keccak256("swept")) return _SWEPT;
        if (k == keccak256("paid")) return _PAID;
        if (k == keccak256("bounty")) return _BOUNTY;
        if (k == keccak256("toSink")) return _TO_SINK;
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
            _cmpField(
                "inbox.checkpointHeight", _u(_j, _o, ".checkpointHeight"), s.checkpointHeight
            ),
            _cmpField("inbox.checkpointHash", _u(_j, _o, ".checkpointHash"), s.checkpointHash),
            _cmpField("inbox.generation", _u(_j, _o, ".generation"), s.generation),
            _cmpField("inbox.recoveryNonce", _u(_j, _o, ".recoveryNonce"), s.recoveryNonce),
            _cmpField("inbox.head", _u(_j, _o, ".head"), s.head),
            _cmpField("inbox.tail", _u(_j, _o, ".tail"), s.tail)
        );
        p_ = string.concat(
            p_,
            _cmpField("inbox.snapshot", _u(_j, _o, ".snapshot"), s.snapshot),
            _cmpField("inbox.ethBalance", _u(_j, _o, ".ethBalance"), inbox.balance),
            _cmpField("inbox.swept", _u(_j, _o, ".swept"), recipient.balance),
            _cmpField("inbox.feeGwei", _u(_j, _o, ".feeGwei"), s.feeGwei)
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

    /// @dev The Inbox's scalar observables: from its getters once initialized; before, from
    /// its appendix B slots, which the bootstrap implementation never writes, and the fee of the
    /// implementation `init` installs (the queue is empty).
    function _inboxState() private view returns (InboxState memory s_) {
        IEtnaInbox ib = IEtnaInbox(inbox);
        if (ib.isInitialized()) {
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
        } else {
            uint256 headTail = _load(inbox, _SLOT_HEAD_TAIL);
            s_ = InboxState({
                checkpointHeight: _load(inbox, _SLOT_CHECKPOINT_HEIGHT),
                checkpointHash: _load(inbox, _SLOT_CHECKPOINT_HASH),
                generation: _load(inbox, _SLOT_GENERATION),
                recoveryNonce: _load(inbox, _SLOT_RECOVERY_NONCE),
                head: uint48(headTail),
                tail: uint48(headTail >> 48),
                snapshot: _load(inbox, _SLOT_SNAPSHOT),
                feeGwei: inboxImpl.getCurrentForcedInclusionFee()
            });
        }
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
            IEtnaInbox.Landing memory l = _landing(h);
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

    function _landing(uint256 _height) private view returns (IEtnaInbox.Landing memory l_) {
        if (IEtnaInbox(inbox).isInitialized()) return IEtnaInbox(inbox).landings(_height);
        uint256 slot = uint256(keccak256(abi.encode(_height, _SLOT_LANDINGS)));
        uint256 word = _load(inbox, slot);
        l_.parentHeight = uint48(word);
        l_.generation = uint48(word >> 48);
        l_.head = uint48(word >> 96);
        l_.elHash = bytes32(_load(inbox, slot + 1));
        l_.cometHash = bytes32(_load(inbox, slot + 2));
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
            IEtnaInbox.Origin memory o = _origin(generation);
            string memory at = string.concat("origins[", vm.toString(generation), "].");
            p_ = string.concat(
                p_,
                _cmp(string.concat(at, "startHeight"), want.height, o.startHeight),
                _cmp(string.concat(at, "l1BlockNumber"), want.l1Block, o.l1BlockNumber),
                _cmp(string.concat(at, "l1Timestamp"), want.timestamp, o.l1Timestamp)
            );
        }
    }

    function _origin(uint256 _generation) private view returns (IEtnaInbox.Origin memory o_) {
        if (IEtnaInbox(inbox).isInitialized()) return IEtnaInbox(inbox).origins(_generation);
        uint256 slot = uint256(keccak256(abi.encode(_generation, _SLOT_ORIGINS)));
        o_.startHeight = _load(inbox, slot);
        o_.l1BlockNumber = _load(inbox, slot + 1);
        o_.l1Timestamp = _load(inbox, slot + 2);
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
            IEtnaInbox.ForcedInclusion memory f;
            if (IEtnaInbox(inbox).isInitialized()) {
                f = IEtnaInbox(inbox).getForcedInclusion(uint48(queue[i].index));
            }
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

    function _checkRegistry(string memory _j, string memory _o) private returns (string memory p_) {
        uint256 checkpoints = registry.checkpointCount();
        p_ = string.concat(
            _cmpField("registry.entryCount", _u(_j, _o, ".entryCount"), registry.entryCount()),
            _cmpField("registry.freeCount", _u(_j, _o, ".freeCount"), registry.freeSlotCount()),
            _cmpField(
                "registry.stakeHeld", _u(_j, _o, ".stakeHeld"), token.balanceOf(address(registry))
            ),
            _cmpField("registry.checkpointCount", _u(_j, _o, ".checkpointCount"), checkpoints)
        );
        if (checkpoints != 0) {
            IEtnaStakingRegistry.Checkpoint memory last = registry.checkpointAt(checkpoints - 1);
            p_ = string.concat(
                p_,
                _cmpField(
                    "registry.lastCheckpointBlock", _u(_j, _o, ".lastCheckpointBlock"), last.l1Block
                ),
                _cmpField(
                    "registry.lastCheckpointCount", _u(_j, _o, ".lastCheckpointCount"), last.count
                )
            );
        }
        uint256 mark = _freeMemory();
        p_ = _keep(
            p_,
            _checkCheckpoints(
                _j, string.concat(_o, ".checkpoints"), _u(_j, _o, ".checkpointCount")
            ),
            mark
        );
        mark = _freeMemory();
        p_ = _keep(p_, _checkBonds(_j, _o), mark);
    }

    /// @dev Compares the checkpoint history, oldest first: each checkpoint's block, slot count
    /// and the entries root of the model's election entries. The number of checkpoints is
    /// `registry.checkpointCount`, compared by the caller; checkpoints the contract has beyond the
    /// model's (only under a recorded observable divergence) must repeat the previous count and
    /// root.
    function _checkCheckpoints(
        string memory _j,
        string memory _path,
        uint256 _modelCount
    )
        private
        returns (string memory p_)
    {
        // The model's list is newest first.
        CheckpointJ[] memory want =
            abi.decode(vm.parseJsonTypeArray(_j, _path, _CHECKPOINT_TYPE), (CheckpointJ[]));
        require(want.length == _modelCount, "checkpoints and checkpointCount differ");
        uint256 count = registry.checkpointCount();
        for (uint256 k; k < count; ++k) {
            uint256 mark = _freeMemory();
            IEtnaStakingRegistry.Checkpoint memory got = registry.checkpointAt(k);
            string memory at = string.concat("checkpoint ", vm.toString(k), " ");
            string memory problem;
            if (k < want.length) {
                CheckpointJ memory w = want[want.length - 1 - k];
                problem = string.concat(
                    _cmp(string.concat(at, "l1Block"), w.block, got.l1Block),
                    _cmp(string.concat(at, "count"), w.entries.length, got.count),
                    _cmp(
                        string.concat(at, "entriesRoot"),
                        uint256(_entriesRoot(w.entries)),
                        uint256(got.entriesRoot)
                    )
                );
            } else if (k != 0) {
                IEtnaStakingRegistry.Checkpoint memory prior = registry.checkpointAt(k - 1);
                problem = string.concat(
                    _cmp(string.concat(at, "count (repeat)"), prior.count, got.count),
                    _cmp(
                        string.concat(at, "entriesRoot (repeat)"),
                        uint256(prior.entriesRoot),
                        uint256(got.entriesRoot)
                    )
                );
            }
            p_ = _keep(p_, problem, mark);
        }
    }

    /// @dev Compares every bond and the lifetime forfeiture flags: each listed key is flagged,
    /// and no other key of a bond is.
    function _checkBonds(string memory _j, string memory _o) private returns (string memory p_) {
        BondJ[] memory bonds = abi.decode(
            vm.parseJsonTypeArray(_j, string.concat(_o, ".bonds"), _BOND_TYPE), (BondJ[])
        );
        uint256[] memory forfeited = vm.parseJsonUintArray(_j, string.concat(_o, ".forfeitedKeys"));
        for (uint256 i; i < bonds.length; ++i) {
            uint256 mark = _freeMemory();
            p_ = _keep(p_, _checkBond(bonds[i]), mark);
        }
        for (uint256 i; i < forfeited.length; ++i) {
            uint256 mark = _freeMemory();
            p_ = _keep(p_, _checkForfeited(forfeited[i], true), mark);
        }
        for (uint256 i; i < bonds.length; ++i) {
            if (bonds[i].key == 0 || _contains(forfeited, bonds[i].key)) continue;
            uint256 mark = _freeMemory();
            p_ = _keep(p_, _checkForfeited(bonds[i].key, false), mark);
        }
    }

    function _checkForfeited(uint256 _key, bool _want) private returns (string memory) {
        return _cmp(
            string.concat("forfeited[key ", vm.toString(_key), "]"),
            _want ? 1 : 0,
            registry.forfeited(_entryKey(_key)) ? 1 : 0
        );
    }

    function _checkBond(BondJ memory _b) private returns (string memory p_) {
        IEtnaStakingRegistry.Entry memory e = registry.entryAt(_b.id);
        (uint256 pending, uint48 readyAt) = registry.topUpOf(_b.id);
        (uint8 prefix, bytes32 x) = _keyParts(_b.key);
        string memory at = string.concat("bond[", vm.toString(_b.id), "].");
        p_ = string.concat(
            _cmp(string.concat(at, "ckPrefix"), prefix, e.ckPrefix),
            _cmp(string.concat(at, "ckX"), uint256(x), uint256(e.ckX)),
            _cmp(string.concat(at, "effStake"), _b.stake, e.effStake),
            _cmp(string.concat(at, "activeFromL1"), _b.activeFrom, e.activeFromL1),
            _cmp(string.concat(at, "exitEffectiveL1"), _b.exitAt, e.exitEffectiveL1)
        );
        p_ = string.concat(
            p_,
            _cmp(
                string.concat(at, "owner"),
                uint160(_account(_b.owner)),
                uint160(registry.ownerOf(_b.id))
            ),
            _cmp(
                string.concat(at, "exitConfirmedAtL1"),
                _b.confirmedAt,
                registry.exitConfirmedAtL1(_b.id)
            ),
            _cmp(string.concat(at, "pendingTopUp"), _b.pendingTopUp, pending),
            _cmp(string.concat(at, "topUpReadyAtL1"), _b.topUpReadyAtL1, readyAt)
        );
    }

    /// @dev The entries root (appendix A) over the model's election entries: entry `i` is bond
    /// `i`, and its leaf is `LibEntriesTree.leaf` of the key's prefix and X and the stake,
    /// activation and exit; the leaves are padded with zero to a power of two.
    function _entriesRoot(EntryJ[] memory _entries) private returns (bytes32) {
        uint256 n = _entries.length;
        if (n == 0) return 0;
        uint256 size = 1;
        while (size < n) {
            size <<= 1;
        }
        bytes32[] memory layer = new bytes32[](size);
        for (uint256 i; i < n; ++i) {
            uint256 mark = _freeMemory();
            (uint8 prefix, bytes32 x) = _keyParts(_entries[i].key);
            require(
                _entries[i].activeFrom <= type(uint48).max
                    && _entries[i].exitAt <= type(uint48).max,
                "entry block width"
            );
            layer[i] = LibEntriesTree.leaf(
                i,
                IEtnaStakingRegistry.Entry({
                    ckX: x,
                    effStake: _entries[i].stake,
                    ckPrefix: prefix,
                    activeFromL1: uint48(_entries[i].activeFrom),
                    exitEffectiveL1: uint48(_entries[i].exitAt)
                })
            );
            _release(mark);
        }
        for (; size > 1; size >>= 1) {
            for (uint256 i; i < size / 2; ++i) {
                layer[i] = keccak256(abi.encodePacked(layer[2 * i], layer[2 * i + 1]));
            }
        }
        return layer[0];
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev `_cmp` for a named observable, with the recorded contract value of an observable
    /// divergence in place of the model's.
    function _cmpField(
        string memory _what,
        uint256 _want,
        uint256 _got
    )
        private
        view
        returns (string memory)
    {
        bytes32 field = keccak256(bytes(_what));
        if (overridden[field]) _want = overrideValue[field];
        return _cmp(_what, _want, _got);
    }

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

    /// @dev Reads an unsigned value (a JSON number or a canonical decimal string); `fits_` is
    /// false if it is 2^256 or more, which no uint256 argument can carry.
    function _word(
        string memory _j,
        string memory _path
    )
        private
        pure
        returns (bool fits_, uint256 value_)
    {
        try vm.parseJsonUint(_j, _path) returns (uint256 value) {
            return (true, value);
        } catch {
            bytes memory digits = bytes(vm.parseJsonString(_j, _path));
            bytes memory max = bytes(vm.toString(type(uint256).max));
            require(digits.length >= max.length && digits[0] != "0", "not an unsigned decimal");
            for (uint256 i; i < digits.length; ++i) {
                require(digits[i] >= "0" && digits[i] <= "9", "not an unsigned decimal");
            }
            require(
                digits.length > max.length || keccak256(digits) != keccak256(max),
                "uint256 max did not parse"
            );
            return (false, 0);
        }
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

    /// @dev Appends `_problem` to `_report`, or, with no problem, releases the memory allocated
    /// since `_mark` (`_report` must predate it).
    function _keep(
        string memory _report,
        string memory _problem,
        uint256 _mark
    )
        private
        pure
        returns (string memory)
    {
        if (bytes(_problem).length == 0) {
            _release(_mark);
            return _report;
        }
        return string.concat(_report, _problem);
    }

    function _contains(uint256[] memory _xs, uint256 _x) private pure returns (bool) {
        for (uint256 i; i < _xs.length; ++i) {
            if (_xs[i] == _x) return true;
        }
        return false;
    }

    function _load(address _target, uint256 _slot) private view returns (uint256) {
        return uint256(vm.load(_target, bytes32(_slot)));
    }

    /// @dev The ERC-7201 base slot of namespace `_id`.
    function _erc7201(string memory _id) private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(_id))) - 1)) & ~bytes32(uint256(0xff));
    }

    /// @dev Account `n` is `0x10000 + n`; account 0 is the zero address.
    function _account(uint256 _n) private pure returns (address) {
        return _n == 0 ? address(0) : address(uint160(0x10000 + _n));
    }

    function _timestamp(uint256 _block) private pure returns (uint256) {
        return _TIMESTAMP_BASE + _TIMESTAMP_STEP * _block;
    }

    /// @dev The stored prefix and X of registry key `_key` (private key `_key`); zero for key 0, a
    /// released slot.
    function _keyParts(uint256 _key) private returns (uint8 prefix_, bytes32 x_) {
        if (_key == 0) return (0, 0);
        bytes memory publicKey = EtnaTestKeys.publicKey(_key);
        prefix_ = uint8(publicKey[0]);
        assembly ("memory-safe") {
            x_ := mload(add(publicKey, 33))
        }
    }

    /// @dev entryKey = keccak256(abi.encode(ckPrefix, ckX)) of key `_key`; key 0 gives the
    /// released (all-zero) slot's key.
    function _entryKey(uint256 _key) private returns (bytes32) {
        (uint8 prefix, bytes32 x) = _keyParts(_key);
        return LibEtnaKeys.entryKey(prefix, x);
    }
}
