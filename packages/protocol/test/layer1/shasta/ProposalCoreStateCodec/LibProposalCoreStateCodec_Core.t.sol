// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibProposalCoreStateCodec } from "src/layer1/shasta/libs/LibProposalCoreStateCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title LibProposalCoreStateCodec_Core
/// @notice Core functionality tests for LibProposalCoreStateCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibProposalCoreStateCodec_Core is CommonTest {
    IInbox.Proposal private proposal;
    IInbox.CoreState private coreState;

    function setUp() public override {
        super.setUp();

        // Setup test data
        bytes32[] memory blobHashes = new bytes32[](3);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");
        blobHashes[2] = keccak256("blob3");

        proposal = IInbox.Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1_234_567_890,
            originBlockNumber: 999_999,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 1024,
                timestamp: 1_234_567_891
            }),
            coreStateHash: keccak256("coreState")
        });

        coreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastClaim"),
            bondInstructionsHash: keccak256("bondInstructions")
        });
    }

    /// @notice Test basic encoding and decoding roundtrip
    function test_basicRoundtrip() public view {
        bytes memory encoded = LibProposalCoreStateCodec.encode(proposal, coreState);
        (IInbox.Proposal memory decoded, IInbox.CoreState memory decodedCore) =
            LibProposalCoreStateCodec.decode(encoded);

        _verifyProposal(proposal, decoded);
        _verifyCoreState(coreState, decodedCore);
    }

    /// @notice Test with minimum values
    function test_minimumValues() public pure {
        bytes32[] memory emptyHashes = new bytes32[](1);

        IInbox.Proposal memory minProposal = IInbox.Proposal({
            id: 0,
            proposer: address(0),
            originTimestamp: 0,
            originBlockNumber: 0,
            isForcedInclusion: false,
            basefeeSharingPctg: 0,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: emptyHashes, offset: 0, timestamp: 0 }),
            coreStateHash: bytes32(0)
        });

        IInbox.CoreState memory minCoreState = IInbox.CoreState({
            nextProposalId: 0,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        bytes memory encoded = LibProposalCoreStateCodec.encode(minProposal, minCoreState);
        (IInbox.Proposal memory decoded, IInbox.CoreState memory decodedCore) =
            LibProposalCoreStateCodec.decode(encoded);

        _verifyProposal(minProposal, decoded);
        _verifyCoreState(minCoreState, decodedCore);
    }

    /// @notice Test with maximum values
    function test_maximumValues() public pure {
        bytes32[] memory maxHashes = new bytes32[](64);
        for (uint256 i = 0; i < 64; i++) {
            maxHashes[i] = bytes32(type(uint256).max - i);
        }

        IInbox.Proposal memory maxProposal = IInbox.Proposal({
            id: type(uint48).max,
            proposer: address(type(uint160).max),
            originTimestamp: type(uint48).max,
            originBlockNumber: type(uint48).max,
            isForcedInclusion: true,
            basefeeSharingPctg: 100,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: maxHashes,
                offset: type(uint24).max,
                timestamp: type(uint48).max
            }),
            coreStateHash: bytes32(type(uint256).max)
        });

        IInbox.CoreState memory maxCoreState = IInbox.CoreState({
            nextProposalId: type(uint48).max,
            lastFinalizedProposalId: type(uint48).max,
            lastFinalizedClaimHash: bytes32(type(uint256).max),
            bondInstructionsHash: bytes32(type(uint256).max)
        });

        bytes memory encoded = LibProposalCoreStateCodec.encode(maxProposal, maxCoreState);
        (IInbox.Proposal memory decoded, IInbox.CoreState memory decodedCore) =
            LibProposalCoreStateCodec.decode(encoded);

        _verifyProposal(maxProposal, decoded);
        _verifyCoreState(maxCoreState, decodedCore);
    }

    /// @notice Test validation for basefeeSharingPctg
    function test_validateBasefeeSharingPctg() public {
        IInbox.Proposal memory testProposal = proposal;

        // Test valid max value (100)
        testProposal.basefeeSharingPctg = 100;
        bytes memory data = LibProposalCoreStateCodec.encode(testProposal, coreState);
        assertTrue(data.length > 0);

        // Test invalid value > 100 should revert
        testProposal.basefeeSharingPctg = 101;
        vm.expectRevert(LibProposalCoreStateCodec.BASEFEE_SHARING_PCTG_EXCEEDS_MAX.selector);
        this.encodeWrapper(testProposal, coreState);
    }

    /// @notice Test validation for blobHashes array length
    function test_validateArrayLength() public {
        IInbox.Proposal memory testProposal = proposal;

        // Test valid max length (64)
        bytes32[] memory validHashes = new bytes32[](64);
        for (uint256 i = 0; i < 64; i++) {
            validHashes[i] = keccak256(abi.encode(i));
        }
        testProposal.blobSlice.blobHashes = validHashes;
        bytes memory data = LibProposalCoreStateCodec.encode(testProposal, coreState);
        assertTrue(data.length > 0);

        // Test invalid length > 64 should revert
        bytes32[] memory invalidHashes = new bytes32[](65);
        for (uint256 i = 0; i < 65; i++) {
            invalidHashes[i] = keccak256(abi.encode(i));
        }
        testProposal.blobSlice.blobHashes = invalidHashes;
        vm.expectRevert(LibProposalCoreStateCodec.BLOB_HASHES_ARRAY_EXCEEDS_MAX.selector);
        this.encodeWrapper(testProposal, coreState);
    }

    /// @notice Test data integrity across multiple encode/decode cycles
    function test_dataIntegrity() public view {
        bytes memory encoded1 = LibProposalCoreStateCodec.encode(proposal, coreState);
        (IInbox.Proposal memory decoded1, IInbox.CoreState memory decodedCore1) =
            LibProposalCoreStateCodec.decode(encoded1);

        bytes memory encoded2 = LibProposalCoreStateCodec.encode(decoded1, decodedCore1);
        (IInbox.Proposal memory decoded2, IInbox.CoreState memory decodedCore2) =
            LibProposalCoreStateCodec.decode(encoded2);

        // Verify data remains consistent
        assertEq(encoded1.length, encoded2.length);
        assertEq(keccak256(encoded1), keccak256(encoded2));
        _verifyProposal(decoded1, decoded2);
        _verifyCoreState(decodedCore1, decodedCore2);
    }

    // Helper function for testing reverts (creates new call depth)
    function encodeWrapper(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        external
        pure
        returns (bytes memory)
    {
        return LibProposalCoreStateCodec.encode(_proposal, _coreState);
    }

    // Helper functions
    function _verifyProposal(
        IInbox.Proposal memory _expected,
        IInbox.Proposal memory _actual
    )
        private
        pure
    {
        assertEq(_expected.id, _actual.id);
        assertEq(_expected.proposer, _actual.proposer);
        assertEq(_expected.originTimestamp, _actual.originTimestamp);
        assertEq(_expected.originBlockNumber, _actual.originBlockNumber);
        assertEq(_expected.isForcedInclusion, _actual.isForcedInclusion);
        assertEq(_expected.basefeeSharingPctg, _actual.basefeeSharingPctg);
        assertEq(_expected.coreStateHash, _actual.coreStateHash);
        assertEq(_expected.blobSlice.offset, _actual.blobSlice.offset);
        assertEq(_expected.blobSlice.timestamp, _actual.blobSlice.timestamp);
        assertEq(_expected.blobSlice.blobHashes.length, _actual.blobSlice.blobHashes.length);

        for (uint256 i = 0; i < _expected.blobSlice.blobHashes.length; i++) {
            assertEq(_expected.blobSlice.blobHashes[i], _actual.blobSlice.blobHashes[i]);
        }
    }

    function _verifyCoreState(
        IInbox.CoreState memory _expected,
        IInbox.CoreState memory _actual
    )
        private
        pure
    {
        assertEq(_expected.nextProposalId, _actual.nextProposalId);
        assertEq(_expected.lastFinalizedProposalId, _actual.lastFinalizedProposalId);
        assertEq(_expected.lastFinalizedClaimHash, _actual.lastFinalizedClaimHash);
        assertEq(_expected.bondInstructionsHash, _actual.bondInstructionsHash);
    }
}
