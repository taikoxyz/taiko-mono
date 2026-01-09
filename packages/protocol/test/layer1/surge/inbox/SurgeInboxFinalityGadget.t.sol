// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "../../core/inbox/InboxTestBase.sol";
import { MockProofVerifier } from "./mocks/MockContracts.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EmptyImpl } from "script/layer1/surge/common/EmptyImpl.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { SurgeVerifier } from "src/layer1/surge/SurgeVerifier.sol";
import { SurgeInbox } from "src/layer1/surge/deployments/internal-devnet/SurgeInbox.sol";
import { FinalityGadgetInbox } from "src/layer1/surge/features/FinalityGadgetInbox.sol";
import { LibProofBitmap } from "src/layer1/surge/libs/LibProofBitmap.sol";

contract SurgeInboxFinalityGadget is InboxTestBase {
    using LibProofBitmap for LibProofBitmap.ProofBitmap;

    uint48 internal constant MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET = 518_400;
    uint48 internal constant MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK = 604_800;
    uint8 internal constant NUM_PROOF_THRESHOLD = 2;

    SurgeVerifier internal surgeVerifier;

    // Wrapped proof bitmap types for reuse across tests
    LibProofBitmap.ProofBitmap internal _risc0Reth;
    LibProofBitmap.ProofBitmap internal _sp1Reth;
    LibProofBitmap.ProofBitmap internal _ziskReth;
    LibProofBitmap.ProofBitmap internal _proofBit4;
    LibProofBitmap.ProofBitmap internal _proofBit5;

    function setUp() public virtual override {
        // We deploy the proxy right away so that surge verifier can use this address
        inbox = Inbox(address(new ERC1967Proxy(address(new EmptyImpl()), "")));
        super.setUp();

        // Initialize wrapped proof bitmap types after surgeVerifier is set up
        _risc0Reth = LibProofBitmap.ProofBitmap.wrap(surgeVerifier.RISC0_RETH());
        _sp1Reth = LibProofBitmap.ProofBitmap.wrap(surgeVerifier.SP1_RETH());
        _ziskReth = LibProofBitmap.ProofBitmap.wrap(surgeVerifier.ZISK_RETH());
        _proofBit4 = LibProofBitmap.ProofBitmap.wrap(uint8(1 << 4));
        _proofBit5 = LibProofBitmap.ProofBitmap.wrap(uint8(1 << 5));
    }

    // ---------------------------------------------------------------------
    // Happy cases
    // ---------------------------------------------------------------------

    /// @dev Two conflicting commitments: finalizing with 2 subproofs, conflicting with 1 subproof
    function test_proveConflicts_twoCommitments_case1() external {
        // Create two conflicting transitions
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2") // Different blockhash to create conflict
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);

        // This will be the finalizing commitment
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });

        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"), // Different stateroot to create conflict
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);

        // Subproofs for the finalizing proof (2 subproofs)
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        // Subproofs for the conflicting proof (1 subproof)
        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        // Attempt to prove conflicts
        vm.expectEmit();
        emit FinalityGadgetInbox.ConflictingProofsDetected(1, _ziskReth);
        SurgeInbox(address(inbox))
            .proveConflicts(
                FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments), proofs
            );

        // The conflicting verifier is marked upgradeable
        _assertUpgradeable(_ziskReth);
    }

    /// @dev Two conflicting commitments: finalizing with 2 subproofs, conflicting with 2 subproofs
    function test_proveConflicts_twoCommitments_case2() external {
        // Create two conflicting transitions
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2") // Different blockhash to create conflict
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);

        // This will be the finalizing commitment
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });

        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"), // Different stateroot to create conflict
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);

        // Subproofs for the finalizing proof (2 subproofs)
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        // Subproofs for the conflicting proof (2 subproofs)
        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](2);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        subProofs2[1] = SurgeVerifier.SubProof({ proofBitFlag: _proofBit4, data: "" });
        proofs[1] = abi.encode(subProofs2);

        // Attempt to prove conflicts
        LibProofBitmap.ProofBitmap expectedBitmap = _ziskReth.merge(_proofBit4);
        vm.expectEmit();
        emit FinalityGadgetInbox.ConflictingProofsDetected(1, expectedBitmap);
        SurgeInbox(address(inbox))
            .proveConflicts(
                FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments), proofs
            );

        // The conflicting verifiers are marked upgradeable
        _assertUpgradeable(_ziskReth);
        _assertUpgradeable(_proofBit4);
    }

    /// @dev Three commitments: 1 finalizing (2 subproofs), 2 conflicting (one with 2 subproofs, one with 1 subproof)
    function test_proveConflicts_threeCommitments() external {
        // Create three conflicting transitions
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2") // Different blockhash to create conflict
        });

        IInbox.Transition[] memory transitions3 = new IInbox.Transition[](1);
        transitions3[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash3") // Different blockhash to create conflict
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](3);

        // This will be the finalizing commitment (2 subproofs)
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });

        // First conflicting commitment (2 subproofs)
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        // Second conflicting commitment (1 subproof)
        commitments[2] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot3"),
            transitions: transitions3
        });

        bytes[] memory proofs = new bytes[](3);

        // Subproofs for the finalizing proof (2 subproofs)
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        // Subproofs for the first conflicting proof (2 subproofs)
        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](2);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        subProofs2[1] = SurgeVerifier.SubProof({ proofBitFlag: _proofBit4, data: "" });
        proofs[1] = abi.encode(subProofs2);

        // Subproofs for the second conflicting proof (1 subproof)
        SurgeVerifier.SubProof[] memory subProofs3 = new SurgeVerifier.SubProof[](1);
        subProofs3[0] = SurgeVerifier.SubProof({ proofBitFlag: _proofBit5, data: "" });
        proofs[2] = abi.encode(subProofs3);

        // Attempt to prove conflicts
        LibProofBitmap.ProofBitmap expectedBitmap = _ziskReth.merge(_proofBit4).merge(_proofBit5);
        vm.expectEmit();
        emit FinalityGadgetInbox.ConflictingProofsDetected(1, expectedBitmap);
        SurgeInbox(address(inbox))
            .proveConflicts(
                FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments), proofs
            );

        // All conflicting verifiers are marked upgradeable
        _assertUpgradeable(_ziskReth);
        _assertUpgradeable(_proofBit4);
        _assertUpgradeable(_proofBit5);
    }

    // ---------------------------------------------------------------------
    // Failing cases
    // ---------------------------------------------------------------------

    /// @dev Reverts when only one commitment is provided (need at least 2 for conflict)
    function test_proveConflicts_revertWhen_InsufficientCommitmentsProvided() external {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](1);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions
        });

        bytes[] memory proofs = new bytes[](1);
        SurgeVerifier.SubProof[] memory subProofs = new SurgeVerifier.SubProof[](2);
        subProofs[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_InsufficientCommitmentsProvided.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when a commitment has more than one transition
    function test_proveConflicts_revertWhen_MoreThanOneTransitionProvided() external {
        // First commitment with 2 transitions (should fail)
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](2);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });
        transitions1[1] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1b")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2")
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_MoreThanOneTransitionProvided.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when firstProposalId differs between commitments
    function test_proveConflicts_revertWhen_FirstProposalIdDiffers() external {
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2")
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 2, // Different firstProposalId
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_FirstProposalIdMustNotDiffer.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when firstProposalParentBlockHash differs between commitments
    function test_proveConflicts_revertWhen_FirstProposalParentBlockHashDiffers() external {
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2")
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash1"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash2"), // Different
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(
            FinalityGadgetInbox.Surge_FirstProposalParentBlockHashMustNotDiffer.selector
        );
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when lastProposalHash differs between commitments
    function test_proveConflicts_revertWhen_LastProposalHashDiffers() external {
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2")
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash1"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash2"), // Different
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_LastProposalHashMustNotDiffer.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when endBlockNumber differs between commitments
    function test_proveConflicts_revertWhen_EndBlockNumberDiffers() external {
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2")
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number + 1), // Different
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_EndBlockNumberMustNotDiffer.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when transition blockHash is the same (no conflict)
    function test_proveConflicts_revertWhen_TransitionBlockhashSame() external {
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("sameBlockhash")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("sameBlockhash") // Same blockhash (not a conflict)
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot1"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("stateroot2"),
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_TransitionBlockhashMustDiffer.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    /// @dev Reverts when endStateRoot is the same (no conflict)
    function test_proveConflicts_revertWhen_CommitmentStateRootsSame() external {
        IInbox.Transition[] memory transitions1 = new IInbox.Transition[](1);
        transitions1[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash1")
        });

        IInbox.Transition[] memory transitions2 = new IInbox.Transition[](1);
        transitions2[0] = IInbox.Transition({
            proposer: address(0x1),
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockhash2") // Different blockhash
        });

        IInbox.Commitment[] memory commitments = new IInbox.Commitment[](2);
        commitments[0] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("sameStateRoot"),
            transitions: transitions1
        });
        commitments[1] = IInbox.Commitment({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32("firstProposalParentBlockHash"),
            lastProposalHash: bytes32("lastProposalHash"),
            actualProver: prover,
            endBlockNumber: uint48(block.number),
            endStateRoot: keccak256("sameStateRoot"), // Same state root (not a conflict)
            transitions: transitions2
        });

        bytes[] memory proofs = new bytes[](2);
        SurgeVerifier.SubProof[] memory subProofs1 = new SurgeVerifier.SubProof[](2);
        subProofs1[0] = SurgeVerifier.SubProof({ proofBitFlag: _risc0Reth, data: "" });
        subProofs1[1] = SurgeVerifier.SubProof({ proofBitFlag: _sp1Reth, data: "" });
        proofs[0] = abi.encode(subProofs1);

        SurgeVerifier.SubProof[] memory subProofs2 = new SurgeVerifier.SubProof[](1);
        subProofs2[0] = SurgeVerifier.SubProof({ proofBitFlag: _ziskReth, data: "" });
        proofs[1] = abi.encode(subProofs2);

        bytes memory encodedCommitments =
            FinalityGadgetInbox(address(inbox)).encodeCommitments(commitments);

        vm.expectRevert(FinalityGadgetInbox.Surge_CommitmentStateRootsMustDiffer.selector);
        SurgeInbox(address(inbox)).proveConflicts(encodedCommitments, proofs);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _assertUpgradeable(LibProofBitmap.ProofBitmap _proofBitflag) internal view {
        SurgeVerifier.InternalVerifier memory internalVerifier =
            surgeVerifier.getInternalVerifier(_proofBitflag);
        assertTrue(internalVerifier.allowInstantUpgrade);
    }

    function _setupSurgeVerifier() internal {
        surgeVerifier = new SurgeVerifier(address(inbox), NUM_PROOF_THRESHOLD, address(this));

        address mockInternalVerifier = address(new MockProofVerifier());
        surgeVerifier.setVerifier(
            LibProofBitmap.ProofBitmap.wrap(surgeVerifier.RISC0_RETH()), mockInternalVerifier
        );
        surgeVerifier.setVerifier(
            LibProofBitmap.ProofBitmap.wrap(surgeVerifier.SP1_RETH()), mockInternalVerifier
        );
        surgeVerifier.setVerifier(
            LibProofBitmap.ProofBitmap.wrap(surgeVerifier.ZISK_RETH()), mockInternalVerifier
        );

        // Extra bitflags for testing
        surgeVerifier.setVerifier(
            LibProofBitmap.ProofBitmap.wrap(uint8(1 << 4)), mockInternalVerifier
        );
        surgeVerifier.setVerifier(
            LibProofBitmap.ProofBitmap.wrap(uint8(1 << 5)), mockInternalVerifier
        );
    }

    // ---------------------------------------------------------------------
    // Hook overrides
    // ---------------------------------------------------------------------

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        _setupSurgeVerifier();

        return IInbox.Config({
            proofVerifier: address(surgeVerifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            bondToken: address(bondToken),
            minBond: 0,
            livenessBond: 0,
            withdrawalDelay: 0,
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
    /// @dev This also hackish-ly goes around directly deploying the inbox and instead upgrades
    /// the existing impl.
    function _deployInbox() internal virtual override returns (Inbox) {
        UUPSUpgradeable(address(inbox))
            .upgradeToAndCall(
                address(
                    new SurgeInbox(
                        config,
                        MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET,
                        MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
                    )
                ),
                abi.encodeCall(Inbox.init, (address(this)))
            );
        return inbox;
    }
}
