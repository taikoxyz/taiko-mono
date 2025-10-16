// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LookaheadStoreBase } from "./LookaheadStoreBase.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";

/// @dev To log the gas report correctly, please run this test in isolation via
/// `FOUNDRY_PROFILE=layer1 forge test --mc TestLookaheadStore_Benchmark --jobs 1`
contract TestLookaheadStore_Benchmark is LookaheadStoreBase {
    // Without pushing lookahead
    // --------------------------

    function test_benchmark_checkProposerSameEpochProposal_case1() external useMainnet {
        // Current lookahead with 1 operator
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is irrelevant
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, bytes(""));
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".same_epoch_proposal.1_operator_in_current_lookahead");
    }

    function test_benchmark_checkProposerSameEpochProposal_case2() external useMainnet {
        // Current lookahead with 5 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](5);
        currLookaheadSlotPositions[0] = 4;
        currLookaheadSlotPositions[1] = 6;
        currLookaheadSlotPositions[2] = 8;
        currLookaheadSlotPositions[3] = 10;
        currLookaheadSlotPositions[4] = 12;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is irrelevant
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, bytes(""));
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".same_epoch_proposal.5_operators_in_current_lookahead");
    }

    function test_benchmark_checkProposerSameEpochProposal_case3() external useMainnet {
        // Current lookahead with 10 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](10);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is irrelevant
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, bytes(""));
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".same_epoch_proposal.10_operators_in_current_lookahead");
    }

    function test_benchmark_checkProposerSameEpochProposal_case4() external useMainnet {
        // Current lookahead with 15 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](15);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        currLookaheadSlotPositions[10] = 22;
        currLookaheadSlotPositions[11] = 24;
        currLookaheadSlotPositions[12] = 26;
        currLookaheadSlotPositions[13] = 28;
        currLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead is irrelevant
        uint256[] memory nextLookaheadSlotPositions = new uint256[](0);
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, bytes(""));
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".same_epoch_proposal.15_operators_in_current_lookahead");
    }

    function test_benchmark_checkProposerCrossProposal_case1() external useMainnet {
        // Current lookahead with 1 operator
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead has 1 operator
        uint256[] memory nextLookaheadSlotPositions = new uint256[](1);
        nextLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[0].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);

        uint256 gasBefore = gasleft();
        _checkProposer(
            type(uint256).max, currLookahead[0].committer, currLookahead, nextLookahead, bytes("")
        );
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".cross_epoch_proposal.1_operator_in_each_lookahead");
    }

    function test_benchmark_checkProposerCrossProposal_case2() external useMainnet {
        // Current lookahead with 5 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](5);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 6;
        currLookaheadSlotPositions[2] = 10;
        currLookaheadSlotPositions[3] = 14;
        currLookaheadSlotPositions[4] = 18;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead has 5 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 6;
        nextLookaheadSlotPositions[2] = 10;
        nextLookaheadSlotPositions[3] = 14;
        nextLookaheadSlotPositions[4] = 18;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[4].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);

        uint256 gasBefore = gasleft();
        _checkProposer(
            type(uint256).max, currLookahead[0].committer, currLookahead, nextLookahead, bytes("")
        );
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".cross_epoch_proposal.5_operators_in_each_lookahead");
    }

    function test_benchmark_checkProposerCrossProposal_case3() external useMainnet {
        // Current lookahead with 10 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](10);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead has 10 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](10);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 4;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        nextLookaheadSlotPositions[5] = 12;
        nextLookaheadSlotPositions[6] = 14;
        nextLookaheadSlotPositions[7] = 16;
        nextLookaheadSlotPositions[8] = 18;
        nextLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[9].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);

        uint256 gasBefore = gasleft();
        _checkProposer(
            type(uint256).max, currLookahead[0].committer, currLookahead, nextLookahead, bytes("")
        );
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".cross_epoch_proposal.10_operators_in_each_lookahead");
    }

    function test_benchmark_checkProposerCrossProposal_case4() external useMainnet {
        // Current lookahead with 15 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](15);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        currLookaheadSlotPositions[10] = 22;
        currLookaheadSlotPositions[11] = 24;
        currLookaheadSlotPositions[12] = 26;
        currLookaheadSlotPositions[13] = 28;
        currLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead has 15 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](15);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 4;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        nextLookaheadSlotPositions[5] = 12;
        nextLookaheadSlotPositions[6] = 14;
        nextLookaheadSlotPositions[7] = 16;
        nextLookaheadSlotPositions[8] = 18;
        nextLookaheadSlotPositions[9] = 20;
        nextLookaheadSlotPositions[10] = 22;
        nextLookaheadSlotPositions[11] = 24;
        nextLookaheadSlotPositions[12] = 26;
        nextLookaheadSlotPositions[13] = 28;
        nextLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, true
        );

        vm.warp(currLookahead[14].timestamp + LibPreconfConstants.SECONDS_IN_SLOT);

        uint256 gasBefore = gasleft();
        _checkProposer(
            type(uint256).max, currLookahead[0].committer, currLookahead, nextLookahead, bytes("")
        );
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(gasConsumed, ".cross_epoch_proposal.15_operators_in_each_lookahead");
    }

    // With lookahead being posted
    // ----------------------------

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPosting_case1()
        external
        useMainnet
    {
        // Current lookahead with 1 operator
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](1);
        nextLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed, ".same_epoch_proposal_with_lookahead_posting.1_operator_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPosting_case2()
        external
        useMainnet
    {
        // Current lookahead with 5 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](5);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 6;
        currLookaheadSlotPositions[2] = 10;
        currLookaheadSlotPositions[3] = 14;
        currLookaheadSlotPositions[4] = 18;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted) with 5 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 6;
        nextLookaheadSlotPositions[2] = 10;
        nextLookaheadSlotPositions[3] = 14;
        nextLookaheadSlotPositions[4] = 18;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting.5_operators_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPosting_case3()
        external
        useMainnet
    {
        // Current lookahead with 10 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](10);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted) with 10 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](10);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 4;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        nextLookaheadSlotPositions[5] = 12;
        nextLookaheadSlotPositions[6] = 14;
        nextLookaheadSlotPositions[7] = 16;
        nextLookaheadSlotPositions[8] = 18;
        nextLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting.10_operators_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPosting_case4()
        external
        useMainnet
    {
        // Current lookahead with 15 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](15);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        currLookaheadSlotPositions[10] = 22;
        currLookaheadSlotPositions[11] = 24;
        currLookaheadSlotPositions[12] = 26;
        currLookaheadSlotPositions[13] = 28;
        currLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted) with 15 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](15);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 4;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        nextLookaheadSlotPositions[5] = 12;
        nextLookaheadSlotPositions[6] = 14;
        nextLookaheadSlotPositions[7] = 16;
        nextLookaheadSlotPositions[8] = 18;
        nextLookaheadSlotPositions[9] = 20;
        nextLookaheadSlotPositions[10] = 22;
        nextLookaheadSlotPositions[11] = 24;
        nextLookaheadSlotPositions[12] = 26;
        nextLookaheadSlotPositions[13] = 28;
        nextLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting.15_operators_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPostingReuseSlot_case1()
        external
        useMainnet
    {
        // Current lookahead with 1 operator
        uint256[] memory currLookaheadSlotPositions = new uint256[](1);
        currLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted)
        uint256[] memory nextLookaheadSlotPositions = new uint256[](1);
        nextLookaheadSlotPositions[0] = 4;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        // Set a dummy hash at next lookahead's storage slot to simulate slot reuse
        _setLookaheadHash(
            (lookaheadStore.LOOKAHEAD_BUFFER_SIZE() * LibPreconfConstants.SECONDS_IN_EPOCH)
                + (EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            bytes26(bytes32(type(uint256).max))
        );

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting_reuse_slot.1_operator_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPostingReuseSlot_case2()
        external
        useMainnet
    {
        // Current lookahead with 5 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](5);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 6;
        currLookaheadSlotPositions[2] = 10;
        currLookaheadSlotPositions[3] = 14;
        currLookaheadSlotPositions[4] = 18;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted) with 5 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](5);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 6;
        nextLookaheadSlotPositions[2] = 10;
        nextLookaheadSlotPositions[3] = 14;
        nextLookaheadSlotPositions[4] = 18;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        // Set a dummy hash at next lookahead's storage slot to simulate slot reuse
        _setLookaheadHash(
            (lookaheadStore.LOOKAHEAD_BUFFER_SIZE() * LibPreconfConstants.SECONDS_IN_EPOCH)
                + (EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            bytes26(bytes32(type(uint256).max))
        );

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting_reuse_slot.5_operators_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPostingReuseSlot_case3()
        external
        useMainnet
    {
        // Current lookahead with 10 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](10);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted) with 10 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](10);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 4;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        nextLookaheadSlotPositions[5] = 12;
        nextLookaheadSlotPositions[6] = 14;
        nextLookaheadSlotPositions[7] = 16;
        nextLookaheadSlotPositions[8] = 18;
        nextLookaheadSlotPositions[9] = 20;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        // Set a dummy hash at next lookahead's storage slot to simulate slot reuse
        _setLookaheadHash(
            (lookaheadStore.LOOKAHEAD_BUFFER_SIZE() * LibPreconfConstants.SECONDS_IN_EPOCH)
                + (EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            bytes26(bytes32(type(uint256).max))
        );

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting_reuse_slot.10_operators_in_both_lookaheads"
        );
    }

    function test_benchmark_checkProposerSameEpochProposalWithLookaheadPostingReuseSlot_case4()
        external
        useMainnet
    {
        // Current lookahead with 15 operators
        uint256[] memory currLookaheadSlotPositions = new uint256[](15);
        currLookaheadSlotPositions[0] = 2;
        currLookaheadSlotPositions[1] = 4;
        currLookaheadSlotPositions[2] = 6;
        currLookaheadSlotPositions[3] = 8;
        currLookaheadSlotPositions[4] = 10;
        currLookaheadSlotPositions[5] = 12;
        currLookaheadSlotPositions[6] = 14;
        currLookaheadSlotPositions[7] = 16;
        currLookaheadSlotPositions[8] = 18;
        currLookaheadSlotPositions[9] = 20;
        currLookaheadSlotPositions[10] = 22;
        currLookaheadSlotPositions[11] = 24;
        currLookaheadSlotPositions[12] = 26;
        currLookaheadSlotPositions[13] = 28;
        currLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            _setupLookahead(EPOCH_START, currLookaheadSlotPositions, true);

        // Next lookahead (to be posted) with 15 operators
        uint256[] memory nextLookaheadSlotPositions = new uint256[](15);
        nextLookaheadSlotPositions[0] = 2;
        nextLookaheadSlotPositions[1] = 4;
        nextLookaheadSlotPositions[2] = 6;
        nextLookaheadSlotPositions[3] = 8;
        nextLookaheadSlotPositions[4] = 10;
        nextLookaheadSlotPositions[5] = 12;
        nextLookaheadSlotPositions[6] = 14;
        nextLookaheadSlotPositions[7] = 16;
        nextLookaheadSlotPositions[8] = 18;
        nextLookaheadSlotPositions[9] = 20;
        nextLookaheadSlotPositions[10] = 22;
        nextLookaheadSlotPositions[11] = 24;
        nextLookaheadSlotPositions[12] = 26;
        nextLookaheadSlotPositions[13] = 28;
        nextLookaheadSlotPositions[14] = 30;
        ILookaheadStore.LookaheadSlot[] memory nextLookahead = _setupLookahead(
            EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH, nextLookaheadSlotPositions, false
        );

        bytes memory signature =
            _signLookaheadCommitment(currLookahead[0].registrationRoot, nextLookahead);

        vm.warp(currLookahead[0].timestamp);

        // Set a dummy hash at next lookahead's storage slot to simulate slot reuse
        _setLookaheadHash(
            (lookaheadStore.LOOKAHEAD_BUFFER_SIZE() * LibPreconfConstants.SECONDS_IN_EPOCH)
                + (EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH),
            bytes26(bytes32(type(uint256).max))
        );

        uint256 gasBefore = gasleft();
        _checkProposer(0, currLookahead[0].committer, currLookahead, nextLookahead, signature);
        uint256 gasConsumed = gasBefore - gasleft();

        _writeJson(
            gasConsumed,
            ".same_epoch_proposal_with_lookahead_posting_reuse_slot.15_operators_in_both_lookaheads"
        );
    }

    function _writeJson(uint256 _gasConsumed, string memory _valueKey) internal {
        vm.writeJson(
            vm.toString(_gasConsumed),
            string.concat(vm.projectRoot(), "/gas-reports/lookahead_check_proposer.json"),
            _valueKey
        );
    }
}
