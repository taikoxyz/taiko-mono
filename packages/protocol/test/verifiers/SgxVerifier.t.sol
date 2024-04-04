// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1TestBase.sol";
import "../automata-attestation/common/AttestationBase.t.sol";

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
        emit SgxVerifier.InstanceAdded(startInstance, instances[0], address(0), block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(startInstance + 1, instances[1], address(0), block.timestamp);

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
        emit SgxVerifier.InstanceAdded(
            startInstance + 2, instances2[0], address(0), block.timestamp
        );
        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(
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
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
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
        vm.expectRevert(SgxVerifier.SGX_ALREADY_ATTESTED.selector);
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

        vm.expectRevert(SgxVerifier.SGX_ALREADY_ATTESTED.selector);
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
        emit SgxVerifier.InstanceAdded(id, newInstance, KNOWN_ADDRESS, block.timestamp);

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
        vm.expectRevert(SgxVerifier.SGX_INVALID_PROOF.selector);
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
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        sv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    // Test `verifyProof()` call is not taiko or higher tier proof
    function test_verifyProof_invalidCaller() public {
        vm.startPrank(Alice); // invalid caller

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

        uint64 chainId = L1.getConfig().chainId;
        bytes32 signedHash = LibPublicInput.hashPublicInputs(
            transition, address(sv), newInstance, ctx.prover, ctx.metaHash, chainId
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KNOWN_ADDRESS_PRIV_KEY, signedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory data = abi.encodePacked(id, newInstance, signature);
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 100, data: data });

        // `verifyProof()`
        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        sv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }
}
