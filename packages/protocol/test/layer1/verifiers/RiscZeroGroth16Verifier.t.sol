// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import "@risc0/contracts/groth16/ControlID.sol";
import "../based/TaikoL1TestBase.sol";

contract RiscZeroGroth16VerifierTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        vm.startPrank(Emma);
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        console2.log("Deployed RiscZeroGroth16Verifier to", address(verifier));
        registerAddress("risc0_groth16_verifier", address(verifier));

        // Deploy Taiko's RiscZero proof verifier
        rv = Risc0Verifier(
            deployProxy({
                name: "tier_zkvm_risc0",
                impl: address(new Risc0Verifier()),
                data: abi.encodeCall(Risc0Verifier.init, (address(0), address(addressManager)))
            })
        );

        rv.setImageIdTrusted(
            bytes32(0xb0e5cbad30f8da6180a9dd768b5de54062164916f0410b0b124a0039d503f997), true
        );
    }

    // Test `verifyProof()` happy path
    function test_risc0_groth16_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory seal =
            hex"c101b42b17dda9eca78d0abdda89996306aecfda823f4fc36866a6aef87a34bc16b64762001401e2c9b09ad1cff495bf746ea4a90c804a144586567ace502884d515153d04ca12eea43e7229f34ed46b75671be7cf38e1bcfc5c571fb53eea3ea7ca0a8c12eec0fb244c4950f4fcd34dc2351d5e0d4eeb9c95b795b0415faa472ae07b1b0552b134c1685ca7049bbfc150661f51d5a87b2eca5adfee1de5fcb0ec06f6ca07c16b54b351302086344c99e84093baf17112d8da40db21ad2d43d8670858982717a58b1522ff88a357d2dc6aa5dc1a3361d756587690d3fbdec6f68dade6a3191ce759e321f17aeb839396afa261eb8aa4935a0d476a6e9a6c4d20c817b1a0";
        bytes32 imageId =
            bytes32(0xb0e5cbad30f8da6180a9dd768b5de54062164916f0410b0b124a0039d503f997);
        bytes32 journalDigest =
            bytes32(0x0eac04720f08f4c696e4860fcad2ba8074ffda3d90fa85954d4d83dfdecddc3b);

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(seal, imageId) });

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
            metaHash: bytes32(0xa0c8136633dff06ad1f03ed6fbb277096e6cae13f39e02ac1cff397b22aafeac),
            blobHash: bytes32(0x0143051e11b9886c061ccb939bf7317cee20378f0d3ac8d1930140f1ba42d99f),
            prover: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
            msgSender: address(0),
            blockId: 749_050, //from mainnet
            isContesting: false,
            blobUsed: true
        });

        // Transition
        transition = TaikoData.Transition({
            parentHash: 0xaa47a56db9be323d923a56002612b168ba73621a98269835e768ec48799fcc95,
            blockHash: 0x405a8978474fbe72d40fa4e2fc6b2edfcc0d439002c6d941ac1385a5a349535d,
            stateRoot: 0xadbeff96af5a990b979135850926fdd7c0d9c5af967e12e60d7b2a473fcf04c9,
            graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
        });
    }

    function test_risc0_verifyBatchProof() public {
        vm.startPrank(Emma);

        bytes32 aggProofImageId = 0x20187e43c11a55330ac17a93299245e34fe0d641e35bc46f77768b60e7779a3a;
        bytes32 blkProofImageId = 0xb0e5cbad30f8da6180a9dd768b5de54062164916f0410b0b124a0039d503f997;

        // proof generation elf
        rv.setImageIdTrusted(aggProofImageId, true);
        // proof aggregation elf
        rv.setImageIdTrusted(blkProofImageId, true);

        vm.startPrank(address(L1));

        // Context
        IVerifier.ContextV2[] memory ctxs = new IVerifier.ContextV2[](2);
        ctxs[0] = IVerifier.ContextV2({
            metaHash: bytes32(0xa0c8136633dff06ad1f03ed6fbb277096e6cae13f39e02ac1cff397b22aafeac),
            blobHash: bytes32(0x0143051e11b9886c061ccb939bf7317cee20378f0d3ac8d1930140f1ba42d99f),
            prover: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
            msgSender: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            blockId: 749_050,
            isContesting: false,
            blobUsed: true,
            tran: TaikoData.Transition({
                parentHash: 0xaa47a56db9be323d923a56002612b168ba73621a98269835e768ec48799fcc95,
                blockHash: 0x405a8978474fbe72d40fa4e2fc6b2edfcc0d439002c6d941ac1385a5a349535d,
                stateRoot: 0xadbeff96af5a990b979135850926fdd7c0d9c5af967e12e60d7b2a473fcf04c9,
                graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
            })
        });
        ctxs[1] = IVerifier.ContextV2({
            metaHash: 0xd385182abb3db17267b32b4e475c5ed9306f52107a8f8cc5309f13af0af3b2a8,
            blobHash: 0x0181040be344c40efb3f4cfd9df5ba02c8474e6c18e15d959ab345de1ee264b7,
            prover: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            msgSender: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            blockId: 749_051,
            isContesting: false,
            blobUsed: true,
            tran: TaikoData.Transition({
                parentHash: 0x405a8978474fbe72d40fa4e2fc6b2edfcc0d439002c6d941ac1385a5a349535d,
                blockHash: 0x8547cf9c2eb9ead5ab55c02d92b9f712ebbc6bbf92915869609016779bf302ef,
                stateRoot: 0x5c37ab91105743f67e5508ae8f4f6f01c44a4ad21da52637bbaf792eba57cf66,
                graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
            })
        });

        bytes memory seal =
            hex"c101b42b090030000272654103ff692da743560878ebc23d2fca58bf4800e3a033d6bb54100b09e9014094a7753c1d6cf3240275586892e426bd9ba4adfa80eb8e6c9d1211537ace36bd515c7844e1dff10b6a9d5afd34782bf877933422d434ba0de96004c54c33937c3b2c5f5cfbe894db673f9608441ff4c35fb440b4b74f8a7cbb1e17ba492db492506c7296bd68711a47a64e10cb63eb7416638f86570a918fccd027a15077e094b275e7f635fea0dd0b86f4606fc3ee32614ff9bb13553abb3f9415965e2967c8fd2786e8dee68871705fe2ecdda24e26756a915b9cd0e9dff0032e04ed383c451e89aa59583219b96fce51f3832ec2faee8a02f43cabda100e1b";
        // TierProof
        TaikoData.TierProof memory proof = TaikoData.TierProof({
            tier: 100,
            data: abi.encode(seal, blkProofImageId, aggProofImageId)
        });

        // `verifyProof()`
        rv.verifyBatchProof(ctxs, proof);

        vm.stopPrank();
    }
}
