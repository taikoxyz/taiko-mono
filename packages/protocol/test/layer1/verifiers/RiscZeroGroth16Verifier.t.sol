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
            bytes32(0x4f6beb0c538971a81491c22de3995c82e6fd7938d5090366d7b618d5f6df504d), true
        );
    }

    // Test `verifyProof()` happy path
    function test_risc0_groth16_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory seal =
            hex"310fe59815ffa3b596af0bdccd0aaa064495d5db94fe367414d3a9212c8ce17383717e531ced511d89956c7c8aa0cc8531dac8660093581c5ae19c48a39fc14fd98dc1050684083592dab0fd9a2482c47ab4833c4f9b9a6770a7ce439a4f0e94bc035809138a7566873e34d202708ce4858665202417e645aeb299d4f7633fead7c667562b9104bdc79a0c379145ca2431598beec20b75a722915ff0a872771652583f9206e75bd317e73b1af7705f70aa52c30bc33ea6792b9e080177502fe074b87beb1add2ebe112c7bd17667a418fd9ef6d8e89e606c5efff14b5df24f7aa40c5c4f2bcaaa6f206d2d1e15356c533c5210258a6f1b1d1d22cb63cff0323863d7fe3b";
        bytes32 imageId =
            bytes32(0x4f6beb0c538971a81491c22de3995c82e6fd7938d5090366d7b618d5f6df504d);
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

        bytes32 aggProofImageId = 0x83e7411adcc296e0a021ff032a868434aa2a519b9d11ad44d11d443832280b44;
        bytes32 blkProofImageId = 0x28879b90699846864c97f8f32e1b12aabd8ce13135302345d6ad242fa81ab40d;

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
            hex"310fe59810425afc4ed2bae56dfd76e9045f6cd41da30ae8f07a239e86fdb157bf37b0f51b937cb8deccab0d201623d530d0800c208f66dad3f6a38bc1df34408994dec1179209a5f94411e015b20e723512150cfb7e295debeb7ef4f8186cddcf19ba6527ee0d2a0fb8825568682a2fe48e2f73fe9fa052379824751c3bd3f1353f44fe1857e07f5b4801846637b68eafb93aba0c8de8fdfffc76af62a513966f92d9750a977bce0568eb7438fa3497848bfce3e5fd815d9c24b4600e12d0d405d1fd76301ccf27547bddd49a2fa12d1a414f49c2030d0cdf29a87684964a171eefb7e82a5f86acbaacd8cd24d6c3bab06a568f4869087e825ee79237770f23315f3c5c";
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
