// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibProveDataDecoder } from "src/layer1/shasta/libs/LibProveDataDecoder.sol";

/// @title LibProveDataDecoderTest
/// @notice Tests for LibProveDataDecoder
/// @custom:security-contact security@taiko.xyz
contract LibProveDataDecoderTest is Test {
    // Wrapper contract to test reverts properly
    TestWrapper wrapper;

    function setUp() public {
        wrapper = new TestWrapper();
    }

    function test_baseline_vs_optimized_simple() public {
        // Setup simple test case with 1 proposal and 1 claim
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 10,
            proposer: address(0x1),
            timestamp: 1000,
            coreStateHash: keccak256("coreState"),
            derivationHash: keccak256("derivation")
        });

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

        // Verify data integrity
        assertEq(proposals1.length, proposals2.length);
        assertEq(claims1.length, claims2.length);
        assertEq(proposals1[0].id, proposals2[0].id);
        assertEq(claims1[0].proposalHash, claims2[0].proposalHash);

        // Log results
        emit log_named_uint("Baseline gas (ABI)", baselineGas);
        emit log_named_uint("Optimized gas", optimizedGas);
        emit log_named_uint("ABI encoded size", abiEncodedData.length);
        emit log_named_uint("Compact encoded size", compactEncodedData.length);

        // Verify compact encoding is smaller
        assertLt(compactEncodedData.length, abiEncodedData.length);
    }

    function test_encode_decode_single() public pure {
        // Create test data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 123,
            proposer: address(0xabcd),
            timestamp: 999_999,
            coreStateHash: keccak256("core_state_hash"),
            derivationHash: keccak256("derivation_hash")
        });

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = IInbox.Claim({
            proposalHash: keccak256("proposal_hash"),
            parentClaimHash: keccak256("parent_hash"),
            endBlockNumber: 456_789,
            endBlockHash: keccak256("end_block_hash"),
            endStateRoot: keccak256("end_state_root"),
            designatedProver: address(0x1234),
            actualProver: address(0x5678)
        });

        // Encode
        bytes memory encoded = LibProveDataDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveDataDecoder.decode(encoded);

        // Verify proposals
        assertEq(decodedProposals.length, 1);
        assertEq(decodedProposals[0].id, proposals[0].id);
        assertEq(decodedProposals[0].proposer, proposals[0].proposer);
        assertEq(decodedProposals[0].timestamp, proposals[0].timestamp);
        assertEq(decodedProposals[0].coreStateHash, proposals[0].coreStateHash);
        assertEq(decodedProposals[0].derivationHash, proposals[0].derivationHash);

        // Verify claims
        assertEq(decodedClaims.length, 1);
        assertEq(decodedClaims[0].proposalHash, claims[0].proposalHash);
        assertEq(decodedClaims[0].parentClaimHash, claims[0].parentClaimHash);
        assertEq(decodedClaims[0].endBlockNumber, claims[0].endBlockNumber);
        assertEq(decodedClaims[0].endBlockHash, claims[0].endBlockHash);
        assertEq(decodedClaims[0].endStateRoot, claims[0].endStateRoot);
        assertEq(decodedClaims[0].designatedProver, claims[0].designatedProver);
        assertEq(decodedClaims[0].actualProver, claims[0].actualProver);
    }

    function test_encode_decode_multiple() public pure {
        uint256 count = 3;

        // Create test data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        IInbox.Claim[] memory claims = new IInbox.Claim[](count);

        for (uint256 i = 0; i < count; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i + 100),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i * 1000),
                coreStateHash: keccak256(abi.encode("core", i)),
                derivationHash: keccak256(abi.encode("deriv", i))
            });

            claims[i] = IInbox.Claim({
                proposalHash: keccak256(abi.encode("proposal", i)),
                parentClaimHash: keccak256(abi.encode("parent", i)),
                endBlockNumber: uint48(200_000 + i * 100),
                endBlockHash: keccak256(abi.encode("block", i)),
                endStateRoot: keccak256(abi.encode("state", i)),
                designatedProver: address(uint160(0x2000 + i)),
                actualProver: address(uint160(0x3000 + i))
            });
        }

        // Encode
        bytes memory encoded = LibProveDataDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveDataDecoder.decode(encoded);

        // Verify lengths
        assertEq(decodedProposals.length, count);
        assertEq(decodedClaims.length, count);

        // Verify each element
        for (uint256 i = 0; i < count; i++) {
            // Verify proposals
            assertEq(decodedProposals[i].id, proposals[i].id);
            assertEq(decodedProposals[i].proposer, proposals[i].proposer);
            assertEq(decodedProposals[i].timestamp, proposals[i].timestamp);
            assertEq(decodedProposals[i].coreStateHash, proposals[i].coreStateHash);
            assertEq(decodedProposals[i].derivationHash, proposals[i].derivationHash);

            // Verify claims
            assertEq(decodedClaims[i].proposalHash, claims[i].proposalHash);
            assertEq(decodedClaims[i].parentClaimHash, claims[i].parentClaimHash);
            assertEq(decodedClaims[i].endBlockNumber, claims[i].endBlockNumber);
            assertEq(decodedClaims[i].endBlockHash, claims[i].endBlockHash);
            assertEq(decodedClaims[i].endStateRoot, claims[i].endStateRoot);
            assertEq(decodedClaims[i].designatedProver, claims[i].designatedProver);
            assertEq(decodedClaims[i].actualProver, claims[i].actualProver);
        }
    }

    function test_encode_decode_empty() public pure {
        // Create empty arrays
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](0);
        IInbox.Claim[] memory claims = new IInbox.Claim[](0);

        // Encode
        bytes memory encoded = LibProveDataDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveDataDecoder.decode(encoded);

        // Verify empty arrays
        assertEq(decodedProposals.length, 0);
        assertEq(decodedClaims.length, 0);
    }

    function test_encode_decode_maxValues() public pure {
        // Create test data with maximum values
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: type(uint48).max,
            proposer: address(type(uint160).max),
            timestamp: type(uint48).max,
            coreStateHash: bytes32(type(uint256).max),
            derivationHash: bytes32(type(uint256).max)
        });

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = IInbox.Claim({
            proposalHash: bytes32(type(uint256).max),
            parentClaimHash: bytes32(type(uint256).max),
            endBlockNumber: type(uint48).max,
            endBlockHash: bytes32(type(uint256).max),
            endStateRoot: bytes32(type(uint256).max),
            designatedProver: address(type(uint160).max),
            actualProver: address(type(uint160).max)
        });

        // Encode
        bytes memory encoded = LibProveDataDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveDataDecoder.decode(encoded);

        // Verify max values preserved
        assertEq(decodedProposals[0].id, type(uint48).max);
        assertEq(decodedProposals[0].proposer, address(type(uint160).max));
        assertEq(decodedProposals[0].timestamp, type(uint48).max);
        assertEq(decodedProposals[0].coreStateHash, bytes32(type(uint256).max));
        assertEq(decodedProposals[0].derivationHash, bytes32(type(uint256).max));

        assertEq(decodedClaims[0].proposalHash, bytes32(type(uint256).max));
        assertEq(decodedClaims[0].parentClaimHash, bytes32(type(uint256).max));
        assertEq(decodedClaims[0].endBlockNumber, type(uint48).max);
        assertEq(decodedClaims[0].endBlockHash, bytes32(type(uint256).max));
        assertEq(decodedClaims[0].endStateRoot, bytes32(type(uint256).max));
        assertEq(decodedClaims[0].designatedProver, address(type(uint160).max));
        assertEq(decodedClaims[0].actualProver, address(type(uint160).max));
    }

    function test_revert_mismatchedLengths() public {
        // Create mismatched arrays
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);

        proposals[0] = IInbox.Proposal({
            id: 1,
            proposer: address(0x1),
            timestamp: 1000,
            coreStateHash: bytes32(0),
            derivationHash: bytes32(0)
        });

        proposals[1] = IInbox.Proposal({
            id: 2,
            proposer: address(0x2),
            timestamp: 2000,
            coreStateHash: bytes32(0),
            derivationHash: bytes32(0)
        });

        claims[0] = IInbox.Claim({
            proposalHash: bytes32(0),
            parentClaimHash: bytes32(0),
            endBlockNumber: 100,
            endBlockHash: bytes32(0),
            endStateRoot: bytes32(0),
            designatedProver: address(0x1),
            actualProver: address(0x2)
        });

        // Should revert due to mismatched lengths
        vm.expectRevert(LibProveDataDecoder.ProposalClaimLengthMismatch.selector);
        wrapper.encode(proposals, claims);
    }

    function test_gasComparison_large() public {
        uint256 count = 10;

        // Create test data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        IInbox.Claim[] memory claims = new IInbox.Claim[](count);

        for (uint256 i = 0; i < count; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i),
                proposer: address(uint160(i + 1)),
                timestamp: uint48(block.timestamp + i),
                coreStateHash: keccak256(abi.encode("core", i)),
                derivationHash: keccak256(abi.encode("deriv", i))
            });

            claims[i] = IInbox.Claim({
                proposalHash: keccak256(abi.encode("proposal", i)),
                parentClaimHash: keccak256(abi.encode("parent", i)),
                endBlockNumber: uint48(i * 1000),
                endBlockHash: keccak256(abi.encode("block", i)),
                endStateRoot: keccak256(abi.encode("state", i)),
                designatedProver: address(uint160(i * 2 + 1)),
                actualProver: address(uint160(i * 2 + 2))
            });
        }

        // ABI encoding
        bytes memory abiEncoded = abi.encode(proposals, claims);

        // Compact encoding
        bytes memory compactEncoded = LibProveDataDecoder.encode(proposals, claims);

        // Measure ABI decode gas
        uint256 gasStart = gasleft();
        abi.decode(abiEncoded, (IInbox.Proposal[], IInbox.Claim[]));
        uint256 abiGas = gasStart - gasleft();

        // Measure compact decode gas
        gasStart = gasleft();
        LibProveDataDecoder.decode(compactEncoded);
        uint256 compactGas = gasStart - gasleft();

        // Log results
        emit log_named_uint("Count", count);
        emit log_named_uint("ABI size", abiEncoded.length);
        emit log_named_uint("Compact size", compactEncoded.length);
        emit log_named_uint("ABI gas", abiGas);
        emit log_named_uint("Compact gas", compactGas);
        emit log_named_uint(
            "Size reduction %",
            ((abiEncoded.length - compactEncoded.length) * 100) / abiEncoded.length
        );

        // Verify compact is smaller
        assertLt(compactEncoded.length, abiEncoded.length);
    }
}

// Wrapper contract to test library reverts properly
contract TestWrapper {
    function encode(
        IInbox.Proposal[] memory proposals,
        IInbox.Claim[] memory claims
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProveDataDecoder.encode(proposals, claims);
    }
}
