// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibProposeDataDecoder } from "src/layer1/shasta/libs/LibProposeDataDecoder.sol";

/// @title LibProposeDataDecoderFuzz
/// @notice Fuzzy tests for LibProposeDataDecoder to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProposeDataDecoderFuzz is Test {
    /// @notice Fuzz test for basic encode/decode with simple types
    function testFuzz_encodeDecodeBasicTypes(
        uint64 deadline,
        uint48 nextProposalId,
        uint48 lastFinalizedProposalId,
        bytes32 lastFinalizedClaimHash,
        bytes32 bondInstructionsHash,
        uint16 blobStartIndex,
        uint16 numBlobs,
        uint24 offset
    )
        public
        pure
    {
        bytes memory encoded = LibProposeDataDecoder.encode(
            deadline,
            IInbox.CoreState({
                nextProposalId: nextProposalId,
                lastFinalizedProposalId: lastFinalizedProposalId,
                lastFinalizedClaimHash: lastFinalizedClaimHash,
                bondInstructionsHash: bondInstructionsHash
            }),
            new IInbox.Proposal[](0),
            LibBlobs.BlobReference({
                blobStartIndex: blobStartIndex,
                numBlobs: numBlobs,
                offset: offset
            }),
            new IInbox.ClaimRecord[](0)
        );

        (
            uint64 decodedDeadline,
            IInbox.CoreState memory decodedCoreState,
            ,
            LibBlobs.BlobReference memory decodedBlobRef,
        ) = LibProposeDataDecoder.decode(encoded);

        // Verify
        assertEq(decodedDeadline, deadline);
        assertEq(decodedCoreState.nextProposalId, nextProposalId);
        assertEq(decodedBlobRef.blobStartIndex, blobStartIndex);
    }

    /// @notice Fuzz test for single proposal
    function testFuzz_encodeDecodeSingleProposal(
        uint48 proposalId,
        address proposer,
        uint48 originTimestamp,
        uint48 originBlockNumber,
        bool isForcedInclusion,
        uint8 basefeeSharingPctg,
        uint24 blobOffset,
        uint48 blobTimestamp
    )
        public
        pure
    {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: proposalId,
            proposer: proposer,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            isForcedInclusion: isForcedInclusion,
            basefeeSharingPctg: basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: blobOffset,
                timestamp: blobTimestamp
            }),
            coreStateHash: keccak256("coreState")
        });

        // Encode and decode
        bytes memory encoded = LibProposeDataDecoder.encode(
            1_000_000,
            IInbox.CoreState({
                nextProposalId: 100,
                lastFinalizedProposalId: 95,
                lastFinalizedClaimHash: keccak256("test"),
                bondInstructionsHash: keccak256("bonds")
            }),
            proposals,
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            new IInbox.ClaimRecord[](0)
        );

        (,, IInbox.Proposal[] memory decoded,,) = LibProposeDataDecoder.decode(encoded);

        // Verify
        assertEq(decoded.length, 1);
        assertEq(decoded[0].id, proposalId);
        assertEq(decoded[0].proposer, proposer);
    }

    /// @notice Fuzz test for claim records with bond instructions
    function testFuzz_encodeDecodeClaimRecord(
        uint48 proposalId,
        bytes32 proposalHash,
        bytes32 parentClaimHash,
        uint48 endBlockNumber,
        bytes32 endBlockHash,
        bytes32 endStateRoot,
        address designatedProver,
        address actualProver,
        uint8 span
    )
        public
        pure
    {
        span = uint8(bound(span, 1, 9));

        LibBonds.BondInstruction[] memory bonds = new LibBonds.BondInstruction[](1);
        bonds[0] = LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: LibBonds.BondType.LIVENESS,
            payer: designatedProver,
            receiver: actualProver
        });

        IInbox.ClaimRecord[] memory claims = new IInbox.ClaimRecord[](1);
        claims[0] = IInbox.ClaimRecord({
            proposalId: proposalId,
            claim: IInbox.Claim({
                proposalHash: proposalHash,
                parentClaimHash: parentClaimHash,
                endBlockNumber: endBlockNumber,
                endBlockHash: endBlockHash,
                endStateRoot: endStateRoot,
                designatedProver: designatedProver,
                actualProver: actualProver
            }),
            span: span,
            bondInstructions: bonds
        });

        bytes memory encoded = LibProposeDataDecoder.encode(
            1_000_000,
            IInbox.CoreState({
                nextProposalId: 100,
                lastFinalizedProposalId: 95,
                lastFinalizedClaimHash: keccak256("test"),
                bondInstructionsHash: keccak256("bonds")
            }),
            new IInbox.Proposal[](0),
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            claims
        );

        (,,,, IInbox.ClaimRecord[] memory decoded) = LibProposeDataDecoder.decode(encoded);

        // Verify
        assertEq(decoded.length, 1);
        assertEq(decoded[0].proposalId, proposalId);
        assertEq(decoded[0].span, span);
    }

    /// @notice Fuzz test with variable array lengths
    function testFuzz_encodeDecodeVariableLengths(
        uint8 proposalCount,
        uint8 claimCount,
        uint8 blobHashCount,
        uint8 bondInstructionCount
    )
        public
        pure
    {
        // Bound the inputs to reasonable values
        proposalCount = uint8(bound(proposalCount, 0, 10));
        claimCount = uint8(bound(claimCount, 0, 10));
        blobHashCount = uint8(bound(blobHashCount, 0, 5));
        bondInstructionCount = uint8(bound(bondInstructionCount, 0, 5));

        // Create test data
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 95,
            lastFinalizedClaimHash: keccak256("test"),
            bondInstructionsHash: keccak256("bonds")
        });

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 });

        // Create proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            bytes32[] memory blobHashes = new bytes32[](blobHashCount);
            for (uint256 j = 0; j < blobHashCount; j++) {
                blobHashes[j] = keccak256(abi.encodePacked("blob", i, j));
            }

            proposals[i] = IInbox.Proposal({
                id: uint48(i + 1),
                proposer: address(uint160(0x1000 + i)),
                originTimestamp: uint48(1_000_000 + i),
                originBlockNumber: uint48(5_000_000 + i),
                isForcedInclusion: i % 2 == 0,
                basefeeSharingPctg: uint8(50 + i),
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(1024 * i),
                    timestamp: uint48(1_000_001 + i)
                }),
                coreStateHash: keccak256(abi.encodePacked("state", i))
            });
        }

        // Create claim records
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](claimCount);
        for (uint256 i = 0; i < claimCount; i++) {
            LibBonds.BondInstruction[] memory bondInstructions =
                new LibBonds.BondInstruction[](bondInstructionCount);
            for (uint256 j = 0; j < bondInstructionCount; j++) {
                bondInstructions[j] = LibBonds.BondInstruction({
                    proposalId: uint48(i + j),
                    bondType: j % 2 == 0 ? LibBonds.BondType.LIVENESS : LibBonds.BondType.PROVABILITY,
                    payer: address(uint160(0x2000 + i * 10 + j)),
                    receiver: address(uint160(0x3000 + i * 10 + j))
                });
            }

            claimRecords[i] = IInbox.ClaimRecord({
                proposalId: uint48(i + 1),
                claim: IInbox.Claim({
                    proposalHash: keccak256(abi.encodePacked("proposal", i)),
                    parentClaimHash: keccak256(abi.encodePacked("parent", i)),
                    endBlockNumber: uint48(2_000_000 + i),
                    endBlockHash: keccak256(abi.encodePacked("endBlock", i)),
                    endStateRoot: keccak256(abi.encodePacked("endState", i)),
                    designatedProver: address(uint160(0x4000 + i)),
                    actualProver: address(uint160(0x5000 + i))
                }),
                span: uint8(1 + i % 3),
                bondInstructions: bondInstructions
            });
        }

        // Encode
        bytes memory encoded =
            LibProposeDataDecoder.encode(999_999, coreState, proposals, blobRef, claimRecords);

        // Decode
        (
            uint64 decodedDeadline,
            ,
            IInbox.Proposal[] memory decodedProposals,
            ,
            IInbox.ClaimRecord[] memory decodedClaimRecords
        ) = LibProposeDataDecoder.decode(encoded);

        // Verify basic properties
        assertEq(decodedDeadline, 999_999, "Deadline mismatch");
        assertEq(decodedProposals.length, proposalCount, "Proposals length mismatch");
        assertEq(decodedClaimRecords.length, claimCount, "ClaimRecords length mismatch");

        // Verify proposal details
        for (uint256 i = 0; i < proposalCount; i++) {
            assertEq(decodedProposals[i].id, proposals[i].id, "Proposal id mismatch");
            assertEq(decodedProposals[i].proposer, proposals[i].proposer, "Proposer mismatch");
            assertEq(
                decodedProposals[i].blobSlice.blobHashes.length,
                blobHashCount,
                "Blob hash count mismatch"
            );
        }

        // Verify claim record details
        for (uint256 i = 0; i < claimCount; i++) {
            assertEq(
                decodedClaimRecords[i].proposalId,
                claimRecords[i].proposalId,
                "ClaimRecord proposalId mismatch"
            );
            assertEq(
                decodedClaimRecords[i].bondInstructions.length,
                bondInstructionCount,
                "Bond instruction count mismatch"
            );
        }
    }

    /// @notice Fuzz test to ensure encoded size is always smaller than abi.encode
    function testFuzz_encodedSizeComparison(uint8 proposalCount, uint8 claimCount) public pure {
        // Bound the inputs
        proposalCount = uint8(bound(proposalCount, 1, 10));
        claimCount = uint8(bound(claimCount, 1, 10));

        // Create test data
        (
            uint64 deadline,
            IInbox.CoreState memory coreState,
            IInbox.Proposal[] memory proposals,
            LibBlobs.BlobReference memory blobRef,
            IInbox.ClaimRecord[] memory claimRecords
        ) = _createTestData(proposalCount, claimCount, proposalCount * 2);

        // Encode with both methods
        bytes memory abiEncoded = abi.encode(deadline, coreState, proposals, blobRef, claimRecords);
        bytes memory libEncoded =
            LibProposeDataDecoder.encode(deadline, coreState, proposals, blobRef, claimRecords);

        // Verify LibProposeDataDecoder produces smaller output
        assertLt(
            libEncoded.length,
            abiEncoded.length,
            "LibProposeDataDecoder should produce smaller output"
        );

        // Verify decode produces identical results
        (
            uint64 decodedDeadline,
            IInbox.CoreState memory decodedCoreState,
            IInbox.Proposal[] memory decodedProposals,
            ,
            IInbox.ClaimRecord[] memory decodedClaimRecords
        ) = LibProposeDataDecoder.decode(libEncoded);

        assertEq(decodedDeadline, deadline, "Deadline mismatch after decode");
        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId, "CoreState mismatch");
        assertEq(decodedProposals.length, proposals.length, "Proposals length mismatch");
        assertEq(decodedClaimRecords.length, claimRecords.length, "ClaimRecords length mismatch");
    }

    /// @notice Helper function to create test data
    function _createTestData(
        uint256 _proposalCount,
        uint256 _claimCount,
        uint256 _totalBondInstructions
    )
        private
        pure
        returns (
            uint64 deadline,
            IInbox.CoreState memory coreState,
            IInbox.Proposal[] memory proposals,
            LibBlobs.BlobReference memory blobRef,
            IInbox.ClaimRecord[] memory claimRecords
        )
    {
        deadline = 2_000_000;

        coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 95,
            lastFinalizedClaimHash: keccak256("last_finalized"),
            bondInstructionsHash: keccak256("bond_instructions")
        });

        proposals = new IInbox.Proposal[](_proposalCount);
        for (uint256 i = 0; i < _proposalCount; i++) {
            bytes32[] memory blobHashes = new bytes32[](2);
            blobHashes[0] = keccak256(abi.encodePacked("blob", i, uint256(0)));
            blobHashes[1] = keccak256(abi.encodePacked("blob", i, uint256(1)));

            proposals[i] = IInbox.Proposal({
                id: uint48(96 + i),
                proposer: address(uint160(0x1000 + i)),
                originTimestamp: uint48(1_000_000 + i * 10),
                originBlockNumber: uint48(5_000_000 + i * 10),
                isForcedInclusion: i % 2 == 0,
                basefeeSharingPctg: uint8(50 + i * 10),
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(1024 * (i + 1)),
                    timestamp: uint48(1_000_001 + i * 10)
                }),
                coreStateHash: keccak256(abi.encodePacked("core_state", i))
            });
        }

        blobRef = LibBlobs.BlobReference({
            blobStartIndex: 1,
            numBlobs: uint16(_proposalCount * 2),
            offset: 512
        });

        claimRecords = new IInbox.ClaimRecord[](_claimCount);
        uint256 bondIndex = 0;
        for (uint256 i = 0; i < _claimCount; i++) {
            uint256 bondsForThisClaim = 0;
            if (i < _claimCount - 1) {
                bondsForThisClaim = _totalBondInstructions / _claimCount;
            } else {
                bondsForThisClaim = _totalBondInstructions - bondIndex;
            }

            LibBonds.BondInstruction[] memory bondInstructions =
                new LibBonds.BondInstruction[](bondsForThisClaim);
            for (uint256 j = 0; j < bondsForThisClaim; j++) {
                bondInstructions[j] = LibBonds.BondInstruction({
                    proposalId: uint48(96 + i),
                    bondType: j % 2 == 0 ? LibBonds.BondType.LIVENESS : LibBonds.BondType.PROVABILITY,
                    payer: address(uint160(0xaaaa + bondIndex)),
                    receiver: address(uint160(0xbbbb + bondIndex))
                });
                bondIndex++;
            }

            claimRecords[i] = IInbox.ClaimRecord({
                proposalId: uint48(96 + i),
                claim: IInbox.Claim({
                    proposalHash: keccak256(abi.encodePacked("proposal", i)),
                    parentClaimHash: keccak256(abi.encodePacked("parent_claim", i)),
                    endBlockNumber: uint48(2_000_000 + i * 10),
                    endBlockHash: keccak256(abi.encodePacked("end_block", i)),
                    endStateRoot: keccak256(abi.encodePacked("end_state", i)),
                    designatedProver: address(uint160(0x2000 + i)),
                    actualProver: address(uint160(0x3000 + i))
                }),
                span: uint8(1 + i % 3),
                bondInstructions: bondInstructions
            });
        }
    }
}
