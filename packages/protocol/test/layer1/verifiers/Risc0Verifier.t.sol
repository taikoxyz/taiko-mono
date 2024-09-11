// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoL1TestBase.sol";

contract MockRisc0RemoteVerifier is IRiscZeroVerifier {
    // To simulate failing and succeeding
    bool public verifying;

    function setVerifier(bool _verifying) public {
        verifying = _verifying;
    }

    function verify(
        bytes calldata, /*seal*/
        bytes32, /*imageId*/
        bytes32 /*journalDigest*/
    )
        external
        view
    {
        require(verifying, "RiscZeroRemoteVerifier: invalid proof");
    }

    function verifyIntegrity(Receipt calldata /*receipt*/ ) external view {
        require(verifying, "RiscZeroRemoteVerifier: invalid integrity");
    }
}

contract TestRiscZeroVerifier is TaikoL1TestBase {
    MockRisc0RemoteVerifier riscZeroRemoteVerifier;

    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        riscZeroRemoteVerifier = new MockRisc0RemoteVerifier();
        riscZeroRemoteVerifier.setVerifier(true);

        registerAddress("risc0_groth16_verifier", address(riscZeroRemoteVerifier));

        // Deploy Taiko's RiscZero proof verifier
        rv = Risc0Verifier(
            deployProxy({
                name: "tier_zkvm_risc0",
                impl: address(new Risc0Verifier()),
                data: abi.encodeCall(Risc0Verifier.init, (address(0), address(addressManager)))
            })
        );

        rv.setImageIdTrusted(bytes32("11"), true);

        registerAddress("risc_zero_verifier", address(rv));
    }

    // Test `verifyProof()` happy path
    function test_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes memory seal = hex"00";
        bytes32 imageId = bytes32("11");
        bytes32 postStateDigest = bytes32("22");

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(seal, imageId, postStateDigest) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _getDummyContextAndTransition();

        // `verifyProof()`
        rv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function test_verifyProof_invalidImageId() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes memory seal = hex"00";
        bytes32 imageId = bytes32("121");
        bytes32 postStateDigest = bytes32("22");

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(seal, imageId, postStateDigest) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _getDummyContextAndTransition();

        vm.expectRevert(Risc0Verifier.RISC_ZERO_INVALID_IMAGE_ID.selector);
        rv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function test_verifyProof_invalidProof() external {
        riscZeroRemoteVerifier.setVerifier(false);
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes memory seal = hex"00";
        bytes32 imageId = bytes32("11");

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(seal, imageId) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _getDummyContextAndTransition();

        vm.expectRevert(Risc0Verifier.RISC_ZERO_INVALID_PROOF.selector);
        rv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function _getDummyContextAndTransition()
        internal
        pure
        returns (IVerifier.Context memory ctx, TaikoData.Transition memory transition)
    {
        // Context
        ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: address(0),
            msgSender: address(0),
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });
    }
}
