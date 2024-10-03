// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SP1PlonkVerifier } from "@sp1-contracts/src/v2.0.0/SP1VerifierPlonk.sol";
import "../based/TaikoL1TestBase.sol";

contract SP1PlonkVerifierTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        vm.startPrank(Emma);
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        SP1PlonkVerifier verifier = new SP1PlonkVerifier();
        console2.log("Deployed SP1PlonkVerifier to", address(verifier));
        registerAddress("sp1_remote_verifier", address(verifier));

        // Deploy Taiko's SP1 proof verifier
        sp1 = SP1Verifier(
            deployProxy({
                name: "tier_zkvm_sp1",
                impl: address(new SP1Verifier()),
                data: abi.encodeCall(SP1Verifier.init, (address(0), address(addressManager)))
            })
        );

        sp1.setProgramTrusted(
            bytes32(0x00851c6ce0153ea4f7a6b8f9923ae1ad15d47476925777f4375d1a4b13137231), true
        );
    }

    // Test `verifyProof()` happy path
    function test_sp1_Plonk_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory sp1Proof =
            hex"4aca240a1f6e9f5f6927e5468a58a7ca24addf975aacc9293e89729bbb84f814725c911c2488230b0922c072f3261a6480dca80af7d3f1ac54aaef2d1929f06a89f92cb71fd0f2015f1bf32ae904e221d342e1efcbd2b1f2275acda3e2dc1e779297937903643bcbbe5a4f7261d091c264d47810e1a5ca2e1ba20b7b1b069567d3ba895d0e088f70848009522bb67c39c108eb1b29272902fbb5d18bb74b5c4085569879188b5c8f0730da420f6da4e656b66eb9a7ce01da7aff3efe9033e02df0549dc214195b64ca178b9e50b2b35c8449eeeef60a6a0056d9c6a525d5684a544088322a14f46d15740fe42ba83c8c6c57548c415610a545d6b2c7b4146a76a2c957ea2a1975915e864e420c006176e00e6ed26810e80d5c6cec4143daa50b61ec0cb207661ad396db21744b713c0454d78752e5e6eee2e9f5273f30322461fa32b2932d7c8a467de8fac07d8363238245369f3bd196e443ff90aec1754537019eaa4928ab7b0a34d973a5c15123d2820923153f47c0b742ebf1e8d952626a77aa957804446347f03aee26e4bddadba1a3b0f275b7271ff1cbcca1ca0756e22113165f2d0472fc2ac3fa2b4593b472c3333cef81bde5fddb31fed8a52fb450de3b74cd0ab415777a733c22d1aab02d794dac192ca2d3088a7b379dba8896c842bf599d15ab8792e980773a131bfdaa0ab4ff7dfae9c98fb5d6774a8007c3927ffd99ce1acd527de2273f9c1163019cfca98e9bea7a56ff0ca0e8cac93c2096860f6aff14ec69181f6554bca186646d1002a8c2ac0fbdde5d4440242360bb9344399a6429bebc7f97f56090217c091b0e655579d598e3979a1acc8a516cfee2dd43c3341c81a4163221e6a4980fdfb2af09d30c9fa18ad3fb9d10bf4d35fe48663dc597277c25927396fb8d8501b3829f8eccc672515d2a249dec90057d3fe53ca105851257092388f2823fecbf09a8ae35e4e0dcf0ec615366a4db47b7d7e1af480a431957268d2e5283a690f9168c215d481e07188c7bfd5bd227d034d74a035119410eb23b74bd2fb0711eefb7502fc61119161d207c42e88cf73640719305a753052f8665d2222b4ae696fa541c99ffcc9c38153a46675fbdf596d00104b4b0b41708da9b30c70462422bba87bdc2b011a8a302649b7249250ce71793cedfb3f5db1622a7ec48ba7ed576f9ced6b2c9c661e9bed64e6f484f1862b0cd71be2aa628";
        bytes32 vKey = bytes32(0x00851c6ce0153ea4f7a6b8f9923ae1ad15d47476925777f4375d1a4b13137231);

        console2.logBytes(abi.encodePacked(vKey, sp1Proof));
        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encodePacked(vKey, sp1Proof) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _generateTaikoMainnetContextAndTransition();

        uint64 chainId = L1.getConfig().chainId;
        bytes32 pi = LibPublicInput.hashPublicInputs(
            transition, address(sp1), address(0), ctx.prover, ctx.metaHash, chainId
        );
        console2.log("chainId: ", chainId);
        console2.log("Verifier: ", address(sp1));
        console2.log("Prover: ", ctx.prover);
        console2.log("MetaHash: ");
        console2.logBytes32(ctx.metaHash);
        console2.log("Public input");
        console2.logBytes32(pi);

        // `verifyProof()`
        sp1.verifyProof(ctx, transition, proof);

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

    // Test `verifyBatchProof()` happy path
    function test_sp1_Plonk_verifyBatchProof() public {
        vm.startPrank(Emma);

        // proof generation elf vk digest which is not a bn254 hash
        // but a sha256 hash from the same Sp1Verifykey.
        sp1.setProgramTrusted(
            bytes32(0x25a022bd2d3ceba748620b63401e94bb156f195a0dc2cf445c2bdfc20358d393), true
        );
        // proof aggregation elf
        sp1.setProgramTrusted(
            bytes32(0x000b55d1eea2d844974b3449118e4221bdf44534897d530dd9ae54201a36ad97), true
        );

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
            hex"000b55d1eea2d844974b3449118e4221bdf44534897d530dd9ae54201a36ad9725a022bd2d3ceba748620b63401e94bb156f195a0dc2cf445c2bdfc20358d3934aca240a294f40587144c884ce9b2326d1b8e002218abeb9535dbfb27fde012f1eba3fba17ee609acf6acf73790d3063da18707342809998f3d8db3fcd5d094b29bb48d22ff04e45f4de3c6026cd67256e45ca562e786db8b36d51c1c5f2f862c993e38f0851ef22ac10ea44ae5b62899650d8a8bc76a983caef459e88c514e1cbd34aea1b6f71f91410d6365b9e635cb4c56b1f6b98eb883d7815273d49fff1c5a4addb0cca4a2f394210ff2d7fc1c33059201a663c9f38f01ef198ef345d4d3d3810b70c99d241029c4a099d3f5ab3b6f5602e04344cc55c821f97fcc163dd472b252119f2940b56f0eee79a0fd5062b20c3445c79d70c773d69abaeced5b68c25f5ae1c385a7f9e8d4c2bc24f9627fa814d8269f2cf73f704b3c46ea8dd0219d41db81e1dc0ac4f62d8d6b8715c5b1637d160c67cde18ee3c66c860830297cc875656120418336954c73523765728f31a0a0bdbf630ad9d937ddf9a1f8dbf88ca281a280e466fe7f8fe8c000826c01930b0d6af20210003b5eac307cd107dff2239340b36e4cbe03ffa0e3bf434aea3252b9b05504321916ac8110f83de55bc9635c62cb569714ad44343866aa1e60e3dd93c4789c0ae94207861bf09838f83cb32a9033d94d3a4d674fcc435cd1b86afd5260c0f6d1501737120d070b950aff9ce5e2821b54d7df5bc8fb28e4f4312f217e9bca61bde4b57cda1075f7bbaedbc259b0f6c6e92661ad9404e0bcb3f15b9839f09fa87d278c2f0f9d99e7eea9ff1f7f023b455edeac48de876a7943796ffba85f3bf1c662081e7e563255f4c268e8711123094ccd2d38b1d3f1ce2c485529b26ab6372fbc3638ffec3aeff657f21a8cf13152c305d2fb084234246dbad615832e98b8c63e8fe582a6fad6efb41642c0018100a1b2f3e2479cb09eaf1d86e530ad63d1d117430a87dcae5182540ad05fd1a17cd482143e3d18c0c82554c71b16c1a62cbad06037c0c61b9894717e681b12e42a110b132225dd8af852412f687ec229710fe17db56c28aad002d5d1313762864a7e8d79b65b9f59f3adcba9c82b891721f7c488d482d5b715f059e3d299602ea0e25424ef254362ac70781e66d35349755e76683c045f4824a6c3b38a9481ace0378d91f74a89cf1138c78f676a1a72931469f8016d9fe1246ae2ccf83422cfeb943fee210a39abcd0551f545f6929fce1722585de936142b2fe1736ccec";
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        sp1.verifyBatchProof(ctxs, proof);

        vm.stopPrank();
    }
}
