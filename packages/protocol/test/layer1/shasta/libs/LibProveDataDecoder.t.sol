// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibProveDataDecoder } from "src/layer1/shasta/libs/LibProveDataDecoder.sol";

contract LibProveDataDecoderTest is Test {
    function test_baseline_vs_optimized_simple() public {
        // Setup simple test case with 1 proposal and 1 claim
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

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = IInbox.Claim({
            proposalHash: keccak256("proposal_10"),
            parentClaimHash: keccak256("parent_claim"),
            endBlockNumber: 200,
            endBlockHash: keccak256("end_block"),
            endStateRoot: keccak256("end_state"),
            designatedProver: address(0x2),
            actualProver: address(0x3)
        });

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData = abi.encode(proposals, claims);

        // Test with compact encoding
        bytes memory compactEncodedData = LibProveDataDecoder.encode(proposals, claims);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        (IInbox.Proposal[] memory proposals1, IInbox.Claim[] memory claims1) =
            abi.decode(abiEncodedData, (IInbox.Proposal[], IInbox.Claim[]));
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        (IInbox.Proposal[] memory proposals2, IInbox.Claim[] memory claims2) =
            LibProveDataDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify correctness
        assertEq(proposals1.length, proposals2.length);
        assertEq(proposals1[0].id, proposals2[0].id);
        assertEq(proposals1[0].proposer, proposals2[0].proposer);
        assertEq(proposals1[0].isForcedInclusion, proposals2[0].isForcedInclusion);
        assertEq(claims1.length, claims2.length);
        assertEq(claims1[0].proposalHash, claims2[0].proposalHash);
        assertEq(claims1[0].actualProver, claims2[0].actualProver);

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
        // Setup complex test case with multiple proposals and claims
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);

        // Proposal 1
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

        // Proposal 2
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

        // Proposal 3
        proposals[2] = IInbox.Proposal({
            id: 98,
            proposer: address(0x9abc),
            originTimestamp: 1_000_020,
            originBlockNumber: 5_000_020,
            isForcedInclusion: false,
            basefeeSharingPctg: 25,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](3),
                offset: 4096,
                timestamp: 1_000_021
            }),
            coreStateHash: keccak256("core_state_98")
        });
        proposals[2].blobSlice.blobHashes[0] = keccak256("blob_hash_4");
        proposals[2].blobSlice.blobHashes[1] = keccak256("blob_hash_5");
        proposals[2].blobSlice.blobHashes[2] = keccak256("blob_hash_6");

        IInbox.Claim[] memory claims = new IInbox.Claim[](3);
        claims[0] = IInbox.Claim({
            proposalHash: keccak256("proposal_96"),
            parentClaimHash: keccak256("parent_claim_96"),
            endBlockNumber: 2_000_000,
            endBlockHash: keccak256("end_block_96"),
            endStateRoot: keccak256("end_state_96"),
            designatedProver: address(0xaaaa),
            actualProver: address(0xbbbb)
        });

        claims[1] = IInbox.Claim({
            proposalHash: keccak256("proposal_97"),
            parentClaimHash: keccak256("parent_claim_97"),
            endBlockNumber: 2_000_010,
            endBlockHash: keccak256("end_block_97"),
            endStateRoot: keccak256("end_state_97"),
            designatedProver: address(0x1111),
            actualProver: address(0x2222)
        });

        claims[2] = IInbox.Claim({
            proposalHash: keccak256("proposal_98"),
            parentClaimHash: keccak256("parent_claim_98"),
            endBlockNumber: 2_000_020,
            endBlockHash: keccak256("end_block_98"),
            endStateRoot: keccak256("end_state_98"),
            designatedProver: address(0x3333),
            actualProver: address(0x4444)
        });

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData = abi.encode(proposals, claims);

        // Test with compact encoding
        bytes memory compactEncodedData = LibProveDataDecoder.encode(proposals, claims);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        (IInbox.Proposal[] memory proposals1, IInbox.Claim[] memory claims1) =
            abi.decode(abiEncodedData, (IInbox.Proposal[], IInbox.Claim[]));
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        (IInbox.Proposal[] memory proposals2, IInbox.Claim[] memory claims2) =
            LibProveDataDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify correctness
        assertEq(proposals1.length, proposals2.length);
        assertEq(claims1.length, claims2.length);

        for (uint256 i = 0; i < proposals1.length; i++) {
            assertEq(proposals1[i].id, proposals2[i].id);
            assertEq(proposals1[i].proposer, proposals2[i].proposer);
            assertEq(proposals1[i].originTimestamp, proposals2[i].originTimestamp);
            assertEq(proposals1[i].originBlockNumber, proposals2[i].originBlockNumber);
            assertEq(proposals1[i].isForcedInclusion, proposals2[i].isForcedInclusion);
            assertEq(proposals1[i].basefeeSharingPctg, proposals2[i].basefeeSharingPctg);
            assertEq(proposals1[i].coreStateHash, proposals2[i].coreStateHash);

            assertEq(
                proposals1[i].blobSlice.blobHashes.length, proposals2[i].blobSlice.blobHashes.length
            );
            assertEq(proposals1[i].blobSlice.offset, proposals2[i].blobSlice.offset);
            assertEq(proposals1[i].blobSlice.timestamp, proposals2[i].blobSlice.timestamp);

            for (uint256 j = 0; j < proposals1[i].blobSlice.blobHashes.length; j++) {
                assertEq(
                    proposals1[i].blobSlice.blobHashes[j], proposals2[i].blobSlice.blobHashes[j]
                );
            }

            assertEq(claims1[i].proposalHash, claims2[i].proposalHash);
            assertEq(claims1[i].parentClaimHash, claims2[i].parentClaimHash);
            assertEq(claims1[i].endBlockNumber, claims2[i].endBlockNumber);
            assertEq(claims1[i].endBlockHash, claims2[i].endBlockHash);
            assertEq(claims1[i].endStateRoot, claims2[i].endStateRoot);
            assertEq(claims1[i].designatedProver, claims2[i].designatedProver);
            assertEq(claims1[i].actualProver, claims2[i].actualProver);
        }

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

    function test_correctness_edge_cases() public pure {
        // Test with various edge cases to ensure correctness
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 281_474_976_710_655, // max uint48
            proposer: address(0xabcd),
            originTimestamp: 999_999,
            originBlockNumber: 888_888,
            isForcedInclusion: true,
            basefeeSharingPctg: 255, // max uint8
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

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = IInbox.Claim({
            proposalHash: bytes32(uint256(0xdead)),
            parentClaimHash: bytes32(uint256(0xbeef)),
            endBlockNumber: 281_474_976_710_655, // max uint48
            endBlockHash: bytes32(uint256(0xcafe)),
            endStateRoot: bytes32(uint256(0xbabe)),
            designatedProver: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF), // max address
            actualProver: address(0x0) // min address
         });

        // Encode using compact encoding
        bytes memory compactEncodedData = LibProveDataDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveDataDecoder.decode(compactEncodedData);

        // Verify all fields decoded correctly
        assertEq(decodedProposals.length, 1);
        assertEq(decodedProposals[0].id, proposals[0].id);
        assertEq(decodedProposals[0].proposer, proposals[0].proposer);
        assertEq(decodedProposals[0].originTimestamp, proposals[0].originTimestamp);
        assertEq(decodedProposals[0].originBlockNumber, proposals[0].originBlockNumber);
        assertEq(decodedProposals[0].isForcedInclusion, proposals[0].isForcedInclusion);
        assertEq(decodedProposals[0].basefeeSharingPctg, proposals[0].basefeeSharingPctg);
        assertEq(decodedProposals[0].coreStateHash, proposals[0].coreStateHash);

        assertEq(decodedProposals[0].blobSlice.blobHashes.length, 3);
        assertEq(decodedProposals[0].blobSlice.offset, proposals[0].blobSlice.offset);
        assertEq(decodedProposals[0].blobSlice.timestamp, proposals[0].blobSlice.timestamp);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                decodedProposals[0].blobSlice.blobHashes[i], proposals[0].blobSlice.blobHashes[i]
            );
        }

        assertEq(decodedClaims.length, 1);
        assertEq(decodedClaims[0].proposalHash, claims[0].proposalHash);
        assertEq(decodedClaims[0].parentClaimHash, claims[0].parentClaimHash);
        assertEq(decodedClaims[0].endBlockNumber, claims[0].endBlockNumber);
        assertEq(decodedClaims[0].endBlockHash, claims[0].endBlockHash);
        assertEq(decodedClaims[0].endStateRoot, claims[0].endStateRoot);
        assertEq(decodedClaims[0].designatedProver, claims[0].designatedProver);
        assertEq(decodedClaims[0].actualProver, claims[0].actualProver);
    }

    function test_empty_arrays() public pure {
        // Test with empty arrays
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](0);
        IInbox.Claim[] memory claims = new IInbox.Claim[](0);

        // Encode using compact encoding
        bytes memory compactEncodedData = LibProveDataDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveDataDecoder.decode(compactEncodedData);

        // Verify arrays are empty
        assertEq(decodedProposals.length, 0);
        assertEq(decodedClaims.length, 0);
    }

    // Note: Error testing for library functions is complex in Solidity
    // The ProposalClaimLengthMismatch error is tested implicitly in the encode function
    // and will revert if arrays have different lengths
}
