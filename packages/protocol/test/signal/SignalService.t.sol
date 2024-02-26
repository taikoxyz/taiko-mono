// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";
import "forge-std/src/console2.sol";

contract MockSignalService is SignalService {
    function _verifyHopProof(
        uint64, /*chainId*/
        address, /*app*/
        bytes32, /*signal*/
        bytes32, /*value*/
        HopProof memory, /*hop*/
        address /*relay*/
    )
        internal
        pure
        override
        returns (bytes32)
    {
        // Skip verifying the merkle proof entirely
        return bytes32(uint256(789));
    }
}

contract TestSignalService is TaikoTest {
    AddressManager addressManager;
    MockSignalService signalService;
    uint64 public destChainId = 7;
    address taiko;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, ()),
                registerTo: address(addressManager),
                owner: address(0)
            })
        );

        signalService = MockSignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new MockSignalService()),
                data: abi.encodeCall(SignalService.init, (address(addressManager)))
            })
        );

        taiko = randAddress();
        signalService.authorize(taiko, true);
        vm.stopPrank();
    }

    function test_SignalService_sendSignal_revert() public {
        vm.expectRevert(SignalService.SS_INVALID_VALUE.selector);
        signalService.sendSignal(0);
    }

    function test_SignalService_isSignalSent_revert() public {
        bytes32 signal = bytes32(uint256(1));
        vm.expectRevert(SignalService.SS_INVALID_SENDER.selector);
        signalService.isSignalSent(address(0), signal);

        signal = bytes32(uint256(0));
        vm.expectRevert(SignalService.SS_INVALID_VALUE.selector);
        signalService.isSignalSent(Alice, signal);
    }

    function test_SignalService_sendSignal_isSignalSent() public {
        vm.startPrank(Alice);
        bytes32 signal = bytes32(uint256(1));
        signalService.sendSignal(signal);

        assertTrue(signalService.isSignalSent(Alice, signal));
    }

    function test_SignalService_proveSignalReceived_revert_invalid_chainid_or_signal() public {
        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        // app being address(0) will revert
        vm.expectRevert(SignalService.SS_INVALID_SENDER.selector);
        signalService.proveSignalReceived({
            chainId: 1,
            app: address(0),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // signal being 0 will revert
        vm.expectRevert(SignalService.SS_INVALID_VALUE.selector);
        signalService.proveSignalReceived({
            chainId: uint64(block.chainid),
            app: randAddress(),
            signal: 0,
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_malformat_proof() public {
        // "undecodable proof" is not decodeable into SignalService.HopProof[] memory
        vm.expectRevert();
        signalService.proveSignalReceived({
            chainId: 0,
            app: randAddress(),
            signal: randBytes32(),
            proof: "undecodable proof"
        });
    }

    function test_SignalService_proveSignalReceived_revert_src_signal_service_not_registered()
        public
    {
        uint64 srcChainId = uint64(block.chainid - 1);

        // Did not call the following, so revert with RESOLVER_ZERO_ADDR
        //   vm.prank(Alice);
        //   addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AddressResolver.RESOLVER_ZERO_ADDR.selector,
                srcChainId,
                strToBytes32("signal_service")
            )
        );
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_zero_size_proof() public {
        uint64 srcChainId = uint64(block.chainid - 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        // proofs.length must > 0 in order not to revert
        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](0);

        vm.expectRevert(SignalService.SS_EMPTY_PROOF.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_last_hop_incorrect_chainid() public {
        uint64 srcChainId = uint64(block.chainid - 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        // proofs[0].chainId must be block.chainid in order not to revert
        proofs[0].chainId = uint64(block.chainid + 1);
        proofs[0].blockId = 1;

        vm.expectRevert(SignalService.SS_INVALID_LAST_HOP_CHAINID.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_mid_hop_incorrect_chainid() public {
        uint64 srcChainId = uint64(block.chainid - 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](2);

        // proofs[0].chainId must NOT be block.chainid in order not to revert
        proofs[0].chainId = uint64(block.chainid);
        proofs[0].blockId = 1;

        vm.expectRevert(SignalService.SS_INVALID_MID_HOP_CHAINID.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_mid_hop_not_registered() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](2);

        // proofs[0].chainId must NOT be block.chainid in order not to revert
        proofs[0].chainId = srcChainId + 1;
        proofs[0].blockId = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AddressResolver.RESOLVER_ZERO_ADDR.selector,
                proofs[0].chainId,
                strToBytes32("signal_service")
            )
        );

        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_local_chaindata_not_found() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].blockId = 1;

        // the proof is a storage proof
        proofs[0].accountProof = new bytes[](0);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // the proof is a full proof
        proofs[0].accountProof = new bytes[](1);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_one_hop_cache_signal_root() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();

        // the proof is a storage proof
        proofs[0].accountProof = new bytes[](0);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // relay the signal root
        vm.prank(taiko);
        signalService.syncChainData(
            srcChainId, LibSignals.SIGNAL_ROOT, proofs[0].blockId, proofs[0].rootHash
        );
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        vm.prank(Alice);
        signalService.authorize(taiko, false);

        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        vm.prank(taiko);
        signalService.syncChainData(
            srcChainId, LibSignals.SIGNAL_ROOT, proofs[0].blockId, proofs[0].rootHash
        );
    }

    function test_SignalService_proveSignalReceived_one_hop_state_root() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();

        // the proof is a full merkle proof
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // relay the state root
        vm.prank(taiko);
        signalService.syncChainData(
            srcChainId, LibSignals.STATE_ROOT, proofs[0].blockId, proofs[0].rootHash
        );

        // Should not revert
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        assertEq(
            signalService.isChainDataSynced(
                srcChainId, LibSignals.SIGNAL_ROOT, proofs[0].blockId, bytes32(uint256(789))
            ),
            false
        );
    }

    function test_SignalService_proveSignalReceived_multiple_hops_no_caching() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](3);

        // first hop with full merkle proof
        proofs[0].chainId = uint64(block.chainid + 2);
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);

        // second hop with storage merkle proof
        proofs[1].chainId = uint64(block.chainid + 3);
        proofs[1].blockId = 2;
        proofs[1].rootHash = randBytes32();
        proofs[1].accountProof = new bytes[](0);
        proofs[1].storageProof = new bytes[](10);

        // third/last hop with full merkle proof
        proofs[2].chainId = uint64(block.chainid);
        proofs[2].blockId = 3;
        proofs[2].rootHash = randBytes32();
        proofs[2].accountProof = new bytes[](1);
        proofs[2].storageProof = new bytes[](10);

        // expect RESOLVER_ZERO_ADDR
        vm.expectRevert(
            abi.encodeWithSelector(
                AddressResolver.RESOLVER_ZERO_ADDR.selector,
                proofs[0].chainId,
                strToBytes32("signal_service")
            )
        );
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // Add two trusted hop relayers
        vm.startPrank(Alice);
        addressManager.setAddress(proofs[0].chainId, "signal_service", randAddress() /*relay1*/ );
        addressManager.setAddress(proofs[1].chainId, "signal_service", randAddress() /*relay2*/ );
        vm.stopPrank();

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        vm.prank(taiko);
        signalService.syncChainData(
            proofs[1].chainId, LibSignals.STATE_ROOT, proofs[2].blockId, proofs[2].rootHash
        );

        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_whatever() public {
        bytes memory proof =
            hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000028c59000000000000000000000000000000000000000000000000000000000000929e0883e3ee355161a08c1696409375ea33f4bb53a9121bc90bc4d69c4f285382aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000005400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000003c00000000000000000000000000000000000000000000000000000000000000214f90211a0f776494ecffe03ad2af2426ee4fb5ae66c012c03ea3955d5b40a52fe7c6b8df6a0ef4a67411e4accae9bbb05bbcc17d036432de4e3ee0b0d02a04ee6a67db9c1a5a06c4c8f2b3206553ec83f1081a6742edff2f7b7830d3ba4166872c4f3f32bae0ba0aa2e8d96490616498fa142ba7c6a628e2839b9b182c9995992ecf1c1d346784fa0f8d7262d0abdf5d084338a640322c4dd45b1484a630331922afa60256917058aa0e49099e467972084cd70025874c6ae0a6841159aec02f39384de2d9ae7460986a02ad2a355fe840ae1bfe7843616d6bb027c1fd478918cc956e0ca7b61ec0044d0a061ec8e714d951772d74765ae997bd25f3982ea8a0c4dda8baa1e47adbd5a3975a039e5f7e8298126da1e7d6f42b1f20846d68ff40dc857b0dd251d2791c0345589a065f4d771a35d862a10b2a2da6d7d6c1e082cd59280cbab1c8e6aaf89069e72dca07851c1d2a801228a1adb24b61a5b4e1d4e12c5043a0af1b1790cd79b281c43a0a031acf4e7bd8cfb52c19cb512fb2578f416cbcf28cd3b4387d7b6107a17d4ff31a09e8def26ad9cf07bfbba2cf4a3fad0fe4075030b9a67acbecbfa5b7bdc8620cca07174a59e7f5b71a1a20f8c4a232100c1303378a7eb5dd523904d5305e20ee7dca0199ae8cd6d2b09717d59b5106ef31b451b30d777296b4afb43db9327117471eca09193465aefe93e209d05f892f77002dd5c2e74d4eed502ebae3acb7db1e33acc8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f3f8f1a0b4df476cf7a24306eb6b96d0a8fe974b88e035d93e6716cf56e3f6bacee15c88808080a09265834cbd374b79cc4f97cdab16770f4434bce18ff9724970bff1c91d54f2f1a0e13b8847e8cfc7fd465a61a64b732d940d8f87ed65828e1004e46fb4256aba48a05a7b35dc9c135fc4df95c4b02179719a3505d201fb590212cf41c31eae1ceb6980a07c46a7878ac08b149792973e8a17982311f3c997624aed0fde76ba45d9a1ba41a0ebfe5b284e549d79c976f878d93266d238d9ea3254d0ef9c199d2c5a12067de48080a05d5e60bc5b531718ba65199b06b68087c640472ef4b3afb7e4b857280edbf2e58080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006bf869a02024e130452851ed161bc592f5949e62d0e9b45d447bdfeef098148a98e92454b846f8440180a09a86a68eec0b73092dc0028cb4afb05332e85df8af2c9b0f67bbb750a4ada35da0dc679fd48cf611aa38e906adc93928c5f8f6fae534978ea2fa4f5935f5ed1b2c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002e00000000000000000000000000000000000000000000000000000000000000520000000000000000000000000000000000000000000000000000000000000076000000000000000000000000000000000000000000000000000000000000008600000000000000000000000000000000000000000000000000000000000000214f90211a062880ba06fb396ad4e16f01d22ca7a1ae677e3fe428817928db30e2cae96b97ca0aa57a805600be2304ffdd527bd3dc9e91161233dc59afb71c1aab542eafe70caa03bc6c86a4c6b49305b95b3812a162f7e6bec891b287ef291e9c468071ef0c4ada08ac85ec9872d9e6f5b4c6e72154158df88d44163457cf0bbf2134e385c871a4ea0f35f3c83fbd9da738bbfea1bc87b073d3b64abdecb6294b61cf3eb535eabefdea0905c9b0e1755d389f306f026ccb71f8f7e54cd68720cc1c76682504eeb7bceaea06867477d77649657f698380e66844a7ed14818e8aad9f4ac5748963ede640e0aa0caa272deb3227cb8b0765a718ac85bbc7ee93a04bc0a2cb9c5509c9394470eb3a01689508cc26d870b0183c13bee39ed5342bf32464813f872d7ea4e5bc5f79845a0b578886ee673adcdf7b219cd13d9d641f8e15dd9ec6c9345435e7968bc6bcc82a0fbd86d32d6c60089268373be401211c3b606efeb550659b9e43458007dce2eb6a035d73d30ad77c85ef247ab8473f71314a9d175c1e9a0ce73a78a103a3766f54ca0c08386bed5af43c7cadb42d9df7ba3b94886f483e8a2e66aaef7391a15ab51cba002ce1e689b6193a6d3a8c822b0b0076dfdf732fd045a4dc122ec3879fe3de70ea0db27c27a802c40acbde50e5c357e5327a91242e6550fe461eec10ac136ddddcea0ad6d871b4c62042c68f0ecfdb986a24ea7d850563bbd3d27f6916bc3ddd170a4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a05c9b8f83e3c03e07271225e2ebce1cbe9e7db3b14d2724ec6efe9cf8fce6fc06a0dbd4cd41e027eefe208271111ea3e99cb39b4645e7e166d084d62f427a9313ada0cc65078735257beecceb9c74985901fa16e8e9fb228ce6aaa62aedb282a1795fa012f4c2ae88c8f0396048da6a095d0fa2c8b86398651cd37a72d68d88d25ff19ea037cda349771733bba3681eda450fee72f5e3dcbb6b8f2acf4a2bd145d0bfad6da0ef1359be1a9f658e580c968b92029dbf62ce7a56932c10acce28b25bf7206665a037d9790673a2be78a1555bee7d37ab10d1b8d94d1f12bb011b7cc7257bf13004a0dd9b4774c203afaaeb098ab623ce32f1df6f8ff0ac1bbcb78e358b7a242cd19aa0dde51d1f37baae98d02b2e35c81030f17407fc31304ab72cf999bb2c7e8abff3a0f8672c12a366e074d6f42c2c7b0c5cc010bc4ec703c65e3b58c4fbfee18e89c2a057ba424e40bd1c6a8e7d494703f392e834d8ca7696759e2c0216ebd18bcf662fa01eafd299e8a772c056e6919eeb67bf7e1098129855234e942cfc18aaf364d39ea0df6b60bdf553e1511f445fdcf1fb7aadc23bf390eeb11145c9e2742552c2ed6da02e79f5afb8c177c40737cea4aed39fe3c0269f5a8989e02c07a0135594b83bb1a035535dac85afa0e4848c0186cc8687bc7d2de0215b97ea43e65c8e4da0a52517a08ce682327123eb41b4d49ef283ffe11d1da1b9d7163e892b775a63dd31072ec0800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a0eb960a5656655116248a9fd59aa005ab3b01621e7bf6af61dda8f68f08837f4fa00a5da0dc07a89fdc3c36a82aafaec6b74ed704afdabbe715c0a748089ef82063a06c9e152d546d9b553329dfaeba159778328cd0485afa3686e7aabd90efd693f6a097cf9348b5d404382cc66427c9a26ea51bb42f695e02fe4965418e6e3ba59b33a04322fdcf19a42a4b96fe7bbbfd6056b11409bc1e04363b89cbe31ece7b1aee47a0ae05af5b2313c1e5d56a31eddc38ddd40aa08c6dd13e453aefef2cc11248f599a08ca6d7e6bb6bd423fdfdddd0db9ab49a2596eb80f290b83f9aec54c95618c4e6a01864eac077fe3a353283d2832ddf7b1c8483f170853f71e2eebfa5d5ed32f4d8a06c6b1092884751879a09e24e25ff2f1d96f465bce90b27dca70b621748f553a1a06718b44e6c0f184d8c7e53df9f2593eef3ed44296c51b9df2d3e6943081cb36fa02fd865f60a69649a6b2870380647f56e2295b51a40b3d6510b70f3f0700aa9a5a0b314377c16ffbc30ac5e6b3ec50689a233cb2caa4b6238bf63ebd9e7b3fa90bba07cc57f820b95948391208256b3388ea71feb395890f74fced1420c4b97d61fa9a02e012f7f4809f19eaeb5fcfc20c60fe32891a2c1bdc413004cec5b3fe560d9f6a0f8611bdbc30c9cd166f15cc8329c5aeb7b36451f7c115c56fd684960be02514ea0ad275955aaa41ad35fe0df0adf1f3140ffaf0d7402bb58e9ca65d8e4d6f4b0948000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d3f8d180a0e5e245fc7c2c871d138c8ffc4b5b5796f43d7ec84c183fd3cdc20803e7f34a49a07fb462f79575e99110325680060d807512fc1403ee15adf62485041d04bb3ac880a0a28f1323555652ce079667a24ab91ac23caedf429e2c4612b3a5126e0683302ea0f1308db66aa45c6697e39d605a3d5a79c26408b7e73fb8d7859a522206cd1b3e808080a03a70296ae5cbdb3fea2cdd68e8bae1e2450967b2f44d69bd39423687bb27d3b28080a09e64767697acfa479007dd72ada2adadc562fe3c710ebda24ce20cc895ba3a0080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044f8429f202894fb37cfe372669bada98f4587d29132fd5700bf7caf9d2ebfb32a8663a1a00686d102436b7ab60988a4240c3e447d11f1fe68f7bba177ce4ab5c611190b8800000000000000000000000000000000000000000000000000000000";
        SignalService.HopProof[] memory _hopProofs = abi.decode(proof, (SignalService.HopProof[]));

        require(_hopProofs.length != 0, "yeeow");
        require(_hopProofs[0].chainId == 167_001, "yeoow2");
        require(_hopProofs[0].blockId == 37_534, "yeoow3");
        require(
            _hopProofs[0].rootHash
                == 0x0883e3ee355161a08c1696409375ea33f4bb53a9121bc90bc4d69c4f285382aa,
            "yeoow4"
        );
        require(_hopProofs[0].cacheOption == SignalService.CacheOption.CACHE_NOTHING, "yeoow5");
        require(_hopProofs[0].storageProof.length != 0, "yeeoow7");
        require(_hopProofs[0].accountProof.length != 0, "yeeoow6");

        console2.logBytes(_hopProofs[0].storageProof[0]);

        // // SignalService ss = new SignalService();

        // uint64 srcChainId = 32_382;

        // vm.prank(Alice);
        // addressManager.setAddress(srcChainId, "signal_service", randAddress());

        // vm.prank(taiko);
        // signalService.syncChainData(
        //     32_382,
        //     LibSignals.STATE_ROOT,
        //     37_534,
        //     0x0883e3ee355161a08c1696409375ea33f4bb53a9121bc90bc4d69c4f285382aa
        // );

        // signalService.proveSignalReceived({
        //     chainId: srcChainId,
        //     app: randAddress(),
        //     signal: randBytes32(),
        //     proof: proof
        // });
    }

    function test_SignalService_proveSignalReceived_multiple_hops_caching() public {
        uint64 srcChainId = uint64(block.chainid + 1);
        uint64 nextChainId = srcChainId + 100;

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](9);

        // hop 1:  full merkle proof, CACHE_NOTHING
        proofs[0].chainId = nextChainId++;
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);
        proofs[0].cacheOption = SignalService.CacheOption.CACHE_NOTHING;

        // hop 2:  full merkle proof, CACHE_STATE_ROOT
        proofs[1].chainId = nextChainId++;
        proofs[1].blockId = 2;
        proofs[1].rootHash = randBytes32();
        proofs[1].accountProof = new bytes[](1);
        proofs[1].storageProof = new bytes[](10);
        proofs[1].cacheOption = SignalService.CacheOption.CACHE_STATE_ROOT;

        // hop 3:  full merkle proof, CACHE_SIGNAL_ROOT
        proofs[2].chainId = nextChainId++;
        proofs[2].blockId = 3;
        proofs[2].rootHash = randBytes32();
        proofs[2].accountProof = new bytes[](1);
        proofs[2].storageProof = new bytes[](10);
        proofs[2].cacheOption = SignalService.CacheOption.CACHE_SIGNAL_ROOT;

        // hop 4:  full merkle proof, CACHE_BOTH
        proofs[3].chainId = nextChainId++;
        proofs[3].blockId = 4;
        proofs[3].rootHash = randBytes32();
        proofs[3].accountProof = new bytes[](1);
        proofs[3].storageProof = new bytes[](10);
        proofs[3].cacheOption = SignalService.CacheOption.CACHE_BOTH;

        // hop 5:  storage merkle proof, CACHE_NOTHING
        proofs[4].chainId = nextChainId++;
        proofs[4].blockId = 5;
        proofs[4].rootHash = randBytes32();
        proofs[4].accountProof = new bytes[](0);
        proofs[4].storageProof = new bytes[](10);
        proofs[4].cacheOption = SignalService.CacheOption.CACHE_NOTHING;

        // hop 6:  storage merkle proof, CACHE_STATE_ROOT
        proofs[5].chainId = nextChainId++;
        proofs[5].blockId = 6;
        proofs[5].rootHash = randBytes32();
        proofs[5].accountProof = new bytes[](0);
        proofs[5].storageProof = new bytes[](10);
        proofs[5].cacheOption = SignalService.CacheOption.CACHE_STATE_ROOT;

        // hop 7:  storage merkle proof, CACHE_SIGNAL_ROOT
        proofs[6].chainId = nextChainId++;
        proofs[6].blockId = 7;
        proofs[6].rootHash = randBytes32();
        proofs[6].accountProof = new bytes[](0);
        proofs[6].storageProof = new bytes[](10);
        proofs[6].cacheOption = SignalService.CacheOption.CACHE_SIGNAL_ROOT;

        // hop 8:  storage merkle proof, CACHE_BOTH
        proofs[7].chainId = nextChainId++;
        proofs[7].blockId = 8;
        proofs[7].rootHash = randBytes32();
        proofs[7].accountProof = new bytes[](0);
        proofs[7].storageProof = new bytes[](10);
        proofs[7].cacheOption = SignalService.CacheOption.CACHE_BOTH;

        // last hop, 9:  full merkle proof, CACHE_BOTH
        proofs[8].chainId = uint64(block.chainid);
        proofs[8].blockId = 9;
        proofs[8].rootHash = randBytes32();
        proofs[8].accountProof = new bytes[](1);
        proofs[8].storageProof = new bytes[](10);
        proofs[8].cacheOption = SignalService.CacheOption.CACHE_BOTH;

        // Add two trusted hop relayers
        vm.startPrank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());
        for (uint256 i; i < proofs.length; ++i) {
            addressManager.setAddress(
                proofs[i].chainId, "signal_service", randAddress() /*relay1*/
            );
        }
        vm.stopPrank();

        vm.prank(taiko);
        signalService.syncChainData(
            proofs[7].chainId, LibSignals.STATE_ROOT, proofs[8].blockId, proofs[8].rootHash
        );

        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // hop 1:  full merkle proof, CACHE_NOTHING
        _verifyCache(srcChainId, proofs[0].blockId, proofs[0].rootHash, false, false);
        // hop 2:  full merkle proof, CACHE_STATE_ROOT
        _verifyCache(proofs[0].chainId, proofs[1].blockId, proofs[1].rootHash, true, false);
        // hop 3:  full merkle proof, CACHE_SIGNAL_ROOT
        _verifyCache(proofs[1].chainId, proofs[2].blockId, proofs[2].rootHash, false, true);
        // hop 4:  full merkle proof, CACHE_BOTH
        _verifyCache(proofs[2].chainId, proofs[3].blockId, proofs[3].rootHash, true, true);
        // hop 5:  storage merkle proof, CACHE_NOTHING
        _verifyCache(proofs[3].chainId, proofs[4].blockId, proofs[4].rootHash, false, false);
        // hop 6:  storage merkle proof, CACHE_STATE_ROOT
        _verifyCache(proofs[4].chainId, proofs[5].blockId, proofs[5].rootHash, false, false);
        // hop 7:  storage merkle proof, CACHE_SIGNAL_ROOT
        _verifyCache(proofs[5].chainId, proofs[6].blockId, proofs[6].rootHash, false, true);
        // hop 8:  storage merkle proof, CACHE_BOTH
        _verifyCache(proofs[6].chainId, proofs[7].blockId, proofs[7].rootHash, false, true);
        // last hop, 9:  full merkle proof, CACHE_BOTH
        // last hop's state root is already cached even before the proveSignalReceived call.
        _verifyCache(proofs[7].chainId, proofs[8].blockId, proofs[8].rootHash, true, true);
    }

    function _verifyCache(
        uint64 chainId,
        uint64 blockId,
        bytes32 stateRoot,
        bool stateRootCached,
        bool signalRootCached
    )
        private
    {
        assertEq(
            signalService.isChainDataSynced(chainId, LibSignals.STATE_ROOT, blockId, stateRoot),
            stateRootCached
        );

        assertEq(
            signalService.isChainDataSynced(
                chainId, LibSignals.SIGNAL_ROOT, blockId, bytes32(uint256(789))
            ),
            signalRootCached
        );
    }
}
