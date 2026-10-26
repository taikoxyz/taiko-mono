// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "../EtnaInboxTestBase.sol";
import { EtnaInboxHandler } from "./EtnaInboxHandler.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxInvariantTest
/// @notice Grid landings, landing records, recovery generations, the fee balance, the forced
/// inclusion queue, the active committee snapshot and the reserved slots under random sequences of
/// saves, landings, recoveries, sweeps, force-sent ETH and L1 time.
/// @dev Foundry runs a separate campaign per invariant function and asserts only that function
/// in it, so every invariant also asserts that the handler saw no violation of any kind.
/// The Inbox lands at most 64 blocks per batch, 60 on the grid, so landings reach back over
/// several checkpoints; Bob and Carol register next to Alice so recoveries have three bonds to
/// force out.
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaInboxInvariantTest is EtnaInboxTestBase {
    /// @dev `K`, the landing grid interval.
    uint256 internal constant K = 6;

    /// @dev The L1 head the Inbox is initialized at, so EIP-2935 references of up to 8191 blocks
    /// exist.
    uint256 internal constant L1_HEAD = 20_000;

    /// @dev `maxBatchBlocks` of the campaign's Inbox; not a multiple of K.
    uint64 internal constant BATCH_LIMIT = 64;

    uint256 internal constant BOB_PK = 0xB0B;
    uint256 internal constant CAROL_PK = 0xCA401;

    bytes32 internal constant BLANK_TX_HASH = keccak256("");

    EtnaInbox internal inbox;
    EtnaInboxHandler internal handler;

    function setUp() public override {
        super.setUp();
        _registerValidator(registry, Bob, BOB_PK);
        _registerValidator(registry, Carol, CAROL_PK);
        vm.warp(block.timestamp + 12 * (L1_HEAD - block.number));
        vm.roll(L1_HEAD);

        IEtnaInbox.Config memory config = _defaultConfig();
        config.maxBatchBlocks = BATCH_LIMIT;
        _upgradeAndInit(_newInboxImpl(config), _defaultInitParams());
        inbox = EtnaInbox(inboxProxy);

        // committeeConfigHash rebuilt from the init parameters (appendix A), not read back.
        bytes32 configHash = keccak256(
            abi.encode(
                bytes32("ETNA_PARENT_ANCHOR_V1"),
                uint256(L2_CHAIN_ID),
                address(registry),
                VP_UNIT,
                S_MIN,
                N_MAX,
                UNSETTLED_LIMIT
            )
        );
        handler = new EtnaInboxHandler(
            EtnaInboxHandler.Deployment({
                inbox: inbox,
                signalService: signalService,
                verifier: landVerifier,
                registry: registry,
                owner: address(this),
                l2ChainId: L2_CHAIN_ID,
                maxBatchBlocks: BATCH_LIMIT,
                forcedInclusionFeeInGwei: FORCED_INCLUSION_FEE_GWEI,
                forcedInclusionFeeDoubleThreshold: FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
                committeeConfigHash: configHash,
                genesisBlockHash: GENESIS_BLOCK_HASH,
                genesisStateRoot: GENESIS_STATE_ROOT,
                genesisCutoff: registryCheckpointBlock
            })
        );

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = EtnaInboxHandler.saveForcedInclusion.selector;
        selectors[1] = EtnaInboxHandler.land.selector;
        selectors[2] = EtnaInboxHandler.recover.selector;
        selectors[3] = EtnaInboxHandler.sweep.selector;
        selectors[4] = EtnaInboxHandler.forceEther.selector;
        selectors[5] = EtnaInboxHandler.advanceBlocks.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        // Foundry refunds a call's unused gas to its sender, so a fuzzed sender that happened to
        // be the Inbox or a tracked account would receive ETH outside the handler's accounting.
        targetSender(makeAddr("invariant sender"));
    }

    /// @dev The test contract initializes the Inbox itself, with `BATCH_LIMIT`.
    function _initializeOnSetUp() internal pure override returns (bool) {
        return false;
    }

    /// @notice 1. The checkpoint c is a grid point and the last landed height; landed heights
    /// strictly increase, one per successful landing; slots 270-271 hold c; the SignalService
    /// holds the block hash and state root of every landed height, genesis included.
    function invariant_checkpointOnGridAndOnlyForward() external view {
        _assertModelHeld();
        uint256 count = handler.checkpointCount();
        assertEq(count, handler.landings() + 1, "one landed height per successful landing");
        uint256 c = handler.checkpointAt(count - 1);
        IEtnaInbox.LandedCheckpoint memory checkpoint = inbox.lastCheckpoint();
        assertEq(checkpoint.height % K, 0, "c is a grid point");
        assertEq(checkpoint.height, c, "c is the last landed height");
        assertEq(checkpoint.blockHash, handler.cutAt(c).elHash, "c's block hash");
        assertEq(uint256(_word(LAST_CHECKPOINT_HEIGHT_SLOT)), c, "slot 270");
        assertEq(_word(LAST_CHECKPOINT_HASH_SLOT), checkpoint.blockHash, "slot 271");

        for (uint256 i; i < count; ++i) {
            uint256 height = handler.checkpointAt(i);
            if (i != 0) assertGt(height, handler.checkpointAt(i - 1), "strictly increasing");
            EtnaInboxHandler.Cut memory cut = handler.cutAt(height);
            ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(uint48(height));
            assertEq(saved.blockHash, cut.elHash, "SignalService block hash");
            assertEq(saved.stateRoot, cut.stateRoot, "SignalService state root");
        }
    }

    /// @notice 2. Following `parentHeight` from c reaches block 0 through every landed height in
    /// reverse order: each record is on the grid, its parent below it and its fields (actual
    /// parent c, generation, queue head, EL and Comet hashes) the model's, through the getter and
    /// the three slot 285 words. No other grid point up to c + 60 has a record.
    function invariant_landingRecordsFormTheActualChain() external view {
        _assertModelHeld();
        uint256 remaining = handler.checkpointCount();
        uint256 c = inbox.lastCheckpoint().height;
        uint256 x = c;
        while (true) {
            assertGt(remaining, 0, "more records than landings");
            --remaining;
            assertEq(x, handler.checkpointAt(remaining), "the chain visits every landed height");
            assertEq(x % K, 0, "record on the grid");
            IEtnaInbox.Landing memory record = inbox.landings(x);
            _assertRecord(x, record, handler.recordAt(x));
            if (x == 0) break;
            assertLt(record.parentHeight, x, "parent below the record");
            for (uint256 y = record.parentHeight + K; y < x; y += K) {
                assertEq(inbox.landings(y).elHash, 0, "no record between landed heights");
            }
            x = record.parentHeight;
        }
        assertEq(remaining, 0, "the chain reaches block 0 through every landing");
        for (uint256 y = c + K; y <= c + BATCH_LIMIT; y += K) {
            assertEq(inbox.landings(y).elHash, 0, "no record above c");
        }
    }

    /// @notice 3. The generation counts the successful recoveries (slot 268); origins(g) is the
    /// model's for every g up to it and origins(generation + 1) is unwritten (slot 290 words);
    /// the views read the current origin, whose start height is at most c; each excluded bond's
    /// exit is min(existing, R) of its recoveries.
    function invariant_generationsAndOriginsAreWriteOnce() external view {
        _assertModelHeld();
        uint48 generation = inbox.recoveryGeneration();
        assertEq(generation, handler.recoveries(), "one generation per recovery");
        assertEq(generation, handler.ghostGeneration(), "the model's generation");
        assertEq(uint256(_word(RECOVERY_GENERATION_SLOT)), generation, "slot 268");
        for (uint256 g; g <= generation; ++g) {
            _assertOrigin(g, handler.originAt(g));
        }
        IEtnaInbox.Origin memory unwritten;
        _assertOrigin(uint256(generation) + 1, unwritten);

        IEtnaInbox.Origin memory current = handler.originAt(generation);
        assertEq(inbox.generationStartHeight(), current.startHeight, "generationStartHeight");
        assertLe(inbox.generationStartHeight(), inbox.lastCheckpoint().height, "start <= c");
        assertEq(inbox.recoverySnapshot(), current.l1BlockNumber, "recoverySnapshot");
        for (uint256 b; b < handler.bondCount(); ++b) {
            assertEq(
                registry.entryAt(b).exitEffectiveL1, handler.ghostExit(b), "exit = min(existing, R)"
            );
        }
    }

    /// @notice 4. The Inbox holds the fees charged by successful saves plus the force-sent ETH
    /// minus every sweep, and the treasury holds exactly what was swept.
    function invariant_balanceIsFeesPlusForcedMinusSwept() external view {
        _assertModelHeld();
        assertEq(
            address(inbox).balance,
            handler.feesCharged() + handler.forcedEther() - handler.swept(),
            "balance = fees + forced - swept"
        );
        assertEq(PROTOCOL_FEE_RECIPIENT.balance, handler.swept(), "the treasury got every sweep");
    }

    /// @notice 5. `head <= tail`; the tail counts the successful saves and the head moves only
    /// with landings, matching c's record; slot 281 packs both. Every entry, consumed or pending,
    /// keeps its saved hash, or keccak256("") once recovery blanked it, and its saved timestamp
    /// and L1 block (slot 280 words); nothing is stored at the tail. The fee follows the pending
    /// count.
    function invariant_forcedInclusionQueueFollowsSavesLandingsAndBlanking() external view {
        _assertModelHeld();
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertLe(head, tail, "head <= tail");
        assertEq(head, handler.ghostHead(), "the head moves only with landings");
        assertEq(tail, handler.ghostTail(), "the tail counts the saves");
        assertEq(
            head, inbox.landings(inbox.lastCheckpoint().height).head, "c's record holds the head"
        );
        assertEq(
            uint256(_word(FORCED_INCLUSION_HEAD_TAIL_SLOT)),
            uint256(head) | (uint256(tail) << 48),
            "slot 281"
        );

        for (uint256 i; i <= tail; ++i) {
            EtnaInboxHandler.SavedInclusion memory saved = handler.savedAt(i);
            bytes32 txHash = saved.blanked ? BLANK_TX_HASH : saved.txHash;
            IEtnaInbox.ForcedInclusion memory entry = inbox.getForcedInclusion(uint48(i));
            assertEq(entry.txHash, txHash, "entry hash");
            assertEq(entry.timestamp, saved.timestamp, "entry timestamp");
            assertEq(entry.l1Block, saved.l1Block, "entry L1 block");
            uint256 slot = uint256(keccak256(abi.encode(i, FORCED_INCLUSION_QUEUE_SLOT)));
            assertEq(_word(slot), txHash, "slot 280 word 1");
            assertEq(
                uint256(_word(slot + 1)),
                uint256(saved.timestamp) | (uint256(saved.l1Block) << 48),
                "slot 280 word 2"
            );
        }

        uint256 fee = uint256(FORCED_INCLUSION_FEE_GWEI)
            * (FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD + tail - head)
            / FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD;
        assertEq(inbox.getCurrentForcedInclusionFee(), fee, "fee follows the pending count");
    }

    /// @notice 6. The active committee snapshot (slot 284) is the genesis cutoff until the first
    /// landing and then the snapshot of the last successful landing; recoveries and failed
    /// landings leave it.
    function invariant_snapshotFollowsLandingsOnly() external view {
        _assertModelHeld();
        assertEq(inbox.activeCommitteeSnapshot(), handler.ghostSnapshot(), "snapshot");
        assertEq(
            uint256(_word(ACTIVE_COMMITTEE_SNAPSHOT_SLOT)), handler.ghostSnapshot(), "slot 284"
        );
    }

    /// @notice 7. The reserved slots 251-257, 259-267, 275-277, 283, 286-289 and 291 stay zero.
    function invariant_reservedSlotsStayZero() external view {
        _assertModelHeld();
        _assertZero(251, 257);
        _assertZero(259, 267);
        _assertZero(275, 277);
        _assertZero(RESERVED_SLOT_283, RESERVED_SLOT_283);
        _assertZero(RESERVED_SLOT_286, RESERVED_SLOT_289);
        _assertZero(RESERVED_SLOT_291, RESERVED_SLOT_291);
    }

    /// @dev Asserts that the handler recorded no broken property and no call whose outcome
    /// (success or revert data) differed from the model's prediction.
    function _assertModelHeld() internal view {
        for (uint8 p; p <= uint8(type(EtnaInboxHandler.Property).max); ++p) {
            EtnaInboxHandler.Property property = EtnaInboxHandler.Property(p);
            assertEq(handler.violations(property), 0, handler.firstViolation(property));
        }
    }

    /// @dev Checks a landing record through the getter and its three slot 285 words.
    function _assertRecord(
        uint256 _height,
        IEtnaInbox.Landing memory _record,
        IEtnaInbox.Landing memory _expected
    )
        internal
        view
    {
        assertEq(_record.parentHeight, _expected.parentHeight, "record parentHeight");
        assertEq(_record.generation, _expected.generation, "record generation");
        assertEq(_record.head, _expected.head, "record head");
        assertEq(_record.elHash, _expected.elHash, "record elHash");
        assertEq(_record.cometHash, _expected.cometHash, "record cometHash");
        uint256 slot = uint256(keccak256(abi.encode(_height, LANDINGS_SLOT)));
        assertEq(
            uint256(_word(slot)),
            uint256(_expected.parentHeight) | (uint256(_expected.generation) << 48)
                | (uint256(_expected.head) << 96),
            "slot 285 word 1"
        );
        assertEq(_word(slot + 1), _expected.elHash, "slot 285 word 2");
        assertEq(_word(slot + 2), _expected.cometHash, "slot 285 word 3");
    }

    /// @dev Checks a generation's origin through the getter and its three slot 290 words.
    function _assertOrigin(uint256 _generation, IEtnaInbox.Origin memory _expected) internal view {
        IEtnaInbox.Origin memory origin = inbox.origins(_generation);
        assertEq(origin.startHeight, _expected.startHeight, "origin startHeight");
        assertEq(origin.l1BlockNumber, _expected.l1BlockNumber, "origin l1BlockNumber");
        assertEq(origin.l1Timestamp, _expected.l1Timestamp, "origin l1Timestamp");
        uint256 slot = uint256(keccak256(abi.encode(_generation, ORIGINS_SLOT)));
        assertEq(uint256(_word(slot)), _expected.startHeight, "slot 290 word 1");
        assertEq(uint256(_word(slot + 1)), _expected.l1BlockNumber, "slot 290 word 2");
        assertEq(uint256(_word(slot + 2)), _expected.l1Timestamp, "slot 290 word 3");
    }

    /// @dev Asserts that Inbox slots `_first` through `_last` hold zero.
    function _assertZero(uint256 _first, uint256 _last) internal view {
        for (uint256 slot = _first; slot <= _last; ++slot) {
            assertEq(_word(slot), bytes32(0), "reserved slot is zero");
        }
    }

    function _word(uint256 _slot) internal view returns (bytes32) {
        return vm.load(inboxProxy, bytes32(_slot));
    }
}
