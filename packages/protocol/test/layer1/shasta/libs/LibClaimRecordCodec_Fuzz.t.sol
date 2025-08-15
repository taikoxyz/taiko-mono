// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibClaimRecordCodec } from "src/layer1/shasta/libs/LibClaimRecordCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title LibClaimRecordCodec_Fuzz
/// @notice Fuzz tests for LibClaimRecordCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibClaimRecordCodec_Fuzz is CommonTest {
    function testFuzz_singleClaimRecord(
        uint48 proposalId,
        bytes32 proposalHash,
        bytes32 parentClaimHash,
        uint48 endBlockNumber,
        bytes32 endBlockHash,
        bytes32 endStateRoot,
        address designatedProver,
        address actualProver,
        uint8 span,
        uint8 bondCount
    )
        public
        pure
    {
        bondCount = uint8(bound(bondCount, 0, 127));

        LibBonds.BondInstruction[] memory bondInstructions =
            new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(i + 1)),
                receiver: address(uint160(i + 2))
            });
        }

        IInbox.ClaimRecord memory original = IInbox.ClaimRecord({
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
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibClaimRecordCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, original.bondInstructions.length);

        for (uint256 i = 0; i < bondCount; i++) {
            assertEq(
                decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(original.bondInstructions[i].bondType)
            );
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }

    function testFuzz_variableBondInstructions(
        uint48 proposalId,
        uint8 span,
        uint256 seed
    )
        public
        pure
    {
        uint8 bondCount = uint8(seed % 128);

        LibBonds.BondInstruction[] memory bondInstructions =
            new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(
                    uint256(keccak256(abi.encode(seed, i, "proposalId"))) % type(uint48).max
                ),
                bondType: LibBonds.BondType(uint256(keccak256(abi.encode(seed, i, "bondType"))) % 3),
                payer: address(uint160(uint256(keccak256(abi.encode(seed, i, "payer"))))),
                receiver: address(uint160(uint256(keccak256(abi.encode(seed, i, "receiver")))))
            });
        }

        IInbox.ClaimRecord memory original = IInbox.ClaimRecord({
            proposalId: proposalId,
            claim: IInbox.Claim({
                proposalHash: keccak256(abi.encode(seed, "proposalHash")),
                parentClaimHash: keccak256(abi.encode(seed, "parentClaimHash")),
                endBlockNumber: uint48(
                    uint256(keccak256(abi.encode(seed, "endBlockNumber"))) % type(uint48).max
                ),
                endBlockHash: keccak256(abi.encode(seed, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(seed, "endStateRoot")),
                designatedProver: address(uint160(uint256(keccak256(abi.encode(seed, "designatedProver"))))),
                actualProver: address(uint160(uint256(keccak256(abi.encode(seed, "actualProver")))))
            }),
            span: span,
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibClaimRecordCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, original.bondInstructions.length);

        for (uint256 i = 0; i < bondCount; i++) {
            assertEq(
                decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(original.bondInstructions[i].bondType)
            );
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }

    function testFuzz_extremeValues(bool useMax) public pure {
        uint48 proposalId = useMax ? type(uint48).max : 0;
        uint48 endBlockNumber = useMax ? type(uint48).max : 0;
        uint8 span = useMax ? type(uint8).max : 0;
        uint8 bondCount = useMax ? 127 : 0;

        LibBonds.BondInstruction[] memory bondInstructions =
            new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: useMax ? type(uint48).max : 0,
                bondType: useMax ? LibBonds.BondType.LIVENESS : LibBonds.BondType.NONE,
                payer: useMax ? address(type(uint160).max) : address(0),
                receiver: useMax ? address(type(uint160).max - 1) : address(0)
            });
        }

        IInbox.ClaimRecord memory original = IInbox.ClaimRecord({
            proposalId: proposalId,
            claim: IInbox.Claim({
                proposalHash: useMax ? bytes32(type(uint256).max) : bytes32(0),
                parentClaimHash: useMax ? bytes32(type(uint256).max - 1) : bytes32(0),
                endBlockNumber: endBlockNumber,
                endBlockHash: useMax ? bytes32(type(uint256).max - 2) : bytes32(0),
                endStateRoot: useMax ? bytes32(type(uint256).max - 3) : bytes32(0),
                designatedProver: useMax ? address(type(uint160).max) : address(0),
                actualProver: useMax ? address(type(uint160).max - 1) : address(0)
            }),
            span: span,
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibClaimRecordCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);

        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, original.bondInstructions.length);
    }

    function testFuzz_hashCollisionResistance(uint256 seed1, uint256 seed2) public pure {
        vm.assume(seed1 != seed2);

        IInbox.ClaimRecord memory record1 = _createRandomClaimRecord(seed1);
        IInbox.ClaimRecord memory record2 = _createRandomClaimRecord(seed2);

        bytes memory encoded1 = LibClaimRecordCodec.encode(record1);
        bytes memory encoded2 = LibClaimRecordCodec.encode(record2);

        if (keccak256(abi.encode(record1)) != keccak256(abi.encode(record2))) {
            assert(keccak256(encoded1) != keccak256(encoded2));
        }
    }

    function testFuzz_differentialTestingAgainstBaseline(
        uint48 proposalId,
        bytes32 proposalHash,
        uint8 span,
        uint8 bondCount
    )
        public
        pure
    {
        bondCount = uint8(bound(bondCount, 0, 10));

        LibBonds.BondInstruction[] memory bondInstructions =
            new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(i + 1)),
                receiver: address(uint160(i + 2))
            });
        }

        IInbox.ClaimRecord memory original = IInbox.ClaimRecord({
            proposalId: proposalId,
            claim: IInbox.Claim({
                proposalHash: proposalHash,
                parentClaimHash: keccak256("parent"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlock"),
                endStateRoot: keccak256("endState"),
                designatedProver: address(0x1111111111111111111111111111111111111111),
                actualProver: address(0x2222222222222222222222222222222222222222)
            }),
            span: span,
            bondInstructions: bondInstructions
        });

        bytes memory optimizedEncoded = LibClaimRecordCodec.encode(original);
        IInbox.ClaimRecord memory optimizedDecoded = LibClaimRecordCodec.decode(optimizedEncoded);

        bytes memory baselineEncoded = abi.encode(original);
        IInbox.ClaimRecord memory baselineDecoded =
            abi.decode(baselineEncoded, (IInbox.ClaimRecord));

        assertEq(optimizedDecoded.proposalId, baselineDecoded.proposalId);
        assertEq(optimizedDecoded.claim.proposalHash, baselineDecoded.claim.proposalHash);
        assertEq(optimizedDecoded.span, baselineDecoded.span);
        assertEq(optimizedDecoded.bondInstructions.length, baselineDecoded.bondInstructions.length);
    }

    function _createRandomClaimRecord(uint256 seed)
        private
        pure
        returns (IInbox.ClaimRecord memory)
    {
        uint8 bondCount = uint8(uint256(keccak256(abi.encode(seed, "bondCount"))) % 10);

        LibBonds.BondInstruction[] memory bondInstructions =
            new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(
                    uint256(keccak256(abi.encode(seed, i, "proposalId"))) % type(uint48).max
                ),
                bondType: LibBonds.BondType(uint256(keccak256(abi.encode(seed, i, "bondType"))) % 3),
                payer: address(uint160(uint256(keccak256(abi.encode(seed, i, "payer"))))),
                receiver: address(uint160(uint256(keccak256(abi.encode(seed, i, "receiver")))))
            });
        }

        return IInbox.ClaimRecord({
            proposalId: uint48(uint256(keccak256(abi.encode(seed, "proposalId"))) % type(uint48).max),
            claim: IInbox.Claim({
                proposalHash: keccak256(abi.encode(seed, "proposalHash")),
                parentClaimHash: keccak256(abi.encode(seed, "parentClaimHash")),
                endBlockNumber: uint48(
                    uint256(keccak256(abi.encode(seed, "endBlockNumber"))) % type(uint48).max
                ),
                endBlockHash: keccak256(abi.encode(seed, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(seed, "endStateRoot")),
                designatedProver: address(uint160(uint256(keccak256(abi.encode(seed, "designatedProver"))))),
                actualProver: address(uint160(uint256(keccak256(abi.encode(seed, "actualProver")))))
            }),
            span: uint8(uint256(keccak256(abi.encode(seed, "span"))) % 256),
            bondInstructions: bondInstructions
        });
    }
}
