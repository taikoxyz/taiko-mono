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
            bytes32(0x7669d1059d0dfa9537c2b3581569b8bc244495e6c406d07dea628bc8cf480392), true
        );
    }

    // Test `verifyProof()` happy path
    function test_risc0_groth16_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory seal =
            hex"50bd1769220929ac1ac3f9d3a8a4e7f4bcec136f8ea44be5a7248785d83b13879b409b762480f0ca5f38b164091e2def50b35829e453d1418492c01cc1b924e851580fe208d3808a925ce28724f0a862b944074f5277c4bd4b3153c1a1ff87056740628008fcc8d7edef53215db823e4773334e6f5fe08fed84c7ebd005fe4f42b80891724044cadde535253739049d99abc1a91a4a987ad93b0fcedbdb2440c9c2d662101509acb5f869bdb2e15d2609aa1a6c6c1a5a83e04fb2f77d25163b5675351be2204a497f20d43277d211adcc66b730b5d8d7635bb4a456cbf9029904ef2493a0346cd8e1aa2c270a160bc28bca77336bf18fe91b9dc8790a15f1618188dafa9";
        bytes32 imageId =
            bytes32(0x7669d1059d0dfa9537c2b3581569b8bc244495e6c406d07dea628bc8cf480392);
        bytes32 journalDigest =
            bytes32(0xa82287ae36a69b51f8013851b3814ff1243da5dfa071f6fd9b46b85445895553);

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
            metaHash: bytes32(0xd7efb262f6f25cc817452a622009a22e5868e53e1f934d899d3ec68d8c4f2c5b),
            blobHash: bytes32(0x015cc9688f24b8d2195e46829b3f726ce006884d5fd2760b7cf414bab9a1b231),
            prover: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
            msgSender: address(0),
            blockId: 223_248, //from mainnet
            isContesting: false,
            blobUsed: true
        });

        // Transition
        transition = TaikoData.Transition({
            parentHash: 0x317de24b32f09629524133334ad552a14e3de603d71a9cf9e88d722809f101b3,
            blockHash: 0x9966d3cf051d3d1e44e2a740169627506a619257c95374e812ca572de91ed885,
            stateRoot: 0x3ae3de1afa16b93a5c7ea20a0b36b43357061f5b8ef857053d68b2735c3df860,
            graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
        });
    }

    function test_risc0_verifyBatchProof() public {
        vm.startPrank(Emma);

        bytes32 aggProofImageId = 0x8e192ebe6872b47645367692838b2d697c467f5e4543d605b0ef7d10365fb11a;
        bytes32 blkProofImageId = 0x7669d1059d0dfa9537c2b3581569b8bc244495e6c406d07dea628bc8cf480392;

        // proof generation elf
        rv.setImageIdTrusted(aggProofImageId, true);
        // proof aggregation elf
        rv.setImageIdTrusted(blkProofImageId, true);

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

        bytes memory seal =
            hex"50bd176901a68e3f05b0e651b6e5ff18e5463be794699597908b42b9ac3195a464c2b67320fb89c8199909a5ef1ff32366d1047009f4758294090f4ce613129f64a9ff58109cf0f6cb0f22e194dab522a2938631b138f4afeb075117a05d1ad75093515e15de11d9b231b79be5d42b0c7921ba22d62a6594258745f3e5c2e10508741fd813581ea8fab28ee1d07cb1f2e84500e2993cff3ca2e37284cfb5cfec5fe301d92f4246b2dbffc17d2ef5d889f50b8f28c51d1bacd6b0c55399e574969bb0a77207ceda541460cfec3e0c315889d62c0c91c5cf0cecd515ada96712735e5cf0ea1664af11012004ba7cb6adea3751911c8afe5eb5979b1adf43da6f9c18837f3d";
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
