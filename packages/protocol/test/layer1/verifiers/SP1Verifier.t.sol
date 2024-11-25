// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SP1RemoteVerifier } from "@sp1-contracts/src/v3.0.0/SP1VerifierPlonk.sol";
import "../Layer1Test.sol";

contract TaikoL1Stub_ReturnMainnetChainId {
    function getConfigV3() external pure returns (ITaikoData.ConfigV3 memory config) {
        config.chainId = 167_000;
    }
}

contract TestSP1Verifier is Layer1Test {
    SP1Verifier internal sp1Verifier;
    address internal taikoL1;

    // function setUpOnEthereum() internal override {
    //     taikoL1 = address(new TaikoL1Stub_ReturnMainnetChainId());
    //     register("taiko", taikoL1);
    //     register("sp1_remote_verifier", address(new SP1RemoteVerifier()));

    //     // Deploy Taiko's SP1 proof verifier
    //     sp1Verifier = SP1Verifier(
    //         deploy({
    //             name: "tier_zkvm_sp1",
    //             impl: address(new SP1Verifier()),
    //             data: abi.encodeCall(SP1Verifier.init, (address(0), address(resolver)))
    //         })
    //     );

    //     sp1Verifier.setProgramTrusted(
    //         bytes32(0x004e167a367ef584f118c2fac6ffdda82e5349913a165703fb1895f0da412bff), true
    //     );
    // }

    // // Test `verifyProof()` happy path
    // function ___test_sp1_Plonk_verifyProof() external {
    //     bytes memory sp1Proof =
    //         hex"54bdcae329f3f04a73d0e51b60e37a3dc2eb812b6c818895fbda375c24ce943d40a1a3541655911e01acabfb1ed0a04027e641f5e492e883d2ca77a03266b485a61563fe1c751fa9821101c5e755f8963df8493e967224867963a4b459457ca1ae23b7c62e7b320dcb495d119ca771ce2030f6aeeb44c328bc03f8a892c69da84aa43ca1201baeb122781539d987fc6fd706123398a8d50f837817873890c18269c3d3dd0e782114074808a1ff3548b49f0b499424c689e4bf5d74cb876237240d6473dc1ab63fc429bee770b10527113efff5ee6f2705031d6c7370d0a60154f19e8dd20ba14bd5fd5683ac1094f7981b122d908442fa6cd1ca460ffbf49e7e162fbc0d25280c78297ab4f7026a04448422da8e376ebb2b359d6c7be1ec1a660d07dfa82ac8c2d89f04fa02cb3a86a2066188f92895f2f42dc2f6f7e5713067a14a925a02fdffdcb99f7ad1df29281d3120d1196595b53b22a386a3eae6043435445f140976aafc537cbad06c46ca5ad2b16a7da0c4bd45ac880aef87078e7347cb464f0db47c51e064400751c2f032fd0fb92d8e4cf42c5bdda442d7a3c28e3dce3bdd10d8e014089f3a9ddc8c56dd154fe487beaf0ac01e73da68271378808786e69b1b709cfdd5666f53d46c569c965ea013a17e733efa740beddb8e56183138db1723e68dc91a3c893c7d05439388d387ed0fbeb19c7e996083b39858b07762a87c21ae07df5ea0fe21cb4974dc52d4e21553864af5e7d7042bfd0703aed1cf80171006aec8456ef123dc1ae4ec805c9d301f0dfe4788a0c5c599ff7a3ed17390bb1f260665e92e3647d7b89fab2681bc7237943c4b45243f68705d53c2ce8e4c5303b8ae78d556d0c4a1efaa48aedbb7feef62a27332a462fbd4e7dff75f3df8d92ea73b5afcc5a42c1a564bcdd99f2dcfe8e0c9873fa0470753900a20f7e01bcd1b3e6c62b2f8cdbd7de3068b7f5dcbfd6c0e9a511baccef6c7adfc41dee3f2dd2bb2409707d3d21594e3f425f6f6873b5245ec7dd2473b9b14b7f80576e776f3068e65e12da6663c8fff51ab2cdf1960225945dea081c5a38231f62439ad08032e4131a32f5b70566b1b86b7fb0138d4e2497621d71b31580ec36043f2c57330190c8b7d5a408a9ca109ae6dc5b90c6f86b4c15d54d2da991591369cb03c3d9c0c5030e89f7de4a5b6e7975fad4d321b1e01863dc0dbe8d49517006c7587a38b";
    //     bytes32 vKey =
    // bytes32(0x004e167a367ef584f118c2fac6ffdda82e5349913a165703fb1895f0da412bff);
    //     console2.logBytes(abi.encodePacked(vKey, sp1Proof));
    //     // TypedProof
    //     IVerifier.TypedProof memory proof =
    //         IVerifier.TypedProof({ tier: 100, data: abi.encodePacked(vKey, sp1Proof) });

    //     vm.warp(block.timestamp + 5);

    //     (IVerifier.Context memory ctx, ITaikoData.TransitionV3 memory transition) =
    //         _generateTaikoMainnetContextAndTransition();

    //     bytes32 pi = LibPublicInput.hashPublicInputs(
    //         transition, address(sp1Verifier), address(0), ctx.prover, ctx.metaHash, 167_000
    //     );
    //     console2.log("Verifier: ", address(sp1Verifier));
    //     console2.log("Prover: ", ctx.prover);
    //     console2.log("MetaHash: ");
    //     console2.logBytes32(ctx.metaHash);
    //     console2.log("Public input");
    //     console2.logBytes32(pi);

    //     sp1Verifier.verifyProof(ctx, transition, proof);
    // }

    // // Test `verifyBatchProof()` happy path
    // function ___test_sp1_Plonk_verifyBatchProof() public {
    //     // proof generation elf vk digest which is not a bn254 hash
    //     // but a sha256 hash from the same Sp1Verifykey.
    //     vm.startPrank(sp1Verifier.owner());
    //     sp1Verifier.setProgramTrusted(
    //         bytes32(0x270b3d1b1fbd613c23185f586ffdda82729a4c8968595c0f76312be15a412bff), true
    //     );
    //     // proof aggregation elf
    //     sp1Verifier.setProgramTrusted(
    //         bytes32(0x00d5ff4ed163b73e75aa1f60c399b3c778df24abe584fc6eee1ce5c444b74bcd), true
    //     );

    //     vm.stopPrank();
    //     // Context
    //     IVerifier.ContextV2[] memory ctxs = new IVerifier.ContextV2[](2);
    //     ctxs[0] = IVerifier.ContextV2({
    //         metaHash: 0x207b2833fb6d804612da24d8785b870a19c7a3f25fa4aaeb9799cd442d65b031,
    //         blobHash: 0x01354e8725e60ad91b32ec4ab19158572a0a5b06b2d4d83f6269c9a7d068f49b,
    //         prover: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         msgSender: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         blockId: 393_333,
    //         isContesting: false,
    //         tran: ITaikoData.TransitionV3({
    //             parentHash: 0xce519622a374dc014c005d7857de26d952751a9067d3e23ffe14da247aa8a399,
    //             blockHash: 0x941d557653da2214cbf3d30af8d9cadbc7b5f77b6c3e48bca548eba04eb9cd79,
    //             stateRoot: 0x4203a2fd98d268d272acb24d91e25055a779b443ff3e732f2cee7abcf639b5e9
    //         })
    //     });
    //     ctxs[1] = IVerifier.ContextV2({
    //         metaHash: 0x946ba1a9c02fc2f01da49e31cb5be83c118193d0389987c6be616ce76426b44d,
    //         blobHash: 0x01abac8c1fb54f87ff7b0cbf14259b9d5ee7a8de458c587dd6eda43ef8354b4f,
    //         prover: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         msgSender: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         blockId: 393_334,
    //         isContesting: false,
    //         tran: ITaikoData.TransitionV3({
    //             parentHash: 0x941d557653da2214cbf3d30af8d9cadbc7b5f77b6c3e48bca548eba04eb9cd79,
    //             blockHash: 0xc0dad38646ab264be30995b7b7fd02db65e7115126fb52bfad94c0fc9572287c,
    //             stateRoot: 0x222061caab95b6bd0f8dd398088030979efbe56e282cd566f7abd77838558eb9
    //         })
    //     });

    //     // TypedProof
    //     bytes memory data =
    //         hex"00d5ff4ed163b73e75aa1f60c399b3c778df24abe584fc6eee1ce5c444b74bcd270b3d1b1fbd613c23185f586ffdda82729a4c8968595c0f76312be15a412bff54bdcae3236b956a67d15b4682d972d50fbb3632ac950bd712dad2d4cc9c302856c11e6c2ed6722fc3e4904ed204eb05a9f32bae3f8e7d4fbdd854c3d269a33e601c39c90d02026cdcdd55268090e316df3ffc0eee6de2765eb0d767f1455cd35af89da20ade1e61dc074884d5317f0206abb720acf8c023d2740b41fe37f2cb00fe561725269f4321543b30d528ee3e8884ea493fc6b1629e9a7537e65353fb0afd7e8021d502cb556e7a2b600e859f3fc524ad681df470d8d0ccc463775434ca56de661b34a3b620726aed8affc8a90d7b798a92d6500dacd9fb7d43a37c301d70e59d2d192fa85b2f6689bd9a6d47df9ea45163a228c8291e8d6d0ed5d7d7be8bd6391d6496989df139eaff5fca0f9d47eccad8ff6fb7aa0b8bb3da8e73fa4ff825d208b0ce5a639f30501f200c12f8fa1bf5c4ac42c4a58ceb34bbb3b012121f6ff31ed772d57c421a75813f987888e7e3b984bff8465bbfbdd30d45fae9904816a21c99ca4a903ed19af479d4ce0a1b4e78e2a9b3bdb8dde8986e8f028da0dd37e3129a184b4d36427d130075802421e5c693297f4705a030454b105b91f3ce8be111967dd8016ec9aed42e42ed3ab53e1dc42a0b796557e05b658203ae972378db1a109898a02ac97adfe3d5b24e1ab0d49f7702b69d137e23264e5b2c5b6e72fc2b2a4562b793a2c00ead94de8890700aa3c2fe5baf59ab8b7f524d38ba3b71712151edd00307dc3c9f24ea9d1bbac6687c8f30dbe845663f7aaddaec9df8d1fd15ced22fa58272184fe02aad68fd5a90ee249fced2ef955c0af40e02be0621e7162413e629b4428cb929d0a2bd87375dcec17664fec3a5a6cd2f7039723d41f10b77f5f3b7b052db1043c302795d3d739eecd2d2f686c2c474dcc67d9e844ca50bdabc7ac085aeb02aff0b3cbf17aaa0114ba85eff4a938d87db17680a5995a90347b2a5eccaeeb1be204a6dd83da39fe9485822667a43d4a5451f494063075007f152eeb46e0bad0675cf6219b53b36b1ca474f13f6dae87d1efad3c71f89cd05a04a6c76f6703858650a5fd6e2b45be3bf299386595d8eca6c8c55d537e8b3263828c7be68c92bdae0be0ed101f89c0c4c16154867228dc47ff0a4fccb4bb72b7cf8aa2c4a9bd4fd01254e51a7fbf680f408b5ae9c189466625b0f41636d94060e805eb6da30eab1202b65d8226918c4b99a73a6874089dbc5eac08cfab3d7";
    //     IVerifier.TypedProof memory proof = IVerifier.TypedProof({ tier: 0, data: data });

    //     sp1Verifier.verifyBatchProof(ctxs, proof);
    // }

    // function _generateTaikoMainnetContextAndTransition()
    //     internal
    //     pure
    //     returns (IVerifier.Context memory ctx, ITaikoData.TransitionV3 memory transition)
    // {
    //     // Context
    //     ctx = IVerifier.Context({
    //         metaHash:
    // bytes32(0xd7efb262f6f25cc817452a622009a22e5868e53e1f934d899d3ec68d8c4f2c5b),
    //         blobHash:
    // bytes32(0x015cc9688f24b8d2195e46829b3f726ce006884d5fd2760b7cf414bab9a1b231),
    //         prover: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
    //         msgSender: address(0),
    //         blockId: 223_248, //from mainnet
    //         isContesting: false,
    //         blobUsed: true
    //     });

    //     // Transition
    //     transition = ITaikoData.TransitionV3({
    //         parentHash: 0x317de24b32f09629524133334ad552a14e3de603d71a9cf9e88d722809f101b3,
    //         blockHash: 0x9966d3cf051d3d1e44e2a740169627506a619257c95374e812ca572de91ed885,
    //         stateRoot: 0x3ae3de1afa16b93a5c7ea20a0b36b43357061f5b8ef857053d68b2735c3df860
    //     });
    // }
}
