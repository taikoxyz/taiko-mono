// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxSwitchTestBase } from "./EtnaInboxSwitchTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title EtnaInboxSwitchTest
/// @notice The Etna start on a switching network (spec 10 steps 5-5b, SWITCH.md): `init` without a
/// start, `setOrigin`, the grid counted from S (6.1) and the first-landing Unzen check
/// (LAND-6.1-8a), with the vector numbers of rules/vectors/10.md and 6.1.md.
contract EtnaInboxSwitchTest is EtnaInboxSwitchTestBase {
    uint256 private constant _TWO_POW_48 = 2 ** 48;

    // ---------------------------------------------------------------
    // init (START-10-5, vector 5.k)
    // ---------------------------------------------------------------

    /// @dev `init` stores L, the committee and FI parameters but no start: slots 270/271 and
    /// 273/274, landings(0) and origins(0) stay zero, slot 272 holds only L, and no SignalService
    /// checkpoint is saved. Before the start write forced inclusion (5b.b), `land` and `recover`
    /// (RECOV-8.3-2) revert; invalidating the recovery nonce and scheduling work.
    function test_init_SwitchingNetworkWritesNoStart() external {
        assertTrue(_inbox().isInitialized(), "initialized");
        assertEq(uint256(_inboxWord(GENESIS_PACKED_SLOT)), EPOCH_LEN_L2 << 96, "272: L only");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), 0, "273");
        assertEq(_inboxWord(GENESIS_STATE_ROOT_SLOT), 0, "274");
        _assertCheckpoint(0, 0);
        for (uint256 w; w < 3; ++w) {
            assertEq(_inboxWord(_landingSlot(0) + w), 0, "landings(0)");
            assertEq(_inboxWord(_originSlot(0) + w), 0, "origins(0)");
        }
        _assertStart(0, 0);
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(0);

        vm.deal(Alice, 1 ether);
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: 1 ether }(hex"c0");
        _expectLandRevert(_input(0, 6), _leaves(0, 6), IEtnaInbox.MissingOrigin.selector);
        vm.expectRevert(IEtnaInbox.StartNotWritten.selector);
        _inbox()
            .recover(0, 0, 0, type(uint256).max, new IEtnaInbox.Exclusion[](0), new uint256[](0), 0);

        _inbox().invalidateRecoveryNonce(0);
        _inbox().scheduleStop(uint48(block.timestamp + MAX_ANCHOR_AGE), 6);
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

    // ---------------------------------------------------------------
    // setOrigin (START-10-5a, 10-5b, 10-5c)
    // ---------------------------------------------------------------

    /// @dev 5a.a, 5b.a, 5b.e, 5c.a: Carol's call at exactly `FORK_TIME` in L1 block B writes slot
    /// 272 = (1000, B, L), slots 273/274, origins(0) = (1000, B, FORK_TIME), the checkpoint
    /// (1000, H) and landings(1000) = (1000, 0, 0, H, 0), saves no SignalService checkpoint and
    /// opens the forced inclusion queue at head 0.
    function test_setOrigin_WritesTheStart() external {
        vm.warp(FORK_TIME);
        uint256 b = block.number;
        vm.expectCall(
            address(signalService),
            abi.encodeWithSelector(ICheckpointStore.saveCheckpoint.selector),
            0
        );
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.StartWritten(S, _startHash(), _startStateRoot());
        vm.prank(Carol);
        _inbox().setOrigin(S, _startHash(), _startStateRoot());

        assertEq(uint256(_inboxWord(GENESIS_PACKED_SLOT)), S | b << 48 | EPOCH_LEN_L2 << 96, "272");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), _startHash(), "273");
        assertEq(_inboxWord(GENESIS_STATE_ROOT_SLOT), _startStateRoot(), "274");
        IEtnaInbox.Origin memory origin = _inbox().origins(0);
        assertEq(origin.startHeight, S, "origin height");
        assertEq(origin.l1BlockNumber, b, "L1_0");
        assertEq(origin.l1Timestamp, FORK_TIME, "origin timestamp");
        assertEq(_inbox().generationStartHeight(), S, "generationStartHeight");
        assertEq(_inbox().recoverySnapshot(), b, "recoverySnapshot");
        _assertCheckpoint(S, _startHash());
        _assertLanding(S, _record(S, 0, 0, S));
        _assertStart(S, _startHash());

        vm.deal(Alice, 1 ether);
        _saveForcedInclusions(1);
        _assertQueue(0, 1);
    }

    /// @dev 5a.b, 5a.c, 5a.e: only Carol, at or after `FORK_TIME`, on an initialized Inbox.
    function test_setOrigin_RevertWhen_CallerTimeOrInitializationIsWrong() external {
        vm.warp(FORK_TIME);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        _inbox().setOrigin(S, _startHash(), _startStateRoot());

        vm.warp(FORK_TIME - 1);
        _expectSetOriginRevert(
            S, _startHash(), _startStateRoot(), IEtnaInbox.BeforeEtnaForkTime.selector
        );

        _deployFreshInbox(_switchConfig(), _switchInitParams(), false);
        _inbox().upgradeTo(address(inboxImpl));
        vm.warp(FORK_TIME);
        _expectSetOriginRevert(
            S, _startHash(), _startStateRoot(), IEtnaInbox.NotInitialized.selector
        );
    }

    /// @dev 5a.i, 5a.j, 5a.k, 5a.l, 5a.n: S in (0, 2^48) with a non-zero hash and state root.
    function test_setOrigin_RevertWhen_StartIsInvalid() external {
        vm.warp(FORK_TIME);
        bytes4 invalid = IEtnaInbox.InvalidStart.selector;
        _expectSetOriginRevert(S, 0, _startStateRoot(), invalid);
        _expectSetOriginRevert(S, _startHash(), 0, invalid);
        _expectSetOriginRevert(0, _startHash(), _startStateRoot(), invalid);
        _expectSetOriginRevert(_TWO_POW_48, _startHash(), _startStateRoot(), invalid);

        vm.prank(Carol);
        _inbox().setOrigin(_TWO_POW_48 - 1, _startHash(), _startStateRoot());
        _assertStart(_TWO_POW_48 - 1, _startHash());
    }

    /// @dev 5a.d, 5c.c: the start is written once.
    function test_setOrigin_RevertWhen_StartIsWritten() external {
        _writeStart();
        _expectSetOriginRevert(
            S + 6, bytes32(uint256(1)), bytes32(uint256(2)), IEtnaInbox.StartAlreadyWritten.selector
        );
    }

    /// @dev 5a.m: a new network's Inbox has no originWriter (and `init` wrote its start), so no
    /// call succeeds.
    function test_setOrigin_RevertWhen_NewNetwork() external {
        _deployFreshInbox(true);
        vm.warp(FORK_TIME);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        vm.prank(Carol);
        _inbox().setOrigin(S, _startHash(), _startStateRoot());
        _assertStart(0, GENESIS_BLOCK_HASH);
    }

    // ---------------------------------------------------------------
    // The grid counted from S (LAND-6.1-5, vectors 5.f and 5.g)
    // ---------------------------------------------------------------

    /// @dev With S = 1000 and K = 6, grid points are 1000, 1006, 1012, ...: 1002 and 1008 (a
    /// multiple of 6 counted from block 0) are off the grid.
    function test_land_GridCountsFromTheStart() external {
        _writeStart();
        _finalizeUnzen();
        _expectLandRevert(_input(S, S + 2), new bytes32[](0), IEtnaInbox.OffGrid.selector);
        _land(S, S + 6);
        _expectLandRevert(_input(S + 6, S + 8), new bytes32[](0), IEtnaInbox.OffGrid.selector);
        _land(S + 6, S + 18);
        _assertLanding(S + 18, _record(S + 6, 0, 0, S + 18));
    }

    // ---------------------------------------------------------------
    // The Unzen start check (LAND-6.1-8a)
    // ---------------------------------------------------------------

    /// @dev 8a.a, 8a.k, 8a.f: with every Unzen proposal finalized (next 8, last finalized 7), the
    /// Unzen Inbox's last finalized hash H and the SignalService checkpoint (H, R) at S, the first
    /// landing settles; once c is above S the check no longer applies.
    function test_land_UnzenCheckPassesThenStopsApplying() external {
        _writeStart();
        _finalizeUnzen();
        _land(S, S + 6);

        unzen.setCoreState(9, 7, bytes32(uint256(1)));
        _land(S + 6, S + 12);
        _assertCheckpoint(S + 12, bytes32(100 + S + 12));
    }

    /// @dev 8a.b, 8a.c, 8a.i: an unfinalized Unzen proposal or a different last finalized hash
    /// rejects the landing before proof verification; the verifier would reject it too.
    function test_land_RevertWhen_UnzenIsNotFinalizedAtTheStart() external {
        _writeStart();
        _finalizeUnzen();
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _input(S, S + 6);

        unzen.setCoreState(9, 7, _startHash());
        _expectLandRevert(input, new bytes32[](0), IEtnaInbox.UnzenNotFinalized.selector);

        unzen.setCoreState(8, 7, bytes32(100 + S - 1));
        _expectLandRevert(input, new bytes32[](0), IEtnaInbox.UnzenStartMismatch.selector);
    }

    /// @dev 8a.d, 8a.e, 8a.j: the SignalService checkpoint at S must exist and hold the start's
    /// hash and state root.
    function test_land_RevertWhen_StartCheckpointIsMissingOrDiffers() external {
        _writeStart();
        unzen.setCoreState(8, 7, _startHash());
        IEtnaInbox.LandInput memory input = _input(S, S + 6);
        _expectLandRevert(input, new bytes32[](0), SignalService.SS_CHECKPOINT_NOT_FOUND.selector);

        _saveUnzenCheckpoint(_startHash(), bytes32(uint256(1)));
        _expectLandRevert(input, new bytes32[](0), IEtnaInbox.StartCheckpointMismatch.selector);

        _saveUnzenCheckpoint(bytes32(uint256(1)), _startStateRoot());
        _expectLandRevert(input, new bytes32[](0), IEtnaInbox.StartCheckpointMismatch.selector);

        _saveUnzenCheckpoint(_startHash(), _startStateRoot());
        _land(S, S + 6);
    }

    /// @dev 8a.g: a governance recovery at c = S keeps the check for generation 1's landings.
    function test_land_UnzenCheckAppliesAfterRecoveryAtTheStart() external {
        _writeStart();
        _inbox()
            .recover(0, S, 0, type(uint256).max, new IEtnaInbox.Exclusion[](0), new uint256[](0), 0);
        assertEq(_inbox().generationStartHeight(), S, "generation 1 starts at S");
        unzen.setCoreState(8, 6, _startHash());
        _saveUnzenCheckpoint(_startHash(), _startStateRoot());
        _expectLandRevert(_input(S, S + 6), new bytes32[](0), IEtnaInbox.UnzenNotFinalized.selector);

        unzen.setCoreState(8, 7, _startHash());
        _land(S, S + 6);
        assertEq(_inbox().landings(S + 6).generation, 1, "generation 1 landing");
    }

    // ---------------------------------------------------------------
    // recover from S (RECOV-8.3-3a, vector 3a.c)
    // ---------------------------------------------------------------

    /// @dev expectedC - S, not expectedC, must be a multiple of K: with S = 1000 a planted c of
    /// 1204 passes and 1206 does not.
    function test_recover_GridCountsFromTheStart() external {
        _writeStart();
        _storeInboxWord(LAST_CHECKPOINT_HEIGHT_SLOT, bytes32(uint256(S + 206)));
        vm.expectRevert(IEtnaInbox.CheckpointOffGrid.selector);
        _inbox()
            .recover(
                0, S + 206, 0, type(uint256).max, new IEtnaInbox.Exclusion[](0), new uint256[](0), 0
            );

        _storeInboxWord(LAST_CHECKPOINT_HEIGHT_SLOT, bytes32(uint256(S + 204)));
        _inbox()
            .recover(
                0, S + 204, 0, type(uint256).max, new IEtnaInbox.Exclusion[](0), new uint256[](0), 0
            );
        assertEq(_inbox().generationStartHeight(), S + 204, "recovered at 1204");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Expects Carol's `setOrigin` to revert with `_selector`, writing no start.
    function _expectSetOriginRevert(
        uint256 _height,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        bytes4 _selector
    )
        private
    {
        bytes32[3] memory before = [
            _inboxWord(GENESIS_PACKED_SLOT),
            _inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT),
            _inboxWord(_originSlot(0) + 1)
        ];
        vm.expectRevert(_selector);
        vm.prank(Carol);
        _inbox().setOrigin(_height, _blockHash, _stateRoot);
        assertEq(_inboxWord(GENESIS_PACKED_SLOT), before[0], "272 unchanged");
        assertEq(_inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT), before[1], "270 unchanged");
        assertEq(_inboxWord(_originSlot(0) + 1), before[2], "origins(0) unchanged");
    }

    /// @dev Checks `etnaStart()` and slot 273.
    function _assertStart(uint256 _height, bytes32 _blockHash) private view {
        (uint48 height, bytes32 blockHash) = _inbox().etnaStart();
        assertEq(height, _height, "etnaStart height");
        assertEq(blockHash, _blockHash, "etnaStart hash");
        assertEq(_inboxWord(GENESIS_BLOCK_HASH_SLOT), _blockHash, "273");
    }
}
