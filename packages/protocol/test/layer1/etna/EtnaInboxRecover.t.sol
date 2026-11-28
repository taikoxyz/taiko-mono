// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxRecoverTest
/// @notice Governance recovery (spec 8 steps 1-4, 8.3, 8.4) and landing across generations.
/// @dev The Lean recovery examples (`Etna.Design.Examples`) run on this suite's state: `world`
/// is the state after `setUp` (c = 0, queue head 0 and tail 3) and `origin` is R = 11 at
/// timestamp 61, the L1 block and time `setUp` ends at. Landings follow the base's committed
/// chain up to the recovery origin 12; above it the chain is the one generation 1 rebuilds, whose
/// blocks differ from the generation-0 suffix the recovery discards.
contract EtnaInboxRecoverTest is EtnaLandTestBase {
    /// @dev keccak256(""), the txHash of a blanked forced inclusion.
    bytes32 private constant _BLANK_TX_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /// @dev The Lean recovery origin: R = 11 at timestamp 61, then R = 12 at 62 for a second
    /// recovery at the same c.
    uint256 private constant _LEAN_R = 11;
    uint256 private constant _LEAN_R_TIMESTAMP = 61;
    uint256 private constant _LEAN_R2 = 12;
    uint256 private constant _LEAN_R2_TIMESTAMP = 62;

    /// @dev The checkpoint the landing-after-recovery tests recover at.
    uint256 private constant _RECOVERY_C = 12;

    uint256 private constant _TWO_POW_48 = 2 ** 48;

    function setUp() public override {
        super.setUp();
        assertEq(block.number, _LEAN_R, "setUp ends at R");
        vm.warp(_LEAN_R_TIMESTAMP);
    }

    /// @dev Up to the recovery origin the base's committed chain; above it the chain generation 1
    /// rebuilds: EL hash 1100 + x and Comet hash 1200 + x instead of 100 + x and 200 + x.
    function _cut(uint256 _x)
        internal
        pure
        override
        returns (bytes32 el_, bytes32 comet_, uint256 head_)
    {
        if (_x <= _RECOVERY_C) return super._cut(_x);
        return (bytes32(1100 + _x), bytes32(1200 + _x), _x / K);
    }

    // ---------------------------------------------------------------
    // The transition
    // ---------------------------------------------------------------

    /// @dev Lean `recovery_fixes_origin`: recovery at c = 12, R = 50 and timestamp 1000 writes
    /// origins(1) = (12, 50, 1000) and moves the generation to 1; both views read the new origin
    /// and generation 0's origin is kept.
    function test_recover_IncrementsGenerationAndWritesOrigin() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.Origin memory origin0 = _inbox().origins(0);
        vm.roll(50);
        vm.warp(1000);

        // `_recover` expects `Recovered(1, 12, 50, 1000, [])`.
        _recover(0, 12, _noIndices());

        assertEq(_inbox().recoveryGeneration(), 1, "generation");
        assertEq(_inboxWord(RECOVERY_GENERATION_SLOT), bytes32(uint256(1)), "slot 268");
        _assertOrigin(1, 12, 50, 1000, DEFAULT_FALLBACK_KEYS_HASH);
        assertEq(_inbox().generationStartHeight(), 12, "generationStartHeight");
        _assertOrigin(
            0,
            origin0.startHeight,
            origin0.l1BlockNumber,
            origin0.l1Timestamp,
            origin0.fallbackKeysHash
        );
        assertEq(origin0.fallbackKeysHash, DEFAULT_FALLBACK_KEYS_HASH, "origins(0) holds [K1]");
        _assertOrigin(2, 0, 0, 0, 0);
    }

    /// @dev Lean `recovery_preserves_settled_prefix`: with a blanking, recovery keeps the
    /// checkpoint, every landing record, the queue pointers, the SignalService checkpoints, the
    /// genesis words, the fallback key state and the Inbox's ETH. The only Inbox slots it writes
    /// are 268, the nonce, the four words of origins(1), the blanked entry's txHash and the rules
    /// schedule.
    function test_recover_PreservesSettledState() external {
        _land(0, 6);
        _land(6, 12);
        uint256[] memory fiToClear = _indices(2);
        uint256 balance = inboxProxy.balance;
        bytes32[] memory settled = _settledWords();
        assertGt(balance, 0, "the forced inclusion fees");

        vm.startStateDiffRecording();
        _recover(0, 12, fiToClear);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        bytes32[] memory settledAfter = _settledWords();
        for (uint256 i; i < settled.length; ++i) {
            assertEq(settledAfter[i], settled[i], "settled state");
        }
        assertEq(inboxProxy.balance, balance, "ETH");
        _assertCheckpoint(12, bytes32(uint256(112)));
        _assertQueue(2, LEAN_FORCED_INCLUSIONS);

        uint256 writes;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.StorageAccess[] memory storageAccesses = accesses[i].storageAccesses;
            for (uint256 j; j < storageAccesses.length; ++j) {
                VmSafe.StorageAccess memory s = storageAccesses[j];
                if (s.account != inboxProxy || !s.isWrite || s.reverted) continue;
                uint256 slot = uint256(s.slot);
                assertTrue(
                    slot == RECOVERY_GENERATION_SLOT || slot == RECOVERY_NONCE_SLOT
                        || (slot >= _originSlot(1) && slot <= _originSlot(1) + 3)
                        || slot == _queueSlot(2) || slot == RULES_SCHEDULE_SLOT,
                    string.concat("unexpected Inbox write to slot ", vm.toString(s.slot))
                );
                ++writes;
            }
        }
        assertEq(writes, 8, "eight Inbox writes including the nonce and the rules schedule");
    }

    // ---------------------------------------------------------------
    // Authorization and replay
    // ---------------------------------------------------------------

    /// @dev Lean `recover_needs_owner_and_expected_values` (owner = false): only the owner, checked
    /// before the arguments. A pending owner cannot call until it accepts, and then the previous
    /// owner cannot.
    function test_recover_RevertWhen_NotOwner() external {
        bytes memory notOwner =
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner");
        uint256[] memory noIndices = _noIndices();

        _expectRecoverRevert(Bob, 0, 0, noIndices, notOwner);
        _expectRecoverRevert(Alice, 0, 0, noIndices, notOwner);
        _expectRecoverRevert(address(signalService), 0, 0, noIndices, notOwner);
        _expectRecoverRevert(Bob, 5, 7, _indices(9), notOwner);

        _inbox().transferOwnership(Carol);
        _expectRecoverRevert(Carol, 0, 0, noIndices, notOwner);
        vm.prank(Carol);
        _inbox().acceptOwnership();
        _expectRecoverRevert(address(this), 0, 0, noIndices, notOwner);

        // `_recover` calls as the current owner, Carol.
        _recover(0, 0, noIndices);
        assertEq(_inbox().recoveryGeneration(), 1, "Carol recovered");
    }

    /// @dev Lean `recover_needs_owner_and_expected_values` (generation 1 on generation 0): the
    /// expected generation must equal the current one, below or above it, and is checked before
    /// the checkpoint.
    function test_recover_RevertWhen_ExpectedGenerationStale() external {
        uint256[] memory noIndices = _noIndices();
        bytes4 mismatch = IEtnaInbox.GenerationMismatch.selector;

        _expectRecoverRevert(1, 0, noIndices, mismatch);
        _expectRecoverRevert(type(uint48).max, 0, noIndices, mismatch);
        _expectRecoverRevert(1, 6, noIndices, mismatch);

        _recover(0, 0, noIndices);
        _expectRecoverRevert(0, 0, noIndices, mismatch);
        _expectRecoverRevert(2, 0, noIndices, mismatch);
    }

    /// @dev Lean `landing_voids_old_authorization`: a recovery authorized at c = 0 cannot execute
    /// once a landing moves c to 6, nor can one naming a c above it; the checkpoint is checked
    /// before the list. An authorization at the new c executes.
    function test_recover_RevertWhen_LandingMovedCheckpoint() external {
        uint256[] memory noIndices = _noIndices();
        bytes4 mismatch = IEtnaInbox.CheckpointMismatch.selector;
        _land(0, 6);

        _expectRecoverRevert(0, 0, noIndices, mismatch);
        _expectRecoverRevert(0, 12, noIndices, mismatch);
        _expectRecoverRevert(0, 0, _indices(2, 1), mismatch);

        _recover(0, 6, noIndices);
        _assertOrigin(1, 6, _LEAN_R, _LEAN_R_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);
    }

    /// @dev RECOV-8.3-3: expectedC need only equal the current c, at any height; generation 1
    /// then lands from it.
    function test_recover_acceptsAnyExpectedC() external {
        _land(0, 7);
        _recover(0, 7, _noIndices());
        _assertOrigin(1, 7, _LEAN_R, _LEAN_R_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);
        assertEq(_inbox().generationStartHeight(), 7, "start height");

        _land(7, 8);
        _assertLanding(8, _record(7, 1, 1, 8));
    }

    /// @dev Lean `repeated_recovery_at_same_c_needs_new_generation`: replaying an executed
    /// recovery fails on its stale generation; one authorized for generation 1 at the same c
    /// writes origins(2) and keeps origins(1).
    function test_recover_ReplayNeedsNewGeneration() external {
        uint256[] memory noIndices = _noIndices();

        _recover(0, 0, noIndices);
        _assertOrigin(1, 0, _LEAN_R, _LEAN_R_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);

        vm.roll(_LEAN_R2);
        vm.warp(_LEAN_R2_TIMESTAMP);
        _expectRecoverRevert(0, 0, noIndices, IEtnaInbox.GenerationMismatch.selector);

        _recover(1, 0, noIndices);
        assertEq(_inbox().recoveryGeneration(), 2, "generation 2");
        _assertOrigin(2, 0, _LEAN_R2, _LEAN_R2_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);
        _assertOrigin(1, 0, _LEAN_R, _LEAN_R_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);
        assertEq(_inbox().generationStartHeight(), 0, "same start height");
    }

    // ---------------------------------------------------------------
    // The forced inclusions to blank
    // ---------------------------------------------------------------

    /// @dev The index list must be strictly increasing: equal or descending neighbours, anywhere
    /// in the list, revert, and the order is checked before the range.
    function test_recover_RevertWhen_ListNotStrictlySorted() external {
        bytes4 indicesNotSorted = IEtnaInbox.FiToClearNotSorted.selector;
        _expectRecoverRevert(0, 0, _indices(1, 1), indicesNotSorted);
        _expectRecoverRevert(0, 0, _indices(2, 1), indicesNotSorted);
        _expectRecoverRevert(0, 0, _indices(0, 2, 2), indicesNotSorted);
        _expectRecoverRevert(0, 0, _indices(5, 3), indicesNotSorted);
    }

    /// @dev Every index to blank must be pending, in [head, tail): the tail itself, indices far
    /// beyond it and, once a landing consumed entry 0, that entry are rejected. [head, tail - 1]
    /// is accepted.
    function test_recover_RevertWhen_FiIndexOutsideHeadTail() external {
        bytes4 outOfRange = IEtnaInbox.FiIndexOutOfRange.selector;
        _assertQueue(0, 3);

        _expectRecoverRevert(0, 0, _indices(3), outOfRange);
        _expectRecoverRevert(0, 0, _indices(0, 3), outOfRange);
        _expectRecoverRevert(0, 0, _indices(_TWO_POW_48), outOfRange);
        _expectRecoverRevert(0, 0, _indices(type(uint256).max), outOfRange);

        _land(0, 6);
        _assertQueue(1, 3);
        _expectRecoverRevert(0, 6, _indices(0), outOfRange);
        _expectRecoverRevert(0, 6, _indices(0, 1), outOfRange);

        IEtnaInbox.ForcedInclusion memory consumed = _inbox().getForcedInclusion(0);
        _recover(0, 6, _indices(1, 2));
        assertEq(_inbox().getForcedInclusion(1).txHash, _BLANK_TX_HASH, "entry 1 blanked");
        assertEq(_inbox().getForcedInclusion(2).txHash, _BLANK_TX_HASH, "entry 2 blanked");
        _assertForcedInclusion(0, consumed);
    }

    // ---------------------------------------------------------------
    // 48-bit limits and the written origin
    // ---------------------------------------------------------------

    /// @dev The new generation must fit 48 bits: from 2^48 - 2 recovery reaches 2^48 - 1 and
    /// writes its origin; from there it reverts, a blanking included, with nothing written.
    function test_recover_RevertWhen_GenerationWouldOverflow() external {
        uint48 last = type(uint48).max;
        _storeInboxWord(RECOVERY_GENERATION_SLOT, bytes32(uint256(last - 1)));

        _recover(last - 1, 0, _noIndices());
        assertEq(_inbox().recoveryGeneration(), last, "generation 2^48 - 1");
        _assertOrigin(last, 0, _LEAN_R, _LEAN_R_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);

        bytes4 overflow = IEtnaInbox.ValueOverflow.selector;
        _expectRecoverRevert(last, 0, _noIndices(), overflow);
        _expectRecoverRevert(last, 0, _indices(0), overflow);
        _assertOrigin(_TWO_POW_48, 0, 0, 0, 0);
    }

    /// @dev RECOV-8.4-4: an origin record is written once. If an upgrade wrote the next
    /// generation's record without advancing the generation, recovery reverts with nothing
    /// written, including the blanking it lists, and the record stays.
    function test_recover_RevertWhen_NextOriginAlreadyWritten() external {
        uint256 slot = _originSlot(1);
        _storeInboxWord(slot, bytes32(uint256(6)));
        _storeInboxWord(slot + 1, bytes32(uint256(7)));
        _storeInboxWord(slot + 2, bytes32(uint256(8)));
        _storeInboxWord(slot + 3, bytes32(uint256(9)));

        _expectRecoverRevert(0, 0, _indices(0), IEtnaInbox.OriginAlreadyWritten.selector);
        assertEq(_inbox().recoveryGeneration(), 0, "generation kept");
        _assertOrigin(1, 6, 7, 8, bytes32(uint256(9)));
    }

    /// @dev Origin timestamps must fit 48 bits: at 2^48 recovery reverts with nothing written,
    /// including the blanking it lists; at 2^48 - 1 it executes.
    function test_recover_RevertWhen_TimestampOverflows48Bits() external {
        vm.warp(_TWO_POW_48);
        _expectRecoverRevert(0, 0, _indices(0), IEtnaInbox.ValueOverflow.selector);

        vm.warp(_TWO_POW_48 - 1);
        _recover(0, 0, _indices(0));
        _assertOrigin(1, 0, _LEAN_R, _TWO_POW_48 - 1, DEFAULT_FALLBACK_KEYS_HASH);
    }

    /// @dev R must fit 48 bits: at block 2^48 recovery reverts with nothing written; at
    /// 2^48 - 1 it executes.
    function test_recover_RevertWhen_L1BlockOverflows48Bits() external {
        vm.roll(_TWO_POW_48);
        _expectRecoverRevert(0, 0, _indices(0), IEtnaInbox.ValueOverflow.selector);

        vm.roll(_TWO_POW_48 - 1);
        _recover(0, 0, _indices(0));
        _assertOrigin(1, 0, _TWO_POW_48 - 1, _LEAN_R_TIMESTAMP, DEFAULT_FALLBACK_KEYS_HASH);
    }

    /// @dev Before `init` the proxy on the `EtnaInbox` implementation rejects the owner's
    /// recovery, a blanking included, and nothing is written.
    function test_recover_RevertWhen_NotInitialized() external {
        _deployFreshInbox(false);
        _inbox().upgradeTo(address(inboxImpl));
        assertFalse(_inbox().isInitialized(), "not initialized");

        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox()
            .recover(
                0, 0, uint256(_inboxWord(RECOVERY_NONCE_SLOT)), type(uint256).max, _noIndices(), 0
            );
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox()
            .recover(
                0, 0, uint256(_inboxWord(RECOVERY_NONCE_SLOT)), type(uint256).max, _indices(0), 0
            );

        for (uint256 slot = 251; slot < 301; ++slot) {
            assertEq(_inboxWord(slot), 0, string.concat("slot ", vm.toString(slot)));
        }
        for (uint256 w; w < 3; ++w) {
            assertEq(_inboxWord(_originSlot(1) + w), 0, "origins(1)");
        }
    }

    // ---------------------------------------------------------------
    // Calls, selector and reserved storage
    // ---------------------------------------------------------------

    /// @dev `recover` calls nothing: every call or creation the recording sees is the owner's call
    /// into the Inbox proxy or the proxy's delegation to its implementation, and no ETH moves.
    function test_recover_MakesNoExternalCall() external {
        _land(0, 6);
        uint256 nonce = _inbox().recoveryNonce();
        uint256[] memory fiToClear = _indices(1, 2);
        EtnaInbox target = _inbox();

        vm.startStateDiffRecording();
        target.recover(0, 6, nonce, type(uint256).max, fiToClear, 0);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 calls;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.AccountAccess memory a = accesses[i];
            if (!_isCall(a.kind) || a.account == address(vm)) continue;
            assertEq(a.value, 0, "no ETH sent");
            if (a.account == inboxProxy) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.Call), "Inbox entry");
                assertEq(a.accessor, address(this), "called by the owner");
            } else if (a.account == address(inboxImpl)) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.DelegateCall), "Inbox impl");
            } else {
                revert(string.concat("unexpected call to ", vm.toString(a.account)));
            }
            ++calls;
        }
        assertEq(calls, 2, "the owner's call and its delegation");
        assertEq(_inbox().recoveryGeneration(), 1, "recovered");
    }

    /// @dev `recover` takes six arguments: the generation, checkpoint and nonce it was authorized
    /// for, the deadline, the forced inclusions to blank and the ruleset.
    function test_recover_SelectorHasSixArguments() external pure {
        assertEq(IEtnaInbox.recover.selector, bytes4(0x95e4b1e5), "selector");
        assertEq(
            IEtnaInbox.recover.selector,
            bytes4(keccak256("recover(uint48,uint256,uint256,uint256,uint256[],uint48)")),
            "signature"
        );
    }

    /// @dev Slot 284 is reserved: `init`, a landing and a recovery all leave it zero.
    function test_reservedSlot284_StaysZeroAfterInitLandAndRecover() external {
        assertEq(vm.load(inboxProxy, bytes32(uint256(284))), 0, "after init");
        _land(0, 6);
        assertEq(vm.load(inboxProxy, bytes32(uint256(284))), 0, "after a landing");
        _recover(0, 6, _indices(1));
        assertEq(vm.load(inboxProxy, bytes32(uint256(284))), 0, "after a recovery");
    }

    // ---------------------------------------------------------------
    // Landing across generations
    // ---------------------------------------------------------------

    /// @dev After recovery at c = 12, (12, 18] proved from the generation's start height lands:
    /// its cut hash and statement are under generation 1, the origin is `landings(12)` from
    /// generation 0, and the new record carries generation 1.
    function test_land_AfterRecoveryStartsAtTheGenerationOrigin() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.LandInput memory input = _input(12, 18);
        bytes32[] memory leaves = _leaves(12, 18);
        bytes32 generation0Statement =
            _statement(input, _inbox().landings(12), _cutHash(input, leaves));

        _recover(0, 12, _noIndices());
        assertEq(_inbox().generationStartHeight(), 12, "start height");

        bytes32 cutHash = _cutHash(input, leaves);
        assertEq(
            cutHash,
            keccak256(
                abi.encode(
                    bytes32("ETNA_LAND_CUTS_V1"),
                    uint256(1),
                    uint256(12),
                    uint256(18),
                    keccak256(abi.encodePacked(leaves))
                )
            ),
            "generation-1 cut hash"
        );
        bytes32 statement = _statement(input, _inbox().landings(12), cutHash);
        assertNotEq(statement, generation0Statement, "generation-1 statement");
        landVerifier.setExpectedStatementHash(statement);

        // `_land` expects `Landed(12, 12, 18, cutHash, 4, 1)`.
        assertEq(_land(input, leaves), statement, "statement over landings(12)");
        _assertLanding(18, _record(12, 1, 3, 18));
        _assertCheckpoint(18, bytes32(uint256(1118)));
        _assertQueue(3, LEAN_FORCED_INCLUSIONS);
        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(18);
        assertEq(saved.blockHash, 0, "root-only signal checkpoint");
        assertEq(saved.stateRoot, bytes32(uint256(318)), "signal state root");
    }

    /// @dev With c = 18 landed in generation 1 above the origin 12, whose record is from
    /// generation 0, (12, 24] proved from 12 lands. The leaf at c is checked against the
    /// generation-1 record, so the discarded generation-0 suffix's leaf at 18 is rejected, and
    /// every origin below 12 is rejected although its record exists.
    function test_land_AfterRecoveryOverlapsFromTheGenerationOrigin() external {
        _land(0, 6);
        _land(6, 12);
        _recover(0, 12, _noIndices());
        _land(12, 18);
        // A fourth entry lets the head reach 24 / 6 = 4.
        _saveForcedInclusions(1);
        IEtnaInbox.Landing memory origin = _inbox().landings(12);
        assertEq(origin.generation, 0, "origin record from generation 0");
        assertEq(_inbox().landings(18).generation, 1, "checkpoint record from generation 1");

        IEtnaInbox.LandInput memory input = _input(12, 24);
        bytes32[] memory leaves = _leaves(12, 24);
        assertEq(leaves.length, 11, "eleven heights inside (12, 24)");
        assertEq(
            leaves[5],
            keccak256(
                abi.encode(uint256(18), bytes32(uint256(1118)), bytes32(uint256(1218)), uint256(3))
            ),
            "the leaf at 18 from the generation-1 record"
        );

        bytes32[] memory discarded = _leaves(12, 24);
        discarded[5] = _leafOf(18, bytes32(uint256(118)), bytes32(uint256(218)), 3);
        _expectLandRevert(input, discarded, IEtnaInbox.FrontierLeafMismatch.selector);
        _expectLandRevert(_input(6, 24), _leaves(6, 24), IEtnaInbox.InvalidRange.selector);
        _expectLandRevert(_input(0, 24), _leaves(0, 24), IEtnaInbox.InvalidRange.selector);

        landVerifier.setExpectedStatementHash(_statement(input, origin, _cutHash(input, leaves)));
        // `_land` expects `Landed(12, 18, 24, ...)` and a statement over `landings(12)`.
        _land(input, leaves);
        _assertLanding(24, _record(18, 1, 4, 24));
        _assertCheckpoint(24, bytes32(uint256(1124)));
        _assertLanding(12, _record(6, 0, 2, 12));
    }

    /// @dev Lean `foreign_generation_proof_rejected`: the (0, 18] inputs prepared before recovery
    /// at c = 12 fail after it because origin 0 is below the new generation's start height, and so
    /// do the inputs from origin 6; origin 12 lands. `LandInput` carries no generation (the
    /// statement binds it), so these rejections come from the range check, before any proof.
    function test_land_AfterRecoveryRejectsOlderOrigins() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.LandInput memory full = _input(0, 18);
        bytes32[] memory fullLeaves = _leaves(0, 18);

        _recover(0, 12, _noIndices());
        _expectLandRevert(full, fullLeaves, IEtnaInbox.InvalidRange.selector);
        _expectLandRevert(_input(6, 18), _leaves(6, 18), IEtnaInbox.InvalidRange.selector);

        _land(12, 18);
        _assertCheckpoint(18, bytes32(uint256(1118)));
    }

    /// @dev A proof of (12, 18] made for generation 0 does not verify after recovery: a verifier
    /// accepting only the generation-0 statement rejects the landing, and the generation-1
    /// statement lands.
    function test_land_AfterRecoveryOldGenerationProofFails() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.LandInput memory input = _input(12, 18);
        bytes32[] memory leaves = _leaves(12, 18);
        bytes32 generation0Statement =
            _statement(input, _inbox().landings(12), _cutHash(input, leaves));

        _recover(0, 12, _noIndices());
        bytes32 generation1Statement =
            _statement(input, _inbox().landings(12), _cutHash(input, leaves));
        assertNotEq(generation1Statement, generation0Statement, "statements differ");

        landVerifier.setExpectedStatementHash(generation0Statement);
        _expectLandRevert(input, leaves, MockLandProofVerifier.ProofRejected.selector);

        landVerifier.setExpectedStatementHash(generation1Statement);
        assertEq(_land(input, leaves), generation1Statement, "generation-1 proof");
    }

    /// @dev The recovery origin's record stays as generation 0 wrote it, with its Comet hash, through
    /// the recovery and the landings above it, and so does its SignalService checkpoint.
    function test_land_RecoveryOriginRecordIsUntouched() external {
        _land(0, 6);
        _land(6, 12);
        IEtnaInbox.Landing memory atOrigin = _record(6, 0, 2, 12);
        assertEq(atOrigin.cometHash, bytes32(uint256(212)), "generation-0 Comet hash");
        _assertLanding(12, atOrigin);

        _recover(0, 12, _noIndices());
        _assertLanding(12, atOrigin);

        _land(12, 18);
        _assertLanding(12, atOrigin);
        _assertLanding(18, _record(12, 1, 3, 18));
        _assertLanding(6, _record(0, 0, 1, 6));
        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(12);
        assertEq(saved.blockHash, 0, "root-only signal checkpoint at 12");
        assertEq(saved.stateRoot, bytes32(uint256(312)), "signal state root at 12");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The owner recovers with `_generation` and `_c` expected, expecting
    /// `Recovered(_generation + 1, _c, block.number, block.timestamp, fallbackKeysHash(),
    /// _fiToClear)`.
    function _recover(uint48 _generation, uint256 _c, uint256[] memory _fiToClear) private {
        bytes32 keysHash = _inbox().fallbackKeysHash();
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.Recovered(
            _generation + 1, _c, block.number, block.timestamp, keysHash, _fiToClear
        );
        vm.prank(_inbox().owner());
        _inbox()
            .recover(
                _generation,
                _c,
                uint256(_inboxWord(RECOVERY_NONCE_SLOT)),
                type(uint256).max,
                _fiToClear,
                0
            );
    }

    /// @dev Expects the owner's recovery to revert with `_selector`, writing nothing.
    function _expectRecoverRevert(
        uint48 _generation,
        uint256 _c,
        uint256[] memory _fiToClear,
        bytes4 _selector
    )
        private
    {
        _expectRecoverRevert(
            _inbox().owner(), _generation, _c, _fiToClear, abi.encodeWithSelector(_selector)
        );
    }

    /// @dev Expects `_caller`'s recovery to revert with `_revertData`, leaving the generation,
    /// nonce, rules schedule, checkpoint, queue, the current and next origins, the checkpoint's
    /// record and every queue entry's txHash unchanged.
    function _expectRecoverRevert(
        address _caller,
        uint48 _generation,
        uint256 _c,
        uint256[] memory _fiToClear,
        bytes memory _revertData
    )
        private
    {
        bytes32[] memory before = _recoveryState();
        vm.expectRevert(_revertData);
        vm.prank(_caller);
        _inbox()
            .recover(
                _generation,
                _c,
                uint256(_inboxWord(RECOVERY_NONCE_SLOT)),
                type(uint256).max,
                _fiToClear,
                0
            );
        bytes32[] memory afterRevert = _recoveryState();
        assertEq(afterRevert.length, before.length, "state shape");
        for (uint256 i; i < before.length; ++i) {
            assertEq(afterRevert[i], before[i], "no state change");
        }
    }

    /// @dev The words a recovery may write, and those it must not.
    function _recoveryState() private view returns (bytes32[] memory words_) {
        uint256 generation = _inbox().recoveryGeneration();
        uint256 c = _inbox().lastCheckpoint().height;
        (, uint48 tail) = _inbox().getForcedInclusionState();
        words_ = new bytes32[](18 + tail);
        uint256 n;
        words_[n++] = _inboxWord(RECOVERY_GENERATION_SLOT);
        words_[n++] = _inboxWord(RECOVERY_NONCE_SLOT);
        words_[n++] = _inboxWord(RULES_SCHEDULE_SLOT);
        words_[n++] = _inboxWord(LAST_CHECKPOINT_HEIGHT_SLOT);
        words_[n++] = _inboxWord(LAST_CHECKPOINT_HASH_SLOT);
        words_[n++] = _inboxWord(FORCED_INCLUSION_HEAD_TAIL_SLOT);
        for (uint256 w; w < 4; ++w) {
            words_[n++] = _inboxWord(_originSlot(generation) + w);
            words_[n++] = _inboxWord(_originSlot(generation + 1) + w);
            words_[n++] = _inboxWord(_landingSlot(c) + w);
        }
        for (uint256 i; i < tail; ++i) {
            words_[n++] = _inboxWord(_queueSlot(i));
        }
    }

    /// @dev The settled state with the chain landed to 12: slots 258-284 except the generation,
    /// landings 0, 6 and 12, origins(0) and the SignalService checkpoints at 0, 6 and 12.
    function _settledWords() private view returns (bytes32[] memory words_) {
        words_ = new bytes32[](26 + 9 + 9 + 4);
        uint256 n;
        for (uint256 slot = INITIALIZATION_STATUS_SLOT; slot <= RESERVED_SLOT_284; ++slot) {
            if (slot != RECOVERY_GENERATION_SLOT) {
                words_[n++] = _inboxWord(slot);
            }
        }
        for (uint256 h; h <= 12; h += K) {
            for (uint256 w; w < 3; ++w) {
                words_[n++] = _inboxWord(_landingSlot(h) + w);
            }
            ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(uint48(h));
            words_[n++] = bytes32(uint256(saved.blockNumber));
            words_[n++] = saved.blockHash;
            words_[n++] = saved.stateRoot;
        }
        for (uint256 w; w < 4; ++w) {
            words_[n++] = _inboxWord(_originSlot(0) + w);
        }
        assertEq(n, words_.length, "settled words");
    }

    /// @dev The first word (txHash) of queue entry `_index` (slot 280 mapping).
    function _queueSlot(uint256 _index) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(_index, FORCED_INCLUSION_QUEUE_SLOT)));
    }

    /// @dev Checks `origins(_generation)` through the getter and its four raw slot 290 words.
    function _assertOrigin(
        uint256 _generation,
        uint256 _startHeight,
        uint256 _l1BlockNumber,
        uint256 _l1Timestamp,
        bytes32 _fallbackKeysHash
    )
        private
        view
    {
        IEtnaInbox.Origin memory origin = _inbox().origins(_generation);
        assertEq(origin.startHeight, _startHeight, "origin startHeight");
        assertEq(origin.l1BlockNumber, _l1BlockNumber, "origin l1BlockNumber");
        assertEq(origin.l1Timestamp, _l1Timestamp, "origin l1Timestamp");
        assertEq(origin.fallbackKeysHash, _fallbackKeysHash, "origin fallbackKeysHash");
        uint256 slot = _originSlot(_generation);
        assertEq(uint256(_inboxWord(slot)), _startHeight, "slot 290 word 1");
        assertEq(uint256(_inboxWord(slot + 1)), _l1BlockNumber, "slot 290 word 2");
        assertEq(uint256(_inboxWord(slot + 2)), _l1Timestamp, "slot 290 word 3");
        assertEq(_inboxWord(slot + 3), _fallbackKeysHash, "slot 290 word 4");
    }

    function _assertForcedInclusion(
        uint48 _index,
        IEtnaInbox.ForcedInclusion memory _expected
    )
        private
        view
    {
        IEtnaInbox.ForcedInclusion memory entry = _inbox().getForcedInclusion(_index);
        assertEq(entry.txHash, _expected.txHash, "entry txHash");
        assertEq(entry.timestamp, _expected.timestamp, "entry timestamp");
        assertEq(entry.l1Block, _expected.l1Block, "entry l1Block");
    }

    function _noIndices() private pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function _indices(uint256 _a) private pure returns (uint256[] memory list_) {
        list_ = new uint256[](1);
        list_[0] = _a;
    }

    function _indices(uint256 _a, uint256 _b) private pure returns (uint256[] memory list_) {
        list_ = new uint256[](2);
        (list_[0], list_[1]) = (_a, _b);
    }

    function _indices(
        uint256 _a,
        uint256 _b,
        uint256 _c
    )
        private
        pure
        returns (uint256[] memory list_)
    {
        list_ = new uint256[](3);
        (list_[0], list_[1], list_[2]) = (_a, _b, _c);
    }
}
