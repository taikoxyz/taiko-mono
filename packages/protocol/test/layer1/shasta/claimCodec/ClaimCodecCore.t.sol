// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibClaimRecordCodec } from "src/layer1/shasta/libs/LibClaimRecordCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title ClaimCodecCore
/// @notice Core functionality tests for LibClaimRecordCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract ClaimCodecCore is CommonTest {
    function setUp() public override {
        super.setUp();
    }

    function _getTestClaimRecord() private pure returns (IInbox.ClaimRecord memory) {
        // Create bond instructions
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 12_345,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111111111111111111111111111111111111111),
            receiver: address(0x2222222222222222222222222222222222222222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 12_346,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333333333333333333333333333333333333333),
            receiver: address(0x4444444444444444444444444444444444444444)
        });

        // Setup test data
        return IInbox.ClaimRecord({
            proposalId: 12_345,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposal"),
                parentClaimHash: keccak256("parent"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlock"),
                endStateRoot: keccak256("stateRoot"),
                designatedProver: address(0x5555555555555555555555555555555555555555),
                actualProver: address(0x6666666666666666666666666666666666666666)
            }),
            span: 10,
            bondInstructions: bondInstructions
        });
    }

    /// @notice Test basic encoding and decoding roundtrip
    function test_basicRoundtrip() public pure {
        IInbox.ClaimRecord memory claimRecord = _getTestClaimRecord();
        bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        _verifyClaimRecord(claimRecord, decoded);
    }

    /// @notice Test with empty bond instructions
    function test_emptyBondInstructions() public pure {
        IInbox.ClaimRecord memory claimRecord = _getTestClaimRecord();
        claimRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        _verifyClaimRecord(claimRecord, decoded);
        assertEq(decoded.bondInstructions.length, 0, "Bond instructions should be empty");
    }

    /// @notice Test with single bond instruction
    function test_singleBondInstruction() public pure {
        IInbox.ClaimRecord memory claimRecord = _getTestClaimRecord();
        LibBonds.BondInstruction[] memory singleInstruction = new LibBonds.BondInstruction[](1);
        singleInstruction[0] = LibBonds.BondInstruction({
            proposalId: 99_999,
            bondType: LibBonds.BondType.NONE,
            payer: address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa),
            receiver: address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB)
        });
        claimRecord.bondInstructions = singleInstruction;

        bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        _verifyClaimRecord(claimRecord, decoded);
    }

    /// @notice Test with different span values
    function test_differentSpanValues() public pure {
        IInbox.ClaimRecord memory claimRecord = _getTestClaimRecord();
        uint8[5] memory spans = [1, 5, 10, 50, 255];

        for (uint256 i = 0; i < spans.length; i++) {
            claimRecord.span = spans[i];

            bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
            IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

            _verifyClaimRecord(claimRecord, decoded);
            assertEq(decoded.span, spans[i], "Span value mismatch");
        }
    }

    /// @notice Test with maximum values
    function test_maximumValues() public pure {
        IInbox.ClaimRecord memory claimRecord = _getTestClaimRecord();
        claimRecord.proposalId = type(uint48).max;
        claimRecord.claim.endBlockNumber = type(uint48).max;
        claimRecord.span = type(uint8).max;

        // Update bond instructions with max proposalId
        for (uint256 i = 0; i < claimRecord.bondInstructions.length; i++) {
            claimRecord.bondInstructions[i].proposalId = type(uint48).max;
        }

        bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        _verifyClaimRecord(claimRecord, decoded);
    }

    /// @notice Test with zero addresses
    function test_zeroAddresses() public pure {
        IInbox.ClaimRecord memory claimRecord = _getTestClaimRecord();
        claimRecord.claim.designatedProver = address(0);
        claimRecord.claim.actualProver = address(0);

        for (uint256 i = 0; i < claimRecord.bondInstructions.length; i++) {
            claimRecord.bondInstructions[i].payer = address(0);
            claimRecord.bondInstructions[i].receiver = address(0);
        }

        bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        _verifyClaimRecord(claimRecord, decoded);
    }

    // Helper functions
    function _verifyClaimRecord(
        IInbox.ClaimRecord memory _expected,
        IInbox.ClaimRecord memory _actual
    )
        private
        pure
    {
        assertEq(_expected.proposalId, _actual.proposalId, "proposalId mismatch");
        assertEq(_expected.span, _actual.span, "span mismatch");

        // Verify claim fields
        assertEq(_expected.claim.proposalHash, _actual.claim.proposalHash, "proposalHash mismatch");
        assertEq(
            _expected.claim.parentClaimHash,
            _actual.claim.parentClaimHash,
            "parentClaimHash mismatch"
        );
        assertEq(
            _expected.claim.endBlockNumber, _actual.claim.endBlockNumber, "endBlockNumber mismatch"
        );
        assertEq(_expected.claim.endBlockHash, _actual.claim.endBlockHash, "endBlockHash mismatch");
        assertEq(_expected.claim.endStateRoot, _actual.claim.endStateRoot, "endStateRoot mismatch");
        assertEq(
            _expected.claim.designatedProver,
            _actual.claim.designatedProver,
            "designatedProver mismatch"
        );
        assertEq(_expected.claim.actualProver, _actual.claim.actualProver, "actualProver mismatch");

        // Verify bond instructions
        assertEq(
            _expected.bondInstructions.length,
            _actual.bondInstructions.length,
            "bondInstructions length mismatch"
        );
        for (uint256 i = 0; i < _expected.bondInstructions.length; i++) {
            assertEq(
                _expected.bondInstructions[i].proposalId,
                _actual.bondInstructions[i].proposalId,
                "bond proposalId mismatch"
            );
            assertEq(
                uint8(_expected.bondInstructions[i].bondType),
                uint8(_actual.bondInstructions[i].bondType),
                "bond type mismatch"
            );
            assertEq(
                _expected.bondInstructions[i].payer,
                _actual.bondInstructions[i].payer,
                "bond payer mismatch"
            );
            assertEq(
                _expected.bondInstructions[i].receiver,
                _actual.bondInstructions[i].receiver,
                "bond receiver mismatch"
            );
        }
    }
}
