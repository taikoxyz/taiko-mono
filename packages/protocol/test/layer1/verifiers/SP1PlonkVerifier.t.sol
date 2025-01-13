// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SuccinctVerifier } from
    "@sp1-contracts/src/v4.0.0-rc.3/SP1VerifierPlonk.sol";
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
            bytes32(0x00dfac9a61cdc96d58296817c977da485dfdfd5cc0900b00d839dfd22a34748b), true
        );
    }

    // Test `verifyProof()` happy path
    function test_sp1_Plonk_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory sp1Proof =
            hex"1b34fe11280520b1b0825805dec273da83c5b9ca82b9c7c705bc61ba238c68d208152c7026bb3ddae13e13dd26ab7209813731305383f5342ced5984ed0c9244c32375b42d23c99c3e423a7983c4974f1a61e8bd0f76a6be5f9cb562d70a54e93d0511a225b96b0e180ffbb7f782798b5ac3c8c926d7b4e8d2a585936d96b67f094c7e7702649013cb970c69af4c2ac100eec7832fb7f42416e1d0b9addb41a805085c74081c28bc0baa90398d7bfad7fd51def40e5536448943787ab671bd27d691a81f1d388fc4491158e220262c45328c6fc9fa02a5847798c54281c8a2b25fa2e6c02bda153ed705c1d420cb68bb7b407cbf04bf721e1b0be0da60bbe84fd378b2d91c52de38a6e43ec9c2822762138bf1739fc5b6545cc68a8c4b779ef7becef09b01d52c34911395e1e051cefe8ad81d32d8c3af332bf4d1d0b2111131600aea0f01c721ec8ce6bdc5e938834cfc732b99f39f56b98a56f6a530000d6eae33442504f9cd8eda82f1c57492d2179632ae87654d4af618eaba05b93f038e329790c52355cc1de1293c05142a60e35b5b06d9cbaedf9b4c9dbdb2e02dea0768aefb8f21a2c0b6e38237ce63c2ad14a47873785dc69ef3a0e7fc89c3c183b4bc949d95177c7983905856234978ac4cbc3fc195fc8c2868496ca44bb85742e5367dc9340c41f941b67ef002a984ec84483c4ffbb1d0f6816aee6896a168f44a356c8ab30ae02fc12f5cf349a1ca21f8e068915e6201a4103134ca191eb8cd121679340e23cf7c52bed3cdae355a4a28fb7e73312df109f7db12a5ed2c5c32336f398f3b20d7cd156ff16fbc43f3aae2daee4e193a290e62ee060bf15656dbcbdc1b5e2301a7eab60766f7cbdea648012ff5e0927e15e67841563b8e496c1d2e642d7bf210d63c50a3bf42b066432d9015f1ca08154f41000e8eae64868f8d1e18d016f619532981ffc3a4a5385d3868fa09c567f237a0edaf9b4b4db8bfff3c2e2a2d1629d413fbe860363e2daf4e3c85d048a34d5164b57f2d4c5190d958617732915b28db9585dfe4d5a92dbbc3e23e0dde9b18257deabc3bdfdec0bc93cc9da60ede1c320ad60b2b4cb414a13556407792549a8eb7fa32f51e1c98ccad56fa5077932be2f5daf75e3e6c73ef38fff0f537d292bea5410dca40bac3f7fd4a3ace99cb297c1be62e5e95661215f27a702831421f611b789a59c103edebe477b532e931";
        bytes32 vKey = bytes32(0x00dfac9a61cdc96d58296817c977da485dfdfd5cc0900b00d839dfd22a34748b);
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

    // Test `verifyBatchProof()` happy path
    function test_sp1_Plonk_verifyBatchProof() public {
        vm.startPrank(Emma);

        // proof generation elf vk digest which is not a bn254 hash
        // but a sha256 hash from the same Sp1Verifykey.
        sp1.setProgramTrusted(
            bytes32(0x6fd64d3073725b56052d02f9177da4856fefeae602402c033073bfa42a34748b), true
        );
        // proof aggregation elf
        sp1.setProgramTrusted(
            bytes32(0x004d3bbf89c01e56c34beec7b553675bdad5345addf094dd79afbcae0708cae7), true
        );

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

        // TierProof
        bytes memory data =
            hex"004d3bbf89c01e56c34beec7b553675bdad5345addf094dd79afbcae0708cae76fd64d3073725b56052d02f9177da4856fefeae602402c033073bfa42a34748b1b34fe112b89047863e8359c941412fe6917b175d2f2bfcf19a15ae94a3e8507d65421411c970709a64de649185b10028c219920a9ca3f6f9c1025a0f257037c04e5ee851ae62e8cb43f445b755080b8b70c3e13e1e54498425b6ebb13bccd35f477c87c2d7ed662ef7d81081dba559aeeb68fa0b4e11d8b6f6b3950ab63af9ec5d49bc82bdfd806c3b08360bfed2f9cdace70ab0052ab1354b36731bdd1bebe4b1525cf17c7488cf82d7ab917f71b0f369f88e96fd5efc627a9747d039a0975de58311b2bf4211c68693d3538419a661f2c9fe7e4e8a8105fc1eaa1378665dad714477f0a6f71b4739c7d9d86a6ac9df2ddd42e3e887852138023a9d00cf5ae13b1252c137b9adb5c9691034ccf15f03dec77c8d9434c0e4814b766703886d3bcb87c780888dc8bcebd53fd34e51f69dcd8df122bef2c7bb5ee4fe7353dbe6d7484a4900ac4b769b883b1f6535f3248802d899a26ed9935e6958401c30c89c549deecb41534f16afd675b4076cdfd076ea7b6fcc0ec3a7e724f8dcdc9a4c5f88f8497c125479e465ebaf464e4fef5536ac9fa9a8917d1ee572429478077a2cf3371a22401fc34694210f9714ddff1028565c9ab2ee6a1bc8a95aa09b0197a5dc2a16ec32404031908a006e94e582fed32087193ee954f4e182282836c3e8b23a1e5bb740c0fcf29b797356803905e4e12c1c928b4269f034c6f92ab1da28ea09baec6de305dcf4f887d36053b6241c52bc7b4507efda81f97773bd641ed576dfeffa57218d10bd5e24720901f21327737508d58113b90ec691f93a533ddfd0a7dc9658014451083b9720245107f7f48a92f46133dd6a2b3e54907ae75dae216cd6bccfc07d62ff61f7ec17ec1b34ea98e701bfcaed544b02b54adcdb913c9d70413e70e1106bb981bffbafcb001b09cddac53edb3201ea71bd242fe1bd66233cc0adbb62fdc9efdd5f2416b3b8f7547b04bc5d172b33635f91fa6bc48f8d9dc0d400a8f194ad54bdbe815786c70c1aac3e304c2615bd7469c45165a96b7c1cab50969df114068631e8d46ae14058a6da10ef08ef8babe229e6523ffb278cd61ecd08d3f225bf2e21d411fc803adc9d281805cc5c5ecdeb086a585709c88f348b66f0ead1722d93e88b11d42098089a4ad333b7e72b1df781824f5215d73092b6f9c0e3a0e81ec5ec4f008246772e4fd61d3c1debfb8c7fbcdf1a5d0698eb3f24447c5d3";
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 0, data: data });

        // `verifyProof()`
        sp1.verifyBatchProof(ctxs, proof);

        vm.stopPrank();
    }
}
