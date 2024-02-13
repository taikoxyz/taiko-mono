// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1TestBase.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { IVerifier } from "../../contracts/verifiers/IVerifier.sol";
import { TaikoData } from "../../contracts/L1/TaikoData.sol";
import { MockPlonkVerifier } from "../mocks/MockPlonkVerifier.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
contract TestPseZkVerifier is TaikoL1TestBase {
    uint16 mockPlonkVerifierId;
    address mockPlonkVerifier;

    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        // Create a mock PLONK Verifier
        mockPlonkVerifierId = 12_345;
        mockPlonkVerifier = address(new MockPlonkVerifier());

        // Add the mock PLONK verifier to the address resolver
        bytes32 verifierName = pv.getVerifierName(mockPlonkVerifierId);

        addressManager.setAddress(
            uint64(block.chainid), bytes32(verifierName), address(mockPlonkVerifier)
        );
    }

    // Test `verifyProof()` when contesting
    function test_verifyProof_isContesting() external view {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: true, // skips all verification when true
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32(0),
            blockHash: bytes32(0),
            stateRoot: bytes32(0),
            graffiti: bytes32(0),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: "" });

        // `verifyProof()`
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` with `isBlobUsed = true`
    function test_verifyProof_isBlobUsed() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: true
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32(0),
            blockHash: bytes32(0),
            stateRoot: bytes32(0),
            graffiti: bytes32(0),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes1[48] memory point;
        PseZkVerifier.PointProof memory pointProof = PseZkVerifier.PointProof({
            txListHash: bytes32(0),
            pointValue: 10,
            pointCommitment: point,
            pointProof: point
        });

        bytes32 instance = pv.calcInstance(
            transition, ctx.msgSender, ctx.metaHash, pointProof.txListHash, pointProof.pointValue
        );
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(instance), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, abi.encode(keccak256("taiko")));

        PseZkVerifier.ZkEvmProof memory zkProof = PseZkVerifier.ZkEvmProof({
            verifierId: mockPlonkVerifierId,
            zkp: zkp,
            pointProof: abi.encode(pointProof)
        });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert(Lib4844.EVAL_FAILED_2.selector);
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, happy path
    function test_verifyProof() external view {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(instance), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, abi.encode(keccak256("taiko")));

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, invalid encoding of ZkEvmProof
    function test_verifyProof_invalidEncodingZkEvmProof() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(uint256(0)) });

        // `verifyProof()`
        vm.expectRevert();
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, invalid instance first part
    function test_verifyProof_invalidInstanceA() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(0), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, abi.encode(keccak256("taiko")));

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert(PseZkVerifier.L1_INVALID_PROOF.selector);
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, invalid instance second part
    function test_verifyProof_invalidInstanceB() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords =
            abi.encodePacked(bytes16(0), bytes16(0), bytes16(instance), bytes16(0));
        bytes memory zkp = abi.encodePacked(instanceWords, abi.encode(keccak256("taiko")));

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert(PseZkVerifier.L1_INVALID_PROOF.selector);
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, zkp less than 64 bytes
    function test_verifyProof_invalidZkpLength() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes memory zkp = abi.encodePacked("invalid");

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert("slice_outOfBounds");
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, invalid verifier ID
    function test_verifyProof_invalidVerifierId() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(instance), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, abi.encode(keccak256("taiko")));

        PseZkVerifier.ZkEvmProof memory zkProof = PseZkVerifier.ZkEvmProof({
            verifierId: 999, // invalid
            zkp: zkp,
            pointProof: ""
        });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert();
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, PLONK verifier reverts
    function test_verifyProof_plonkVerifierRevert() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(instance), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, abi.encode(keccak256("taiko")));

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // Tell verifier to revert
        MockPlonkVerifier(mockPlonkVerifier).setShouldRevert(true);

        // `verifyProof()`
        vm.expectRevert(PseZkVerifier.L1_INVALID_PROOF.selector);
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, PLONK verifier returns the wrong length
    function test_verifyProof_plonkVerifierInvalidLength() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(instance), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, "Hi");

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert(PseZkVerifier.L1_INVALID_PROOF.selector);
        pv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` without blob, PLONK verifier returns the wrong 32 bytes
    function test_verifyProof_plonkVerifierInvalidRetrun() external {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("23"),
            stateRoot: bytes32("34"),
            graffiti: bytes32("1234"),
            __reserved: [bytes32(0), bytes32(0)]
        });

        // TierProof
        bytes32 instance = pv.calcInstance(transition, ctx.msgSender, ctx.metaHash, ctx.blobHash, 0);
        bytes memory instanceWords = abi.encodePacked(
            bytes16(0), bytes16(instance), bytes16(0), bytes16(uint128(uint256(instance)))
        );
        bytes memory zkp = abi.encodePacked(instanceWords, bytes32("Hi"));

        PseZkVerifier.ZkEvmProof memory zkProof =
            PseZkVerifier.ZkEvmProof({ verifierId: mockPlonkVerifierId, zkp: zkp, pointProof: "" });

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ prover: ctx.msgSender, tier: 0, data: abi.encode(zkProof) });

        // `verifyProof()`
        vm.expectRevert(PseZkVerifier.L1_INVALID_PROOF.selector);
        pv.verifyProof(ctx, transition, proof);
    }
}
