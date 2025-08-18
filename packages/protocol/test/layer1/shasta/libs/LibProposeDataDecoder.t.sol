// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibProposeDataDecoder } from "src/layer1/shasta/libs/LibProposeDataDecoder.sol";

contract LibProposeDataDecoderTest is Test {
    function test_baseline_vs_optimized_simple() public {
        // Setup simple test case
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 10,
            lastFinalizedProposalId: 9,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 10,
            proposer: address(0x1),
            originTimestamp: 1000,
            originBlockNumber: 100,
            isForcedInclusion: false,
            basefeeSharingPctg: 50,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: new bytes32[](1), offset: 0, timestamp: 1000 }),
            coreStateHash: bytes32(0)
        });
        proposals[0].blobSlice.blobHashes[0] = bytes32(uint256(1));

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = IInbox.ClaimRecord({
            proposalId: 10,
            claim: IInbox.Claim({
                proposalHash: bytes32(0),
                parentClaimHash: bytes32(0),
                endBlockNumber: 200,
                endBlockHash: bytes32(0),
                endStateRoot: bytes32(0),
                designatedProver: address(0x2),
                actualProver: address(0x3)
            }),
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        uint64 deadline = 2_000_000;

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData =
            abi.encode(deadline, coreState, proposals, blobRef, claimRecords);

        // Test with compact encoding
        bytes memory compactEncodedData =
            LibProposeDataDecoder.encode(deadline, coreState, proposals, blobRef, claimRecords);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        (
            uint64 deadline1,
            IInbox.CoreState memory coreState1,
            IInbox.Proposal[] memory proposals1,
            LibBlobs.BlobReference memory blobRef1,
            IInbox.ClaimRecord[] memory claimRecords1
        ) = abi.decode(
            abiEncodedData,
            (
                uint64,
                IInbox.CoreState,
                IInbox.Proposal[],
                LibBlobs.BlobReference,
                IInbox.ClaimRecord[]
            )
        );
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        (
            uint64 deadline2,
            IInbox.CoreState memory coreState2,
            IInbox.Proposal[] memory proposals2,
            LibBlobs.BlobReference memory blobRef2,
            IInbox.ClaimRecord[] memory claimRecords2
        ) = LibProposeDataDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify correctness
        assertEq(deadline1, deadline2);
        assertEq(coreState1.nextProposalId, coreState2.nextProposalId);
        assertEq(coreState1.lastFinalizedProposalId, coreState2.lastFinalizedProposalId);
        assertEq(proposals1.length, proposals2.length);
        assertEq(blobRef1.numBlobs, blobRef2.numBlobs);
        assertEq(claimRecords1.length, claimRecords2.length);

        // Log gas usage
        emit log_named_uint("Simple case - Baseline ABI gas", baselineGas);
        emit log_named_uint("Simple case - Optimized compact gas", optimizedGas);

        // Log data sizes
        emit log_named_uint("ABI encoded size", abiEncodedData.length);
        emit log_named_uint("Compact encoded size", compactEncodedData.length);

        if (optimizedGas < baselineGas) {
            uint256 savings = ((baselineGas - optimizedGas) * 100) / baselineGas;
            emit log_named_uint("Gas savings %", savings);
        } else if (optimizedGas > baselineGas) {
            uint256 increase = ((optimizedGas - baselineGas) * 100) / baselineGas;
            emit log_named_uint("Gas increase %", increase);
        } else {
            emit log_string("Gas usage unchanged");
        }
    }

    function test_baseline_vs_optimized_complex() public {
        // Setup complex test case
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 95,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: keccak256("last_finalized"),
            bondInstructionsHash: keccak256("bond_instructions")
        });

        // Setup 2 proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = IInbox.Proposal({
            id: 96,
            proposer: address(0x1234),
            originTimestamp: 1_000_000,
            originBlockNumber: 5_000_000,
            isForcedInclusion: false,
            basefeeSharingPctg: 50,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](2),
                offset: 1024,
                timestamp: 1_000_001
            }),
            coreStateHash: keccak256("core_state_96")
        });
        proposals[0].blobSlice.blobHashes[0] = keccak256("blob_hash_1");
        proposals[0].blobSlice.blobHashes[1] = keccak256("blob_hash_2");

        proposals[1] = IInbox.Proposal({
            id: 97,
            proposer: address(0x5678),
            originTimestamp: 1_000_010,
            originBlockNumber: 5_000_010,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](1),
                offset: 2048,
                timestamp: 1_000_011
            }),
            coreStateHash: keccak256("core_state_97")
        });
        proposals[1].blobSlice.blobHashes[0] = keccak256("blob_hash_3");

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 3, offset: 512 });

        // Setup 2 claim records with bond instructions
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](2);

        LibBonds.BondInstruction[] memory bondInstructions1 = new LibBonds.BondInstruction[](2);
        bondInstructions1[0] = LibBonds.BondInstruction({
            proposalId: 96,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xcccc),
            receiver: address(0xdddd)
        });
        bondInstructions1[1] = LibBonds.BondInstruction({
            proposalId: 96,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0xeeee),
            receiver: address(0xffff)
        });

        claimRecords[0] = IInbox.ClaimRecord({
            proposalId: 96,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposal_96"),
                parentClaimHash: keccak256("parent_claim_96"),
                endBlockNumber: 2_000_000,
                endBlockHash: keccak256("end_block_96"),
                endStateRoot: keccak256("end_state_96"),
                designatedProver: address(0xaaaa),
                actualProver: address(0xbbbb)
            }),
            span: 1,
            bondInstructions: bondInstructions1
        });

        LibBonds.BondInstruction[] memory bondInstructions2 = new LibBonds.BondInstruction[](1);
        bondInstructions2[0] = LibBonds.BondInstruction({
            proposalId: 97,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333),
            receiver: address(0x4444)
        });

        claimRecords[1] = IInbox.ClaimRecord({
            proposalId: 97,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposal_97"),
                parentClaimHash: keccak256("parent_claim_97"),
                endBlockNumber: 2_000_010,
                endBlockHash: keccak256("end_block_97"),
                endStateRoot: keccak256("end_state_97"),
                designatedProver: address(0x1111),
                actualProver: address(0x2222)
            }),
            span: 2,
            bondInstructions: bondInstructions2
        });

        uint64 deadline = 2_000_000;

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData =
            abi.encode(deadline, coreState, proposals, blobRef, claimRecords);

        // Test with compact encoding
        bytes memory compactEncodedData =
            LibProposeDataDecoder.encode(deadline, coreState, proposals, blobRef, claimRecords);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        (
            uint64 deadline1,
            IInbox.CoreState memory coreState1,
            IInbox.Proposal[] memory proposals1,
            LibBlobs.BlobReference memory blobRef1,
            IInbox.ClaimRecord[] memory claimRecords1
        ) = abi.decode(
            abiEncodedData,
            (
                uint64,
                IInbox.CoreState,
                IInbox.Proposal[],
                LibBlobs.BlobReference,
                IInbox.ClaimRecord[]
            )
        );
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        (
            uint64 deadline2,
            IInbox.CoreState memory coreState2,
            IInbox.Proposal[] memory proposals2,
            LibBlobs.BlobReference memory blobRef2,
            IInbox.ClaimRecord[] memory claimRecords2
        ) = LibProposeDataDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify correctness
        assertEq(deadline1, deadline2);
        assertEq(coreState1.nextProposalId, coreState2.nextProposalId);
        assertEq(coreState1.lastFinalizedProposalId, coreState2.lastFinalizedProposalId);
        assertEq(coreState1.lastFinalizedClaimHash, coreState2.lastFinalizedClaimHash);
        assertEq(coreState1.bondInstructionsHash, coreState2.bondInstructionsHash);
        assertEq(proposals1.length, proposals2.length);
        assertEq(blobRef1.blobStartIndex, blobRef2.blobStartIndex);
        assertEq(blobRef1.numBlobs, blobRef2.numBlobs);
        assertEq(blobRef1.offset, blobRef2.offset);
        assertEq(claimRecords1.length, claimRecords2.length);

        // Log gas usage
        emit log_named_uint("Complex case - Baseline ABI gas", baselineGas);
        emit log_named_uint("Complex case - Optimized compact gas", optimizedGas);

        // Log data sizes
        emit log_named_uint("ABI encoded size", abiEncodedData.length);
        emit log_named_uint("Compact encoded size", compactEncodedData.length);

        if (optimizedGas < baselineGas) {
            uint256 savings = ((baselineGas - optimizedGas) * 100) / baselineGas;
            emit log_named_uint("Gas savings %", savings);
        } else if (optimizedGas > baselineGas) {
            uint256 increase = ((optimizedGas - baselineGas) * 100) / baselineGas;
            emit log_named_uint("Gas increase %", increase);
        } else {
            emit log_string("Gas usage unchanged");
        }
    }

    function test_correctness() public pure {
        // Test with various edge cases to ensure correctness
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTimestamp: 0,
            lastFinalizedClaimHash: bytes32(uint256(0xdead)),
            bondInstructionsHash: bytes32(uint256(0xbeef))
        });

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 1,
            proposer: address(0xabcd),
            originTimestamp: 999_999,
            originBlockNumber: 888_888,
            isForcedInclusion: true,
            basefeeSharingPctg: 100,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](3),
                offset: 16_777_215, // max uint24
                timestamp: 281_474_976_710_655 // max uint48
             }),
            coreStateHash: bytes32(uint256(0x123456))
        });

        for (uint256 i = 0; i < 3; i++) {
            proposals[0].blobSlice.blobHashes[i] = bytes32(uint256(i + 1));
        }

        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 65_535, // max uint16
            numBlobs: 65_535, // max uint16
            offset: 16_777_215 // max uint24
         });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);

        uint64 deadline = 18_446_744_073_709_551_615; // max uint64

        // Encode using compact encoding
        bytes memory compactEncodedData =
            LibProposeDataDecoder.encode(deadline, coreState, proposals, blobRef, claimRecords);

        // Decode
        (
            uint64 decodedDeadline,
            IInbox.CoreState memory decodedCoreState,
            IInbox.Proposal[] memory decodedProposals,
            LibBlobs.BlobReference memory decodedBlobRef,
            IInbox.ClaimRecord[] memory decodedClaimRecords
        ) = LibProposeDataDecoder.decode(compactEncodedData);

        // Verify all fields decoded correctly
        assertEq(decodedDeadline, deadline);
        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId);
        assertEq(decodedCoreState.lastFinalizedProposalId, coreState.lastFinalizedProposalId);
        assertEq(decodedCoreState.lastFinalizedClaimHash, coreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, coreState.bondInstructionsHash);

        assertEq(decodedProposals.length, 1);
        assertEq(decodedProposals[0].id, proposals[0].id);
        assertEq(decodedProposals[0].proposer, proposals[0].proposer);
        assertEq(decodedProposals[0].isForcedInclusion, proposals[0].isForcedInclusion);

        assertEq(decodedBlobRef.blobStartIndex, blobRef.blobStartIndex);
        assertEq(decodedBlobRef.numBlobs, blobRef.numBlobs);
        assertEq(decodedBlobRef.offset, blobRef.offset);

        assertEq(decodedClaimRecords.length, 0);
    }
}
