// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/SgxVerifierBase.sol";
import "../automata-attestation/common/AttestationBase.t.sol";
import "../based/TaikoL1TestBase.sol";


contract TestSgxVerifier is TaikoL1TestBase, AttestationBase {
    address internal SGX_Y =
        vm.addr(0x9b1bb8cb3bdb539d0d1f03951d27f167f2d5443e7ef0d7ce745cd4ec619d3dd7);
    address internal SGX_Z = randAddress();

    address KNOWN_ADDRESS = address(0xAAAAAFE838B80D164535CD4d50058E456A4f9E16);
    uint256 KNOWN_ADDRESS_PRIV_KEY =
        0xde9b0c39e60bb0404347b588c6891947db2c873942b553d5d15c03ea30c04c63;

    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        // Call the AttestationBase init setup
        super.initialSetup();

        registerAddress("automata_dcap_attestation", address(attestation));
    }

    // Tests `addInstances()` from the owner
    function test_addInstances() public {
        uint256 startInstance = sv.nextInstanceId();

        // Create instances to add
        address[] memory instances = new address[](2);
        instances[0] = Alice;
        instances[1] = Bob;

        vm.expectEmit(true, true, true, true);
        emit SgxVerifierBase.InstanceAdded(startInstance, instances[0], address(0), block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit SgxVerifierBase.InstanceAdded(startInstance + 1, instances[1], address(0), block.timestamp);

        // `addInstances()`
        uint256[] memory ids = sv.addInstances(instances);

        // Verification
        assertEq(ids.length, 2, "Invalid IDs length");
        assertEq(ids[0], startInstance, "Invalid ID");
        assertEq(ids[1], startInstance + 1, "Invalid ID");

        (address instanceAddr, uint64 instanceAddedAt) = sv.instances(startInstance);
        assertEq(instanceAddr, instances[0], "Invalid instance address");
        assertEq(instanceAddedAt, block.timestamp, "Invalid instance addedAt");

        (instanceAddr, instanceAddedAt) = sv.instances(startInstance + 1);
        assertEq(instanceAddr, instances[1], "Invalid instance address");
        assertEq(instanceAddedAt, block.timestamp, "Invalid instance addedAt");

        assertEq(sv.nextInstanceId(), startInstance + 2, "Invalid next instance ID");

        // Setup for second `addInstances()` from the owner
        address[] memory instances2 = new address[](2);
        instances2[0] = Carol;
        instances2[1] = David;

        vm.expectEmit(true, true, true, true);
        emit SgxVerifierBase.InstanceAdded(
            startInstance + 2, instances2[0], address(0), block.timestamp
        );
        vm.expectEmit(true, true, true, true);
        emit SgxVerifierBase.InstanceAdded(
            startInstance + 3, instances2[1], address(0), block.timestamp
        );

        // `addInstances()`
        ids = sv.addInstances(instances2);

        // Verification
        assertEq(ids.length, 2, "Invalid IDs length");
        assertEq(ids[0], startInstance + 2, "Invalid ID");
        assertEq(ids[1], startInstance + 3, "Invalid ID");

        (instanceAddr, instanceAddedAt) = sv.instances(startInstance + 2);
        assertEq(instanceAddr, instances2[0], "Invalid instance address");
        assertEq(instanceAddedAt, block.timestamp, "Invalid instance addedAt");

        (instanceAddr, instanceAddedAt) = sv.instances(startInstance + 3);
        assertEq(instanceAddr, instances2[1], "Invalid instance address");
        assertEq(instanceAddedAt, block.timestamp, "Invalid instance addedAt");

        assertEq(sv.nextInstanceId(), startInstance + 4, "Invalid next instance ID");

        vm.stopPrank();
    }

    // Tests `addInstances()` from the owner when there is a zero address
    function test_addInstances_zeroAddress() external {
        // Create instances to add
        address[] memory instances = new address[](2);
        instances[0] = Alice;
        instances[1] = address(0);

        // `addInstances()`
        vm.expectRevert(SgxVerifierBase.SGX_INVALID_INSTANCE.selector);
        sv.addInstances(instances);

        vm.stopPrank();
    }

    // Tests `addInstances()` from the owner with duplicates
    function test_addInstances_duplicates() external {
        // Create instances to add
        address[] memory instances = new address[](2);
        instances[0] = Alice;
        instances[1] = Alice; // invalid as duplicate instance

        // `addInstances()`
        vm.expectRevert(SgxVerifierBase.SGX_ALREADY_ATTESTED.selector);
        sv.addInstances(instances);
    }

    function test_addInstancesByOwner_WithoutOwnerRole() external {
        address[] memory _instances = new address[](3);
        _instances[0] = SGX_X_0;
        _instances[1] = SGX_Y;
        _instances[2] = SGX_Z;

        vm.expectRevert();
        vm.prank(Bob, Bob);
        sv.addInstances(_instances);
    }

    function test_deleteInstancesByOwner() external {
        uint256[] memory _ids = new uint256[](1);
        _ids[0] = 0;

        address instance;
        (instance,) = sv.instances(0);
        assertEq(instance, SGX_X_0);

        sv.deleteInstances(_ids);

        (instance,) = sv.instances(0);
        assertEq(instance, address(0));
    }

    function test_registerInstanceWithAttestation() external {
        V3Struct.ParsedV3QuoteStruct memory v3quote =
            ParseV3QuoteBytes(address(pemCertChainLib), sampleQuote);

        vm.prank(Bob, Bob);
        sv.registerInstance(v3quote);
    }

    function test_registerInstanceTwiceWithSameAttestation() external {
        V3Struct.ParsedV3QuoteStruct memory v3quote =
            ParseV3QuoteBytes(address(pemCertChainLib), sampleQuote);

        vm.prank(Bob, Bob);
        sv.registerInstance(v3quote);

        vm.expectRevert(SgxVerifierBase.SGX_ALREADY_ATTESTED.selector);
        vm.prank(Carol, Carol);
        sv.registerInstance(v3quote);
    }

    // Test `verifyProof()` happy path
    function test_verifyProof() external {
        uint32 id = uint32(sv.nextInstanceId());

        // `addInstances()` add an alice instance
        address[] memory instances = new address[](1);
        instances[0] = KNOWN_ADDRESS;
        sv.addInstances(instances);

        vm.stopPrank();

        // Caller should be TaikoL1 contract
        vm.startPrank(address(L1));

        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: KNOWN_ADDRESS,
            msgSender: KNOWN_ADDRESS,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });

        // TierProof
        address newInstance = address(0x33);

        uint64 chainId = L1.getConfig().chainId;
        bytes32 signedHash = LibPublicInput.hashPublicInputs(
            transition, address(sv), newInstance, ctx.prover, ctx.metaHash, chainId
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KNOWN_ADDRESS_PRIV_KEY, signedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // bytes memory data = abi.encodePacked(id, newInstance, signature); -> comment out to avoid
        // stack too deep.
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encodePacked(id, newInstance, signature) });

        vm.warp(block.timestamp + 5);

        vm.expectEmit(true, true, true, true);
        emit SgxVerifierBase.InstanceAdded(id, newInstance, KNOWN_ADDRESS, block.timestamp);

        // `verifyProof()`
        sv.verifyProof(ctx, transition, proof);

        // Verification
        (address instanceAddr, uint64 instanceAddedAt) = sv.instances(id);
        assertEq(instanceAddr, newInstance, "Invalid instance address");
        assertEq(instanceAddedAt, block.timestamp, "Invalid instance addedAt");

        vm.stopPrank();
    }

    // Test `verifyProof()` when contesting
    function test_verifyProof_isContesting() external {
        vm.startPrank(address(L1));

        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: Alice,
            msgSender: Alice,
            blockId: 10,
            isContesting: true, // skips all verification when true
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: LibTiers.TIER_GUARDIAN, data: "" });

        // `verifyProof()`
        sv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    // Test `verifyProof()` invalid proof length
    function test_verifyProof_invalidProofLength() external {
        vm.startPrank(address(L1));

        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: Alice,
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });

        // TierProof
        TaikoData.TierProof memory proof = TaikoData.TierProof({
            tier: 0,
            data: new bytes(80) // invalid length
         });

        // `verifyProof()`
        vm.expectRevert(SgxVerifierBase.SGX_INVALID_PROOF.selector);
        sv.verifyProof(ctx, transition, proof);
    }

    // Test `verifyProof()` invalid signature
    function test_verifyProof_invalidSignature() public {
        vm.startPrank(address(L1));

        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: Alice,
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });

        // TierProof
        uint32 id = 0;
        address newInstance = address(0x33);
        bytes memory signature = new bytes(65); // invalid length
        bytes memory data = abi.encodePacked(id, newInstance, signature);
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        vm.expectRevert("ECDSA: invalid signature");
        sv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    // Test `verifyProof()` invalid instance
    function test_verifyProof_invalidInstance() public {
        vm.startPrank(address(L1));

        uint32 id = uint32(sv.nextInstanceId());

        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: Alice,
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });

        // TierProof
        address newInstance = address(0x33);

        uint64 chainId = L1.getConfig().chainId;
        bytes32 signedHash = LibPublicInput.hashPublicInputs(
            transition, address(sv), newInstance, ctx.prover, ctx.metaHash, chainId
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KNOWN_ADDRESS_PRIV_KEY, signedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory data = abi.encodePacked(id, newInstance, signature);
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        vm.expectRevert(SgxVerifierBase.SGX_INVALID_INSTANCE.selector);
        sv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    // Test `verifyBatchProof()` happy path
    function test_verifyBatchProofs() public {
        // setup instances
        address newInstance = address(0x6Aa1108c1903E3AeF092FF46E4C506fD3ac567c0);
        address[] memory instances = new address[](1);
        instances[0] = newInstance;
        uint256[] memory ids = sv.addInstances(instances);
        console.log("Instance ID: ", ids[0]);

        vm.startPrank(address(L1));

        // Context
        IVerifier.ContextV2[] memory ctxs = new IVerifier.ContextV2[](2);
        ctxs[0] = IVerifier.ContextV2({
            metaHash: 0x207b2833fb6d804612da24d8785b870a19c7a3f25fa4aaeb9799cd442d65b031,
            blobHash: 0x01354e8725e60ad91b32ec4ab19158572a0a5b06b2d4d83f6269c9a7d068f49b,
            prover: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            msgSender: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            blockId: 393_333,
            isContesting: false,
            blobUsed: true,
            tran: TaikoData.Transition({
                parentHash: 0xce519622a374dc014c005d7857de26d952751a9067d3e23ffe14da247aa8a399,
                blockHash: 0x941d557653da2214cbf3d30af8d9cadbc7b5f77b6c3e48bca548eba04eb9cd79,
                stateRoot: 0x4203a2fd98d268d272acb24d91e25055a779b443ff3e732f2cee7abcf639b5e9,
                graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
            })
        });
        ctxs[1] = IVerifier.ContextV2({
            metaHash: 0x946ba1a9c02fc2f01da49e31cb5be83c118193d0389987c6be616ce76426b44d,
            blobHash: 0x01abac8c1fb54f87ff7b0cbf14259b9d5ee7a8de458c587dd6eda43ef8354b4f,
            prover: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            msgSender: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            blockId: 393_334,
            isContesting: false,
            blobUsed: true,
            tran: TaikoData.Transition({
                parentHash: 0x941d557653da2214cbf3d30af8d9cadbc7b5f77b6c3e48bca548eba04eb9cd79,
                blockHash: 0xc0dad38646ab264be30995b7b7fd02db65e7115126fb52bfad94c0fc9572287c,
                stateRoot: 0x222061caab95b6bd0f8dd398088030979efbe56e282cd566f7abd77838558eb9,
                graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
            })
        });

        // TierProof
        bytes memory data =
            hex"000000016aa1108c1903e3aef092ff46e4c506fd3ac567c06aa1108c1903e3aef092ff46e4c506fd3ac567c0dda91ea274c36678a0680bae65216b40bd935e646b6364ea669a6de9b58e0cd11e1c1b86765f98ac5a3113fdc08296aa663378e8e2e44cf08db7a4ba6e5f00f21b";
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        sv.verifyBatchProof(ctxs, proof);

        vm.stopPrank();
    }
}