// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v3.0.0-rc3/SP1VerifierPlonk.sol";
import "../based/TaikoL1TestBase.sol";

contract SuccinctVerifierTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        vm.startPrank(Emma);
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        SuccinctVerifier verifier = new SuccinctVerifier();
        console2.log("Deployed SuccinctVerifier to", address(verifier));
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
            bytes32(0x00b6e596137c781eb0d53073d86d8a7ab56cffc5b5f04b5297ef2e62ac0c56bf), true
        );
    }

    // Test `verifyProof()` happy path
    function test_sp1_Plonk_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory sp1Proof =
            hex"8fd4de722cab7cfc38b19720f0152ca6311a0a907219bf8dd0c449fe0b3e919f786053d124bd3e9bf8cfa21c98cbea4a43cf70c9c96af9a867a57277a763f5d19331cb772086bb134e1a27d16405dde7b59a654d2146a7d822fa9782e461b3cb4eb272000dc4d93a25a6be5cf1006217fb4be228102117d0a317052b4dd0434482ded2021ab08599ceadcf1cc15c9348dd32ec50d2b6c4b646e0c12472b266832b269d0926a6e6b95b473aa3fdce76052ca64818631c2bcdbe603ad8f87ed0bdd01ab9a00c2e00635547b918704c8ea4b5c7d3e1e8ddf7720f1f58178d10b254ce1090e20fcbdc1f89ccfc9ff88cc25ff96ebc683eed7f9792584446f923a7b30e0d248b133655fcdba58c2c6b8f4b79f4276211df7a78ef5ce97063fed0ebcbb005d47804fd8a75f57cc5f0524ce41601dcbbbc21f73eeac25cc28ec8b66f1e03e8a7202a878463c8ac8038639e4fd211be2b095055e8f06392e0c82c1bae65f791f0c92a6e77bec5e2b62812a9060949dbcca69f714c8b0cca0272d718c9c9b5d410cd2ebbdbb9a143dea6eeb17f39115475409169245f3b61b1c46a9ea6a3296797820c8892a15001619923a972ddbbd8c7dc16df8a698b63ff84f5b34236d464ab252495aebe4902046fb4879e5ca9be9a51b26d672718491adb533ab900b40ef3e70138310b399d6c544e35d4750d3ef44cfa8b721dcff6f5c55a5587da65c1216a26550a3e35dfa4bf583b90e99b3ac051901b689b17ac0390f6e49a334c62d6f1082cda2cafad0d059e00b61173d7ce925fbea86e03c8fe76d47d98ac2090e6051f4d0528029ff31747260bdd9692dc105bd598fb4816a45ef9e13705714fcdda1c19e82a87e5dbf0caff752ce3396a4ebe6d9399c4d422285bcfff0cdf81bddf19ffeb7b405da2dceb60e661c597226eaba2e753e81a92ad19cec6510bd82de50beeff70200e2241cf7fe9d8270c9a4779480c49995d5c99cd9ae7d5c1f9acdf1b4635b78b4a2d8975ce0f587eccce699f590594d837426c5bd59fc078f811ba2717e3816f83cb191077a3ccbb5cd09adf92ff69bcbc9fcaf0fd22bc0c573750251553c7f2cec501e12761e48a9c7377e307c5202ec5707ff6b9e41b3a3085380fc07b0fed0e3abf32aaa6922d7d9649f8a13a1083fe58ccfa9501757be0e85a2ecfd9c2bbeffce6922a421a2ccdca93c7632974a8c6618558e5a33eb4d8ed1d";
        bytes32 vKey = bytes32(0x00b6e596137c781eb0d53073d86d8a7ab56cffc5b5f04b5297ef2e62ac0c56bf);
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
            bytes32(0x5b72cb095f1e07ac1aa60e7b06d8a7ab2b67fe2d57c12d4a2fde5cc52c0c56bf), true
        );
        // proof aggregation elf
        sp1.setProgramTrusted(
            bytes32(0x0041b4e466ae95d8e71c376eac1f45b8999d5eb1509b39edc12bf97521097880), true
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
            hex"0041b4e466ae95d8e71c376eac1f45b8999d5eb1509b39edc12bf975210978805b72cb095f1e07ac1aa60e7b06d8a7ab2b67fe2d57c12d4a2fde5cc52c0c56bf8fd4de721f01f0d571dab506ab0a8c4b99f357f11b4fc8b47ab97c2efa686437fc053872083c9e70147649c2fbaa5e68e77b014a024b20206b865bd3a1c28ced4d21cba41de4ac423e9fd71b6a0193f33ebb9e06805e13d95032fe8862548800823b85b3132160d62dddcc882a51c62aab4ba196f6fcf09fd0943ef8153ac99f9982f01a30052e27bb82d88f5506537c18880f36219fe17751b562ecf6e08685cdafcafe2bec9ca35246370a51e4570ee437eca2d9fd373fc26f74dc3c5658ed6fc9a5c60a2245b77dd711b1a96992551bd101a9ce764dff8704c87f95f8d4669b8bf65c25c086d160405532b0eff81477135ae6b3ef791c7539ded4f525ab0c4d0bc179029836461907f0cf3c04d681395a10c8240ced3da9d30dfabd9ef5e4adb75dda11027bad2cc8e8b4ab2648137fa9bb44e6c21ec3cff40c1e356dd9e2d0db572f2f030b9e591c91cc5210beb693fc66ce5d51ecbb23b3f24af0e0e280ea1e62a3036d2da06fdcde9a0c8db3a3773e03e1476588ff54e47543e86f7cdaf37bbaa8124b1d2544e423be363a8a07aed33b1fd242631902f91bcdcf8405e59886d9ae073a20596079eb474c33bb9d14bc8d84d9cc6033b211ddbb97039734bedaccef163c7ac8df54a7760434563ad4e90a5526e9ac1e3535707cb1cb1867aa83e6ca0ecc4fd402eda1c35213f546e3d171c9660965c08e3d5f3e4de6d0163e0a18d922d56ba61565738167c49d8b1262c48ae47d749ab7ddbd7caf8a235115649ef32817e387937415e50aecb1e4614b183d4e8813e5809100e8b36843c9e29291d21b6e3309c6f534b3e6a40443d0efee93b2fceae0e2a39e59c95dbd672dbefb1827d46c1e9794a4bea891fa3fcd8403916185369c0c94fd4e93a45f53d2fe3b3e15e8d2114f9afcb7a3863d92a3259fb315d5c0bc9ad09e887e119de3e74a49b60bb47a4d3901835087c7fd1d9686fd83f81fc1eb7d0498b1c5f9a4d299af7ded192d8fe5e012fded12f7f7238926fa8b5207220d524756c49076abaf6e8327120e7bb56699fcd13d94cb50bc01e306552db7e8af06efbb954bff76efc844da0e14952b5b8480b0522296e67a8ebc2581bf8a8c6bcb36228949b483d8ce592cd2186c2c8ea51515ae38ceaac637dc170bb9a1755cdb3d94ffdeee7d0c5f78ecb60fb12b04f1951c38a5520feffe350aeb4046a1909d478f0605933fb5edfe50d9";
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        sp1.verifyBatchProof(ctxs, proof);

        vm.stopPrank();
    }
}
