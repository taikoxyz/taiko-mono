// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "./mocks/TestInboxOptimized.sol";
import "src/layer1/shasta/libs/LibBlobs.sol";
import "src/layer1/shasta/libs/LibCodec.sol";
import "src/shared/based/libs/LibBonds.sol";

contract InboxOptimizedTest is Test {
    TestInboxOptimized inbox;

    function setUp() public {
        IInbox.Config memory config = IInbox.Config({
            bondToken: address(0x1),
            provingWindow: 3600,
            extendedProvingWindow: 7200,
            maxFinalizationCount: 10,
            ringBufferSize: 100,
            basefeeSharingPctg: 75,
            syncedBlockManager: address(0x2),
            proofVerifier: address(0x3),
            proposerChecker: address(0x4),
            forcedInclusionStore: address(0x5)
        });

        inbox = new TestInboxOptimized(config);
    }

    function test_EncodeDecodeProposedEventData_Simple() public view {
        // Create test data
        IInbox.Proposal memory proposal;
        proposal.id = 123;
        proposal.proposer = address(0x1234567890123456789012345678901234567890);
        proposal.originTimestamp = 1_234_567_890;
        proposal.originBlockNumber = 9_876_543;
        proposal.isForcedInclusion = true;
        proposal.basefeeSharingPctg = 75;
        proposal.blobSlice.blobHashes = new bytes32[](2);
        proposal.blobSlice.blobHashes[0] = bytes32(uint256(1));
        proposal.blobSlice.blobHashes[1] = bytes32(uint256(2));
        proposal.blobSlice.offset = 100;
        proposal.blobSlice.timestamp = 1_234_567_891;
        proposal.coreStateHash = bytes32(uint256(999));

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = 124;
        coreState.lastFinalizedProposalId = 122;
        coreState.lastFinalizedClaimHash = bytes32(uint256(888));
        coreState.bondInstructionsHash = bytes32(uint256(777));

        // Encode
        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        // Verify Proposal fields
        assertEq(decodedProposal.id, proposal.id);
        assertEq(decodedProposal.proposer, proposal.proposer);
        assertEq(decodedProposal.originTimestamp, proposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, proposal.originBlockNumber);
        assertEq(decodedProposal.isForcedInclusion, proposal.isForcedInclusion);
        assertEq(decodedProposal.basefeeSharingPctg, proposal.basefeeSharingPctg);
        assertEq(decodedProposal.blobSlice.blobHashes.length, proposal.blobSlice.blobHashes.length);
        for (uint256 i; i < proposal.blobSlice.blobHashes.length; ++i) {
            assertEq(decodedProposal.blobSlice.blobHashes[i], proposal.blobSlice.blobHashes[i]);
        }
        assertEq(decodedProposal.blobSlice.offset, proposal.blobSlice.offset);
        assertEq(decodedProposal.blobSlice.timestamp, proposal.blobSlice.timestamp);
        assertEq(decodedProposal.coreStateHash, proposal.coreStateHash);

        // Verify CoreState fields
        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId);
        assertEq(decodedCoreState.lastFinalizedProposalId, coreState.lastFinalizedProposalId);
        assertEq(decodedCoreState.lastFinalizedClaimHash, coreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, coreState.bondInstructionsHash);
    }

    function test_EncodeDecodeProposedEventData_NoBlobHashes() public view {
        // Create test data with no blob hashes
        IInbox.Proposal memory proposal;
        proposal.id = 1;
        proposal.proposer = address(0xdead);
        proposal.originTimestamp = 100;
        proposal.originBlockNumber = 200;
        proposal.isForcedInclusion = false;
        proposal.basefeeSharingPctg = 50;
        proposal.blobSlice.blobHashes = new bytes32[](0); // Empty array
        proposal.blobSlice.offset = 0;
        proposal.blobSlice.timestamp = 101;
        proposal.coreStateHash = bytes32(uint256(1));

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = 2;
        coreState.lastFinalizedProposalId = 0;
        coreState.lastFinalizedClaimHash = bytes32(uint256(2));
        coreState.bondInstructionsHash = bytes32(uint256(3));

        // Encode
        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        // Verify
        assertEq(decodedProposal.id, proposal.id);
        assertEq(decodedProposal.proposer, proposal.proposer);
        assertEq(decodedProposal.blobSlice.blobHashes.length, 0);
        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId);
    }

    function test_EncodeDecodeProveEventData_Simple() public view {
        // Create test data
        IInbox.ClaimRecord memory claimRecord;
        claimRecord.claim.proposalId = 456;
        claimRecord.claim.proposalHash = bytes32(uint256(111));
        claimRecord.claim.parentClaimHash = bytes32(uint256(222));
        claimRecord.claim.endBlockNumber = 789_012;
        claimRecord.claim.endBlockHash = bytes32(uint256(333));
        claimRecord.claim.endStateRoot = bytes32(uint256(444));
        claimRecord.claim.designatedProver = address(0xaaaa);
        claimRecord.claim.actualProver = address(0xbbbb);
        claimRecord.span = 5;

        // Create bond instructions
        claimRecord.bondInstructions = new LibBonds.BondInstruction[](2);
        claimRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 456,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0xcccc),
            receiver: address(0xdddd)
        });
        claimRecord.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 457,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xeeee),
            receiver: address(0xffff)
        });

        // Encode
        bytes memory encoded = LibCodec.encodeProveEventData(claimRecord);

        // Decode
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        // Verify Claim fields
        assertEq(decodedClaimRecord.claim.proposalId, claimRecord.claim.proposalId);
        assertEq(decodedClaimRecord.claim.proposalHash, claimRecord.claim.proposalHash);
        assertEq(decodedClaimRecord.claim.parentClaimHash, claimRecord.claim.parentClaimHash);
        assertEq(decodedClaimRecord.claim.endBlockNumber, claimRecord.claim.endBlockNumber);
        assertEq(decodedClaimRecord.claim.endBlockHash, claimRecord.claim.endBlockHash);
        assertEq(decodedClaimRecord.claim.endStateRoot, claimRecord.claim.endStateRoot);
        assertEq(decodedClaimRecord.claim.designatedProver, claimRecord.claim.designatedProver);
        assertEq(decodedClaimRecord.claim.actualProver, claimRecord.claim.actualProver);

        // Verify span
        assertEq(decodedClaimRecord.span, claimRecord.span);

        // Verify bond instructions
        assertEq(decodedClaimRecord.bondInstructions.length, claimRecord.bondInstructions.length);
        for (uint256 i; i < claimRecord.bondInstructions.length; ++i) {
            assertEq(
                decodedClaimRecord.bondInstructions[i].proposalId,
                claimRecord.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decodedClaimRecord.bondInstructions[i].bondType),
                uint8(claimRecord.bondInstructions[i].bondType)
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].payer, claimRecord.bondInstructions[i].payer
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].receiver,
                claimRecord.bondInstructions[i].receiver
            );
        }
    }

    function test_EncodeDecodeProveEventData_NoBondInstructions() public view {
        // Create test data with no bond instructions
        IInbox.ClaimRecord memory claimRecord;
        claimRecord.claim.proposalId = 1;
        claimRecord.claim.proposalHash = bytes32(uint256(1));
        claimRecord.claim.parentClaimHash = bytes32(uint256(2));
        claimRecord.claim.endBlockNumber = 100;
        claimRecord.claim.endBlockHash = bytes32(uint256(3));
        claimRecord.claim.endStateRoot = bytes32(uint256(4));
        claimRecord.claim.designatedProver = address(0x1111);
        claimRecord.claim.actualProver = address(0x2222);
        claimRecord.span = 1;
        claimRecord.bondInstructions = new LibBonds.BondInstruction[](0); // Empty array

        // Encode
        bytes memory encoded = LibCodec.encodeProveEventData(claimRecord);

        // Decode
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        // Verify
        assertEq(decodedClaimRecord.claim.proposalId, claimRecord.claim.proposalId);
        assertEq(decodedClaimRecord.span, claimRecord.span);
        assertEq(decodedClaimRecord.bondInstructions.length, 0);
    }

    function test_EncodeDecodeProposedEventData_MaxValues() public view {
        // Test with maximum values for various fields
        IInbox.Proposal memory proposal;
        proposal.id = type(uint48).max;
        proposal.proposer = address(type(uint160).max);
        proposal.originTimestamp = type(uint48).max;
        proposal.originBlockNumber = type(uint48).max;
        proposal.isForcedInclusion = true;
        proposal.basefeeSharingPctg = type(uint8).max;
        proposal.blobSlice.blobHashes = new bytes32[](1);
        proposal.blobSlice.blobHashes[0] = bytes32(type(uint256).max);
        proposal.blobSlice.offset = type(uint24).max;
        proposal.blobSlice.timestamp = type(uint48).max;
        proposal.coreStateHash = bytes32(type(uint256).max);

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = type(uint48).max;
        coreState.lastFinalizedProposalId = type(uint48).max;
        coreState.lastFinalizedClaimHash = bytes32(type(uint256).max);
        coreState.bondInstructionsHash = bytes32(type(uint256).max);

        // Encode and decode
        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        // Verify all max values are preserved
        assertEq(decodedProposal.id, type(uint48).max);
        assertEq(decodedProposal.proposer, address(type(uint160).max));
        assertEq(decodedProposal.originTimestamp, type(uint48).max);
        assertEq(decodedProposal.originBlockNumber, type(uint48).max);
        assertEq(decodedProposal.basefeeSharingPctg, type(uint8).max);
        assertEq(decodedProposal.blobSlice.offset, type(uint24).max);
        assertEq(decodedProposal.blobSlice.timestamp, type(uint48).max);
        assertEq(decodedCoreState.nextProposalId, type(uint48).max);
        assertEq(decodedCoreState.lastFinalizedProposalId, type(uint48).max);
    }

    function test_EncodeDecodeProveEventData_MaxValues() public view {
        // Test with maximum values
        IInbox.ClaimRecord memory claimRecord;
        claimRecord.claim.proposalId = type(uint48).max;
        claimRecord.claim.proposalHash = bytes32(type(uint256).max);
        claimRecord.claim.parentClaimHash = bytes32(type(uint256).max);
        claimRecord.claim.endBlockNumber = type(uint48).max;
        claimRecord.claim.endBlockHash = bytes32(type(uint256).max);
        claimRecord.claim.endStateRoot = bytes32(type(uint256).max);
        claimRecord.claim.designatedProver = address(type(uint160).max);
        claimRecord.claim.actualProver = address(type(uint160).max);
        claimRecord.span = type(uint8).max;

        claimRecord.bondInstructions = new LibBonds.BondInstruction[](1);
        claimRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: type(uint48).max,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(type(uint160).max),
            receiver: address(type(uint160).max)
        });

        // Encode and decode
        bytes memory encoded = LibCodec.encodeProveEventData(claimRecord);
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        // Verify all max values are preserved
        assertEq(decodedClaimRecord.claim.proposalId, type(uint48).max);
        assertEq(decodedClaimRecord.claim.endBlockNumber, type(uint48).max);
        assertEq(decodedClaimRecord.claim.designatedProver, address(type(uint160).max));
        assertEq(decodedClaimRecord.claim.actualProver, address(type(uint160).max));
        assertEq(decodedClaimRecord.span, type(uint8).max);
        assertEq(decodedClaimRecord.bondInstructions[0].proposalId, type(uint48).max);
        assertEq(decodedClaimRecord.bondInstructions[0].payer, address(type(uint160).max));
        assertEq(decodedClaimRecord.bondInstructions[0].receiver, address(type(uint160).max));
    }

    function testFuzz_EncodeDecodeProposedEventData(
        uint48 id,
        address proposer,
        uint48 originTimestamp,
        uint48 originBlockNumber,
        bool isForcedInclusion,
        uint8 basefeeSharingPctg,
        uint8 numBlobHashes,
        uint24 offset,
        uint48 timestamp,
        bytes32 coreStateHash,
        uint48 nextProposalId,
        uint48 lastFinalizedProposalId,
        bytes32 lastFinalizedClaimHash,
        bytes32 bondInstructionsHash
    )
        public
        view
    {
        // Limit blob hashes to reasonable number for testing
        numBlobHashes = uint8(bound(numBlobHashes, 0, 10));

        // Create proposal
        IInbox.Proposal memory proposal;
        proposal.id = id;
        proposal.proposer = proposer;
        proposal.originTimestamp = originTimestamp;
        proposal.originBlockNumber = originBlockNumber;
        proposal.isForcedInclusion = isForcedInclusion;
        proposal.basefeeSharingPctg = basefeeSharingPctg;
        proposal.blobSlice.blobHashes = new bytes32[](numBlobHashes);
        for (uint256 i; i < numBlobHashes; ++i) {
            proposal.blobSlice.blobHashes[i] = keccak256(abi.encode(i));
        }
        proposal.blobSlice.offset = offset;
        proposal.blobSlice.timestamp = timestamp;
        proposal.coreStateHash = coreStateHash;

        // Create core state
        IInbox.CoreState memory coreState;
        coreState.nextProposalId = nextProposalId;
        coreState.lastFinalizedProposalId = lastFinalizedProposalId;
        coreState.lastFinalizedClaimHash = lastFinalizedClaimHash;
        coreState.bondInstructionsHash = bondInstructionsHash;

        // Encode and decode
        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        // Verify all fields match
        assertEq(decodedProposal.id, proposal.id);
        assertEq(decodedProposal.proposer, proposal.proposer);
        assertEq(decodedProposal.originTimestamp, proposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, proposal.originBlockNumber);
        assertEq(decodedProposal.isForcedInclusion, proposal.isForcedInclusion);
        assertEq(decodedProposal.basefeeSharingPctg, proposal.basefeeSharingPctg);
        assertEq(decodedProposal.blobSlice.blobHashes.length, proposal.blobSlice.blobHashes.length);
        for (uint256 i; i < proposal.blobSlice.blobHashes.length; ++i) {
            assertEq(decodedProposal.blobSlice.blobHashes[i], proposal.blobSlice.blobHashes[i]);
        }
        assertEq(decodedProposal.blobSlice.offset, proposal.blobSlice.offset);
        assertEq(decodedProposal.blobSlice.timestamp, proposal.blobSlice.timestamp);
        assertEq(decodedProposal.coreStateHash, proposal.coreStateHash);

        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId);
        assertEq(decodedCoreState.lastFinalizedProposalId, coreState.lastFinalizedProposalId);
        assertEq(decodedCoreState.lastFinalizedClaimHash, coreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, coreState.bondInstructionsHash);
    }

    function testFuzz_EncodeDecodeProveEventData(
        uint48 proposalId,
        bytes32 proposalHash,
        bytes32 parentClaimHash,
        uint48 endBlockNumber,
        bytes32 endBlockHash,
        bytes32 endStateRoot,
        address designatedProver,
        address actualProver,
        uint8 span,
        uint8 numInstructions
    )
        public
        view
    {
        // Limit instructions to reasonable number for testing
        numInstructions = uint8(bound(numInstructions, 0, 10));

        // Create claim record
        IInbox.ClaimRecord memory claimRecord;
        claimRecord.claim.proposalId = proposalId;
        claimRecord.claim.proposalHash = proposalHash;
        claimRecord.claim.parentClaimHash = parentClaimHash;
        claimRecord.claim.endBlockNumber = endBlockNumber;
        claimRecord.claim.endBlockHash = endBlockHash;
        claimRecord.claim.endStateRoot = endStateRoot;
        claimRecord.claim.designatedProver = designatedProver;
        claimRecord.claim.actualProver = actualProver;
        claimRecord.span = span;

        // Create bond instructions
        claimRecord.bondInstructions = new LibBonds.BondInstruction[](numInstructions);
        for (uint256 i; i < numInstructions; ++i) {
            claimRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType(uint8(i % 3)),
                payer: address(uint160(uint256(keccak256(abi.encode("payer", i))))),
                receiver: address(uint160(uint256(keccak256(abi.encode("receiver", i)))))
            });
        }

        // Encode and decode
        bytes memory encoded = LibCodec.encodeProveEventData(claimRecord);
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        // Verify all fields match
        assertEq(decodedClaimRecord.claim.proposalId, claimRecord.claim.proposalId);
        assertEq(decodedClaimRecord.claim.proposalHash, claimRecord.claim.proposalHash);
        assertEq(decodedClaimRecord.claim.parentClaimHash, claimRecord.claim.parentClaimHash);
        assertEq(decodedClaimRecord.claim.endBlockNumber, claimRecord.claim.endBlockNumber);
        assertEq(decodedClaimRecord.claim.endBlockHash, claimRecord.claim.endBlockHash);
        assertEq(decodedClaimRecord.claim.endStateRoot, claimRecord.claim.endStateRoot);
        assertEq(decodedClaimRecord.claim.designatedProver, claimRecord.claim.designatedProver);
        assertEq(decodedClaimRecord.claim.actualProver, claimRecord.claim.actualProver);
        assertEq(decodedClaimRecord.span, claimRecord.span);

        assertEq(decodedClaimRecord.bondInstructions.length, claimRecord.bondInstructions.length);
        for (uint256 i; i < claimRecord.bondInstructions.length; ++i) {
            assertEq(
                decodedClaimRecord.bondInstructions[i].proposalId,
                claimRecord.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decodedClaimRecord.bondInstructions[i].bondType),
                uint8(claimRecord.bondInstructions[i].bondType)
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].payer, claimRecord.bondInstructions[i].payer
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].receiver,
                claimRecord.bondInstructions[i].receiver
            );
        }
    }
}
