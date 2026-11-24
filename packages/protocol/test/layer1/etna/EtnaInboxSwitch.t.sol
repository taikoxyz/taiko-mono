// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxSwitchTestBase } from "./EtnaInboxSwitchTestBase.sol";
import { MockUnzenInbox } from "./MockUnzenInbox.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IUnzenProposeCutoff } from "src/layer1/etna/iface/IUnzenProposeCutoff.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title EtnaInboxSwitchTest
/// @notice The Etna start on a switching network (spec 10 steps 5-5c, SWITCH.md): `init` without a
/// start, the origin multisig's `setOrigin(S)` latch over the live Unzen Inbox (START-10-5a,
/// LAND-6.1-8a), the Unzen checkpoint forwarder (START-10-5) and landings at any height above S
/// (6.1), with the vector numbers of rules/vectors/10.md.
contract EtnaInboxSwitchTest is EtnaInboxSwitchTestBase {
    uint256 private constant _TWO_POW_48 = 2 ** 48;

    // ---------------------------------------------------------------
    // init (START-10-5, vector 5.k)
    // ---------------------------------------------------------------

    /// @dev `init` stores the config hash and the forced inclusion parameters but no start:
    /// slots 270-274, landings(0) and origins(0) stay zero, and no SignalService
    /// checkpoint is saved. Before the start write forced inclusion (5b.b), `land` and `recover`
    /// (RECOV-8.3-2) revert, and so do the views of the missing generation 0 origin (8.4 5.b);
    /// invalidating the recovery nonce and scheduling work.
    function test_init_SwitchingNetworkWritesNoStart() external {
        assertTrue(_inbox().isInitialized(), "initialized");
        assertEq(_inboxWord(GENESIS_PACKED_SLOT), 0, "272");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), 0, "273");
        assertEq(_inboxWord(GENESIS_STATE_ROOT_SLOT), 0, "274");
        _assertCheckpoint(0, 0);
        for (uint256 w; w < 4; ++w) {
            assertEq(_inboxWord(_landingSlot(0) + w), 0, "landings(0)");
        }
        for (uint256 w; w < 4; ++w) {
            assertEq(_inboxWord(_originSlot(0) + w), 0, "origins(0)");
        }
        _assertStart(0, 0);
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(0);
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        _inbox().generationStartHeight();

        vm.deal(Alice, 1 ether);
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: 1 ether }(hex"c0");
        _expectLandRevert(_input(0, 6), _leaves(0, 6), IEtnaInbox.MissingOrigin.selector);
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        _inbox().recover(0, 0, 0, type(uint256).max, new uint256[](0), 0);

        _inbox().invalidateRecoveryNonce(0);
        _inbox().scheduleStop(0, uint48(block.timestamp + MAX_ANCHOR_AGE));
        assertEq(_inbox().recoveryNonce(), 1, "nonce invalidated");
    }

    /// @dev A switching network's `init` takes no genesis hash or state root, and a new network's
    /// needs both.
    function test_init_RevertWhen_GenesisDoesNotMatchTheNetwork() external {
        _deployFreshInbox(_switchConfig(), _switchInitParams(), false);
        IEtnaInbox.InitParams memory params = _switchInitParams();
        params.genesisBlockHash = _startHash();
        vm.expectRevert(IEtnaInbox.InvalidGenesis.selector);
        _upgradeAndInit(inboxImpl, params);
        params = _switchInitParams();
        params.genesisStateRoot = _startStateRoot();
        vm.expectRevert(IEtnaInbox.InvalidGenesis.selector);
        _upgradeAndInit(inboxImpl, params);

        _deployFreshInbox(_defaultConfig(), _switchInitParams(), false);
        vm.expectRevert(IEtnaInbox.InvalidGenesis.selector);
        _upgradeAndInit(inboxImpl, _switchInitParams());
    }

    /// @dev PARAM-11-12a: the Unzen Inbox, the fork time and the origin multisig are all set or
    /// all zero, and the Unzen Inbox has code.
    function test_constructor_RevertWhen_SwitchConfigIsMixed() external {
        IEtnaInbox.Config memory config = _switchConfig();
        config.etnaForkTime = 0;
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        new EtnaInbox(config);

        config = _switchConfig();
        config.unzenInbox = address(0);
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        new EtnaInbox(config);

        // A switching network needs the origin multisig, and a new network takes none.
        config = _switchConfig();
        config.originMultisig = address(0);
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        new EtnaInbox(config);

        config = _defaultConfig();
        config.originMultisig = ORIGIN_MULTISIG;
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        new EtnaInbox(config);

        assertEq(new EtnaInbox(_switchConfig()).originMultisig(), ORIGIN_MULTISIG, "switching");
        assertEq(new EtnaInbox(_defaultConfig()).originMultisig(), address(0), "new network");

        config = _switchConfig();
        config.unzenInbox = address(0xC0DE);
        vm.expectRevert(IEtnaInbox.InvalidSwitchConfig.selector);
        new EtnaInbox(config);
    }

    // ---------------------------------------------------------------
    // setOrigin (START-10-5a, LAND-6.1-8a, START-10-5b, START-10-5c)
    // ---------------------------------------------------------------

    /// @dev 5a.a, 8a.a, 5b.a, 5b.e, 5c.a: with the proposal set closed and fully proven (next ID
    /// 8, last finalized 7, tip H) and the SignalService checkpoint at S returning a zero hash and
    /// root R, the origin multisig latches S at exactly `FORK_TIME` in L1 block B. The start write
    /// takes H from the Unzen Inbox and R from the checkpoint and writes slot 272 = (1000, B),
    /// slots 273/274, origins(0) = (1000, B, FORK_TIME, slot 278), the checkpoint (1000, H) and
    /// landings(1000) = (1000, 0, 0, H, 0); it leaves the SignalService checkpoint untouched and
    /// opens the forced inclusion queue at head 0.
    function test_setOrigin_LatchesTheFinalizedUnzenTip() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME);
        _assertSignalCheckpoint(S, _startStateRoot());
        uint256 b = block.number;
        vm.expectCall(
            address(signalService),
            abi.encodeWithSelector(ICheckpointStore.saveCheckpoint.selector),
            0
        );
        vm.expectCall(address(unzen), abi.encodeCall(IUnzenProposeCutoff.proposeCutoff, ()));
        vm.expectCall(address(unzen), abi.encodeCall(MockUnzenInbox.getCoreState, ()));
        vm.expectCall(
            address(signalService), abi.encodeCall(ICheckpointStore.getCheckpoint, (uint48(S)))
        );
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.StartWritten(S, _startHash(), _startStateRoot());
        vm.prank(ORIGIN_MULTISIG);
        _inbox().setOrigin(uint48(S));

        assertEq(uint256(_inboxWord(GENESIS_PACKED_SLOT)), S | b << 48, "272");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), _startHash(), "273");
        assertEq(_inboxWord(GENESIS_STATE_ROOT_SLOT), _startStateRoot(), "274");
        IEtnaInbox.Origin memory origin = _inbox().origins(0);
        assertEq(origin.startHeight, S, "origin height");
        assertEq(origin.l1BlockNumber, b, "L1_0");
        assertEq(origin.l1Timestamp, FORK_TIME, "origin timestamp");
        assertEq(origin.fallbackKeysHash, _inboxWord(FALLBACK_KEYS_HASH_SLOT), "origin word 4");
        assertEq(_inboxWord(_originSlot(0) + 3), DEFAULT_FALLBACK_KEYS_HASH, "slot 278 at S");
        assertEq(_inbox().generationStartHeight(), S, "generationStartHeight");
        _assertCheckpoint(S, _startHash());
        _assertLanding(S, _record(S, 0, 0, S));
        _assertStart(S, _startHash());
        _assertSignalCheckpoint(S, _startStateRoot());

        vm.deal(Alice, 1 ether);
        _saveForcedInclusions(1);
        _assertQueue(0, 1);
    }

    /// @dev 5a.f: an unrelated caller supplying the correct S after every other gate passes is
    /// refused without writing the start. The caller is checked first, so it is refused before
    /// the fork time and on an uninitialized Inbox too; the multisig then writes the start.
    function test_setOrigin_RevertWhen_CallerIsNotTheOriginMultisig() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME);
        _expectSetOriginRevertFrom(Carol, S, IEtnaInbox.NotOriginMultisig.selector);
        _expectSetOriginRevertFrom(address(this), S, IEtnaInbox.NotOriginMultisig.selector);
        _expectSetOriginRevertFrom(address(unzen), S, IEtnaInbox.NotOriginMultisig.selector);
        vm.warp(FORK_TIME - 1);
        _expectSetOriginRevertFrom(Carol, S, IEtnaInbox.NotOriginMultisig.selector);

        vm.warp(FORK_TIME);
        vm.prank(ORIGIN_MULTISIG);
        _inbox().setOrigin(uint48(S));
        _assertStart(S, _startHash());

        _deployFreshInbox(_switchConfig(), _switchInitParams(), false);
        _inbox().upgradeTo(address(inboxImpl));
        _expectSetOriginRevertFrom(Carol, S, IEtnaInbox.NotOriginMultisig.selector);
    }

    /// @dev The origin record's fourth word is slot 278 at the start write, not at `init`: keys
    /// the owner sets between the two are the ones generation 0's record holds.
    function test_setOrigin_RecordsTheFallbackKeysHashAtTheStartWrite() external {
        IEtnaInbox.FallbackKey[] memory keys = _sortedKeys(3);
        _inbox().setFallbackKeys(keys);
        bytes32 keysHash = _fallbackKeysHash(keys);
        assertTrue(keysHash != DEFAULT_FALLBACK_KEYS_HASH, "a new list");

        _writeStart();

        assertEq(_inbox().origins(0).fallbackKeysHash, keysHash, "origins(0).fallbackKeysHash");
        assertEq(_inboxWord(_originSlot(0) + 3), keysHash, "origin word 4");
    }

    /// @dev 5a.b: one second before the fork the call reverts, even with the tip proven.
    function test_setOrigin_RevertWhen_BeforeTheForkTime() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME - 1);
        _expectSetOriginRevert(S, IEtnaInbox.BeforeEtnaForkTime.selector);
    }

    /// @dev 5a.b: a `proposeCutoff()` that reverts, returns zero or returns a future timestamp
    /// rejects the call, even with the current tip proven: an open proposal set cannot supply a
    /// start.
    function test_setOrigin_RevertWhen_ProposalsAreNotClosed() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME);

        unzen.setProposeCutoffReverts(true);
        _expectSetOriginRevert(S, MockUnzenInbox.ProposeCutoffUnavailable.selector);
        unzen.setProposeCutoffReverts(false);

        unzen.setProposeCutoff(0);
        _expectSetOriginRevert(S, IEtnaInbox.ProposalsNotClosed.selector);

        unzen.setProposeCutoff(FORK_TIME + 1);
        _expectSetOriginRevert(S, IEtnaInbox.ProposalsNotClosed.selector);
    }

    /// @dev 5a.e: a cutoff equal to the current timestamp passes the cutoff predicate.
    function test_setOrigin_CutoffReachedExactly() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME + 100);
        unzen.setProposeCutoff(FORK_TIME + 100);
        vm.prank(ORIGIN_MULTISIG);
        _inbox().setOrigin(uint48(S));
        _assertStart(S, _startHash());
    }

    /// @dev 5a.c: a repeated call, an uninitialized Inbox and a new network all revert.
    function test_setOrigin_RevertWhen_RepeatedUninitializedOrNotSwitching() external {
        _writeStart();
        _expectSetOriginRevert(S, IEtnaInbox.StartAlreadyWritten.selector);

        _deployFreshInbox(_switchConfig(), _switchInitParams(), false);
        _inbox().upgradeTo(address(inboxImpl));
        vm.warp(FORK_TIME);
        _expectSetOriginRevert(S, IEtnaInbox.NotInitialized.selector);

        // A new network has no origin multisig, so every caller is refused. Even the zero address,
        // which no transaction is sent from, finds the latch closed: `init` wrote the start at
        // block 0, and with slot 273 cleared its zero Unzen Inbox and fork time reject the call.
        _deployFreshInbox(true);
        _expectSetOriginRevert(S, IEtnaInbox.NotOriginMultisig.selector);
        _expectSetOriginRevertFrom(address(0), S, IEtnaInbox.StartAlreadyWritten.selector);
        _storeInboxWord(GENESIS_BLOCK_HASH_SLOT, 0);
        _expectSetOriginRevert(S, IEtnaInbox.NotOriginMultisig.selector);
        _expectSetOriginRevertFrom(address(0), S, IEtnaInbox.NotSwitching.selector);
    }

    /// @dev 5a.d: of S = 0, 2^48 - 1 and 2^48, only 2^48 - 1 passes the height check; 2^48 does
    /// not decode as a `uint48`.
    function test_setOrigin_HeightBoundaries() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME);
        _expectSetOriginRevert(0, IEtnaInbox.InvalidStart.selector);

        (bool ok,) = inboxProxy.call(abi.encodeWithSignature("setOrigin(uint48)", _TWO_POW_48));
        assertFalse(ok, "2^48 does not decode");
        _assertStart(0, 0);

        bytes32 tip = bytes32(uint256(0x7e));
        unzen.setCoreState(8, 7, tip);
        _forwardUnzenCheckpoint(_TWO_POW_48 - 1, tip, bytes32(uint256(0x7f)));
        vm.prank(ORIGIN_MULTISIG);
        _inbox().setOrigin(type(uint48).max);
        _assertStart(_TWO_POW_48 - 1, tip);
    }

    /// @dev 8a.b: an unfinalized proposal (next ID 9, last finalized 7) rejects the call without
    /// writing state; once the final proof finalizes it, the multisig retries with its height.
    function test_setOrigin_RevertWhen_UnzenIsNotFinalized() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME);
        unzen.setCoreState(9, 7, _startHash());
        _expectSetOriginRevert(S, IEtnaInbox.UnzenNotFinalized.selector);

        bytes32 tip = bytes32(uint256(0x7e));
        unzen.setCoreState(9, 8, tip);
        _forwardUnzenCheckpoint(S + 3, tip, bytes32(uint256(0x7f)));
        vm.prank(ORIGIN_MULTISIG);
        _inbox().setOrigin(uint48(S + 3));
        _assertStart(S + 3, tip);
    }

    /// @dev 8a.c: the multisig supplies an earlier checkpointed height with a nonzero root. Every
    /// on-chain gate passes, because L1 does not tie the finalized hash to a height, so the write
    /// succeeds with that height, the finalized hash H and the earlier root; nodes and guests
    /// reject the mismatch later. A second write, even with the right height, reverts.
    function test_setOrigin_LatchesAnEarlierCheckpointedHeightOnce() external {
        _finalizeUnzen();
        bytes32 earlierRoot = _stateRoot(S - 1);
        _forwardUnzenCheckpoint(S - 1, bytes32(100 + S - 1), earlierRoot);
        vm.warp(FORK_TIME);

        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.StartWritten(S - 1, _startHash(), earlierRoot);
        vm.prank(ORIGIN_MULTISIG);
        _inbox().setOrigin(uint48(S - 1));
        _assertStart(S - 1, _startHash());
        assertEq(_inboxWord(GENESIS_STATE_ROOT_SLOT), earlierRoot, "274");
        assertEq(_inbox().generationStartHeight(), S - 1, "generationStartHeight");

        _expectSetOriginRevert(S, IEtnaInbox.StartAlreadyWritten.selector);
        _expectSetOriginRevert(S - 1, IEtnaInbox.StartAlreadyWritten.selector);
    }

    /// @dev 8a.d: a height without a checkpoint, a zero Unzen finalized hash and a zero
    /// checkpoint state root all revert, and Etna forced inclusion stays closed. The checkpoint's
    /// hash field is not compared: the finalized hash needs only to be nonzero.
    function test_setOrigin_RevertWhen_TheCheckpointOrTheFinalizedHashIsMissing() external {
        _finalizeUnzen();
        vm.warp(FORK_TIME);

        _expectSetOriginRevert(S + 1, SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        unzen.setCoreState(8, 7, 0);
        _expectSetOriginRevert(S, IEtnaInbox.UnzenTipHashZero.selector);

        // The SignalService rejects a zero state root, so a zero one can only be read back from a
        // store that holds it.
        unzen.setCoreState(8, 7, _startHash());
        vm.mockCall(
            address(signalService),
            abi.encodeCall(ICheckpointStore.getCheckpoint, (uint48(S))),
            abi.encode(
                ICheckpointStore.Checkpoint({ blockNumber: uint48(S), blockHash: 0, stateRoot: 0 })
            )
        );
        _expectSetOriginRevert(S, IEtnaInbox.InvalidStart.selector);
        vm.clearMockedCalls();

        vm.deal(Alice, 1 ether);
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: 1 ether }(hex"c0");
    }

    // ---------------------------------------------------------------
    // The Unzen checkpoint forwarder (START-10-5, vectors 5.n-5.r)
    // ---------------------------------------------------------------

    /// @dev 5.p: before the start write the Inbox forwards an Unzen checkpoint at any height,
    /// unchanged.
    function test_saveCheckpoint_ForwardsAnyHeightBeforeTheStart() external {
        _forwardUnzenCheckpoint(S + 600, bytes32(uint256(1)), bytes32(uint256(2)));
        _forwardUnzenCheckpoint(1, bytes32(uint256(3)), bytes32(uint256(4)));

        _assertSignalCheckpoint(S + 600, bytes32(uint256(2)));
        _assertSignalCheckpoint(1, bytes32(uint256(4)));
    }

    /// @dev 5.n, 5.o: once the start is written the forwarder reverts at every height, below, at
    /// and above S, and the stored checkpoints stay unchanged.
    function test_saveCheckpoint_ClosedAtEveryHeightOnceTheStartIsWritten() external {
        _writeStart();
        uint256[3] memory heights = [S - 1, S, S + 1];
        for (uint256 i; i < heights.length; ++i) {
            vm.expectRevert(IEtnaInbox.ForwardingClosed.selector);
            _forwardUnzenCheckpoint(heights[i], bytes32(uint256(1)), bytes32(uint256(2)));
        }
        _assertSignalCheckpoint(S, _startStateRoot());
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(uint48(S - 1));
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(uint48(S + 1));
    }

    /// @dev 5.r: only the Unzen Inbox may call it; the Inbox's owner and others may not, and on a
    /// new network nobody may.
    function test_saveCheckpoint_RevertWhen_CallerIsNotTheUnzenInbox() external {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: uint48(S), blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(2))
        });
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        EtnaInbox(inboxProxy).saveCheckpoint(checkpoint);
        vm.prank(Carol);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        EtnaInbox(inboxProxy).saveCheckpoint(checkpoint);

        _deployFreshInbox(true);
        vm.prank(address(unzen));
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        EtnaInbox(inboxProxy).saveCheckpoint(checkpoint);
    }

    /// @dev 5.q: it reverts for no reason besides its own checks and the SignalService's: not
    /// while paused or before `init`.
    function test_saveCheckpoint_IgnoresPauseAndInitialization() external {
        EssentialContract(inboxProxy).pause();
        _forwardUnzenCheckpoint(S, _startHash(), _startStateRoot());
        _assertSignalCheckpoint(S, _startStateRoot());

        // A fresh proxy upgraded to the switching implementation but not yet initialized.
        _deployFreshInbox(_switchConfig(), _switchInitParams(), false);
        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        assertFalse(_inbox().isInitialized(), "uninitialized");
        _forwardUnzenCheckpoint(S, _startHash(), _startStateRoot());
        _assertSignalCheckpoint(S, _startStateRoot());

        // The SignalService's own checks still apply.
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _forwardUnzenCheckpoint(S, _startHash(), 0);
    }

    // ---------------------------------------------------------------
    // Landing from S (LAND-6.1-5, vector 8a.e)
    // ---------------------------------------------------------------

    /// @dev With S = 1000, landings end at any height above the checkpoint: 1002 and 1008 land.
    function test_land_AnyHeightFromTheStart() external {
        _writeStart();
        _land(S, S + 2);
        _land(S + 2, S + 8);
        _land(S + 8, S + 18);
        _assertLanding(S + 18, _record(S + 8, 0, 0, S + 18));
    }

    /// @dev 8a.e: after the start write the first landing from S uses S's recorded origin and
    /// reads nothing from the Unzen Inbox, even once its state no longer shows the tip.
    function test_land_FirstLandingReadsNoUnzenState() external {
        _writeStart();
        unzen.setCoreState(9, 7, bytes32(uint256(1)));
        unzen.setProposeCutoffReverts(true);
        vm.expectCall(address(unzen), "", 0);
        _land(S, S + 6);
        _assertCheckpoint(S + 6, bytes32(100 + S + 6));
    }

    /// @dev 5c.b: neither a landing nor a governance recovery at c = S rewrites the start, and the
    /// recovery generation lands from S without an Unzen read.
    function test_start_SurvivesRecoveryAtTheStart() external {
        _writeStart();
        bytes32[3] memory start = [
            _inboxWord(GENESIS_PACKED_SLOT),
            _inboxWord(GENESIS_BLOCK_HASH_SLOT),
            _inboxWord(GENESIS_STATE_ROOT_SLOT)
        ];
        _inbox().recover(0, S, 0, type(uint256).max, new uint256[](0), 0);
        assertEq(_inbox().generationStartHeight(), S, "generation 1 starts at S");
        unzen.setCoreState(9, 7, bytes32(uint256(1)));
        vm.expectCall(address(unzen), "", 0);
        _land(S, S + 6);
        assertEq(_inbox().landings(S + 6).generation, 1, "generation 1 landing");

        assertEq(_inboxWord(GENESIS_PACKED_SLOT), start[0], "272 unchanged");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), start[1], "273 unchanged");
        assertEq(_inboxWord(GENESIS_STATE_ROOT_SLOT), start[2], "274 unchanged");
        _assertSignalCheckpoint(S, _startStateRoot());
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Expects the origin multisig's `setOrigin(_s)` to revert with `_selector`, writing no
    /// start.
    function _expectSetOriginRevert(uint256 _s, bytes4 _selector) private {
        _expectSetOriginRevertFrom(ORIGIN_MULTISIG, _s, _selector);
    }

    /// @dev Expects `_caller`'s `setOrigin(_s)` to revert with `_selector`, writing no start.
    function _expectSetOriginRevertFrom(
        address _caller,
        uint256 _s,
        bytes4 _selector
    )
        private
    {
        bytes32[4] memory before = [
            _inboxWord(GENESIS_PACKED_SLOT),
            _inboxWord(GENESIS_BLOCK_HASH_SLOT),
            _inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT),
            _inboxWord(_originSlot(0) + 1)
        ];
        vm.expectRevert(_selector);
        vm.prank(_caller);
        _inbox().setOrigin(uint48(_s));
        assertEq(_inboxWord(GENESIS_PACKED_SLOT), before[0], "272 unchanged");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), before[1], "273 unchanged");
        assertEq(_inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT), before[2], "270 unchanged");
        assertEq(_inboxWord(_originSlot(0) + 1), before[3], "origins(0) unchanged");
    }

    /// @dev Checks the root-only SignalService checkpoint at `_height`: `_stateRoot` and a zero
    /// hash.
    function _assertSignalCheckpoint(uint256 _height, bytes32 _stateRoot) private view {
        ICheckpointStore.Checkpoint memory checkpoint = signalService.getCheckpoint(uint48(_height));
        assertEq(checkpoint.blockHash, 0, "checkpoint hash");
        assertEq(checkpoint.stateRoot, _stateRoot, "checkpoint state root");
        assertEq(signalService.getStateRoot(uint64(_height)), _stateRoot, "getStateRoot");
    }

    /// @dev Checks `etnaStart()` and slot 273.
    function _assertStart(uint256 _height, bytes32 _blockHash) private view {
        (uint48 height, bytes32 blockHash) = _inbox().etnaStart();
        assertEq(height, _height, "etnaStart height");
        assertEq(blockHash, _blockHash, "etnaStart hash");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), _blockHash, "273");
    }
}
