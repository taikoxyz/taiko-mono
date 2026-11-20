// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EtnaInboxTestBase} from "../EtnaInboxTestBase.sol";
import {EtnaReplayTestBase} from "./EtnaReplayTestBase.sol";
import {EtnaTestKeys} from "../EtnaTestKeys.sol";
import {IEtnaInbox} from "src/layer1/etna/iface/IEtnaInbox.sol";
import {IEtnaStakingRegistry} from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @notice Replays eighteen actual frozen M08 Held public attempts against deployed code.
/// @dev Gridq maps to6q; tokenunit maps toMIN_STAKE, feeunit to1gwei. Proof
/// verification is statement-bound mock. Callback/Withdrawn/literal confirmed95 are GAPs.
/// Model Unix timestamps map as T(t)=1200*t; L1 block coordinates remain unchanged.
contract EtnaRecoveryReplayTest is EtnaReplayTestBase {
    bytes32[2] private originalKeys;
    bytes4 private lastRecoveryRevert;
    string private constant FILE = "/test/layer1/etna/conformance/vectors/recovery_cases.json";

    /// @notice Leaves a source-valid uninitialized Inbox to initialize per scenario.
    function setUp() public override {
        vm.roll(90);
        vm.warp(1200 * 990);
        EtnaInboxTestBase.setUp();
    }

    /// @notice Executes all eighteen real atomic recovery attempts.
    function test_conformance_recoveryReplay() external {
        vm.pauseGasMetering();
        string memory j = vm.readFile(string.concat(vm.projectRoot(), FILE));
        assertEq(vm.parseJsonString(j, ".schema"), "etna-recovery-replay-1");
        assertEq(vm.parseJsonUint(j, ".grid"), K);
        assertTrue(vm.keyExistsJson(j, ".cases[17].id"));
        assertFalse(vm.keyExistsJson(j, ".cases[18].id"));
        uint256 snapshot = vm.snapshotState();
        for (uint256 i; i < 18; ++i) {
            emit log_string(vm.parseJsonString(j, string.concat(".cases[", vm.toString(i), "].id")));
            this.runCase(j, i);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    /// @notice Materializes and replays one public receipt in a separate memory frame.
    /// @param j The actual TLC-generated M08 receipt collection.
    /// @param index The selected receipt index.
    function runCase(string memory j, uint256 index) external {
        require(msg.sender == address(this), "test only");
        _setupHeld();
        string memory p = string.concat(".cases[", vm.toString(index), "].attempt");
        uint256 executionBlock = _u(j, p, ".execution.block");
        vm.roll(executionBlock);
        vm.warp(1200 * _u(j, p, ".execution.timestamp"));
        _assertCanonical(j, string.concat(p, ".before"));
        bytes32 original = _rawDigest();
        bytes32 preserved = _preservedDigest();
        bool ok = _callRecover(j, p);
        if (
            keccak256(bytes(vm.parseJsonString(j, string.concat(".cases[", vm.toString(index), "].id"))))
                == keccak256("LateUnissued/None")
        ) {
            assertEq(lastRecoveryRevert, IEtnaStakingRegistry.UnknownBond.selector, "genuine unissued/default record");
        }
        assertEq(ok, vm.parseJsonBool(j, string.concat(p, ".outcome.accepted")), p);
        if (!ok) {
            assertEq(_rawDigest(), original, "complete raw selected projection abort atomicity");
        }
        _assertCanonical(j, string.concat(p, ".after"));
        assertEq(_preservedDigest(), preserved, "raw metadata and historic records preserved");
        assertEq(registry.bondCount(), 2, "no new identity");
        assertEq(taikoToken.balanceOf(address(registry)), 6 * MIN_STAKE, "principal unchanged");
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
            vm.record();
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
            // code is replaced; real first-call tentative writes must be rolled back by EVM.
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
        if (lateFailure) {
            (, bytes32[] memory writes) = vm.accesses(address(registry));
            assertGt(writes.length, 0, "real first registry write before second-call failure");
        }
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
            _u(j, p, ".before.checkpoint") * K,
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
                _u(j, path, ".expectedC") * K,
                _u(j, path, ".expectedRecoveryNonce"),
                1200 * _u(j, path, ".validUntil"),
                exclusions,
                indices,
                uint48(_u(j, path, ".rules"))
            )
        );
    }

    /// @dev Builds the Held fixture solely via public token/registry/Inbox APIs.
    function _setupHeld() private {
        IEtnaStakingRegistry.Config memory config = _registryConfig(address(taikoToken), inboxProxy);
        config.activationDelay = 1;
        config.exitDelay = 1;
        config.withdrawalDelay = 3;
        registry = _deployRegistry(config);
        originalKeys[0] = EtnaTestKeys.entryKey(1);
        originalKeys[1] = EtnaTestKeys.entryKey(2);
        _registerAmount(1, 2 * MIN_STAKE);
        _registerAmount(2, 3 * MIN_STAKE);
        vm.roll(96);
        taikoToken.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        taikoToken.approve(address(registry), MIN_STAKE);
        vm.prank(Alice);
        registry.topUp(0, MIN_STAKE);
        vm.roll(97);
        vm.warp(1200 * 997);
        IEtnaInbox.Config memory inboxConfig = _defaultConfig();
        inboxConfig.forcedInclusionFeeInGwei = 1;
        inboxConfig.forcedInclusionFeeDoubleThreshold = 1;
        inboxImpl = _newInboxImpl(inboxConfig);
        IEtnaInbox.InitParams memory params = _leanInitParams();
        params.genesisCutoff = 94;
        params.maxAnchorAge = 1152;
        params.forcedInclusionDelay = 1;
        _upgradeAndInit(inboxImpl, params);
        _inbox().scheduleRules(1, 1200 * 1002);
        _inbox().scheduleStop(1200 * 1001, uint48(2 * K));
        vm.deal(Alice, 1 ether);
        vm.roll(98);
        vm.warp(1200 * 998);
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
        IEtnaInbox.LandInput memory input = _input(0, K);
        input.activeCommitteeSnapshot = 94;
        bytes32[] memory leaves = _leaves(0, K);
        landVerifier.setExpectedStatementHash(_statement(input, _inbox().landings(0), _cutHash(input, leaves)));
        _land(input, leaves);
        _assertSuccessfulPublication(input);
    }

    /// @dev Pays for a real key registration under this registry's actual domain.
    function _registerAmount(uint256 key, uint256 amount) private {
        taikoToken.mint(Alice, amount);
        vm.prank(Alice);
        taikoToken.approve(address(registry), amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(key);
        bytes memory pop = EtnaTestKeys.popSig(key, registry, Alice);
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
            result[i] =
                IEtnaInbox.Exclusion(_u(j, e, ".bondId"), _key(vm.parseJsonString(j, string.concat(e, ".entryKey"))));
        }
    }

    /// @dev Checks all finite canonical fields against the actual model public observation.
    function _assertCanonical(string memory j, string memory p) private view {
        _assertCheckpoint(_u(j, p, ".checkpoint") * K, bytes32(100 + _u(j, p, ".checkpoint") * K));
        assertEq(_inbox().recoveryGeneration(), _u(j, p, ".generation"));
        assertEq(_inbox().recoveryNonce(), _u(j, p, ".nonce"));
        assertEq(_inbox().origins(_inbox().recoveryGeneration()).startHeight, _u(j, p, ".start") * K);
        string memory state = string.concat(p, ".state");
        _assertQueue(_u(j, state, ".head"), _u(j, state, ".tail"));
        assertEq(_inbox().activeCommitteeSnapshot(), _u(j, state, ".activeSnapshot"));
        assertEq(address(inboxProxy).balance, _u(j, state, ".fees") * 1 gwei, "admission fees retained");
        assertEq(taikoToken.balanceOf(address(registry)), _u(j, state, ".tokenVault") * MIN_STAKE);
        for (uint256 h; h <= 2; ++h) {
            string memory r = string.concat(p, ".landings.", vm.toString(h));
            if (vm.parseJsonBool(j, string.concat(r, ".present"))) {
                _assertLanding(h * K, _record(_u(j, r, ".parent") * K, _u(j, r, ".generation"), h, h * K));
            } else {
                IEtnaInbox.Landing memory empty;
                _assertLanding(h * K, empty);
            }
        }
        for (uint256 g; g <= 1; ++g) {
            string memory o = string.concat(state, ".origins.", vm.toString(g));
            IEtnaInbox.Origin memory actual = _inbox().origins(g);
            assertEq(actual.startHeight, _u(j, o, ".start") * K);
            assertEq(actual.l1BlockNumber, _u(j, o, ".block"));
            assertEq(actual.l1Timestamp, 1200 * _u(j, o, ".timestamp"));
        }
        for (uint256 i; i <= 2; ++i) {
            _assertBond(j, string.concat(state, ".bonds.", vm.toString(i)), i);
        }
        for (uint256 i; i <= 1; ++i) {
            string memory token = i == 0 ? "K0" : "K1";
            (bool registered, uint256 id) = registry.bondForKey(vm.addr(i + 1));
            assertEq(registered, vm.parseJsonBool(j, string.concat(state, ".registered.", token)));
            assertEq(id, i);
            assertEq(registry.forfeited(_key(token)), vm.parseJsonBool(j, string.concat(state, ".forfeited.", token)));
            string memory slot = string.concat(state, ".slots.", vm.toString(i));
            (bool occupied, uint256 holder) = registry.bondInSlot(i);
            assertEq(occupied, vm.parseJsonBool(j, string.concat(slot, ".occupied")));
            assertEq(holder, _u(j, slot, ".id"));
        }
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
        assertEq(keccak256(abi.encode(registry.entryAt(id))), keccak256(abi.encode(bond.entry)), "slot mirrors bond");
        assertEq(bond.entry.activeFromL1, 92, "activation metadata preserved");
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
        (bool occupied, uint256 heldId) = registry.bondInSlot(id);
        assertTrue(occupied);
        assertEq(heldId, id);
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
                    registry.bondAt(i),
                    registry.ownerOf(i),
                    registry.exitConfirmedAtL1(i),
                    registry.entryAt(i),
                    _inbox().getForcedInclusion(uint48(i)),
                    _inbox().origins(i)
                )
            );
        }
        value = keccak256(abi.encode(value, _inbox().getForcedInclusion(2)));
        for (uint256 h; h <= 2; ++h) {
            value = keccak256(abi.encode(value, _inbox().landings(h * K)));
        }
        for (uint256 i; i <= 1; ++i) {
            (uint256 pending, uint48 ready) = registry.topUpOf(i);
            (bool registered, uint256 id) = registry.bondForKey(vm.addr(i + 1));
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
        (uint256 pending, uint48 ready) = registry.topUpOf(2);
        (bool holds, uint256 slot) = registry.slotOfBond(2);
        (bool exists, bytes memory reason) =
            address(registry).staticcall(abi.encodeCall(IEtnaStakingRegistry.bondAt, (uint256(2))));
        return keccak256(
            abi.encode(
                registry.ownerOf(2),
                pending,
                ready,
                holds,
                slot,
                registry.exitConfirmedAtL1(2),
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
            value = keccak256(abi.encode(value, _inbox().landings(h * K)));
        }
    }

    /// @dev Reads original receipt fields only; no protocol acceptance predicates.
    function _u(string memory j, string memory p, string memory f) private view returns (uint256) {
        return vm.parseJsonUint(j, string.concat(p, f));
    }
}

/// @notice Concrete unconfirmed issued/unheld recovery variant outside the Held projection.
contract EtnaRecoveryUnheldReplayTest is EtnaReplayTestBase {
    /// @notice Exercises a genuinely issued/unheld unconfirmed bond from paid public history.
    /// @dev Separate concrete variant, not literal M08 confirmed95 displaced correspondence.
    function test_publicDisplacementThenUnheldRecoveryExclusion() external {
        vm.pauseGasMetering();
        bytes32 oldKey = _entryKey(registry, 0);
        for (uint256 i = 1; i < 4096; ++i) {
            this.registerFiller(i);
        }
        assertEq(registry.bondCount(), 4096);
        vm.roll(12);
        uint256 amount = 2 * MIN_STAKE;
        taikoToken.mint(Alice, amount);
        vm.prank(Alice);
        taikoToken.approve(address(registry), amount);
        bytes memory key = EtnaTestKeys.publicKey(4097);
        bytes memory pop = EtnaTestKeys.popSig(4097, registry, Alice);
        vm.prank(Alice);
        assertEq(registry.register(key, amount, pop), 4096);
        (bool oldHeld,) = registry.slotOfBond(0);
        assertFalse(oldHeld);
        (bool occupied, uint256 replacement) = registry.bondInSlot(0);
        assertTrue(occupied);
        assertEq(replacement, 4096);
        assertEq(registry.bondAt(0).entry.effStake, MIN_STAKE);
        bytes32 oldBond = keccak256(abi.encode(registry.bondAt(0), registry.ownerOf(0)));
        assertEq(registry.exitConfirmedAtL1(0), 0, "explicit unconfirmed variant");
        bytes32 beforeReplacement = keccak256(abi.encode(registry.bondAt(4096), registry.entryAt(0)));
        bytes32 beforeRoot = registry.entriesRoot();
        uint256 beforeVault = taikoToken.balanceOf(address(registry));
        IEtnaInbox.Exclusion[] memory exclusions = new IEtnaInbox.Exclusion[](1);
        exclusions[0] = IEtnaInbox.Exclusion(0, oldKey);
        vm.roll(13);
        vm.warp(block.timestamp + 1);
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, new uint256[](0), 0);
        assertEq(_inbox().recoveryGeneration(), 1);
        assertEq(registry.bondAt(0).entry.exitEffectiveL1, 12);
        assertEq(
            keccak256(abi.encode(registry.bondAt(0), registry.ownerOf(0))), oldBond, "funded unheld bond preserved"
        );
        assertEq(registry.exitConfirmedAtL1(0), 0, "confirmation unchanged");
        assertEq(keccak256(abi.encode(registry.bondAt(4096), registry.entryAt(0))), beforeReplacement);
        assertEq(registry.entriesRoot(), beforeRoot);
        assertEq(taikoToken.balanceOf(address(registry)), beforeVault);
        emit log_string("4096 public registrations + paid replacement + genuine issued/unheld exclusion");
    }

    /// @notice Registers one paid filler in a bounded external memory frame.
    /// @param id The fresh consensus-key fixture identity.
    function registerFiller(uint256 id) external {
        require(msg.sender == address(this));
        _registerValidator(registry, Alice, id);
    }
}
