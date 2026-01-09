// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "../../core/inbox/InboxTestBase.sol";
import { MockSurgeVerifier } from "./mocks/MockContracts.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { SurgeInbox } from "src/layer1/surge/deployments/internal-devnet/SurgeInbox.sol";
import { RollbackInbox } from "src/layer1/surge/features/RollbackInbox.sol";

contract SurgeInboxRollback is InboxTestBase {
    uint48 internal constant MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET = 518_400;
    uint48 internal constant MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK = 604_800;

    // ---------------------------------------------------------------------
    // Rollback (Happy cases)
    // ---------------------------------------------------------------------

    /// @dev Tests if the first proposal after genesis can be rolled back
    function test_rollback_firstProposal() external {
        IInbox.CoreState memory stateBefore = inbox.getCoreState();
        assertEq(stateBefore.nextProposalId, 1, "stateBefore: nextProposalId");

        _proposeOne();

        IInbox.CoreState memory stateAfterFirstProposal = inbox.getCoreState();
        assertEq(
            stateAfterFirstProposal.nextProposalId, 2, "stateAfterFirstProposal: nextProposalId"
        );

        vm.warp(
            stateAfterFirstProposal.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        vm.expectEmit();
        emit RollbackInbox.Rollbacked(1, 1);
        SurgeInbox(address(inbox)).rollback();

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        assertEq(stateAfterRollback.nextProposalId, 1, "stateAfterRollback: nextProposalId");
        assertTrue(SurgeInbox(address(inbox)).inLimpMode(), "afterRollback: inLimpMode");
    }

    /// @dev Tests if a single proposal can be rolled back
    function test_rollback_singleProposal() external {
        uint256 existingProposals = 10;
        uint256 proposalsToRollback = 1;

        IInbox.ProveInput memory proveInput = _buildBatchInput(existingProposals);
        _prove(proveInput);

        IInbox.CoreState memory initialState = inbox.getCoreState();
        assertEq(initialState.nextProposalId, existingProposals + 1, "initialState: nextProposalId");

        _proposeN(proposalsToRollback);

        IInbox.CoreState memory stateAfterSingleProposal = inbox.getCoreState();
        assertEq(
            stateAfterSingleProposal.nextProposalId,
            existingProposals + proposalsToRollback + 1,
            "stateAfterSingleProposal: nextProposalId"
        );

        vm.warp(
            stateAfterSingleProposal.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        vm.expectEmit();
        emit RollbackInbox.Rollbacked(
            existingProposals + 1, existingProposals + proposalsToRollback
        );
        SurgeInbox(address(inbox)).rollback();

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        _assertEqCoreState(initialState, stateAfterRollback);
        assertTrue(SurgeInbox(address(inbox)).inLimpMode(), "afterRollback: inLimpMode");
    }

    /// @dev Tests if two proposals can be rolled back
    function test_rollback_TwoProposals() external {
        uint256 existingProposals = 10;
        uint256 proposalsToRollback = 2;

        IInbox.ProveInput memory proveInput = _buildBatchInput(existingProposals);
        _prove(proveInput);

        IInbox.CoreState memory initialState = inbox.getCoreState();
        assertEq(initialState.nextProposalId, existingProposals + 1, "initialState: nextProposalId");

        _proposeN(proposalsToRollback);

        IInbox.CoreState memory stateAfterTwoProposals = inbox.getCoreState();
        assertEq(
            stateAfterTwoProposals.nextProposalId,
            existingProposals + proposalsToRollback + 1,
            "stateAfterTwoProposals: nextProposalId"
        );

        vm.warp(
            stateAfterTwoProposals.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        vm.expectEmit();
        emit RollbackInbox.Rollbacked(
            existingProposals + 1, existingProposals + proposalsToRollback
        );
        SurgeInbox(address(inbox)).rollback();

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        _assertEqCoreState(initialState, stateAfterRollback);
        assertTrue(SurgeInbox(address(inbox)).inLimpMode(), "afterRollback: inLimpMode");
    }

    /// @dev Tests if three proposals can be rolled back
    function test_rollback_ThreeProposals() external {
        uint256 existingProposals = 10;
        uint256 proposalsToRollback = 3;

        IInbox.ProveInput memory proveInput = _buildBatchInput(existingProposals);
        _prove(proveInput);

        IInbox.CoreState memory initialState = inbox.getCoreState();
        assertEq(initialState.nextProposalId, existingProposals + 1, "initialState: nextProposalId");

        _proposeN(proposalsToRollback);

        IInbox.CoreState memory stateAfterThreeProposals = inbox.getCoreState();
        assertEq(
            stateAfterThreeProposals.nextProposalId,
            existingProposals + proposalsToRollback + 1,
            "stateAfterThreeProposals: nextProposalId"
        );

        vm.warp(
            stateAfterThreeProposals.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        vm.expectEmit();
        emit RollbackInbox.Rollbacked(
            existingProposals + 1, existingProposals + proposalsToRollback
        );
        SurgeInbox(address(inbox)).rollback();

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        _assertEqCoreState(initialState, stateAfterRollback);
        assertTrue(SurgeInbox(address(inbox)).inLimpMode(), "afterRollback: inLimpMode");
    }

    /// @dev Tests if the chain can progress after rolling back the first proposal after genesis
    function test_rollback_chainCanProgressAfterRollingBackFirstProposal() external {
        _proposeOne();

        IInbox.CoreState memory stateAfterFirstProposal = inbox.getCoreState();
        assertEq(
            stateAfterFirstProposal.nextProposalId, 2, "stateAfterFirstProposal: nextProposalId"
        );

        vm.warp(
            stateAfterFirstProposal.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        SurgeInbox(address(inbox)).rollback();
        SurgeInbox(address(inbox)).setLimpMode(false); // Disable to allow direct proving in the test

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        assertEq(stateAfterRollback.nextProposalId, 1, "stateAfterRollback: nextProposalId");

        // Propose and prove a few batches after the rollback
        _advanceBlock();
        _prove(_buildBatchInput(5));

        // The chain is progressing correctly
        IInbox.CoreState memory finalState = inbox.getCoreState();
        assertEq(finalState.nextProposalId, 6, "finalState: nextProposalId");
        assertEq(finalState.lastFinalizedProposalId, 5, "finalState: nextProposalId");
        assertEq(
            finalState.lastFinalizedTimestamp, block.timestamp, "finalState: lastFinalizedTimestamp"
        );
    }

    function test_rollback_chainCanProgressAfterRollingBackOneProposal() external {
        uint256 existingProposals = 10;
        uint256 proposalsToRollback = 1;

        IInbox.ProveInput memory proveInput = _buildBatchInput(existingProposals);
        _prove(proveInput);

        IInbox.CoreState memory initialState = inbox.getCoreState();
        assertEq(initialState.nextProposalId, existingProposals + 1, "initialState: nextProposalId");

        _proposeN(proposalsToRollback);

        IInbox.CoreState memory stateAfterOneProposal = inbox.getCoreState();
        assertEq(
            stateAfterOneProposal.nextProposalId,
            existingProposals + proposalsToRollback + 1,
            "stateAfterOneProposal: nextProposalId"
        );

        vm.warp(
            stateAfterOneProposal.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        SurgeInbox(address(inbox)).rollback();
        SurgeInbox(address(inbox)).setLimpMode(false); // Disable to allow direct proving in the test

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        _assertEqCoreState(initialState, stateAfterRollback);

        // Propose and prove a few batches after the rollback
        _advanceBlock();
        _prove(_buildBatchInput(5));

        // The chain is progressing correctly
        IInbox.CoreState memory finalState = inbox.getCoreState();
        assertEq(finalState.nextProposalId, existingProposals + 6, "finalState: nextProposalId");
        assertEq(
            finalState.lastFinalizedProposalId, existingProposals + 5, "finalState: nextProposalId"
        );
        assertEq(
            finalState.lastFinalizedTimestamp, block.timestamp, "finalState: lastFinalizedTimestamp"
        );
    }

    function test_rollback_chainCanProgressAfterRollingBackThreeProposals() external {
        uint256 existingProposals = 10;
        uint256 proposalsToRollback = 3;

        IInbox.ProveInput memory proveInput = _buildBatchInput(existingProposals);
        _prove(proveInput);

        IInbox.CoreState memory initialState = inbox.getCoreState();
        assertEq(initialState.nextProposalId, existingProposals + 1, "initialState: nextProposalId");

        _proposeN(proposalsToRollback);

        IInbox.CoreState memory stateAfterThreeProposals = inbox.getCoreState();
        assertEq(
            stateAfterThreeProposals.nextProposalId,
            existingProposals + proposalsToRollback + 1,
            "stateAfterThreeProposals: nextProposalId"
        );

        vm.warp(
            stateAfterThreeProposals.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                + 1
        );
        SurgeInbox(address(inbox)).rollback();
        SurgeInbox(address(inbox)).setLimpMode(false); // Disable to allow direct proving in the test

        IInbox.CoreState memory stateAfterRollback = inbox.getCoreState();
        _assertEqCoreState(initialState, stateAfterRollback);

        // Propose and prove a few batches after the rollback
        _advanceBlock();
        _prove(_buildBatchInput(5));

        // The chain is progressing correctly
        IInbox.CoreState memory finalState = inbox.getCoreState();
        assertEq(finalState.nextProposalId, existingProposals + 6, "finalState: nextProposalId");
        assertEq(
            finalState.lastFinalizedProposalId, existingProposals + 5, "finalState: nextProposalId"
        );
        assertEq(
            finalState.lastFinalizedTimestamp, block.timestamp, "finalState: lastFinalizedTimestamp"
        );
    }

    // ---------------------------------------------------------------------
    // Limp mode (Happy cases)
    // ---------------------------------------------------------------------

    /// @dev Propose and prove when the head is already finalized
    function test_proposeAndProve_singleFinalization() external {
        // Not very relevant since propose and prove can be called outside of limp mode too.
        // Only added for brevity
        SurgeInbox(address(inbox)).setLimpMode(true);

        _advanceBlock();
        _setBlobHashes(1);
        IInbox.ProposeInput memory proposeInput = _defaultProposeInput();

        // Build the expected proposal to predict its hash
        IInbox.CoreState memory stateBefore = inbox.getCoreState();

        // Build the derivation sources (in limp mode, only the blob reference source)
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", 0)); // Same as _getBlobHashes
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: proposeInput.blobReference.offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: stateBefore.nextProposalId,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0, // PreconfWhitelist returns 0
            proposer: proposer,
            parentProposalHash: inbox.getProposalHash(stateBefore.nextProposalId - 1),
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0,
            sources: sources
        });

        bytes32 expectedProposalHash = codec.hashProposal(expectedProposal);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash1")
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: stateBefore.lastFinalizedBlockHash,
                lastProposalHash: expectedProposalHash,
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateroot"),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encodedProposeInput = codec.encodeProposeInput(proposeInput);
        bytes memory encodedProveInput = codec.encodeProveInput(proveInput);
        vm.prank(proposer);
        vm.startSnapshotGas("surge-propose", "propose_and_prove_limp_mode");
        SurgeInbox(address(inbox))
            .proposeAndProve(bytes(""), encodedProposeInput, encodedProveInput, bytes("proof"));
        vm.stopSnapshotGas();

        // Chain has progressed correctly
        IInbox.CoreState memory stateAfter = inbox.getCoreState();
        assertEq(stateAfter.nextProposalId, 2, "stateAfter: nextProposalId");
        assertEq(stateAfter.lastFinalizedProposalId, 1, "stateAfter: lastFinalizedProposalId");
        assertEq(
            stateAfter.lastFinalizedBlockHash,
            keccak256("blockHash1"),
            "stateAfter: lastFinalizedBlockHash"
        );
    }

    /// @dev This test propose and proves when the head is not finalized.
    function test_proposeAndProve_multipleFinalization() external {
        _proposeN(5);

        // Not very relevant since propose and prove can be called outside of limp mode too.
        // Only added for brevity
        SurgeInbox(address(inbox)).setLimpMode(true);

        _advanceBlock();
        _setBlobHashes(1);
        IInbox.ProposeInput memory proposeInput = _defaultProposeInput();

        // Build the expected proposal to predict its hash
        IInbox.CoreState memory stateBefore = inbox.getCoreState();

        // Build the derivation sources (in limp mode, only the blob reference source)
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", 0)); // Same as _getBlobHashes
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: proposeInput.blobReference.offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: stateBefore.nextProposalId,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0, // PreconfWhitelist returns 0
            proposer: proposer,
            parentProposalHash: inbox.getProposalHash(stateBefore.nextProposalId - 1),
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0,
            sources: sources
        });

        bytes32 expectedProposalHash = codec.hashProposal(expectedProposal);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](6);
        for (uint256 i; i < transitions.length; ++i) {
            transitions[i] = IInbox.Transition({
                proposer: proposer,
                designatedProver: prover,
                // Can keep this as latest timestamp since proof is not verified
                timestamp: uint48(block.timestamp),
                blockHash: keccak256(abi.encode("blockhash", i + 1))
            });
        }

        // Proves the formerly unproven batches as well as the current proposal
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: stateBefore.lastFinalizedBlockHash,
                lastProposalHash: expectedProposalHash,
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateroot"),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encodedProposeInput = codec.encodeProposeInput(proposeInput);
        bytes memory encodedProveInput = codec.encodeProveInput(proveInput);
        vm.prank(proposer);
        SurgeInbox(address(inbox))
            .proposeAndProve(bytes(""), encodedProposeInput, encodedProveInput, bytes("proof"));

        // Chain has progressed correctly
        IInbox.CoreState memory stateAfter = inbox.getCoreState();
        assertEq(stateAfter.nextProposalId, 7, "stateAfter: nextProposalId");
        assertEq(stateAfter.lastFinalizedProposalId, 6, "stateAfter: lastFinalizedProposalId");
        assertEq(
            stateAfter.lastFinalizedBlockHash,
            keccak256(abi.encode("blockhash", 6)),
            "stateAfter: lastFinalizedBlockHash"
        );
    }

    function test_proposeAndProve_forcedInclusionDisabledInLimpMode() external {
        // To prevent `IncorrectProposalCount()` error
        _proposeOne();

        // Add a proposal to forced inclusion store and warp the time to expect force inclusion
        // addition to the next proposal's source
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(forcedRef);
        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);

        _advanceBlock();
        _setBlobHashes(1);
        IInbox.ProposeInput memory proposeInput = _defaultProposeInput();

        // Build the expected proposal to predict its hash
        IInbox.CoreState memory stateBefore = inbox.getCoreState();

        // Build the derivation sources (we skip the force inclusion)
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", 0)); // Same as _getBlobHashes
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: proposeInput.blobReference.offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: stateBefore.nextProposalId,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0, // PreconfWhitelist returns 0
            proposer: proposer,
            parentProposalHash: inbox.getProposalHash(stateBefore.nextProposalId - 1),
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0,
            sources: sources // Force inclusion is not added to the expected proposal
        });

        bytes32 expectedProposalHash = codec.hashProposal(expectedProposal);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash1")
        });
        transitions[1] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash2")
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: stateBefore.lastFinalizedBlockHash,
                lastProposalHash: expectedProposalHash,
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateroot"),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encodedProposeInput = codec.encodeProposeInput(proposeInput);
        bytes memory encodedProveInput = codec.encodeProveInput(proveInput);

        // First attempt fails because limp mode is not activated
        vm.prank(proposer);
        vm.expectRevert(Inbox.UnprocessedForcedInclusionIsDue.selector);
        SurgeInbox(address(inbox))
            .proposeAndProve(bytes(""), encodedProposeInput, encodedProveInput, bytes("proof"));

        // Second attempt with limp mode activated should pass
        SurgeInbox(address(inbox)).setLimpMode(true);
        vm.prank(proposer);
        SurgeInbox(address(inbox))
            .proposeAndProve(bytes(""), encodedProposeInput, encodedProveInput, bytes("proof"));

        // Chain has progressed correctly
        IInbox.CoreState memory stateAfter = inbox.getCoreState();
        assertEq(stateAfter.nextProposalId, 3, "stateAfter: nextProposalId");
        assertEq(stateAfter.lastFinalizedProposalId, 2, "stateAfter: lastFinalizedProposalId");
        assertEq(
            stateAfter.lastFinalizedBlockHash,
            keccak256("blockHash2"),
            "stateAfter: lastFinalizedBlockHash"
        );
    }

    // ---------------------------------------------------------------------
    // Limp mode (Failing cases)
    // ---------------------------------------------------------------------

    function test_proposeAndProve_revertWhen_headIsNotFinalizedAfterCall() external {
        _proposeN(5);

        // Not very relevant since propose and prove can be called outside of limp mode too.
        // Only added for brevity
        SurgeInbox(address(inbox)).setLimpMode(true);

        _advanceBlock();
        _setBlobHashes(1);
        IInbox.ProposeInput memory proposeInput = _defaultProposeInput();

        // Build the expected proposal to predict its hash
        IInbox.CoreState memory stateBefore = inbox.getCoreState();

        // Build the derivation sources (in limp mode, only the blob reference source)
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", 0)); // Same as _getBlobHashes
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: proposeInput.blobReference.offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Send only 5 transitions to skip head finalization
        IInbox.Transition[] memory transitions = new IInbox.Transition[](5);
        for (uint256 i; i < transitions.length; ++i) {
            transitions[i] = IInbox.Transition({
                proposer: proposer,
                designatedProver: prover,
                // Can keep this as latest timestamp since proof is not verified
                timestamp: uint48(block.timestamp),
                blockHash: keccak256(abi.encode("blockhash", i + 1))
            });
        }

        // Does not prove the current proposal
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: stateBefore.lastFinalizedBlockHash,
                // Only finalize upto current proposal's id - 1
                lastProposalHash: inbox.getProposalHash(5),
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateroot"),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encodedProposeInput = codec.encodeProposeInput(proposeInput);
        bytes memory encodedProveInput = codec.encodeProveInput(proveInput);
        vm.prank(proposer);
        vm.expectRevert(RollbackInbox.Surge_HeadMustBeFinalizedInLimpMode.selector);
        SurgeInbox(address(inbox))
            .proposeAndProve(bytes(""), encodedProposeInput, encodedProveInput, bytes("proof"));
    }

    function test_propose_revertWhen_inLimpMode() external {
        SurgeInbox(address(inbox)).setLimpMode(true);
        IInbox.ProposeInput memory input;
        bytes memory encoded = codec.encodeProposeInput(input);
        vm.expectRevert(RollbackInbox.Surge_CannotProposeDirectlyInLimpMode.selector);
        inbox.propose("", encoded);
    }

    function test_prove_revertWhen_inLimpMode() external {
        SurgeInbox(address(inbox)).setLimpMode(true);
        IInbox.ProveInput memory input;
        bytes memory encoded = codec.encodeProveInput(input);
        vm.expectRevert(RollbackInbox.Surge_CannotProveDirectlyInLimpMode.selector);
        inbox.prove(encoded, "");
    }

    // ---------------------------------------------------------------------
    // Rollback (Failing cases)
    // ---------------------------------------------------------------------

    /// @dev Tests that rollback reverts when finalization delay has not been exceeded
    function test_rollback_revertWhen_RollbackWindowNotPassed() external {
        _proposeOne();

        IInbox.CoreState memory stateAfterProposal = inbox.getCoreState();

        // Warp to exactly the rollback threshold (not past it)
        vm.warp(stateAfterProposal.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK);

        vm.expectRevert(RollbackInbox.Surge_RollbackNotAllowed.selector);
        SurgeInbox(address(inbox)).rollback();
    }

    /// @dev Tests that rollback reverts when finalization delay has not been exceeded (before threshold)
    function test_rollback_revertWhen_RollbackWindowNotPassedBeforeThreshold() external {
        _proposeOne();

        IInbox.CoreState memory stateAfterProposal = inbox.getCoreState();

        // Warp to halfway through the rollback window
        vm.warp(
            stateAfterProposal.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK / 2
        );

        vm.expectRevert(RollbackInbox.Surge_RollbackNotAllowed.selector);
        SurgeInbox(address(inbox)).rollback();
    }

    /// @dev Tests that rollback reverts when there are no unfinalized proposals (genesis state)
    function test_rollback_revertWhen_NoProposalsAtGenesis() external {
        IInbox.CoreState memory genesisState = inbox.getCoreState();
        assertEq(genesisState.nextProposalId, 1, "genesisState: nextProposalId");
        assertEq(genesisState.lastFinalizedProposalId, 0, "genesisState: lastFinalizedProposalId");

        // Warp past the rollback threshold
        vm.warp(genesisState.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK + 1);

        vm.expectRevert(RollbackInbox.Surge_NoProposalsToRollback.selector);
        SurgeInbox(address(inbox)).rollback();
    }

    /// @dev Tests that rollback reverts when all proposals are finalized
    function test_rollback_revertWhen_AllProposalsFinalized() external {
        uint256 proposals = 5;

        // Propose and prove all proposals
        IInbox.ProveInput memory proveInput = _buildBatchInput(proposals);
        _prove(proveInput);

        IInbox.CoreState memory stateAfterProving = inbox.getCoreState();
        assertEq(
            stateAfterProving.nextProposalId, proposals + 1, "stateAfterProving: nextProposalId"
        );
        assertEq(
            stateAfterProving.lastFinalizedProposalId,
            proposals,
            "stateAfterProving: lastFinalizedProposalId"
        );

        // Warp past the rollback threshold
        vm.warp(
            stateAfterProving.lastFinalizedTimestamp + MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK + 1
        );

        vm.expectRevert(RollbackInbox.Surge_NoProposalsToRollback.selector);
        SurgeInbox(address(inbox)).rollback();
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _assertEqCoreState(
        IInbox.CoreState memory actual,
        IInbox.CoreState memory expected
    )
        internal
        pure
    {
        assertEq(
            actual.nextProposalId, expected.nextProposalId, "_assertEqCoreState: nextProposalId"
        );
        assertEq(
            actual.lastFinalizedProposalId,
            expected.lastFinalizedProposalId,
            "_assertEqCoreState: lastFinalizedProposalId"
        );
        assertEq(
            actual.lastFinalizedTimestamp,
            expected.lastFinalizedTimestamp,
            "_assertEqCoreState: lastFinalizedTimestamp"
        );
        assertEq(
            actual.lastCheckpointTimestamp,
            expected.lastCheckpointTimestamp,
            "_assertEqCoreState: lastCheckpointTimestamp"
        );
        assertEq(
            actual.lastFinalizedBlockHash,
            expected.lastFinalizedBlockHash,
            "_assertEqCoreState: lastFinalizedBlockHash"
        );

        // Note: lastProposalBlockId may differ
    }

    // ---------------------------------------------------------------------
    // Hook overrides
    // ---------------------------------------------------------------------

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(new MockSurgeVerifier()),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            provingWindow: 2 hours,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000, // large enough for skipping checkpoints in prove benches
            permissionlessInclusionMultiplier: 5
        });
    }

    /// @dev Override to deploy surge inbox instead of the base inbox
    function _deployInbox() internal virtual override returns (Inbox) {
        address impl = address(
            new SurgeInbox(
                config,
                MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET,
                MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
            )
        );
        return _deployProxy(impl);
    }
}
