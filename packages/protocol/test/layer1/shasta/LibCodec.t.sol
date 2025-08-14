// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibCodec } from "src/layer1/shasta/libs/LibCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title LibCodec Test
/// @notice Comprehensive tests for LibCodec encoding/decoding functionality
/// @custom:security-contact security@taiko.xyz
contract LibCodecTest is CommonTest {
    // ---------------------------------------------------------------
    // Round-trip tests
    // ---------------------------------------------------------------

    function test_encodeDecodeProposedEventData_roundTrip() public pure {
        // Create test data
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");

        IInbox.Proposal memory originalProposal = IInbox.Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1_234_567_890,
            originBlockNumber: 9_876_543,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 123,
                timestamp: 1_234_567_890
            }),
            coreStateHash: keccak256("coreStateHash")
        });

        IInbox.CoreState memory originalCoreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastFinalizedClaimHash"),
            bondInstructionsHash: keccak256("bondInstructionsHash")
        });

        // Encode then decode
        bytes memory encoded = LibCodec.encodeProposedEventData(originalProposal, originalCoreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        // Verify proposal fields
        assertEq(decodedProposal.id, originalProposal.id, "Proposal ID mismatch");
        assertEq(decodedProposal.proposer, originalProposal.proposer, "Proposer mismatch");
        assertEq(
            decodedProposal.originTimestamp,
            originalProposal.originTimestamp,
            "Origin timestamp mismatch"
        );
        assertEq(
            decodedProposal.originBlockNumber,
            originalProposal.originBlockNumber,
            "Origin block number mismatch"
        );
        assertEq(
            decodedProposal.isForcedInclusion,
            originalProposal.isForcedInclusion,
            "Forced inclusion mismatch"
        );
        assertEq(
            decodedProposal.basefeeSharingPctg,
            originalProposal.basefeeSharingPctg,
            "Basefee sharing percentage mismatch"
        );
        assertEq(
            decodedProposal.coreStateHash,
            originalProposal.coreStateHash,
            "Core state hash mismatch"
        );

        // Verify blob slice
        assertEq(
            decodedProposal.blobSlice.blobHashes.length,
            originalProposal.blobSlice.blobHashes.length,
            "Blob hashes length mismatch"
        );
        for (uint256 i = 0; i < originalProposal.blobSlice.blobHashes.length; i++) {
            assertEq(
                decodedProposal.blobSlice.blobHashes[i],
                originalProposal.blobSlice.blobHashes[i],
                "Blob hash mismatch"
            );
        }
        assertEq(
            decodedProposal.blobSlice.offset,
            originalProposal.blobSlice.offset,
            "Blob slice offset mismatch"
        );
        assertEq(
            decodedProposal.blobSlice.timestamp,
            originalProposal.blobSlice.timestamp,
            "Blob slice timestamp mismatch"
        );

        // Verify core state
        assertEq(
            decodedCoreState.nextProposalId,
            originalCoreState.nextProposalId,
            "Next proposal ID mismatch"
        );
        assertEq(
            decodedCoreState.lastFinalizedProposalId,
            originalCoreState.lastFinalizedProposalId,
            "Last finalized proposal ID mismatch"
        );
        assertEq(
            decodedCoreState.lastFinalizedClaimHash,
            originalCoreState.lastFinalizedClaimHash,
            "Last finalized claim hash mismatch"
        );
        assertEq(
            decodedCoreState.bondInstructionsHash,
            originalCoreState.bondInstructionsHash,
            "Bond instructions hash mismatch"
        );
    }

    function test_encodeDecodeProveEventData_roundTrip() public pure {
        // Create bond instructions
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 12_345,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x2222222222222222222222222222222222222222),
            receiver: address(0x3333333333333333333333333333333333333333)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 12_346,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x4444444444444444444444444444444444444444),
            receiver: address(0x5555555555555555555555555555555555555555)
        });

        IInbox.ClaimRecord memory originalClaimRecord = IInbox.ClaimRecord({
            proposalId: 12_345,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposalHash"),
                parentClaimHash: keccak256("parentClaimHash"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlockHash"),
                endStateRoot: keccak256("endStateRoot"),
                designatedProver: address(0x5555555555555555555555555555555555555555),
                actualProver: address(0x6666666666666666666666666666666666666666)
            }),
            span: 5,
            bondInstructions: bondInstructions
        });

        // Encode then decode
        bytes memory encoded = LibCodec.encodeProveEventData(originalClaimRecord);
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        // Verify claim record fields
        assertEq(
            decodedClaimRecord.proposalId,
            originalClaimRecord.proposalId,
            "Claim record proposal ID mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.proposalHash,
            originalClaimRecord.claim.proposalHash,
            "Proposal hash mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.parentClaimHash,
            originalClaimRecord.claim.parentClaimHash,
            "Parent claim hash mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.endBlockNumber,
            originalClaimRecord.claim.endBlockNumber,
            "End block number mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.endBlockHash,
            originalClaimRecord.claim.endBlockHash,
            "End block hash mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.endStateRoot,
            originalClaimRecord.claim.endStateRoot,
            "End state root mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.designatedProver,
            originalClaimRecord.claim.designatedProver,
            "Designated prover mismatch"
        );
        assertEq(
            decodedClaimRecord.claim.actualProver,
            originalClaimRecord.claim.actualProver,
            "Actual prover mismatch"
        );

        // Verify span
        assertEq(decodedClaimRecord.span, originalClaimRecord.span, "Span mismatch");

        // Verify bond instructions
        assertEq(
            decodedClaimRecord.bondInstructions.length,
            originalClaimRecord.bondInstructions.length,
            "Bond instructions length mismatch"
        );
        for (uint256 i = 0; i < originalClaimRecord.bondInstructions.length; i++) {
            assertEq(
                uint256(decodedClaimRecord.bondInstructions[i].proposalId),
                uint256(originalClaimRecord.bondInstructions[i].proposalId),
                "Bond instruction proposal ID mismatch"
            );
            assertEq(
                uint256(decodedClaimRecord.bondInstructions[i].bondType),
                uint256(originalClaimRecord.bondInstructions[i].bondType),
                "Bond instruction type mismatch"
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].payer,
                originalClaimRecord.bondInstructions[i].payer,
                "Bond instruction payer mismatch"
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].receiver,
                originalClaimRecord.bondInstructions[i].receiver,
                "Bond instruction receiver mismatch"
            );
        }
    }

    // ---------------------------------------------------------------
    // Edge cases tests
    // ---------------------------------------------------------------

    function test_encodeDecodeProposedEventData_emptyBlobHashes() public pure {
        bytes32[] memory emptyBlobHashes = new bytes32[](0);

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 1,
            proposer: address(0x1),
            originTimestamp: 1,
            originBlockNumber: 1,
            isForcedInclusion: false,
            basefeeSharingPctg: 0,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: emptyBlobHashes, offset: 0, timestamp: 1 }),
            coreStateHash: bytes32(0)
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);
        (IInbox.Proposal memory decodedProposal,) = LibCodec.decodeProposedEventData(encoded);

        assertEq(
            decodedProposal.blobSlice.blobHashes.length, 0, "Empty blob hashes should remain empty"
        );
        assertEq(decodedProposal.id, proposal.id, "Proposal ID should match with empty blob hashes");
    }

    function test_encodeDecodeProposedEventData_maxValues() public pure {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(type(uint256).max);

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: type(uint48).max,
            proposer: address(type(uint160).max),
            originTimestamp: type(uint48).max,
            originBlockNumber: type(uint48).max,
            isForcedInclusion: true,
            basefeeSharingPctg: type(uint8).max,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: type(uint24).max,
                timestamp: type(uint48).max
            }),
            coreStateHash: bytes32(type(uint256).max)
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: type(uint48).max,
            lastFinalizedProposalId: type(uint48).max,
            lastFinalizedClaimHash: bytes32(type(uint256).max),
            bondInstructionsHash: bytes32(type(uint256).max)
        });

        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        assertEq(decodedProposal.id, type(uint48).max, "Max proposal ID should be preserved");
        assertEq(
            decodedProposal.proposer,
            address(type(uint160).max),
            "Max proposer address should be preserved"
        );
        assertEq(
            decodedProposal.basefeeSharingPctg,
            type(uint8).max,
            "Max basefee sharing percentage should be preserved"
        );
        assertEq(
            decodedCoreState.nextProposalId,
            type(uint48).max,
            "Max next proposal ID should be preserved"
        );
    }

    function test_encodeDecodeProveEventData_noBondInstructions() public pure {
        LibBonds.BondInstruction[] memory emptyBonds = new LibBonds.BondInstruction[](0);

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 1,
            claim: IInbox.Claim({
                proposalHash: keccak256("test"),
                parentClaimHash: keccak256("parent"),
                endBlockNumber: 100,
                endBlockHash: keccak256("endBlock"),
                endStateRoot: keccak256("endState"),
                designatedProver: address(0x1),
                actualProver: address(0x2)
            }),
            span: 1,
            bondInstructions: emptyBonds
        });

        bytes memory encoded = LibCodec.encodeProveEventData(claimRecord);
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        assertEq(
            decodedClaimRecord.bondInstructions.length,
            0,
            "Empty bond instructions should remain empty"
        );
        assertEq(
            decodedClaimRecord.span, 1, "Span should be preserved with empty bond instructions"
        );
    }

    function test_encodeDecodeProveEventData_manyBondInstructions() public pure {
        // Test with 10 bond instructions
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](10);
        for (uint256 i = 0; i < 10; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i + 1000),
                bondType: LibBonds.BondType(i % 2), // Alternate between PROVABILITY and LIVENESS
                payer: address(uint160(0x1000 + i)),
                receiver: address(uint160(0x2000 + i))
            });
        }

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 999,
            claim: IInbox.Claim({
                proposalHash: keccak256("largeClaim"),
                parentClaimHash: keccak256("largeParent"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("largeEndBlock"),
                endStateRoot: keccak256("largeEndState"),
                designatedProver: address(0x9999),
                actualProver: address(0x8888)
            }),
            span: 255,
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibCodec.encodeProveEventData(claimRecord);
        IInbox.ClaimRecord memory decodedClaimRecord = LibCodec.decodeProveEventData(encoded);

        assertEq(
            decodedClaimRecord.bondInstructions.length,
            10,
            "Should preserve all 10 bond instructions"
        );
        for (uint256 i = 0; i < 10; i++) {
            assertEq(
                uint256(decodedClaimRecord.bondInstructions[i].proposalId),
                uint256(bondInstructions[i].proposalId),
                "Bond instruction proposal ID should match"
            );
            assertEq(
                uint256(decodedClaimRecord.bondInstructions[i].bondType),
                uint256(bondInstructions[i].bondType),
                "Bond instruction type should match"
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].payer,
                bondInstructions[i].payer,
                "Bond instruction payer should match"
            );
            assertEq(
                decodedClaimRecord.bondInstructions[i].receiver,
                bondInstructions[i].receiver,
                "Bond instruction receiver should match"
            );
        }
    }

    // ---------------------------------------------------------------
    // Memory safety tests
    // ---------------------------------------------------------------

    function test_memoryOverreadBug() public pure {
        // This test verifies the memory safety fix in LibCodec.encodeProposedEventData
        // Previously buggy: return(result, add(0x20, totalSize)) returned 32 extra bytes
        // Now fixed: return(add(result, 0x20), totalSize) returns correct size

        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256("test");

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1_234_567_890,
            originBlockNumber: 9_876_543,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 123,
                timestamp: 1_234_567_890
            }),
            coreStateHash: keccak256("coreStateHash")
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastFinalizedClaimHash"),
            bondInstructionsHash: keccak256("bondInstructionsHash")
        });

        // Test that the fix returns the correct size without extra bytes
        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);

        // Calculate expected size: 183 + (1 * 32) = 215 bytes
        uint256 expectedSize = 183 + 32;

        // After the fix, we should get exactly the expected size, not 32 extra bytes
        assertEq(
            encoded.length,
            expectedSize,
            "Memory safety fix: returning correct size without extra bytes"
        );

        // Verify the encoded data can still be decoded properly
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        assertEq(decodedProposal.id, proposal.id, "Decoded proposal ID should match");
        assertEq(
            decodedCoreState.nextProposalId,
            coreState.nextProposalId,
            "Decoded core state should match"
        );
    }

    // ---------------------------------------------------------------
    // Error cases tests
    // ---------------------------------------------------------------

    function test_decodeProposedEventData_tooMuchData() public pure {
        // Create data that's too long with extra bytes to test robustness
        bytes memory validData = new bytes(200);

        // Set up valid structure - zero blob hashes length at offset 40
        validData[40] = 0x00; // blobHashesLen high byte
        validData[41] = 0x00; // blobHashesLen low byte

        // This should work despite extra bytes
        LibCodec.decodeProposedEventData(validData);
    }

    function test_decodeProveEventData_tooMuchData() public pure {
        // Create data that's too long with extra bytes to test robustness
        bytes memory validData = new bytes(200);

        // Set up valid structure - zero bond instructions length at offset 181
        validData[181] = 0x00; // bondInstructionsLen high byte
        validData[182] = 0x00; // bondInstructionsLen low byte

        // This should work despite extra bytes
        LibCodec.decodeProveEventData(validData);
    }

    function test_decodeProposedEventData_minimumLength() public pure {
        // Create valid data with minimum length (183 bytes) - updated for uint24 array length
        // encoding
        bytes memory minData = new bytes(183);

        // Set up valid structure - zero blob hashes length at offset 40 (3 bytes for uint24)
        minData[40] = 0x00; // blobHashesLen high byte
        minData[41] = 0x00; // blobHashesLen mid byte
        minData[42] = 0x00; // blobHashesLen low byte

        // This should not revert
        LibCodec.decodeProposedEventData(minData);
    }

    function test_decodeProveEventData_minimumLength() public pure {
        // Create valid data with minimum length (184 bytes) - updated for uint24 array length
        // encoding
        bytes memory minData = new bytes(184);

        // Set up valid structure - zero bond instructions length at offset 181 (3 bytes for uint24)
        minData[181] = 0x00; // bondInstructionsLen high byte
        minData[182] = 0x00; // bondInstructionsLen mid byte
        minData[183] = 0x00; // bondInstructionsLen low byte

        // This should not revert
        LibCodec.decodeProveEventData(minData);
    }

    // ---------------------------------------------------------------
    // Gas comparison tests
    // ---------------------------------------------------------------

    function test_gasComparison_proposedEventData() public {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1_234_567_890,
            originBlockNumber: 9_876_543,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 123,
                timestamp: 1_234_567_890
            }),
            coreStateHash: keccak256("coreStateHash")
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastFinalizedClaimHash"),
            bondInstructionsHash: keccak256("bondInstructionsHash")
        });

        // Test LibCodec encoding
        uint256 gasBeforeLibCodec = gasleft();
        bytes memory libCodecEncoded = LibCodec.encodeProposedEventData(proposal, coreState);
        uint256 libCodecEncodeGas = gasBeforeLibCodec - gasleft();

        // Test abi.encode
        uint256 gasBeforeAbi = gasleft();
        bytes memory abiEncoded = abi.encode(proposal, coreState);
        uint256 abiEncodeGas = gasBeforeAbi - gasleft();

        // Test LibCodec decoding
        uint256 gasBeforeLibCodecDecode = gasleft();
        LibCodec.decodeProposedEventData(libCodecEncoded);
        uint256 libCodecDecodeGas = gasBeforeLibCodecDecode - gasleft();

        // Test abi.decode
        uint256 gasBeforeAbiDecode = gasleft();
        abi.decode(abiEncoded, (IInbox.Proposal, IInbox.CoreState));
        uint256 abiDecodeGas = gasBeforeAbiDecode - gasleft();

        // LibCodec should be more gas efficient for encoding (but not necessarily decoding)
        assertLt(
            libCodecEncoded.length,
            abiEncoded.length,
            "LibCodec should produce smaller encoded data"
        );

        // Log gas usage for analysis
        emit log_named_uint("LibCodec encode gas", libCodecEncodeGas);
        emit log_named_uint("abi.encode gas", abiEncodeGas);
        emit log_named_uint("LibCodec decode gas", libCodecDecodeGas);
        emit log_named_uint("abi.decode gas", abiDecodeGas);
        emit log_named_uint("LibCodec encoded size", libCodecEncoded.length);
        emit log_named_uint("abi.encode size", abiEncoded.length);
    }

    function test_gasComparison_proveEventData() public {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](3);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 12_345,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x2222222222222222222222222222222222222222),
            receiver: address(0x3333333333333333333333333333333333333333)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 12_346,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x4444444444444444444444444444444444444444),
            receiver: address(0x5555555555555555555555555555555555555555)
        });
        bondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 12_347,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x6666666666666666666666666666666666666666),
            receiver: address(0x7777777777777777777777777777777777777777)
        });

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 12_345,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposalHash"),
                parentClaimHash: keccak256("parentClaimHash"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlockHash"),
                endStateRoot: keccak256("endStateRoot"),
                designatedProver: address(0x5555555555555555555555555555555555555555),
                actualProver: address(0x6666666666666666666666666666666666666666)
            }),
            span: 5,
            bondInstructions: bondInstructions
        });

        // Test LibCodec encoding
        uint256 gasBeforeLibCodec = gasleft();
        bytes memory libCodecEncoded = LibCodec.encodeProveEventData(claimRecord);
        uint256 libCodecEncodeGas = gasBeforeLibCodec - gasleft();

        // Test abi.encode
        uint256 gasBeforeAbi = gasleft();
        bytes memory abiEncoded = abi.encode(claimRecord);
        uint256 abiEncodeGas = gasBeforeAbi - gasleft();

        // Test LibCodec decoding
        uint256 gasBeforeLibCodecDecode = gasleft();
        LibCodec.decodeProveEventData(libCodecEncoded);
        uint256 libCodecDecodeGas = gasBeforeLibCodecDecode - gasleft();

        // Test abi.decode
        uint256 gasBeforeAbiDecode = gasleft();
        abi.decode(abiEncoded, (IInbox.ClaimRecord));
        uint256 abiDecodeGas = gasBeforeAbiDecode - gasleft();

        // LibCodec should produce smaller data
        assertLt(
            libCodecEncoded.length,
            abiEncoded.length,
            "LibCodec should produce smaller encoded data"
        );

        // Log gas usage for analysis
        emit log_named_uint("LibCodec encode gas", libCodecEncodeGas);
        emit log_named_uint("abi.encode gas", abiEncodeGas);
        emit log_named_uint("LibCodec decode gas", libCodecDecodeGas);
        emit log_named_uint("abi.decode gas", abiDecodeGas);
        emit log_named_uint("LibCodec encoded size", libCodecEncoded.length);
        emit log_named_uint("abi.encode size", abiEncoded.length);
    }

    // ---------------------------------------------------------------
    // Fuzzing tests
    // ---------------------------------------------------------------

    function testFuzz_encodeDecodeProposedEventData(
        uint48 _proposalId,
        address _proposer,
        uint48 _originTimestamp,
        uint48 _originBlockNumber
    )
        public
        pure
    {
        // Create minimal test data to avoid stack too deep
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode(_proposalId));

        IInbox.Proposal memory proposal;
        proposal.id = _proposalId;
        proposal.proposer = _proposer;
        proposal.originTimestamp = _originTimestamp;
        proposal.originBlockNumber = _originBlockNumber;
        proposal.isForcedInclusion = true;
        proposal.basefeeSharingPctg = 50;
        proposal.blobSlice.blobHashes = blobHashes;
        proposal.blobSlice.offset = 100;
        proposal.blobSlice.timestamp = _originTimestamp;
        proposal.coreStateHash = keccak256("test");

        IInbox.CoreState memory coreState;
        // Avoid overflow by capping the addition
        coreState.nextProposalId =
            _proposalId < type(uint48).max ? _proposalId + 1 : type(uint48).max;
        coreState.lastFinalizedProposalId = _proposalId > 0 ? _proposalId - 1 : 0;
        coreState.lastFinalizedClaimHash = keccak256("claim");
        coreState.bondInstructionsHash = keccak256("bond");

        // Round-trip test
        bytes memory encoded = LibCodec.encodeProposedEventData(proposal, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibCodec.decodeProposedEventData(encoded);

        // Verify key fields match
        assertEq(decodedProposal.id, proposal.id);
        assertEq(decodedProposal.proposer, proposal.proposer);
        assertEq(decodedProposal.originTimestamp, proposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, proposal.originBlockNumber);
        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId);
        assertEq(decodedCoreState.lastFinalizedProposalId, coreState.lastFinalizedProposalId);
    }
}
