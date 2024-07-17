// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../L1/TaikoL1TestBase.sol";
import "../../../contracts/thirdparty/risczero/groth16/RiscZeroGroth16Verifier.sol";
import "../../../contracts/thirdparty/risczero/groth16/ControlID.sol";

import "forge-std/src/console2.sol";

contract RiscZeroGroth16VerifierTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        console2.log("Deployed RiscZeroGroth16Verifier to", address(verifier));

        // Deploy Taiko's RiscZero proof verifier
        rv = RiscZeroVerifier(
            deployProxy({
                name: "tier_risc_zero",
                impl: address(new RiscZeroVerifier()),
                data: abi.encodeCall(
                    RiscZeroVerifier.init, (address(0), address(addressManager), address(verifier))
                )
            })
        );

        rv.setImageIdTrusted(
            bytes32(0xc600106390ac1814f9412767b035e2dc67e579579cfef2027e783607c6280d68), true
        );

        registerAddress("risc_zero_verifier", address(rv));
    }

    // Test `verifyProof()` happy path
    function test_risc0_groth16_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes memory seal =
            hex"310fe5980dc2781dc78d77dfdf0156420de674d1e728280666c83e5b455cb113fbd68b671cf01ecb0b534f3587eca0132f1fde91949743cdcb9a8d41874c02270a2084a60662d42262ca2d94c80f8b782fb7b7523221e2af52c3068458de46a4086666b71b65d9ad500fef9a163f174b1333938eaa284b31d007492d031423e0690938de188cfb8cf429a92ae4c0cea02955b8568648e25fc2e8a60ad100d1c4661d448d0069ee64bb884482eb4bb24f553dbbdfd0b14c84c617bdef8d975ea64faccd5d12ab645e0d08f00a70b2366b25c266e819f4d1195d355fabc649a893dc4321ec0db7befe3958f4610a48bd6d9154fb178c5dd6348aea1ea8e19b71e91eb5c216";
        bytes32 imageId =
            bytes32(0xc600106390ac1814f9412767b035e2dc67e579579cfef2027e783607c6280d68);
        bytes32 journalDigest =
            bytes32(0xe91e7cb555e4d763d6ee32ca72491aca1ecd27f0d303edf383bd7bbe4aa9db6f);

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(seal, imageId, journalDigest) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _generateTaikoMainnetContextAndTransition();

        uint64 chainId = L1.getConfig().chainId;
        bytes32 pi = LibPublicInput.hashPublicInputs(
            transition, address(rv), address(0), ctx.prover, ctx.metaHash, chainId
        );
        bytes memory header = hex"20000000"; // [32, 0, 0, 0] -- big-endian uint32(32) for hash
            // bytes len
        assert(sha256(bytes.concat(header, pi)) == journalDigest);

        // `verifyProof()`
        rv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function _generateTaikoMainnetContextAndTransition()
        internal
        pure
        returns (IVerifier.Context memory ctx, TaikoData.Transition memory transition)
    {
        // Context
        ctx = IVerifier.Context({
            metaHash: bytes32(0x291188ef31a9d3ee9590101f851a8787611a5c6675ad9508f4e473ce8cd61d7c),
            blobHash: bytes32(0x015f83d7ebd6984efe66d2bc86d8294a6ac72f8b59e4eb995bfaf9791b03149c),
            prover: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
            msgSender: address(0),
            blockId: 122_224,
            isContesting: false,
            blobUsed: true
        });

        // Transition
        transition = TaikoData.Transition({
            parentHash: bytes32(0x6c51441b4749eb1fa87dc032c630be200ac317454b8e03081ae467401d31aa03),
            blockHash: bytes32(0xd8bdb8642a72e2b45e5a1702fd8762c9fbf1174c36a13941ce8c322e4d780360),
            stateRoot: bytes32(0x46bec7406eca597ea09434fdd4f1e214d96eb9eeaeaca57e642e0ce29cc39729),
            graffiti: bytes32(0x8008500000000000000000000000000000000000000000000000000000000000)
        });
    }
}
