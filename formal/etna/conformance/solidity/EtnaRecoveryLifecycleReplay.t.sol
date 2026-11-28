// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EtnaInboxTestBase} from "../EtnaInboxTestBase.sol";
import {EtnaReplayTestBase} from "./EtnaReplayTestBase.sol";
import {MockUnzenInbox} from "../MockUnzenInbox.sol";
import {ICheckpointStore} from "src/shared/signal/ICheckpointStore.sol";
import {EtnaTestKeys} from "../EtnaTestKeys.sol";
import {IEtnaInbox} from "src/layer1/etna/iface/IEtnaInbox.sol";
import {IEtnaStakingRegistry} from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @notice Replays eight frozen M08 Displaced/Withdrawn receipts with real public history.
/// @dev H(q)=6+6q, T(t)=1200t; token unit MIN_STAKE. Unzen finalization and
/// proof verification are explicit imported/mocked premises; registry state is real.
contract EtnaRecoveryLifecycleReplayTest is EtnaReplayTestBase {
    uint256 private constant S = 6;
    uint256 private constant REPLACEMENT = 4096;
    uint256 private constant UNISSUED = 4097;
    uint256 private constant FILLER_RESERVE = 4095 * 5 * MIN_STAKE;
    bytes32[2] private originalKeys;
    bytes4 private lastRecoveryRevert;
    string private constant FILE = "/test/layer1/etna/conformance/vectors/recovery_lifecycle_cases.json";

    /// @notice Deploys an uninitialized bootstrap before the monotone public history.
    function setUp() public override {
        vm.roll(86);
        vm.warp(1200 * 986);
        EtnaInboxTestBase.setUp(); // Its default stack rolls exactly once, to87.
    }

    /// @notice Exercises the public history before any model replay.
    function test_lifecycle_publicHistoryProbe() external {
        vm.pauseGasMetering();
        _setupLifecycle(false);
        assertEq(registry.exitConfirmedAtL1(0), 95);
        assertEq(registry.bondAt(0).entry.exitEffectiveL1, 93);
        assertEq(registry.bondAt(0).entry.effStake, MIN_STAKE);
        assertEq(_inbox().origins(0).l1BlockNumber, 97);
        assertEq(taikoToken.balanceOf(address(registry)), FILLER_RESERVE + 7 * MIN_STAKE);
    }

    /// @notice Unknown original identity fails at the real registry and rolls the call back.
    function test_lifecycle_unissuedRecoveryRevertsUnknownBond() external {
        vm.pauseGasMetering();
        _setupLifecycle(false);
        vm.roll(101);
        vm.warp(1200 * 1001);
        bytes32 beforeState = _rawDigest();
        bytes32 fillers = _fillerDigest();
        IEtnaInbox.Exclusion[] memory exclusions = new IEtnaInbox.Exclusion[](2);
        exclusions[0] = IEtnaInbox.Exclusion(0, originalKeys[0]);
        exclusions[1] = IEtnaInbox.Exclusion(UNISSUED, _key("DefaultKey"));
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        _inbox().recover(0, S + K, 0, block.timestamp, exclusions, new uint256[](0), 0);
        assertEq(_rawDigest(), beforeState, "unknown identity recovery abort atomicity");
        assertEq(_fillerDigest(), fillers);
    }

    /// @notice Executes all eight actual receipts, reusing one paid history per profile.
    function test_conformance_recoveryLifecycleReplay() external {
        vm.pauseGasMetering();
        string memory j = vm.readFile(string.concat(vm.projectRoot(), FILE));
        assertEq(vm.parseJsonString(j, ".schema"), "etna-recovery-lifecycle-1");
        assertEq(vm.parseJsonUint(j, ".grid"), K);
        assertTrue(vm.keyExistsJson(j, ".cases[7].id"));
        assertFalse(vm.keyExistsJson(j, ".cases[8].id"));
        uint256 initial = vm.snapshotState();
        for (uint256 profile; profile < 2; ++profile) {
            _setupLifecycle(profile == 1);
            uint256 prepared = vm.snapshotState();
            for (uint256 i = profile * 4; i < profile * 4 + 4; ++i) {
                assertEq(
                    vm.parseJsonString(j, string.concat(".cases[", vm.toString(i), "].profile")),
                    profile == 0 ? "Displaced" : "Withdrawn"
                );
                this.runCase(j, i);
                assertTrue(vm.revertToState(prepared));
            }
            assertTrue(vm.revertToState(initial));
        }
    }

    /// @notice Materializes one original public attempt in a bounded external frame.
    /// @param j Actual TLC receipts.
    /// @param index Original attempt index.
    function runCase(string memory j, uint256 index) external {
        require(msg.sender == address(this), "test only");
        string memory p = string.concat(".cases[", vm.toString(index), "].attempt");
        emit log_string(vm.parseJsonString(j, string.concat(".cases[", vm.toString(index), "].id")));
        vm.roll(_u(j, p, ".execution.block"));
        vm.warp(1200 * _u(j, p, ".execution.timestamp"));
        _assertCanonical(j, string.concat(p, ".before"));
        bytes32 original = _rawDigest();
        bytes32 preserved = _preservedDigest();
        bytes32 fillers = _fillerDigest();
        bytes32 oldBond = _oldBondDigest();
        bool ok = _callRecover(j, p);
        assertEq(ok, vm.parseJsonBool(j, string.concat(p, ".outcome.accepted")), p);
        if (!ok) {
            assertEq(lastRecoveryRevert, bytes4(keccak256("InjectedSecondRegistry()")), "exact dependency failure");
            assertEq(_rawDigest(), original, "complete raw abort atomicity");
        }
        _assertCanonical(j, string.concat(p, ".after"));
        assertEq(_preservedDigest(), preserved, "history and custody preserved");
        assertEq(_fillerDigest(), fillers, "all4095 filler identities and slots preserved");
        assertEq(_oldBondDigest(), oldBond, "original unheld/withdrawn identity untouched");
        assertEq(registry.bondCount(), UNISSUED, "no new identity");
    }

    /// @dev Executes exactly one atomic call with separately labeled dependency injection.
    function _callRecover(string memory j, string memory p) private returns (bool ok) {
        string memory callPath = string.concat(p, ".calldata");
        IEtnaInbox.Exclusion[] memory exclusions = _exclusions(j, callPath);
        uint256[] memory indices = vm.parseJsonUintArray(j, string.concat(callPath, ".fiToClear"));
        bool inject =
            keccak256(bytes(vm.parseJsonString(j, string.concat(p, ".injection.failure"))))
                    == keccak256("SecondRegistry") && exclusions.length >= 2;
        bool lateFailure = inject
            && keccak256(bytes(vm.parseJsonString(j, string.concat(p, ".outcome.reason"))))
                == keccak256("RegistryFailed");
        if (lateFailure) {
            vm.expectCall(
                address(registry),
                abi.encodeCall(IEtnaStakingRegistry.forceExit, (exclusions[0].bondId, exclusions[0].entryKey))
            );
            vm.expectCall(
                address(registry),
                abi.encodeCall(IEtnaStakingRegistry.forceExit, (exclusions[1].bondId, exclusions[1].entryKey))
            );
        }
        if (inject) {
            // A concrete dependency failure at the second requested forceExit. No production
            // code is replaced. First forceExit is a no-op for the original unheld bond;
            // the failure must preserve every original and replacement observation.
            vm.mockCallRevert(
                address(registry),
                abi.encodeCall(IEtnaStakingRegistry.forceExit, (exclusions[1].bondId, exclusions[1].entryKey)),
                abi.encodeWithSignature("InjectedSecondRegistry()")
            );
        }
        if (vm.parseJsonBool(j, string.concat(p, ".outcome.accepted"))) {
            _expectRecovered(j, p, exclusions, indices);
        }
        bytes memory reason;
        (ok, reason) = inboxProxy.call(_encodedRecover(j, callPath, exclusions, indices));
        lastRecoveryRevert = reason.length >= 4 ? bytes4(reason) : bytes4(0);
        vm.clearMockedCalls();
    }

    /// @dev Checks the selected success event against actual model observations and original lists.
    function _expectRecovered(
        string memory j,
        string memory p,
        IEtnaInbox.Exclusion[] memory exclusions,
        uint256[] memory indices
    ) private {
        vm.expectEmit(true, false, false, true, inboxProxy);
        emit IEtnaInbox.Recovered(
            uint48(_u(j, p, ".after.generation")),
            _height(_u(j, p, ".before.checkpoint")),
            _u(j, p, ".execution.block"),
            1200 * _u(j, p, ".execution.timestamp"),
            exclusions,
            indices
        );
    }

    /// @dev Encodes original authorization and list arguments in a bounded helper frame.
    function _encodedRecover(
        string memory j,
        string memory path,
        IEtnaInbox.Exclusion[] memory exclusions,
        uint256[] memory indices
    ) private view returns (bytes memory) {
        return abi.encodeCall(
            IEtnaInbox.recover,
            (
                uint48(_u(j, path, ".expectedGeneration")),
                _height(_u(j, path, ".expectedC")),
                _u(j, path, ".expectedRecoveryNonce"),
                1200 * _u(j, path, ".validUntil"),
                exclusions,
                indices,
                uint48(_u(j, path, ".rules"))
            )
        );
    }

    /// @dev Paid public registration, topup, displacement, forfeiture and withdrawal history.
    function _setupLifecycle(bool withdrawn) private {
        assertEq(block.number, 87, "helper deployment clock");
        IEtnaStakingRegistry.Config memory config = _registryConfig(address(taikoToken), inboxProxy);
        config.activationDelay = 5;
        config.exitDelay = 1;
        config.withdrawalDelay = 3;
        config.forfeitBps = 5000;
        registry = _deployRegistry(config);
        originalKeys[0] = EtnaTestKeys.entryKey(1);
        originalKeys[1] = EtnaTestKeys.entryKey(4097);
        _registerAmount(1, 3 * MIN_STAKE);
        for (uint256 i = 1; i < 4096; ++i) {
            this.registerFiller(i);
        }
        assertEq(registry.bondCount(), 4096);
        vm.roll(92);
        vm.warp(1200 * 992);
        taikoToken.mint(Alice, MIN_STAKE);
        vm.startPrank(Alice);
        taikoToken.approve(address(registry), MIN_STAKE);
        registry.topUp(0, MIN_STAKE);
        registry.requestExit(0);
        vm.stopPrank();
        (uint256 pending, uint48 ready) = registry.topUpOf(0);
        assertEq(pending, MIN_STAKE);
        assertEq(ready, 97);
        assertEq(registry.bondAt(0).entry.activeFromL1, 92);
        assertEq(registry.bondAt(0).entry.exitEffectiveL1, 93);
        vm.roll(93);
        vm.warp(1200 * 993);
        _registerAmount(4097, 5 * MIN_STAKE);
        assertFalse(registry.bondAt(0).holdsSlot);
        assertEq(registry.bondAt(REPLACEMENT).slot, 0);
        vm.roll(95);
        vm.warp(1200 * 995);
        MockUnzenInbox unzen = new MockUnzenInbox();
        IEtnaInbox.Config memory inboxConfig = _defaultConfig();
        inboxConfig.forcedInclusionFeeInGwei = 1;
        inboxConfig.forcedInclusionFeeDoubleThreshold = 1;
        inboxConfig.originWriter = Carol;
        inboxConfig.unzenInbox = address(unzen);
        inboxConfig.etnaForkTime = 1200 * 997;
        inboxImpl = _newInboxImpl(inboxConfig);
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.genesisCutoff = 94;
        params.genesisBlockHash = 0;
        params.genesisStateRoot = 0;
        params.maxAnchorAge = 1152;
        params.forcedInclusionDelay = 1;
        _upgradeAndInit(inboxImpl, params);
        vm.expectEmit(true, true, false, true, address(registry));
        emit IEtnaStakingRegistry.Forfeited(0, originalKeys[0], bytes32(uint256(1)), 4 * MIN_STAKE, 2 * MIN_STAKE);
        registry.forfeit(0, originalKeys[0], bytes32(uint256(1)), block.timestamp);
        assertEq(registry.bondAt(0).entry.effStake, MIN_STAKE, "exact effective-first50percent penalty");
        assertEq(taikoToken.balanceOf(SLASH_SINK), 2 * MIN_STAKE);
        vm.expectEmit(true, false, false, true, address(registry));
        emit IEtnaStakingRegistry.ExitConfirmed(0, 95);
        registry.confirmExit(0);
        vm.roll(97);
        vm.warp(1200 * 997);
        vm.prank(Carol);
        _inbox().setOrigin(S, bytes32(100 + S), _stateRoot(S));
        // Imported boundary: Unzen final proof and its checkpoint are not replayed here.
        unzen.setCoreState(8, 7, bytes32(100 + S));
        vm.prank(inboxProxy);
        signalService.saveCheckpoint(ICheckpointStore.Checkpoint(uint48(S), bytes32(100 + S), _stateRoot(S)));
        _inbox().scheduleRules(1, 1200 * 1002);
        _inbox().scheduleStop(1200 * 1001, uint48(2 * K));
        vm.deal(Alice, 1 ether);
        vm.roll(98);
        vm.warp(1200 * 998);
        if (withdrawn) {
            uint256 balance = taikoToken.balanceOf(Alice);
            vm.expectEmit(true, true, false, true, address(registry));
            emit IEtnaStakingRegistry.StakeWithdrawn(0, Alice, 2 * MIN_STAKE);
            vm.prank(Alice);
            registry.withdraw(0, Alice);
            assertEq(taikoToken.balanceOf(Alice), balance + 2 * MIN_STAKE);
            assertEq(registry.ownerOf(0), address(0));
            assertEq(registry.exitConfirmedAtL1(0), 0);
            (pending, ready) = registry.topUpOf(0);
            assertEq(pending, 0);
            assertEq(ready, 0);
        }
        vm.prank(Alice);
        _inbox().saveForcedInclusion{value: 1 gwei}("A");
        vm.roll(99);
        vm.warp(1200 * 999);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{value: 2 gwei}("B");
        vm.roll(100);
        vm.warp(1200 * 1000);
        _setReference(99, bytes32(uint256(999)));
        _setBlobCount(2);
        IEtnaInbox.LandInput memory input = _input(S, S + K);
        input.activeCommitteeSnapshot = 94;
        bytes32[] memory leaves = _leaves(S, S + K);
        landVerifier.setExpectedStatementHash(_statement(input, _inbox().landings(S), _cutHash(input, leaves)));
        _land(input, leaves);
        _assertSuccessfulPublication(input);
    }

    /// @notice Registers one fully paid filler in a bounded frame.
    /// @param index Its slot/identity coordinate,1..4095.
    function registerFiller(uint256 index) external {
        require(msg.sender == address(this), "test only");
        _registerAmount(index + 1, 5 * MIN_STAKE);
    }

    /// @dev Concrete affine L2 height mapping, excluding absent-record sentinels.
    function _height(uint256 q) private pure returns (uint256) {
        return S + K * q;
    }

    /// @dev Relative FI cursor and zero start Comet identity for the switching fixture.
    function _cut(uint256 x) internal pure override returns (bytes32, bytes32, uint256) {
        return (bytes32(100 + x), x == S ? bytes32(0) : bytes32(200 + x), (x - S) / K);
    }

    /// @dev The validator commitment is zero only at the imported start.
    function _valStateHash(uint256 x) internal pure override returns (bytes32) {
        return x == S ? bytes32(0) : bytes32(400 + x);
    }

    /// @dev Symbolic identities map to genuine lifetime registry IDs.
    function _id(uint256 id) private pure returns (uint256) {
        return id == 0 ? 0 : id == 1 ? REPLACEMENT : UNISSUED;
    }

    /// @dev Pays for a real key registration under this registry's actual domain.
    function _registerAmount(uint256 key, uint256 amount) private {
        taikoToken.mint(Alice, amount);
        vm.prank(Alice);
        taikoToken.approve(address(registry), amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(key);
        bytes memory pop = EtnaTestKeys.popSig(key, registry, Alice);
        if (key == 4097) {
            vm.expectEmit(true, true, true, true, address(registry));
            emit IEtnaStakingRegistry.BondDisplaced(0, 0, REPLACEMENT);
        }
        vm.prank(Alice);
        registry.register(publicKey, amount, pop);
    }

    /// @dev Maps symbolic keys to the actual issued key; DefaultKey remains genuinely unissued.
    function _key(string memory token) private view returns (bytes32) {
        bytes32 value = keccak256(bytes(token));
        if (value == keccak256("DefaultKey")) return keccak256(abi.encode(uint8(0), bytes32(0)));
        uint256 id = value == keccak256("K0") ? 0 : 1;
        return originalKeys[id];
    }

    /// @dev Decodes original exclusion order and identities without sorting or repairing input.
    function _exclusions(string memory j, string memory p) private view returns (IEtnaInbox.Exclusion[] memory result) {
        uint256 count;
        while (vm.keyExistsJson(j, string.concat(p, ".exclusions[", vm.toString(count), "]"))) {
            ++count;
        }
        result = new IEtnaInbox.Exclusion[](count);
        for (uint256 i; i < count; ++i) {
            string memory e = string.concat(p, ".exclusions[", vm.toString(i), "]");
            result[i] = IEtnaInbox.Exclusion(
                _id(_u(j, e, ".bondId")), _key(vm.parseJsonString(j, string.concat(e, ".entryKey")))
            );
        }
    }

    /// @dev Checks all finite canonical fields against the actual model public observation.
    function _assertCanonical(string memory j, string memory p) private view {
        _assertCheckpoint(_height(_u(j, p, ".checkpoint")), bytes32(100 + _height(_u(j, p, ".checkpoint"))));
        assertEq(_inbox().recoveryGeneration(), _u(j, p, ".generation"));
        assertEq(_inbox().recoveryNonce(), _u(j, p, ".nonce"));
        assertEq(_inbox().origins(_inbox().recoveryGeneration()).startHeight, _height(_u(j, p, ".start")));
        string memory state = string.concat(p, ".state");
        _assertQueue(_u(j, state, ".head"), _u(j, state, ".tail"));
        assertEq(_inbox().activeCommitteeSnapshot(), _u(j, state, ".activeSnapshot"));
        assertEq(address(inboxProxy).balance, _u(j, state, ".fees") * 1 gwei, "admission fees retained");
        assertEq(taikoToken.balanceOf(address(registry)), FILLER_RESERVE + _u(j, state, ".tokenVault") * MIN_STAKE);
        for (uint256 h; h <= 2; ++h) {
            string memory r = string.concat(p, ".landings.", vm.toString(h));
            if (vm.parseJsonBool(j, string.concat(r, ".present"))) {
                _assertLanding(
                    _height(h), _record(_height(_u(j, r, ".parent")), _u(j, r, ".generation"), h, _height(h))
                );
            } else {
                IEtnaInbox.Landing memory empty;
                _assertLanding(_height(h), empty);
            }
        }
        for (uint256 g; g <= 1; ++g) {
            string memory o = string.concat(state, ".origins.", vm.toString(g));
            IEtnaInbox.Origin memory actual = _inbox().origins(g);
            assertEq(
                actual.startHeight, vm.parseJsonBool(j, string.concat(o, ".present")) ? _height(_u(j, o, ".start")) : 0
            );
            assertEq(actual.l1BlockNumber, _u(j, o, ".block"));
            assertEq(actual.l1Timestamp, 1200 * _u(j, o, ".timestamp"));
        }
        for (uint256 i; i <= 2; ++i) {
            _assertBond(j, string.concat(state, ".bonds.", vm.toString(i)), i);
        }
        for (uint256 i; i <= 1; ++i) {
            string memory token = i == 0 ? "K0" : "K1";
            (bool registered, uint256 id) = registry.bondForKey(vm.addr(i == 0 ? 1 : 4097));
            assertEq(registered, vm.parseJsonBool(j, string.concat(state, ".registered.", token)));
            assertEq(id, _id(i));
            assertEq(registry.forfeited(_key(token)), vm.parseJsonBool(j, string.concat(state, ".forfeited.", token)));
        }
        (bool occupied, uint256 holder) = registry.bondInSlot(0);
        assertEq(occupied, vm.parseJsonBool(j, string.concat(state, ".slots.0.occupied")));
        assertEq(holder, _id(_u(j, state, ".slots.0.id")));
        (bool unused,) = registry.bondForKey(address(0));
        assertFalse(unused);
        assertFalse(registry.forfeited(_key("DefaultKey")));

        for (uint256 i; i <= 2; ++i) {
            string memory e = string.concat(state, ".entries.", vm.toString(i));
            IEtnaInbox.ForcedInclusion memory actual = _inbox().getForcedInclusion(uint48(i));
            string memory hashToken = vm.parseJsonString(j, string.concat(e, ".hash"));
            bytes32 expected = keccak256(bytes(hashToken));
            if (keccak256(bytes(hashToken)) == keccak256("Nil")) {
                expected = _u(j, e, ".timestamp") == 0 ? bytes32(0) : keccak256("");
            }
            assertEq(actual.txHash, expected, "actual FI hash");
            assertEq(actual.timestamp, 1200 * _u(j, e, ".timestamp"));
            assertEq(actual.l1Block, _u(j, e, ".block"));
        }
        IEtnaInbox.RulesSchedule memory rules = _inbox().rulesSchedule();
        assertEq(rules.activeRules, _u(j, state, ".activeRules"));
        assertEq(rules.nextRules, _u(j, state, ".nextRules"));
        assertEq(rules.rulesTime, 1200 * _u(j, state, ".rulesTime"));
        assertEq(rules.stopTime, 1200 * _u(j, state, ".stopTime"));
        assertEq(rules.stopGrid, _u(j, state, ".stopGrid") * K);
    }

    /// @dev Compares permanent identity, custody and slot fields; unissued id stays real/default.
    function _assertBond(string memory j, string memory p, uint256 id) private view {
        uint256 symbolicId = id;
        id = _id(id);
        bool issued = vm.parseJsonBool(j, string.concat(p, ".issued"));
        if (!issued) {
            assertEq(registry.ownerOf(id), address(0));
            (bool holds,) = registry.slotOfBond(id);
            assertFalse(holds);
            (uint256 pending, uint48 ready) = registry.topUpOf(id);
            assertEq(pending, _u(j, p, ".pending") * MIN_STAKE);
            assertEq(ready, _u(j, p, ".ready"));
            assertEq(registry.exitConfirmedAtL1(id), _u(j, p, ".confirmed"));
            (bool exists, bytes memory reason) =
                address(registry).staticcall(abi.encodeCall(IEtnaStakingRegistry.bondAt, (id)));
            assertFalse(exists, "genuine unissued bond");
            assertEq(bytes4(reason), IEtnaStakingRegistry.UnknownBond.selector);
            return;
        }
        IEtnaStakingRegistry.Bond memory bond = registry.bondAt(id);
        assertEq(bond.withdrawn, vm.parseJsonBool(j, string.concat(p, ".withdrawn")));
        assertEq(bond.holdsSlot, vm.parseJsonBool(j, string.concat(p, ".holds")));
        assertEq(bond.slot, _u(j, p, ".slot"));
        if (bond.holdsSlot) assertEq(keccak256(abi.encode(registry.entryAt(0))), keccak256(abi.encode(bond.entry)));
        assertEq(bond.entry.activeFromL1, symbolicId == 0 ? 92 : 98, "activation metadata preserved");
        assertEq(bond.entry.effStake, _u(j, p, ".eff") * MIN_STAKE);
        assertEq(bond.entry.exitEffectiveL1, _u(j, p, ".exit") == 10_000 ? registry.NO_EXIT() : _u(j, p, ".exit"));
        assertEq(registry.ownerOf(id), _u(j, p, ".owner") == 0 ? address(0) : Alice);
        assertEq(registry.exitConfirmedAtL1(id), _u(j, p, ".confirmed"));
        (uint256 pending, uint48 ready) = registry.topUpOf(id);
        assertEq(pending, _u(j, p, ".pending") * MIN_STAKE);
        assertEq(ready, _u(j, p, ".ready"));
        assertEq(
            _key(vm.parseJsonString(j, string.concat(p, ".key"))),
            keccak256(abi.encode(bond.entry.ckPrefix, bond.entry.ckX))
        );
    }

    /// @dev Full selected raw public state, including opaque commitments and external balances.
    function _rawDigest() private view returns (bytes32 value) {
        value = keccak256(
            abi.encode(
                _unissuedDigest(),
                _inbox().lastCheckpoint(),
                _inbox().recoveryGeneration(),
                _inbox().recoveryNonce(),
                _inbox().rulesSchedule(),
                _inbox().activeCommitteeSnapshot(),
                address(inboxProxy).balance,
                taikoToken.balanceOf(address(registry)),
                registry.entriesRoot(),
                registry.checkpointCount()
            )
        );
        for (uint256 i; i <= 1; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    registry.bondAt(_id(i)),
                    registry.ownerOf(_id(i)),
                    registry.exitConfirmedAtL1(_id(i)),
                    registry.entryAt(0),
                    _inbox().getForcedInclusion(uint48(i)),
                    _inbox().origins(i)
                )
            );
        }
        value = keccak256(abi.encode(value, _inbox().getForcedInclusion(2)));
        for (uint256 h; h <= 2; ++h) {
            value = keccak256(abi.encode(value, _inbox().landings(_height(h))));
        }
        for (uint256 i; i <= 1; ++i) {
            (uint256 pending, uint48 ready) = registry.topUpOf(_id(i));
            (bool registered, uint256 id) = registry.bondForKey(vm.addr(i == 0 ? 1 : 4097));
            value = keccak256(
                abi.encode(value, pending, ready, registered, id, registry.forfeited(_key(i == 0 ? "K0" : "K1")))
            );
        }
        for (uint256 i; i < registry.checkpointCount(); ++i) {
            value = keccak256(abi.encode(value, registry.checkpointAt(i)));
        }
    }

    /// @dev Captures all public observations of the genuine unissued/default identity.
    function _unissuedDigest() private view returns (bytes32) {
        (uint256 pending, uint48 ready) = registry.topUpOf(UNISSUED);
        (bool holds, uint256 slot) = registry.slotOfBond(UNISSUED);
        (bool exists, bytes memory reason) =
            address(registry).staticcall(abi.encodeCall(IEtnaStakingRegistry.bondAt, (UNISSUED)));
        return keccak256(
            abi.encode(
                registry.ownerOf(UNISSUED),
                pending,
                ready,
                holds,
                slot,
                registry.exitConfirmedAtL1(UNISSUED),
                exists,
                reason,
                registry.forfeited(_key("DefaultKey"))
            )
        );
    }

    /// @dev Raw fields outside legitimate recovery writes, including historical commitments.
    function _preservedDigest() private view returns (bytes32 value) {
        IEtnaInbox.RulesSchedule memory rules = _inbox().rulesSchedule();
        value = keccak256(
            abi.encode(
                registry.checkpointAt(0),
                _inbox().origins(0),
                _inbox().activeCommitteeSnapshot(),
                rules.activeRules,
                rules.nextRules,
                rules.rulesTime,
                taikoToken.balanceOf(Alice),
                taikoToken.balanceOf(PROTOCOL_FEE_RECIPIENT),
                taikoToken.balanceOf(SLASH_SINK)
            )
        );
        for (uint256 i; i <= 1; ++i) {
            IEtnaInbox.ForcedInclusion memory entry = _inbox().getForcedInclusion(uint48(i));
            value = keccak256(abi.encode(value, entry.timestamp, entry.l1Block));
        }
        value = keccak256(abi.encode(value, _inbox().getForcedInclusion(2)));
        for (uint256 h; h <= 2; ++h) {
            value = keccak256(abi.encode(value, _inbox().landings(_height(h))));
        }
    }

    /// @dev Every permanent original-bond observation survives no-op forceExit.
    function _oldBondDigest() private view returns (bytes32) {
        (uint256 pending, uint48 ready) = registry.topUpOf(0);
        return keccak256(
            abi.encode(
                registry.bondAt(0),
                registry.ownerOf(0),
                registry.exitConfirmedAtL1(0),
                pending,
                ready,
                registry.forfeited(originalKeys[0])
            )
        );
    }

    /// @dev Inventories all excluded custody, identities and actual slots independently.
    function _fillerDigest() private view returns (bytes32 value) {
        for (uint256 i = 1; i < 4096; ++i) {
            IEtnaStakingRegistry.Bond memory bond = registry.bondAt(i);
            assertTrue(bond.holdsSlot);
            assertFalse(bond.withdrawn);
            assertEq(bond.slot, i);
            assertEq(bond.entry.effStake, 5 * MIN_STAKE);
            assertEq(bond.entry.activeFromL1, 92);
            assertEq(bond.entry.exitEffectiveL1, registry.NO_EXIT());
            assertEq(registry.ownerOf(i), Alice);
            (uint256 pending, uint48 ready) = registry.topUpOf(i);
            (bool registered, uint256 id) = registry.bondForKey(vm.addr(i + 1));
            (bool occupied, uint256 holder) = registry.bondInSlot(i);
            assertTrue(registered && occupied);
            assertEq(id, i);
            assertEq(holder, i);
            assertEq(pending, 0);
            assertEq(ready, 0);
            assertEq(registry.exitConfirmedAtL1(i), 0);
            assertFalse(registry.forfeited(keccak256(abi.encode(bond.entry.ckPrefix, bond.entry.ckX))));
            assertEq(keccak256(abi.encode(registry.entryAt(i))), keccak256(abi.encode(bond.entry)));
            value = keccak256(abi.encode(value, bond, registry.ownerOf(i), registered, id, occupied, holder));
        }
    }

    /// @dev Reads original receipt fields only; no protocol acceptance predicates.
    function _u(string memory j, string memory p, string memory f) private view returns (uint256) {
        return vm.parseJsonUint(j, string.concat(p, f));
    }
}
