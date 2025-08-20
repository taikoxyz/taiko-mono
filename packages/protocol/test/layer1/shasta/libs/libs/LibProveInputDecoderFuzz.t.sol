// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibProveInputDecoder } from "src/layer1/shasta/libs/LibProveInputDecoder.sol";

/// @title LibProveInputDecoderFuzz
/// @notice Fuzzy tests for LibProveInputDecoder to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProveInputDecoderFuzz is Test {
    // Wrapper contract to test reverts properly
    TestWrapperFuzz wrapper;

    function setUp() public {
        wrapper = new TestWrapperFuzz();
    }
    /// @notice Fuzz test for single proposal and claim

    function testFuzz_encodeDecodeSingleProposal(
        uint48 proposalId,
        address proposer,
        uint48 timestamp,
        uint48 endBlockNumber,
        address designatedProver
    )
        public
        pure
    {
        // Derive other values to avoid stack too deep
        bytes32 coreStateHash = keccak256(abi.encode("core", proposalId));
        bytes32 derivationHash = keccak256(abi.encode("deriv", proposalId));
        bytes32 proposalHash = keccak256(abi.encode("proposal", proposalId));
        bytes32 parentClaimHash = keccak256(abi.encode("parent", proposalId));
        bytes32 endBlockHash = keccak256(abi.encode("block", endBlockNumber));
        bytes32 endStateRoot = keccak256(abi.encode("state", endBlockNumber));
        address actualProver = address(uint160(designatedProver) + 1);
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: proposalId,
            proposer: proposer,
            timestamp: timestamp,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash
        });

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = IInbox.Claim({
            proposalHash: proposalHash,
            parentClaimHash: parentClaimHash,
            endBlockNumber: endBlockNumber,
            endBlockHash: endBlockHash,
            endStateRoot: endStateRoot,
            designatedProver: designatedProver,
            actualProver: actualProver
        });

        // Encode
        bytes memory encoded = LibProveInputDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveInputDecoder.decode(encoded);

        // Verify lengths
        assertEq(decodedProposals.length, 1);
        assertEq(decodedClaims.length, 1);

        // Verify proposal fields
        assertEq(decodedProposals[0].id, proposals[0].id);
        assertEq(decodedProposals[0].proposer, proposals[0].proposer);
        assertEq(decodedProposals[0].timestamp, proposals[0].timestamp);
        assertEq(decodedProposals[0].coreStateHash, proposals[0].coreStateHash);
        assertEq(decodedProposals[0].derivationHash, proposals[0].derivationHash);

        // Verify claim fields
        assertEq(decodedClaims[0].proposalHash, claims[0].proposalHash);
        assertEq(decodedClaims[0].parentClaimHash, claims[0].parentClaimHash);
        assertEq(decodedClaims[0].endBlockNumber, claims[0].endBlockNumber);
        assertEq(decodedClaims[0].endBlockHash, claims[0].endBlockHash);
        assertEq(decodedClaims[0].endStateRoot, claims[0].endStateRoot);
        assertEq(decodedClaims[0].designatedProver, claims[0].designatedProver);
        assertEq(decodedClaims[0].actualProver, claims[0].actualProver);
    }

    /// @notice Fuzz test for multiple proposals and claims
    function testFuzz_encodeDecodeMultiple(uint8 count) public pure {
        // Bound count to reasonable values
        count = uint8(bound(count, 1, 20));

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        IInbox.Claim[] memory claims = new IInbox.Claim[](count);

        for (uint256 i = 0; i < count; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i + 1),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i),
                coreStateHash: keccak256(abi.encodePacked("state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i))
            });

            claims[i] = IInbox.Claim({
                proposalHash: keccak256(abi.encodePacked("proposal", i)),
                parentClaimHash: keccak256(abi.encodePacked("parent", i)),
                endBlockNumber: uint48(2_000_000 + i),
                endBlockHash: keccak256(abi.encodePacked("endBlock", i)),
                endStateRoot: keccak256(abi.encodePacked("endState", i)),
                designatedProver: address(uint160(0x2000 + i)),
                actualProver: address(uint160(0x3000 + i))
            });
        }

        // Encode
        bytes memory encoded = LibProveInputDecoder.encode(proposals, claims);

        // Decode
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveInputDecoder.decode(encoded);

        // Verify lengths
        assertEq(decodedProposals.length, count);
        assertEq(decodedClaims.length, count);

        // Verify each element
        for (uint256 i = 0; i < count; i++) {
            assertEq(decodedProposals[i].id, proposals[i].id);
            assertEq(decodedProposals[i].proposer, proposals[i].proposer);
            assertEq(decodedProposals[i].timestamp, proposals[i].timestamp);
            assertEq(decodedProposals[i].coreStateHash, proposals[i].coreStateHash);
            assertEq(decodedProposals[i].derivationHash, proposals[i].derivationHash);

            assertEq(decodedClaims[i].proposalHash, claims[i].proposalHash);
            assertEq(decodedClaims[i].parentClaimHash, claims[i].parentClaimHash);
            assertEq(decodedClaims[i].endBlockNumber, claims[i].endBlockNumber);
            assertEq(decodedClaims[i].endBlockHash, claims[i].endBlockHash);
            assertEq(decodedClaims[i].endStateRoot, claims[i].endStateRoot);
            assertEq(decodedClaims[i].designatedProver, claims[i].designatedProver);
            assertEq(decodedClaims[i].actualProver, claims[i].actualProver);
        }
    }

    /// @notice Fuzz test with boundary values
    function testFuzz_boundaryValues(bool useMaxValues) public pure {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);

        if (useMaxValues) {
            // Test with maximum values
            proposals[0] = IInbox.Proposal({
                id: type(uint48).max,
                proposer: address(type(uint160).max),
                timestamp: type(uint48).max,
                coreStateHash: bytes32(type(uint256).max),
                derivationHash: bytes32(type(uint256).max)
            });

            claims[0] = IInbox.Claim({
                proposalHash: bytes32(type(uint256).max),
                parentClaimHash: bytes32(type(uint256).max),
                endBlockNumber: type(uint48).max,
                endBlockHash: bytes32(type(uint256).max),
                endStateRoot: bytes32(type(uint256).max),
                designatedProver: address(type(uint160).max),
                actualProver: address(type(uint160).max)
            });
        } else {
            // Test with minimum/zero values
            proposals[0] = IInbox.Proposal({
                id: 0,
                proposer: address(0),
                timestamp: 0,
                coreStateHash: bytes32(0),
                derivationHash: bytes32(0)
            });

            claims[0] = IInbox.Claim({
                proposalHash: bytes32(0),
                parentClaimHash: bytes32(0),
                endBlockNumber: 0,
                endBlockHash: bytes32(0),
                endStateRoot: bytes32(0),
                designatedProver: address(0),
                actualProver: address(0)
            });
        }

        // Encode and decode
        bytes memory encoded = LibProveInputDecoder.encode(proposals, claims);
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveInputDecoder.decode(encoded);

        // Verify values preserved
        assertEq(decodedProposals[0].id, proposals[0].id);
        assertEq(decodedProposals[0].proposer, proposals[0].proposer);
        assertEq(decodedProposals[0].timestamp, proposals[0].timestamp);
        assertEq(decodedProposals[0].coreStateHash, proposals[0].coreStateHash);
        assertEq(decodedProposals[0].derivationHash, proposals[0].derivationHash);

        assertEq(decodedClaims[0].proposalHash, claims[0].proposalHash);
        assertEq(decodedClaims[0].parentClaimHash, claims[0].parentClaimHash);
        assertEq(decodedClaims[0].endBlockNumber, claims[0].endBlockNumber);
        assertEq(decodedClaims[0].endBlockHash, claims[0].endBlockHash);
        assertEq(decodedClaims[0].endStateRoot, claims[0].endStateRoot);
        assertEq(decodedClaims[0].designatedProver, claims[0].designatedProver);
        assertEq(decodedClaims[0].actualProver, claims[0].actualProver);
    }

    /// @notice Fuzz test for size and gas comparison
    function testFuzz_sizeAndGasComparison(uint8 count) public {
        // Bound to reasonable values
        count = uint8(bound(count, 1, 50));

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
                proposalHash: keccak256(abi.encode("prop", i)),
                parentClaimHash: keccak256(abi.encode("parent", i)),
                endBlockNumber: uint48(i * 1000),
                endBlockHash: keccak256(abi.encode("block", i)),
                endStateRoot: keccak256(abi.encode("state", i)),
                designatedProver: address(uint160(i * 2 + 1)),
                actualProver: address(uint160(i * 2 + 2))
            });
        }

        // Compare ABI encoding vs compact encoding
        bytes memory abiEncoded = abi.encode(proposals, claims);
        bytes memory compactEncoded = LibProveInputDecoder.encode(proposals, claims);

        // Size comparison
        assertLt(compactEncoded.length, abiEncoded.length, "Compact should be smaller");

        // Gas comparison for decoding
        uint256 gasStart = gasleft();
        abi.decode(abiEncoded, (IInbox.Proposal[], IInbox.Claim[]));
        uint256 abiGas = gasStart - gasleft();

        gasStart = gasleft();
        LibProveInputDecoder.decode(compactEncoded);
        uint256 compactGas = gasStart - gasleft();

        // Log for analysis
        emit log_named_uint("Count", count);
        emit log_named_uint("ABI size", abiEncoded.length);
        emit log_named_uint("Compact size", compactEncoded.length);
        emit log_named_uint(
            "Size reduction %",
            ((abiEncoded.length - compactEncoded.length) * 100) / abiEncoded.length
        );
        emit log_named_uint("ABI decode gas", abiGas);
        emit log_named_uint("Compact decode gas", compactGas);
    }

    /// @notice Fuzz test for data integrity with random values
    function testFuzz_dataIntegrity(
        uint48 id1,
        address proposer1,
        uint48 timestamp1,
        bytes32 proposalHash1,
        uint48 endBlockNumber1
    )
        public
        pure
    {
        uint256 count = 3;
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        IInbox.Claim[] memory claims = new IInbox.Claim[](count);

        // Use fuzzed values for first item, derive rest to avoid stack too deep
        for (uint256 i = 0; i < count; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(id1 + i),
                proposer: address(uint160(proposer1) + uint160(i)),
                timestamp: uint48(timestamp1 + i),
                coreStateHash: keccak256(abi.encode("core", i, id1)),
                derivationHash: keccak256(abi.encode("deriv", i, id1))
            });

            claims[i] = IInbox.Claim({
                proposalHash: keccak256(abi.encode(proposalHash1, i)),
                parentClaimHash: keccak256(abi.encode("parent", i, proposalHash1)),
                endBlockNumber: uint48(endBlockNumber1 + i * 100),
                endBlockHash: keccak256(abi.encode("block", i, endBlockNumber1)),
                endStateRoot: keccak256(abi.encode("state", i)),
                designatedProver: address(uint160(proposer1) + uint160(i * 2)),
                actualProver: address(uint160(proposer1) + uint160(i * 2 + 1))
            });
        }

        // Encode and decode
        bytes memory encoded = LibProveInputDecoder.encode(proposals, claims);
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveInputDecoder.decode(encoded);

        // Verify all data preserved correctly
        for (uint256 i = 0; i < count; i++) {
            assertEq(decodedProposals[i].id, proposals[i].id);
            assertEq(decodedProposals[i].proposer, proposals[i].proposer);
            assertEq(decodedProposals[i].timestamp, proposals[i].timestamp);
            assertEq(decodedProposals[i].coreStateHash, proposals[i].coreStateHash);
            assertEq(decodedProposals[i].derivationHash, proposals[i].derivationHash);

            assertEq(decodedClaims[i].proposalHash, claims[i].proposalHash);
            assertEq(decodedClaims[i].parentClaimHash, claims[i].parentClaimHash);
            assertEq(decodedClaims[i].endBlockNumber, claims[i].endBlockNumber);
            assertEq(decodedClaims[i].endBlockHash, claims[i].endBlockHash);
            assertEq(decodedClaims[i].endStateRoot, claims[i].endStateRoot);
            assertEq(decodedClaims[i].designatedProver, claims[i].designatedProver);
            assertEq(decodedClaims[i].actualProver, claims[i].actualProver);
        }
    }

    /// @notice Test empty arrays handling
    function testFuzz_emptyArrays() public pure {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](0);
        IInbox.Claim[] memory claims = new IInbox.Claim[](0);

        bytes memory encoded = LibProveInputDecoder.encode(proposals, claims);
        (IInbox.Proposal[] memory decodedProposals, IInbox.Claim[] memory decodedClaims) =
            LibProveInputDecoder.decode(encoded);

        assertEq(decodedProposals.length, 0);
        assertEq(decodedClaims.length, 0);
    }

    /// @notice Test that mismatched lengths revert
    function testFuzz_mismatchedLengthsRevert(uint8 proposalCount, uint8 claimCount) public {
        vm.assume(proposalCount != claimCount);
        vm.assume(proposalCount > 0 && proposalCount <= 10);
        vm.assume(claimCount > 0 && claimCount <= 10);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](proposalCount);
        IInbox.Claim[] memory claims = new IInbox.Claim[](claimCount);

        // Fill with dummy data
        for (uint256 i = 0; i < proposalCount; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i),
                proposer: address(uint160(i)),
                timestamp: uint48(i),
                coreStateHash: bytes32(uint256(i)),
                derivationHash: bytes32(uint256(i))
            });
        }

        for (uint256 i = 0; i < claimCount; i++) {
            claims[i] = IInbox.Claim({
                proposalHash: bytes32(uint256(i)),
                parentClaimHash: bytes32(uint256(i)),
                endBlockNumber: uint48(i),
                endBlockHash: bytes32(uint256(i)),
                endStateRoot: bytes32(uint256(i)),
                designatedProver: address(uint160(i)),
                actualProver: address(uint160(i))
            });
        }

        vm.expectRevert(LibProveInputDecoder.ProposalClaimLengthMismatch.selector);
        wrapper.encode(proposals, claims);
    }
}

// Wrapper contract to test library reverts properly
contract TestWrapperFuzz {
    function encode(
        IInbox.Proposal[] memory proposals,
        IInbox.Claim[] memory claims
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProveInputDecoder.encode(proposals, claims);
    }
}
