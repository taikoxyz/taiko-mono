// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibInboxMigration } from "src/layer1/core/libs/LibInboxMigration.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract InboxFreezeTest is InboxTestBase {
    /// @dev Storage slot of `Inbox._migration`, read by the Etna node and the Etna Inbox.
    uint256 private constant _MIGRATION_SLOT = 258;

    // ---------------------------------------------------------------------
    // freeze
    // ---------------------------------------------------------------------

    function test_freeze_SetsFrozenState() public {
        vm.roll(1234);

        vm.expectEmit();
        emit Inbox.Frozen(1234);
        inbox.freeze();

        LibInboxMigration.State memory migration = inbox.migration();
        assertEq(migration.migrationState, LibInboxMigration.FROZEN, "migration state");
        assertEq(migration.frozenAtL1Block, 1234, "frozen at");
        assertEq(migration.drainedAtL1Block, 0, "drained at");
    }

    function test_freeze_WritesMigrationWordAtSlot258() public {
        assertEq(vm.load(address(inbox), bytes32(_MIGRATION_SLOT)), bytes32(0), "word before");

        uint64 frozenAt = 0x0102030405060708;
        vm.roll(frozenAt);
        inbox.freeze();

        uint256 word = uint256(vm.load(address(inbox), bytes32(_MIGRATION_SLOT)));
        assertEq(uint8(word), LibInboxMigration.FROZEN, "bits 0-7: migration state");
        assertEq(uint64(word >> 8), frozenAt, "bits 8-71: frozen at");
        assertEq(uint64(word >> 72), 0, "bits 72-135: drained at");
        assertEq(word, (uint256(frozenAt) << 8) | LibInboxMigration.FROZEN, "whole word");

        assertEq(vm.load(address(inbox), bytes32(_MIGRATION_SLOT + 1)), bytes32(0), "gap untouched");
    }

    function test_migration_DecodesPackedWord() public {
        uint256 word =
            (uint256(0xbbbb) << 72) | (uint256(0xaaaa) << 8) | LibInboxMigration.ETNA_ACTIVE;
        vm.store(address(inbox), bytes32(_MIGRATION_SLOT), bytes32(word));

        LibInboxMigration.State memory migration = inbox.migration();
        assertEq(migration.migrationState, LibInboxMigration.ETNA_ACTIVE, "migration state");
        assertEq(migration.frozenAtL1Block, 0xaaaa, "frozen at");
        assertEq(migration.drainedAtL1Block, 0xbbbb, "drained at");
    }

    function test_freeze_RevertWhen_CallerNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(Alice);
        inbox.freeze();
    }

    function test_freeze_RevertWhen_AlreadyFrozen() public {
        inbox.freeze();
        _advanceBlock();

        vm.expectRevert(Inbox.InvalidMigrationState.selector);
        inbox.freeze();
    }

    function test_freeze_RevertWhen_MigrationStateNotNone() public {
        vm.store(
            address(inbox),
            bytes32(_MIGRATION_SLOT),
            bytes32(uint256(LibInboxMigration.ETNA_ACTIVE))
        );

        vm.expectRevert(Inbox.InvalidMigrationState.selector);
        inbox.freeze();
    }

    // ---------------------------------------------------------------------
    // Gates
    // ---------------------------------------------------------------------

    function test_propose_RevertWhen_Frozen() public {
        _proposeOne();
        _advanceBlock();

        inbox.freeze();

        _setBlobHashes(3);
        bytes memory data = codec.encodeProposeInput(_defaultProposeInput());
        vm.expectRevert(Inbox.InboxIsFrozen.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), data);
    }

    function test_saveForcedInclusion_RevertWhen_Frozen() public {
        _proposeOne();
        _advanceBlock();
        _saveForcedInclusion(1);

        inbox.freeze();

        uint256 fee = uint256(inbox.getCurrentForcedInclusionFee()) * 1 gwei;
        LibBlobs.BlobReference memory ref =
            LibBlobs.BlobReference({ blobStartIndex: 2, numBlobs: 1, offset: 0 });
        vm.expectRevert(Inbox.InboxIsFrozen.selector);
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(ref);
    }

    // ---------------------------------------------------------------------
    // Unchanged after freeze
    // ---------------------------------------------------------------------

    function test_prove_SucceedsAfterFreeze() public {
        // Propose before the freeze, prove after it.
        IInbox.ProveInput memory input = _buildBatchInput(3);

        inbox.freeze();
        _advanceBlock();
        _prove(input);

        IInbox.Commitment memory commitment = input.commitment;
        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, commitment.firstProposalId + 2, "finalized id");
        assertEq(state.lastFinalizedProposalId + 1, state.nextProposalId, "drained");
        assertEq(state.lastFinalizedBlockHash, commitment.transitions[2].blockHash, "block hash");

        ICheckpointStore.Checkpoint memory checkpoint =
            signalService.getCheckpoint(commitment.endBlockNumber);
        assertEq(checkpoint.blockHash, commitment.transitions[2].blockHash, "checkpoint hash");
        assertEq(checkpoint.stateRoot, commitment.endStateRoot, "checkpoint state root");
    }

    function test_withdraw_SucceedsAfterFreeze() public {
        inbox.freeze();

        uint64 balance = inbox.getBond(David).balance;
        uint256 tokensBefore = bondToken.balanceOf(David);

        vm.startPrank(David);
        inbox.requestWithdrawal();
        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1);
        inbox.withdraw(David, balance);
        vm.stopPrank();

        assertEq(inbox.getBond(David).balance, 0, "bond balance");
        assertEq(
            bondToken.balanceOf(David), tokensBefore + _toTokenAmount(balance), "token balance"
        );
    }

    function test_cancelWithdrawal_SucceedsAfterFreeze() public {
        inbox.freeze();

        vm.startPrank(David);
        inbox.requestWithdrawal();
        assertGt(inbox.getBond(David).withdrawalRequestedAt, 0, "requested");
        inbox.cancelWithdrawal();
        vm.stopPrank();

        assertEq(inbox.getBond(David).withdrawalRequestedAt, 0, "cancelled");
    }

    function test_deposit_SucceedsAfterFreeze() public {
        inbox.freeze();

        uint64 amount = 1_000_000_000;
        bondToken.mint(Emma, _toTokenAmount(2 * amount));

        vm.startPrank(Emma);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.deposit(amount);
        inbox.depositTo(Alice, amount);
        vm.stopPrank();

        assertEq(inbox.getBond(Emma).balance, amount, "depositor bond");
        assertEq(inbox.getBond(Alice).balance, amount, "recipient bond");
    }

    function test_views_UnchangedAfterFreeze() public {
        _proposeOne();
        _advanceBlock();
        _saveForcedInclusion(1);

        IInbox.CoreState memory stateBefore = inbox.getCoreState();
        bytes32 configBefore = keccak256(abi.encode(inbox.getConfig()));
        bytes32 proposalHashBefore = inbox.getProposalHash(1);
        IBondManager.Bond memory bondBefore = inbox.getBond(proposer);
        uint64 feeBefore = inbox.getCurrentForcedInclusionFee();

        inbox.freeze();

        _assertStateEqual(inbox.getCoreState(), stateBefore);
        assertEq(keccak256(abi.encode(inbox.getConfig())), configBefore, "config");
        assertEq(inbox.getProposalHash(1), proposalHashBefore, "proposal hash");
        assertEq(inbox.getBond(proposer).balance, bondBefore.balance, "bond balance");
        assertEq(inbox.getCurrentForcedInclusionFee(), feeBefore, "forced inclusion fee");

        // The forced inclusion queued before the freeze stays queued and can never be consumed.
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, 0, "head");
        assertEq(tail, 1, "tail");
        IForcedInclusionStore.ForcedInclusion[] memory inclusions = inbox.getForcedInclusions(0, 1);
        assertEq(inclusions.length, 1, "queued inclusions");
    }

    // ---------------------------------------------------------------------
    // Private helpers
    // ---------------------------------------------------------------------

    function _saveForcedInclusion(uint16 _blobStartIndex) private {
        LibBlobs.BlobReference memory ref =
            LibBlobs.BlobReference({ blobStartIndex: _blobStartIndex, numBlobs: 1, offset: 0 });
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(ref);
    }
}
