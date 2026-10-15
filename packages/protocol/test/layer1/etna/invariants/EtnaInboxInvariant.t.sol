// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "../EtnaInboxTestBase.sol";
import { EtnaInboxHandler } from "./EtnaInboxHandler.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title EtnaInboxInvariantTest
/// @notice Inbox invariants over forced inclusion saves and landings: the landed checkpoint only
/// moves forward and reaches the SignalService, the forced inclusion queue moves only through
/// saves and landings, and every wei a save accepts is refunded, paid to a fee recipient or
/// held for a pending entry.
/// @dev Foundry runs a separate campaign per invariant function and asserts only that function
/// in it, so every invariant also asserts that the handler saw no violation of any kind.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaInboxInvariantTest is EtnaInboxTestBase {
    /// @dev The L1 head the campaign starts at, so EIP-2935 references of up to 8191 blocks
    /// exist.
    uint64 internal constant L1_HEAD = 20_000;

    EtnaInboxHandler internal handler;

    function setUp() public override {
        super.setUp();
        vm.warp(block.timestamp + 12 * (L1_HEAD - block.number));
        vm.roll(L1_HEAD);
        handler = new EtnaInboxHandler(
            etnaInbox, signalService, landVerifier, etnaConfig, genesisStateRoot, _committee()
        );

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = EtnaInboxHandler.saveForcedInclusion.selector;
        selectors[1] = EtnaInboxHandler.land.selector;
        selectors[2] = EtnaInboxHandler.advanceBlocks.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        // Foundry refunds a call's unused gas to its sender, so a fuzzed sender that happened to
        // be the Inbox or a tracked account would receive ETH outside the handler's accounting.
        targetSender(makeAddr("invariant sender"));
    }

    /// @notice 1. The landed checkpoint height strictly increases with every successful landing
    /// and never otherwise, slots 270-271 hold it, and the SignalService holds the block hash and
    /// state root of every landed height, genesis included.
    function invariant_checkpointOnlyMovesForward() external view {
        _assertModelHeld();
        EtnaInboxHandler.LandedBlock[] memory landed = handler.landedBlocks();
        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        EtnaInboxHandler.LandedBlock memory latest = landed[landed.length - 1];
        assertEq(checkpoint.height, latest.height, "checkpoint height");
        assertEq(checkpoint.blockHash, latest.blockHash, "checkpoint block hash");
        assertEq(_loadSlot(LAST_CHECKPOINT_SLOT), checkpoint.height, "slot 270");
        assertEq(bytes32(_loadSlot(LAST_CHECKPOINT_SLOT + 1)), checkpoint.blockHash, "slot 271");

        for (uint256 i; i < landed.length; ++i) {
            if (i != 0) assertGt(landed[i].height, landed[i - 1].height, "strictly increasing");
            ICheckpointStore.Checkpoint memory saved =
                signalService.getCheckpoint(uint48(landed[i].height));
            assertEq(saved.blockHash, landed[i].blockHash, "SignalService block hash");
            assertEq(saved.stateRoot, landed[i].stateRoot, "SignalService state root");
        }
    }

    /// @notice 2. `head <= tail`; the tail counts the successful saves and the head is the
    /// `forcedInclusionHead` of the last successful landing; slot 281 packs both; pending
    /// entries are the saved submissions and consumed ones stay stored.
    function invariant_forcedInclusionQueueFollowsSavesAndLandings() external view {
        _assertModelHeld();
        (uint48 head, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertLe(head, tail, "head <= tail");
        assertEq(head, handler.ghostHead(), "the head moves only through landings");
        assertEq(tail, handler.ghostTail(), "the tail grows by one per save");
        assertEq(
            _loadSlot(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            uint256(head) | (uint256(tail) << 48),
            "slot 281 packs head and tail"
        );

        IEtnaInbox.ForcedInclusion[] memory pending =
            etnaInbox.getForcedInclusions(head, tail - head);
        assertEq(pending.length, tail - head, "every pending entry is readable");
        for (uint256 i; i < pending.length; ++i) {
            EtnaInboxHandler.SavedInclusion memory saved = handler.savedAt(head + i);
            assertEq(pending[i].txHash, saved.txHash, "pending transaction hash");
            assertEq(pending[i].timestamp, saved.timestamp, "pending timestamp");
            assertEq(pending[i].l1Block, saved.l1Block, "pending L1 block");
            assertEq(pending[i].feeInGwei, saved.feeInGwei, "pending fee");
        }
        for (uint256 i; i < head; ++i) {
            uint256 slot = uint256(keccak256(abi.encode(i, FORCED_INCLUSION_QUEUE_SLOT)));
            assertEq(bytes32(_loadSlot(slot)), handler.savedAt(i).txHash, "consumed entry kept");
        }
    }

    /// @notice 3. Fee conservation: the value accepted by successful saves equals the refunds
    /// plus the fees paid to recipients plus the Inbox balance, which is exactly the fees of
    /// the pending entries; each landing paid its consumed fees to its fee recipient only.
    function invariant_forcedInclusionFeesAreConserved() external view {
        _assertModelHeld();
        uint256 balance = address(etnaInbox).balance;
        assertEq(
            handler.valueAccepted(),
            handler.refunded() + handler.paidToRecipients() + balance,
            "accepted = refunded + paid + held"
        );
        (uint48 head, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertLe(head, tail, "head <= tail");
        IEtnaInbox.ForcedInclusion[] memory pending =
            etnaInbox.getForcedInclusions(head, tail - head);
        uint256 pendingFees;
        for (uint256 i; i < pending.length; ++i) {
            pendingFees += uint256(pending[i].feeInGwei) * 1 gwei;
        }
        assertEq(balance, pendingFees, "the Inbox holds exactly the pending fees");
    }

    /// @dev Asserts that the handler recorded no broken property and no call whose outcome
    /// (success or custom error) differed from the model's prediction.
    function _assertModelHeld() internal view {
        for (uint8 p; p <= uint8(type(EtnaInboxHandler.Property).max); ++p) {
            EtnaInboxHandler.Property property = EtnaInboxHandler.Property(p);
            assertEq(handler.violations(property), 0, handler.firstViolation(property));
        }
    }
}
