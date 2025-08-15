// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibClaimRecordCodec } from "src/layer1/shasta/libs/LibClaimRecordCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title LibClaimRecordCodec_Core
/// @notice Core functionality tests for LibClaimRecordCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibClaimRecordCodec_Core is CommonTest {
    function test_basicRoundtrip() public view {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](3);
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
        bondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 12_347,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x5555555555555555555555555555555555555555),
            receiver: address(0x6666666666666666666666666666666666666666)
        });

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 12_345,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposal"),
                parentClaimHash: keccak256("parentClaim"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlock"),
                endStateRoot: keccak256("endState"),
                designatedProver: address(0x7777777777777777777777777777777777777777),
                actualProver: address(0x8888888888888888888888888888888888888888)
            }),
            span: 5,
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        assertEq(decoded.proposalId, claimRecord.proposalId);
        assertEq(decoded.claim.proposalHash, claimRecord.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, claimRecord.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, claimRecord.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, claimRecord.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, claimRecord.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, claimRecord.claim.designatedProver);
        assertEq(decoded.claim.actualProver, claimRecord.claim.actualProver);
        assertEq(decoded.span, claimRecord.span);
        assertEq(decoded.bondInstructions.length, claimRecord.bondInstructions.length);

        for (uint256 i = 0; i < claimRecord.bondInstructions.length; i++) {
            assertEq(
                decoded.bondInstructions[i].proposalId, claimRecord.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(claimRecord.bondInstructions[i].bondType)
            );
            assertEq(decoded.bondInstructions[i].payer, claimRecord.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, claimRecord.bondInstructions[i].receiver);
        }
    }

    function test_minimalValues() public view {
        IInbox.ClaimRecord memory minimal = IInbox.ClaimRecord({
            proposalId: 0,
            claim: IInbox.Claim({
                proposalHash: bytes32(0),
                parentClaimHash: bytes32(0),
                endBlockNumber: 0,
                endBlockHash: bytes32(0),
                endStateRoot: bytes32(0),
                designatedProver: address(0),
                actualProver: address(0)
            }),
            span: 0,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibClaimRecordCodec.encode(minimal);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        assertEq(decoded.proposalId, 0);
        assertEq(decoded.claim.proposalHash, bytes32(0));
        assertEq(decoded.claim.parentClaimHash, bytes32(0));
        assertEq(decoded.claim.endBlockNumber, 0);
        assertEq(decoded.claim.endBlockHash, bytes32(0));
        assertEq(decoded.claim.endStateRoot, bytes32(0));
        assertEq(decoded.claim.designatedProver, address(0));
        assertEq(decoded.claim.actualProver, address(0));
        assertEq(decoded.span, 0);
        assertEq(decoded.bondInstructions.length, 0);
    }

    function test_maximumValues() public view {
        LibBonds.BondInstruction[] memory maxBonds = new LibBonds.BondInstruction[](127);
        for (uint256 i = 0; i < 127; i++) {
            maxBonds[i] = LibBonds.BondInstruction({
                proposalId: uint48(type(uint48).max),
                bondType: LibBonds.BondType.LIVENESS,
                payer: address(type(uint160).max),
                receiver: address(type(uint160).max - 1)
            });
        }

        IInbox.ClaimRecord memory maximal = IInbox.ClaimRecord({
            proposalId: type(uint48).max,
            claim: IInbox.Claim({
                proposalHash: bytes32(type(uint256).max),
                parentClaimHash: bytes32(type(uint256).max - 1),
                endBlockNumber: type(uint48).max,
                endBlockHash: bytes32(type(uint256).max - 2),
                endStateRoot: bytes32(type(uint256).max - 3),
                designatedProver: address(type(uint160).max),
                actualProver: address(type(uint160).max - 1)
            }),
            span: type(uint8).max,
            bondInstructions: maxBonds
        });

        bytes memory encoded = LibClaimRecordCodec.encode(maximal);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        assertEq(decoded.proposalId, maximal.proposalId);
        assertEq(decoded.claim.proposalHash, maximal.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, maximal.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, maximal.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, maximal.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, maximal.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, maximal.claim.designatedProver);
        assertEq(decoded.claim.actualProver, maximal.claim.actualProver);
        assertEq(decoded.span, maximal.span);
        assertEq(decoded.bondInstructions.length, 127);
    }

    function test_multipleRoundtrips() public view {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 100,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            receiver: address(0x2222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 101,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333),
            receiver: address(0x4444)
        });

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 999,
            claim: IInbox.Claim({
                proposalHash: keccak256("test"),
                parentClaimHash: keccak256("parent"),
                endBlockNumber: 100,
                endBlockHash: keccak256("end"),
                endStateRoot: keccak256("state"),
                designatedProver: address(0x5555),
                actualProver: address(0x6666)
            }),
            span: 10,
            bondInstructions: bondInstructions
        });

        bytes memory encoded1 = LibClaimRecordCodec.encode(claimRecord);
        IInbox.ClaimRecord memory decoded1 = LibClaimRecordCodec.decode(encoded1);

        bytes memory encoded2 = LibClaimRecordCodec.encode(decoded1);
        IInbox.ClaimRecord memory decoded2 = LibClaimRecordCodec.decode(encoded2);

        bytes memory encoded3 = LibClaimRecordCodec.encode(decoded2);
        IInbox.ClaimRecord memory decoded3 = LibClaimRecordCodec.decode(encoded3);

        assertEq(encoded1, encoded2);
        assertEq(encoded2, encoded3);

        assertEq(decoded3.proposalId, claimRecord.proposalId);
        assertEq(decoded3.claim.proposalHash, claimRecord.claim.proposalHash);
        assertEq(decoded3.span, claimRecord.span);
        assertEq(decoded3.bondInstructions.length, claimRecord.bondInstructions.length);
    }

    function test_validation_bondInstructionsExceedsMax() public {
        LibBonds.BondInstruction[] memory tooManyBonds = new LibBonds.BondInstruction[](128);
        for (uint256 i = 0; i < 128; i++) {
            tooManyBonds[i] = LibBonds.BondInstruction({
                proposalId: 1,
                bondType: LibBonds.BondType.PROVABILITY,
                payer: address(1),
                receiver: address(2)
            });
        }

        IInbox.ClaimRecord memory invalidRecord = IInbox.ClaimRecord({
            proposalId: 1,
            claim: IInbox.Claim({
                proposalHash: bytes32(0),
                parentClaimHash: bytes32(0),
                endBlockNumber: 0,
                endBlockHash: bytes32(0),
                endStateRoot: bytes32(0),
                designatedProver: address(0),
                actualProver: address(0)
            }),
            span: 0,
            bondInstructions: tooManyBonds
        });

        vm.expectRevert(LibClaimRecordCodec.BOND_INSTRUCTIONS_ARRAY_EXCEEDS_MAX.selector);
        LibClaimRecordCodec.encode(invalidRecord);
    }

    function test_decodeInvalidDataLength() public {
        bytes memory tooShort = new bytes(100);

        vm.expectRevert(LibClaimRecordCodec.INVALID_DATA_LENGTH.selector);
        LibClaimRecordCodec.decode(tooShort);
    }
}
