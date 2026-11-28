// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";

/// @title EtnaUnzenCutoffsTest
/// @notice The real Unzen Inbox upgraded to `InboxWithEtnaCutoffs` (START-10-5d, vectors 5d.a-5d.d):
/// the `proposeCutoff()` that `EtnaInbox.setOrigin` reads is the time from which `propose` reverts,
/// `FI_CUTOFF` the time from which `saveForcedInclusion` reverts, and neither stops `prove` or a
/// bond withdrawal.
contract EtnaUnzenCutoffsTest is InboxTestBase {
    uint48 private constant _FORK_TIME = 1_000_000;
    uint48 private constant _PROPOSE_MARGIN = 12;
    uint48 private constant _FI_MARGIN = 500;

    InboxWithEtnaCutoffs private _cutoffs;

    function setUp() public override {
        super.setUp();
        inbox.upgradeTo(
            address(new InboxWithEtnaCutoffs(config, _FORK_TIME, _PROPOSE_MARGIN, _FI_MARGIN))
        );
        _cutoffs = InboxWithEtnaCutoffs(address(inbox));
    }

    function test_proposeCutoff_IsTheTimeFromWhichProposeReverts() external {
        uint48 cutoff = _cutoffs.proposeCutoff();
        assertEq(cutoff, _FORK_TIME - _PROPOSE_MARGIN, "cutoff");
        assertEq(cutoff, _cutoffs.PROPOSE_CUTOFF(), "getter");

        // 5d.a: a proposal one second before the cutoff is accepted.
        _warpTo(cutoff - 1);
        uint48 next = inbox.getCoreState().nextProposalId;
        _proposeOne();
        assertEq(inbox.getCoreState().nextProposalId, next + 1, "accepted");

        // 5d.b: a proposal at the cutoff reverts.
        _warpTo(cutoff);
        _setBlobHashes(3);
        bytes memory input = codec.encodeProposeInput(_defaultProposeInput());
        vm.expectRevert(InboxWithEtnaCutoffs.ProposalsClosed.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), input);
    }

    function test_saveForcedInclusion_RevertWhen_AtTheForcedInclusionCutoff() external {
        _proposeOne();
        uint48 cutoff = _cutoffs.FI_CUTOFF();
        assertEq(cutoff, _FORK_TIME - _FI_MARGIN, "cutoff");
        LibBlobs.BlobReference memory ref =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });

        _warpTo(cutoff - 1);
        _setBlobHashes(2);
        uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(ref);

        // 5d.c: a forced inclusion at the cutoff reverts.
        _warpTo(cutoff);
        _setBlobHashes(2);
        fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.expectRevert(InboxWithEtnaCutoffs.ForcedInclusionsClosed.selector);
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(ref);
    }

    /// @dev 5d.d: after both cutoffs, a proposal made before them is still proven and a bond is
    /// still withdrawn.
    function test_prove_AndBondWithdrawalWorkAfterTheCutoffs() external {
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _warpTo(_FORK_TIME);
        _prove(input);
        assertEq(
            inbox.getCoreState().lastFinalizedProposalId,
            input.commitment.firstProposalId,
            "finalized"
        );

        IBondManager.Bond memory bond = inbox.getBond(David);
        vm.prank(David);
        inbox.requestWithdrawal();
        _warpTo(_FORK_TIME + WITHDRAWAL_DELAY);
        uint256 balance = bondToken.balanceOf(David);
        vm.prank(David);
        inbox.withdraw(David, bond.balance);
        assertEq(bondToken.balanceOf(David), balance + _toTokenAmount(bond.balance), "withdrawn");
    }

    function _warpTo(uint256 _timestamp) private {
        vm.roll(block.number + 1);
        vm.warp(_timestamp);
    }
}
