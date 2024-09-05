// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../L1/TaikoL1TestBase.sol";
import { SP1Verifier as SP1PlonkVerifier } from "@sp1-contracts/src/v1.2.0-rc/SP1VerifierPlonk.sol";

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
            bytes32(0x008985ad6b5f2bcf7045ae495ae7e36ec0744befcd0881ecf0c3618541f21c9a), true
        );
    }

    // Test `verifyProof()` happy path
    function test_sp1_Plonk_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory sp1Proof =
            hex"616a42051d0b264598d3ce80b077e8e5d3d6209834817c3d5cc6ae9ef9282129999978a3262175276ff5cb3072fe862a210a50f81e7d8684944202c3a19672ad87bfb4a81699105748fa8516cce7c817e72717cf91cba986e01c82f72cbd3e0a5b18f9540ccde87997b79148c1c19689afa2d67b701b9d3705d93f39912a9e956016d7d027112ae07e51b658a565fde7c21b03d1ebd799f9fb92680cba9ed7903a690fc10b03b6b8bc3f29d487533ca9aecc762ddc297e0f54d2290038bb7673a3867e1217c52471a108298e34cb25ae15082832cf4ddc6ca13e3fe418c391e9ea053738116833c96667052033452ee4e97baf77acabf21673a7d650a84866124122e493256a9f1679db2f46c0722267a16efe6ba1ef6a0bf105f973ef6b5d98e0236a6c1e74c4c7c984fe7a61f89b9dd739c3a43947b44835202afe54bdef012e0945a22569c82f420ebd0e08b3552d1b07e15e7cd81a33c55fb12f3c83ebc114d25a5527b2f9a20ed48a5e8dbaeb000b21a7106f0d2538278d985a619fc2074999e79512adce8bbe362113c965400a8127f85543f909d6f65a909ea0e5bb7a6e867ed3261111ea8b12c041df1d70e02aa42b9fe30be06265d02ff4f0d29545c22339430c5164fd0496b03fb5ce39f4518402251450a2ebca06d1209a570e859702ff552bc7bae5b3118017bea5569dfc6188fe5442236fd0330879076ed37313cc04be11386895c911c06b72b63785656050e9858975a9b5280a89cf3edc109130619718159eeeb77a1b48773a0a0df65170aefdd3a82858ac729ead3aa0918b52a7f101ec6ee3baccbc890bed38622a157541153167dd5f497bf8778c886508bc172a179618294af48fcc69354c93f013e06666fe26b5006729a03728a7ddc319f66600b0bcdece21a82072b2a2036a97246f101138ee19cf39a90d24fb5f12f0c40b1aa9ccd2a70c96da3af9bc9b76cdbd37054291c9ee6974c9d40089bf68d525a612e992cf3de3acf7feb072b928852bfaf50d6c69c7672a08ed15d1bbcfaff22a0277ea85becd001bf9df5589050e71d8ee11e6d13b63365f445377aebcec33140d4b5ff2150633f2d1edddfe100a42f81b25f22fd667180056607c34fb808a7125b16ae2fb907f5629b987eb596377ff1e3e42042b9e14741e258c17d14e1ae91f178226c8b10798b84a7c5a93b282a7b6115f568cebf95c15b47e7e084d031c";
        bytes32 vKey = bytes32(0x008985ad6b5f2bcf7045ae495ae7e36ec0744befcd0881ecf0c3618541f21c9a);

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
