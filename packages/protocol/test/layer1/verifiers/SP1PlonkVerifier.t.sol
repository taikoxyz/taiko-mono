// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SP1PlonkVerifier } from "@sp1-contracts/src/v3.0.0-rc3/SP1VerifierPlonk.sol";
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
            hex"000b55d1eea2d844974b3449118e4221bdf44534897d530dd9ae54201a36ad9725a022bd2d3ceba748620b63401e94bb156f195a0dc2cf445c2bdfc20358d3934aca240a13f0480dfbc197dbe9697d43442397ea1ad15495c4fd4a8d33ffb7fb74f132d7111a770ef85bcb97f6c0843c2203d98a16e3c1aa65c40908bfd8f2238b84a4e32c18d1100cd5ae14f11c795eb13ad1e9250ddbc024b6a521955985912a998e2d057edf8ca1f9fe5fb0c09d50c37cb84ee607c1e8a2b5ff1646f0e2c59b87669c17fcc4f81d9dd6179e906407f41a31a80008ea91479d3f2b2dcf0814827fcc6c20de92778e179dee9e88b364176fbfcf54f9a9042de7735c7fa3892ca87c80b42ba0ad7926e6d096908cb482aa02783844e1cc6a45a93b2664cf76259d76833e081139997b00ede54f9cdaed18ac74646aef6be33f5021f147c8baf8b6947af800d66e46d2b6f34a01c02d30403d186d44ed967761736b8963e1fe5a9745da7007e513800c0c5bf10d21eb35182a8e512158618af3350134a4919623b72427fa29ca8b4602e2dd8d1bdb930a91417a562c497e3960dd6abd84d0157060c668d6145c9580e1420459cf54bd92b84a33cea97d356ea1e61cb689750b0dff43aace1e4b92cb5241826e62974fafc377158d86c3bcf12e385ca7906b9b5b40d62fb81f1fc860bed8e96e2bf420b88d5184420e58de52cfa9602c74680d977f9a7eee2f7fdc97d7bba9431ad61de9743321697c1fe1993012ddaf1f82315e1a12f22728bd881154ba9e473032a4576eb5bae4d565eda97c8661bdfe26840cf1922f8e1edbe17403c5a4e7a7b6b020806b572457b0eaf78e9d3cf241e0c724fdf0bbd00dbe4235ba34708e1d0abaff5c49a161466fbf1c3ea8aeee6ae8e12395c1e382085cd9383c5c5c45fde6e1fdffc1a5ac68c094ae5ac487fe3e542f16afe7b5571f48b078e579c22ce759e9b8e6ec546770c9bd0092f3a0982d4ae06eb54f66d729f7c36b8ac9ae66ee9f39dacd2263075e297145cdb103246668feb30f1fd61b139327e50649e850642237cb2365cbb8a8d94acd238aca0e9fcdf018eb51d96c22769e67a62d74e1ccf96f0eb8a443ec80b7eb320aba5cbbb9e13d24963a999b17a4742ccc581cc81cc27529c826f23ce9f9a0a80a87ecfad395e752f925825d1af4a83ed18f3741dfa0d3fe966df42d3a79a29d9feeaa14ed97478fc800c4e41b4c36bb135ba7cb7d9dae4df53c7ae0e991c9e6251f416da0c7be07e3dd481c14d6926a64bb1547f05c588ce314e980c3a5203ec38cecb6bd1f40a0c8a43f18";
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        sp1.verifyBatchProof(ctxs, proof);

        vm.stopPrank();
    }
}
