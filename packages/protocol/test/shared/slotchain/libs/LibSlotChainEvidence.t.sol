// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import {
    LibSlotChainEncoding
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEncoding.sol";
import {
    LibSlotChainEvidence
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEvidence.sol";
import { Test } from "forge-std/src/Test.sol";

contract SlotChainEvidenceHarness {
    function decodePackedBlock(
        bytes calldata _encoded,
        uint256 _offset
    )
        external
        pure
        returns (SlotChainTypes.SlotChainBlock memory block_)
    {
        return LibSlotChainEvidence.decodePackedBlock(_encoded, _offset);
    }

    function recoverSigner(
        bytes32 _digest,
        bytes calldata _encoded,
        uint256 _offset
    )
        external
        pure
        returns (address signer_)
    {
        return LibSlotChainEvidence.recoverSigner(_digest, _encoded, _offset);
    }

    function validateEquivocationPair(
        SlotChainTypes.SlotChainBlock memory _a,
        SlotChainTypes.SlotChainBlock memory _b,
        bytes calldata _evidence,
        uint256 _signatureAOffset,
        uint256 _signatureBOffset
    )
        external
        pure
        returns (address builder_, bytes32 digestA_, bytes32 digestB_)
    {
        return LibSlotChainEvidence.validateEquivocationPair(
            _a, _b, _evidence, _signatureAOffset, _signatureBOffset
        );
    }

    function readBytes32(
        bytes calldata _encoded,
        uint256 _offset
    )
        external
        pure
        returns (bytes32 value_)
    {
        return LibSlotChainEvidence.readBytes32(_encoded, _offset);
    }

    function readU16(
        bytes calldata _encoded,
        uint256 _offset
    )
        external
        pure
        returns (uint16 value_)
    {
        return LibSlotChainEvidence.readU16(_encoded, _offset);
    }

    function readU64(
        bytes calldata _encoded,
        uint256 _offset
    )
        external
        pure
        returns (uint64 value_)
    {
        return LibSlotChainEvidence.readU64(_encoded, _offset);
    }
}

contract LibSlotChainEvidenceTest is Test {
    uint256 private constant _BUILDER_KEY = 0xB017D3;
    uint256 private constant _OTHER_KEY = 0xBAD;
    uint256 private constant _SECP256K1N =
        0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

    uint256 private constant _PACKED_BLOCK_LENGTH = 521;
    uint256 private constant _SIGNATURE_LENGTH = 65;
    uint256 private constant _EVIDENCE_LENGTH = 2366;
    uint256 private constant _HISTORICAL_POSITION_OFFSET = 1172;
    uint256 private constant _WINDOW_OFFSET = 1526;
    uint256 private constant _LAST_REGISTRY_SIBLING_OFFSET = 2334;

    SlotChainEvidenceHarness private _harness;

    function setUp() public {
        _harness = new SlotChainEvidenceHarness();
    }

    function test_decodePackedBlock_DecodesEveryExactWidthAtLastValidOffset() external {
        SlotChainTypes.SlotChainBlock memory expected = _normalBlock();
        bytes memory prefix = hex"aabbcc";
        bytes memory encoded = bytes.concat(prefix, _pack(expected));

        SlotChainTypes.SlotChainBlock memory actual =
            _harness.decodePackedBlock(encoded, prefix.length);
        assertEq(keccak256(abi.encode(actual)), keccak256(abi.encode(expected)));

        vm.expectRevert(LibSlotChainEvidence.InvalidPackedBlockLength.selector);
        _harness.decodePackedBlock(encoded, prefix.length + 1);
        vm.expectRevert(LibSlotChainEvidence.InvalidPackedBlockLength.selector);
        _harness.decodePackedBlock(encoded, type(uint256).max);
    }

    function test_decodePackedBlock_AcceptsCanonicalRecoveryTier() external {
        SlotChainTypes.SlotChainBlock memory expected = _normalBlock();
        expected.tier = 2;
        expected.episode = 1;
        expected.recoveryRevision = 2;
        expected.recoveryId = keccak256("recovery-id");
        expected.contextId = expected.recoveryId;

        SlotChainTypes.SlotChainBlock memory actual = _harness.decodePackedBlock(_pack(expected), 0);
        assertEq(keccak256(abi.encode(actual)), keccak256(abi.encode(expected)));
    }

    function test_decodePackedBlock_RevertWhen_TierFieldsAreNoncanonical() external {
        SlotChainTypes.SlotChainBlock memory block_ = _normalBlock();
        block_.episode = 1;
        vm.expectRevert(LibSlotChainEvidence.InvalidTierFields.selector);
        _harness.decodePackedBlock(_pack(block_), 0);

        block_ = _normalBlock();
        block_.tier = 2;
        block_.episode = 1;
        block_.recoveryRevision = 1;
        block_.recoveryId = keccak256("recovery-id");
        vm.expectRevert(LibSlotChainEvidence.InvalidTierFields.selector);
        _harness.decodePackedBlock(_pack(block_), 0);

        block_ = _normalBlock();
        block_.tier = 3;
        vm.expectRevert(LibSlotChainEvidence.InvalidEvidenceTier.selector);
        _harness.decodePackedBlock(_pack(block_), 0);
    }

    function test_validateEquivocationPair_AcceptsEqualBlockHashWhenFullStructsDiffer() external {
        SlotChainTypes.SlotChainBlock memory a = _normalBlock();
        SlotChainTypes.SlotChainBlock memory b = _normalBlock();
        b.stateRoot = keccak256("different-state-root");
        assertEq(a.blockHash, b.blockHash);
        (a, b) = _ordered(a, b);

        (bytes memory evidence, bytes32 expectedDigestA, bytes32 expectedDigestB) =
            _signedPair(a, b, _BUILDER_KEY, _BUILDER_KEY);
        (address builder, bytes32 digestA, bytes32 digestB) =
            _harness.validateEquivocationPair(a, b, evidence, 0, _SIGNATURE_LENGTH);

        assertEq(builder, vm.addr(_BUILDER_KEY));
        assertEq(digestA, expectedDigestA);
        assertEq(digestB, expectedDigestB);
        assertTrue(
            uint256(LibSlotChainEncoding.hashSlotChainBlock(a))
                < uint256(LibSlotChainEncoding.hashSlotChainBlock(b))
        );
    }

    function test_validateEquivocationPair_AcceptsRecoveryTierSignatures() external {
        SlotChainTypes.SlotChainBlock memory a = _normalBlock();
        a.tier = 2;
        a.episode = 9;
        a.recoveryRevision = 3;
        a.recoveryId = keccak256("recovery-id");
        a.contextId = a.recoveryId;
        SlotChainTypes.SlotChainBlock memory b = _clone(a);
        b.blockHash = keccak256("second-block");
        (a, b) = _ordered(a, b);

        (bytes memory evidence,,) = _signedPair(a, b, _BUILDER_KEY, _BUILDER_KEY);
        (address builder,,) =
            _harness.validateEquivocationPair(a, b, evidence, 0, _SIGNATURE_LENGTH);
        assertEq(builder, vm.addr(_BUILDER_KEY));
    }

    function test_validateEquivocationPair_RevertWhen_StructHashOrderIsReversedOrEqual() external {
        SlotChainTypes.SlotChainBlock memory a = _normalBlock();
        SlotChainTypes.SlotChainBlock memory b = _clone(a);
        b.bodyRoot = keccak256("different-body");
        (a, b) = _ordered(a, b);

        vm.expectRevert(LibSlotChainEvidence.InvalidStructHashOrder.selector);
        _harness.validateEquivocationPair(b, a, bytes(""), 0, 0);

        vm.expectRevert(LibSlotChainEvidence.InvalidStructHashOrder.selector);
        _harness.validateEquivocationPair(a, a, bytes(""), 0, 0);
    }

    function test_validateEquivocationPair_RevertWhen_Eip712SignerDiffers() external {
        SlotChainTypes.SlotChainBlock memory a = _normalBlock();
        SlotChainTypes.SlotChainBlock memory b = _clone(a);
        b.blockHash = keccak256("different-block");
        (a, b) = _ordered(a, b);
        (bytes memory evidence,,) = _signedPair(a, b, _BUILDER_KEY, _OTHER_KEY);

        vm.expectRevert(LibSlotChainEvidence.SignerMismatch.selector);
        _harness.validateEquivocationPair(a, b, evidence, 0, _SIGNATURE_LENGTH);
    }

    function test_validateEquivocationPair_RevertWhen_DomainOrSharedContextDiffers() external {
        SlotChainTypes.SlotChainBlock memory a = _normalBlock();
        SlotChainTypes.SlotChainBlock memory b = _clone(a);
        b.settlementChainId += 1;
        vm.expectRevert(LibSlotChainEvidence.InvalidEquivocationPair.selector);
        _harness.validateEquivocationPair(a, b, bytes(""), 0, 0);

        b = _clone(a);
        b.verifyingContract = address(0x1234);
        vm.expectRevert(LibSlotChainEvidence.InvalidEquivocationPair.selector);
        _harness.validateEquivocationPair(a, b, bytes(""), 0, 0);

        b = _clone(a);
        b.contextId = bytes32(0);
        a.contextId = bytes32(0);
        vm.expectRevert(LibSlotChainEvidence.InvalidEquivocationPair.selector);
        _harness.validateEquivocationPair(a, b, bytes(""), 0, 0);
    }

    function test_recoverSigner_RevertWhen_HighSZeroScalarOrNoncanonicalV() external {
        bytes32 digest = keccak256("digest");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_BUILDER_KEY, digest);
        bytes memory highS = abi.encodePacked(r, bytes32(_SECP256K1N - uint256(s)), v);
        vm.expectRevert(LibSlotChainEvidence.InvalidSignature.selector);
        _harness.recoverSigner(digest, highS, 0);

        bytes memory zeroR = abi.encodePacked(bytes32(0), s, v);
        vm.expectRevert(LibSlotChainEvidence.InvalidSignature.selector);
        _harness.recoverSigner(digest, zeroR, 0);

        bytes memory badV = abi.encodePacked(r, s, uint8(1));
        vm.expectRevert(LibSlotChainEvidence.InvalidSignature.selector);
        _harness.recoverSigner(digest, badV, 0);

        vm.expectRevert(LibSlotChainEvidence.InvalidSignatureLength.selector);
        _harness.recoverSigner(digest, abi.encodePacked(r, s), 0);
    }

    function test_readEvidenceTail_PinsLastHistoricalPositionWindowAndFinalSibling() external {
        bytes memory evidence = new bytes(_EVIDENCE_LENGTH);
        evidence[_HISTORICAL_POSITION_OFFSET] = 0x07;
        evidence[_HISTORICAL_POSITION_OFFSET + 1] = 0xff;
        for (uint256 i; i < 8; ++i) {
            evidence[_WINDOW_OFFSET + i] = 0xff;
        }
        bytes32 finalSibling = keccak256("final-registry-sibling");
        for (uint256 i; i < 32; ++i) {
            evidence[_LAST_REGISTRY_SIBLING_OFFSET + i] = finalSibling[i];
        }

        assertEq(_harness.readU16(evidence, _HISTORICAL_POSITION_OFFSET), 2047);
        assertEq(_harness.readU64(evidence, _WINDOW_OFFSET), type(uint64).max);
        assertEq(_harness.readBytes32(evidence, _LAST_REGISTRY_SIBLING_OFFSET), finalSibling);

        vm.expectRevert(LibSlotChainEvidence.EvidenceReadOutOfBounds.selector);
        _harness.readBytes32(evidence, _LAST_REGISTRY_SIBLING_OFFSET + 1);
        vm.expectRevert(LibSlotChainEvidence.EvidenceReadOutOfBounds.selector);
        _harness.readU64(evidence, _EVIDENCE_LENGTH - 7);
    }

    function _normalBlock() private pure returns (SlotChainTypes.SlotChainBlock memory block_) {
        block_ = SlotChainTypes.SlotChainBlock({
            settlementChainId: 1,
            l2ChainId: 167_000,
            protocolVersion: 7,
            verifyingContract: address(0xBEEF),
            slot: 38_400,
            parentHash: keccak256("parent"),
            blockHash: keccak256("block"),
            stateRoot: keccak256("state"),
            bodyRoot: keccak256("body"),
            anchorNumber: 100,
            anchorHash: keccak256("anchor"),
            forceRoot: keccak256("force"),
            forceCutoff: 5,
            messageStart: 10,
            messageEnd: 12,
            dataManifestRoot: keccak256("manifest"),
            coinbase: address(0xCAFE),
            tier: 1,
            contextId: keccak256("context"),
            admissionVersion: 8,
            admissionRoot: keccak256("admission"),
            episode: 0,
            recoveryRevision: 0,
            recoveryId: bytes32(0)
        });
    }

    function _pack(SlotChainTypes.SlotChainBlock memory _block)
        private
        pure
        returns (bytes memory encoded_)
    {
        bytes memory prefix = abi.encodePacked(
            _block.settlementChainId,
            _block.l2ChainId,
            _block.protocolVersion,
            _block.verifyingContract,
            _block.slot,
            _block.parentHash,
            _block.blockHash,
            _block.stateRoot,
            _block.bodyRoot
        );
        bytes memory middle = abi.encodePacked(
            _block.anchorNumber,
            _block.anchorHash,
            _block.forceRoot,
            _block.forceCutoff,
            _block.messageStart,
            _block.messageEnd,
            _block.dataManifestRoot,
            _block.coinbase,
            _block.tier
        );
        bytes memory suffix = abi.encodePacked(
            _block.contextId,
            _block.admissionVersion,
            _block.admissionRoot,
            _block.episode,
            _block.recoveryRevision,
            _block.recoveryId
        );
        encoded_ = bytes.concat(prefix, middle, suffix);
        assert(encoded_.length == _PACKED_BLOCK_LENGTH);
    }

    function _ordered(
        SlotChainTypes.SlotChainBlock memory _a,
        SlotChainTypes.SlotChainBlock memory _b
    )
        private
        pure
        returns (
            SlotChainTypes.SlotChainBlock memory first_,
            SlotChainTypes.SlotChainBlock memory second_
        )
    {
        if (
            uint256(LibSlotChainEncoding.hashSlotChainBlock(_a))
                < uint256(LibSlotChainEncoding.hashSlotChainBlock(_b))
        ) {
            return (_clone(_a), _clone(_b));
        }
        return (_clone(_b), _clone(_a));
    }

    function _clone(SlotChainTypes.SlotChainBlock memory _block)
        private
        pure
        returns (SlotChainTypes.SlotChainBlock memory clone_)
    {
        return abi.decode(abi.encode(_block), (SlotChainTypes.SlotChainBlock));
    }

    function _signedPair(
        SlotChainTypes.SlotChainBlock memory _a,
        SlotChainTypes.SlotChainBlock memory _b,
        uint256 _keyA,
        uint256 _keyB
    )
        private
        returns (bytes memory evidence_, bytes32 digestA_, bytes32 digestB_)
    {
        digestA_ = LibSlotChainEncoding.hashSlotChainDigest(
            _a.settlementChainId, _a.verifyingContract, _a
        );
        digestB_ = LibSlotChainEncoding.hashSlotChainDigest(
            _b.settlementChainId, _b.verifyingContract, _b
        );
        (uint8 vA, bytes32 rA, bytes32 sA) = vm.sign(_keyA, digestA_);
        (uint8 vB, bytes32 rB, bytes32 sB) = vm.sign(_keyB, digestB_);
        evidence_ = abi.encodePacked(rA, sA, vA, rB, sB, vB);
    }
}
