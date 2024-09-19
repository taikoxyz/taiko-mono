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
}
