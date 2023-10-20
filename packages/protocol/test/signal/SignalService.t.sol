// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { AddressResolver } from "../../contracts/common/AddressResolver.sol";
import { Bridge } from "../../contracts/bridge/Bridge.sol";
import { BridgedERC20 } from "../../contracts/tokenvault/BridgedERC20.sol";
import { console } from "forge-std/console.sol";
import { FreeMintERC20 } from "../../contracts/test/erc20/FreeMintERC20.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";
import { TestBase, DummyCrossChainSync } from "../TestBase.sol";

contract TestSignalService is TestBase {
    AddressManager addressManager;

    SignalService signalService;
    SignalService destSignalService;
    DummyCrossChainSync crossChainSync;
    uint256 destChainId = 7;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);

        addressManager = new AddressManager();
        addressManager.init();

        signalService = new SignalService();
        signalService.init(address(addressManager));

        destSignalService = new SignalService();
        destSignalService.init(address(addressManager));

        crossChainSync = new DummyCrossChainSync();

        addressManager.setAddress(
            block.chainid, "signal_service", address(signalService)
        );

        addressManager.setAddress(
            destChainId, "signal_service", address(destSignalService)
        );

        addressManager.setAddress(destChainId, "taiko", address(crossChainSync));

        vm.stopPrank();
    }

    function test_SignalService_sendSignal_revert() public {
        vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
        signalService.sendSignal(0);
    }

    function test_SignalService_isSignalSent_revert() public {
        bytes32 signal = bytes32(uint256(1));
        vm.expectRevert(SignalService.SS_INVALID_APP.selector);
        signalService.isSignalSent(address(0), signal);

        signal = bytes32(uint256(0));
        vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
        signalService.isSignalSent(Alice, signal);
    }

    function test_SignalService_sendSignal_isSignalSent() public {
        vm.startPrank(Alice);
        bytes32 signal = bytes32(uint256(1));
        signalService.sendSignal(signal);

        assertTrue(signalService.isSignalSent(Alice, signal));
    }

    function test_SignalService_getSignalSlot() public {
        vm.startPrank(Alice);
        for (uint8 i = 1; i < 100; ++i) {
            bytes32 signal = bytes32(block.prevrandao + i);
            signalService.sendSignal(signal);

            assertTrue(signalService.isSignalSent(Alice, signal));
        }
    }

    function test_SignalService_proveSignalReceived_L1_L2() public {
        uint256 chainId = 11_155_111; // Created the proofs on a deployed
            // Sepolia contract, this is why this chainId.
        address app = 0x927a146e18294efb36edCacC99D9aCEA6aB16b95; // Mock app,
            // actually it is an EOA, but it is ok for tests!
        bytes32 signal =
            0x21761f7cd1af3972774272b39a0f4602dbcd418325cddb14e156b4bb073d52a8;
        bytes memory inclusionProof =
            hex"e5a4e3a120be7cf54b321b1863f6772ac6b5776a712628a78149e662c87d93ae1ef2a5b3bd01"; //eth_getProof's
            // result RLP encoded storage proof
        bytes32 signalRoot =
            0x15e2682cef63ccbfeb896e5faaf1eeaa2a834301e468c92f9764be56416682d4; //eth_getProof
            // result's storage hash

        vm.startPrank(Alice);
        addressManager.setAddress(
            block.chainid, "taiko", address(crossChainSync)
        );

        crossChainSync.setSyncedData("", signalRoot);

        SignalService.Proof memory p;
        SignalService.Hop[] memory h;
        p.height = 10;
        p.storageProof = inclusionProof;
        p.hops = h;

        bool isSignalReceived = signalService.proveSignalReceived(
            chainId, app, signal, abi.encode(p)
        );
        assertEq(isSignalReceived, true);
    }

    function test_SignalService_proveSignalReceived_L2_L2() public {
        uint256 chainId = 11_155_111; // Created the proofs on a deployed
            // Sepolia contract, this is why this chainId. This works as a
            // static 'chainId' becuase i imitated 2 contracts (L2A and L1
            // Signal Service contracts) on Sepolia.
        address app = 0x927a146e18294efb36edCacC99D9aCEA6aB16b95; // Mock app,
            // actually it is an EOA, but it is ok for tests! Same applies here,
            // i imitated everything with one 'app' (Bridge) with my same EOA
            // wallet.
        bytes32 signal_of_L2A_msgHash =
            0x21761f7cd1af3972774272b39a0f4602dbcd418325cddb14e156b4bb073d52a8; //
        bytes memory inclusionProof_of_L2A_msgHash =
            hex"e5a4e3a120be7cf54b321b1863f6772ac6b5776a712628a78149e662c87d93ae1ef2a5b3bd01"; //eth_getProof's
            // result RLP encoded storage proof
        bytes32 signalRoot_of_L2 =
            0x15e2682cef63ccbfeb896e5faaf1eeaa2a834301e468c92f9764be56416682d4; //eth_getProof
            // result's storage hash
        bytes memory hop_inclusionProof_from_L1_SignalService =
            hex"e5a4e3a1201a9344e0a9498d6fb8f30b92d061ca7cee3ec0cdf641e63b777b94b5717b21be01"; //eth_getProof's
            // result RLP encoded storage proof
        bytes32 l1_common_signalService_root =
            0x630872b5926b611c6dbcff64c181865a376d4e9250b594e8669198e0f19aa9b0; //eth_getProof
            // result's storage hash

        vm.startPrank(Alice);
        addressManager.setAddress(
            block.chainid, "taiko", address(crossChainSync)
        );

        vm.startPrank(Alice);
        addressManager.setAddress(chainId, "taiko", app);

        crossChainSync.setSyncedData("", l1_common_signalService_root);

        SignalService.Proof memory p;
        p.height = 10;
        p.storageProof = inclusionProof_of_L2A_msgHash;

        // Imagine this scenario: L2A to L2B birdging.
        // The 'hop' proof is the one that proves to L2B, that L1 Signal service
        // contains the signalRoot (as storage slot / leaf) with value 0x1.
        // The 'normal' proof is the one which proves that the resolving
        // hop.signalRoot is the one which belongs to L2A, and the proof is
        // accordingly.
        SignalService.Hop[] memory h = new SignalService.Hop[](1);
        h[0].chainId = chainId;
        h[0].signalRoot = signalRoot_of_L2;
        h[0].storageProof = hop_inclusionProof_from_L1_SignalService;

        p.hops = h;

        bool isSignalReceived = signalService.proveSignalReceived(
            chainId, app, signal_of_L2A_msgHash, abi.encode(p)
        );
        assertEq(isSignalReceived, true);
    }

    function test_signalService_proveSignalReceived() public view {
        bytes memory proof =
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000708000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000680f9067db90214f90211a0fa95a3fa099029a2bae738573b190af7e367c53168e68230b973ab669ab92273a03209154dafca2fb338bad6a4ee4a8418ad9bbf6737769410d2a3cb15105da8eda071bca6a07bf78fa2d7af40dbdb8bdedfebf31e1056a09b2b2c2a1bdcfa3a3edea0fb995079645a03208611b505a4f45e371f8fa368de4fcfbf5cea7dc17583528aa002c633ccfb0257ca4c0905f5d66a66f0a5d56dfed6e75987921f9457c20cb1b7a0db8ee86f9e55a0b764b5fe18ef5418d3b9f5517fc021b2bb01cda6f2f666ee51a0bc6f82098986e0a0e897efc5fbc704281a15337c3e4629a2ff55f5f9c51f0ef8a0f5e74eb65561196e4eedae1accdf35c310927f23734ece974b6e211e20d8f3e2a0aa8f8d43c051bc6b5149683683385bcc3de5c47204eb585c76f1a82a1ca706b4a0fa32571b4806ed0e9b6fafc018ecdb2186c5598d5262f9959aac240d9c14cf6da0dee0093f7e6b0b905add4718bf36ee21009fe9dfa20fdd2ed2168a268b598f44a0c4edf7b57c2d02bc524b7aebcf3648ab31dfa06eab094a2df726bfe57cf07f9ea0f8bcf4fa3abaff712831040220231dbe4229a3924e784ee41af7b98a143e758da084ad09040cacd573c05309d3406ef81d197d0c998e5d4a25b3c7f50a11d7f7e0a0c30fbdb428c1cc945851f2451b87d0e94ce7355dec5112f3eb52a232d5000512a0e780f0de77e9e26c9ec82fb6306443431cbc80fcffa54dc981a48476b87e3bf680b90214f90211a03bc53d8ec9de12131cf6383246a1988aca726feb3006cfcfbb564ef74e11536fa0881d9b0d970abdec9df0942bbae16f29c1dc394fb50c4ce98dc3c4cfa9a55e8aa030404644653c2c1ceadd54403a8c1f9c4a52a27d87fe9a067fa55eb41e7ecce6a08540eb02b9cd8cc368e7a1422227ebd65a00c5c207cf1af9ab2b1e82e7462d3ea083b853ba8262bf35e3a84b04fc80dd78088ac1f7babf390b92172134936998daa024c02ee912708a3ea5109a0bbd4fe96128a11548d5a7a54387aaca72ab28ebe0a03623643d25836904a18da819169e39be2e7a3dc8f653878061c38be52a28d6bba085bf2725206ab5a61dd601c3f43e515b974a36827f76e6bf6366c0e31fc40c55a0463c0f1556ec32a9ea404831cc3a915a8f77caae536d3cef29fa55445dcbf704a0c0319d08a5a78675521de8b70fa117b102c88669d9bd8b637b576a942996ab59a0fed40c7f742a4af1f83e763b9bb8e254170b6235fa5fe9f36e1cd320b897d3a0a04509d130dea44b86f8917120087852f1dd78a8abe2c18883f0bf323ab0c9aa8aa0fa420475e3454b39ad16ee3cad8002fb9909e9591661cd7199897cb213b0f326a0583081396353941de30ef88eb71713c80544a58591a5157807978acfca69966aa08db3641575309d042c43e5774f6b88f76941ee5ae4deb3b92a61ce635424743da090648efc1cf417ab1ac8e130800c3e855421c7485c06082fdc1d8f7c73bc867d80b901d4f901d1a0edb03358a1d53b5858b44a196abef07858ab1704c150428297a9819cdf292d40a0873224f010f8cd033814865b56e9f88a89a79a52b6d1fce7baab89bb30928fff8080a0d8843ca98e05ed656dd8c6ca00d14c08d985f98e6bdb1f9b7dc138199df065eaa0feeb5bc02c6574172429ad6338d40b33ad057924c8e2f95dea11e04f74f676cda01e3abb03ba77687265fb3cde14b2f0b128e09deaa72935499cb6f1f1d4b1624da0a0552df8b2b50fe9e953c75af14d288bf12e1d9df36e793ad5c50adf7394f63da0f3c292a02c0df239f82165a98e05b19d2f6aba70216179ec33a412af657831b6a053876d77612b8834c822d951071649a6bdef6d2d3e415ee5cb0887ccc5d61565a0f0a9b1cc94eb9ec2e5681e9a4c87945db4197b09bc1260b9f3ea98c0fee5690aa0c371e567105b1622f09271d67bab00e044a890655354376d581c77662058b47ba0373de207bd10f42f6d00e7901deedcdc8a7a5b77f4664c3e4c4b4abcb4d52749a05afb0cf67e3f99057c524fa111deabe0e257183a8bf6bcb05996947ffa775581a0db79d110ffde85c967200f098063a6bdd7f62d07b97a23745ccd8e07d1be7730a05a99de2589e8e3cd443dbb48ca2fa57b388141756a8cbbe4828b3fe5a1027f1680b853f85180808080808080a073f98bf1aa871e9a9149e3935f374e76ac5703d607860dd2a35a7e47afc566e2808080808080a05cf76d7e259887a5c33c9799e9942bd931d9ba0ab560bf56ea4ecbc8bcc602978080a2e19f209ee758b5002b40eecd6933df395acda2c9bc4cd76f5d3828b5326d647eab01000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000028c59c0922ff3a0fb042fc73fc22cf5421895e8967e26a2e633fd8b199787a61c450d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000005c0f905bdb90214f90211a05bc0559ced4f5e31b34e40120a2fe01130f24c9b9232db6b67244bf6f4cc629aa0812eead1dddf3e657ff6628f14fffcb8fe23a251c966990b4a47fcbb5c7a7788a00c0f28c9b782023c02c3d427f1915a7840c8926d91dd4f001db9f578ff2b18e4a0bcd1d59ac14070a9a38e4d564792972fbc061724aa5c443f5cdfbe80bc7be543a043cc7ce4941d46799da060032e0367217f06e20635f591b08d0874e228f6a28ca03356cb60d41b449483e0c909063afc723adcf352b3c2f28470b2831fe4bc994aa07d66632a558ab4852e392768ce7a6dda60972c6f97c13c0cd7f52bddc6401b17a09f4a0fec171659cf0781b3f39626b1e902f7bd8380e136b9064cca18edaf0d2da052f024d1211cf998ec8c5c48fb5b8bffd2fa2295e5ad89a7c79091018e57fe6fa04e4c27ce0b8e778d5c5e27013738627318e473afc07c6c5ab703c5cf860cbebba0f3416d980717d362193b578017d0808216c6ee4a019d59c4086edb84f3eb20c6a0a793e71659765a36d9378705ca116d2e486959904f7831a5ac59bfb216ca92d0a0e1fad67ce51988684ddb8f616bc434641555c71f3de1722ff89180d682a662cda0ede50f1ef38193ba599bffb0243e72d30db1e887d0e4d213cb9b86143040bd8ba0c048bad97c245fcd08be39f5af75e4de92d52ca6008b83764e70f2703b887d0fa0d577088cdad32ac3b629ff689e1b691c6382a2635cee5eff34159992a45e4ffe80b90214f90211a09d015e285c0fb46825d1b786f7534a88ea087f6a3ac9eda7d41b00a5f0874a1ba0b8df3e513d50a57ac01eff94c3430205f2ffad965e0520b5060d4c478315ee9aa0b576df8b7731cf3de174f469eec910b244b08f96f2b0ff195392e19e21f5658aa0757a670a4ff13af44fe5b062b2f71d90f66857cd3dc694b0645f61ee5434c90ba02e7d31371ca7086b8b325b5c1e04b3a43067cc7b2cdfc046b6d61fc55e473bc4a0c5e0b883c37aa724ecd1d77f08824db731e9b04b276c57d4897aaa9da3a968eaa03397c7dd60a87d96a079ade78c8f2ad8e59a9cbc2a32ac9740cbf7c7884a87fca09a177445ac51191685d86a62cf8ba4990d4ede614be1e8105169b4d79b14f399a001db12c830f191b11768baf178cb4676be117abd6907aa29697a3ae395ddd695a077026a77992ee220ec01d75a0cc9a9e203a23f8d6863b470b963658958e30b97a0e16e75ff546b23670ab79c059458095348e5ca9216f1d19758dd4137fb8e23c0a0ca0756b07809c217622c5e484667c03f25937befcaf5bda1cdd92599932a9ea1a01df314ba17a09aa90ed82cb0bc9dc0ec5ff7c11d1beea888b350a7c27b430960a09863ff2d0a38ce7c802be418d5c2e26dd5f96f66ce73ef04871b24c111573504a06c3ea38dd5959807510c3843b340a29bf06cb0b51f882bbf92a7b1861749cc76a0adfcd36e959480a32442a343d748ac61d990ade099cd5480e80d987c842d419d80b90114f9011180a0d9a1eb543a5345096caf4065f8bfbc765d95508751a68a77db1da04b5496745ba0d764fe8ee1920824f4ec1ca7e7a460ab66c2fdb0a9fe7848d1a42add4179fc9ca048a3457cda558ce0c63739c73f3698d7146f2de50a54e2656e93008eba7d7c63a0c10d8a564ee50032fa42fd81dc0e752cbb5e44889dca0c57667278037cb871c2808080a03364930ea222d0f8f16e64eb8ccf266e907cf6797e86eb4ef6fa101c5e753cf8a06fb39583f0dff43ca858a23d0f774079f801b7c77359edec0514176b0a9a3d0f80a0a1c491e823af1b1d6bca7accff0364df77e694ac58f7bf50ee207ac01805f26f8080a0c0dbdf50763fea3edae65aaaf506864af84b6602ad8f355d22846cb21c7935a08080b853f85180808080808080808080a04283d4fbc6b3b5b8accf37105cab5ce2fe200845e39300bc9194e67688b3a7d180808080a0965e1422b9db2ccd6e21f38955fc84143c2fd7b310be9594f911a24142385f9d80a2e19f20768d83d5b13057663a92c030f88aaf0362b7ff391789ed0703ce1658ea8b01";

        SignalService.Proof memory p = abi.decode(proof, (SignalService.Proof));

        console.log(p.height);
        console.logBytes(p.storageProof);
        console.logBytes(p.hops[0].storageProof);
        console.log(p.hops[0].chainId);
        console.logBytes32(p.hops[0].signalRoot);
    }
}
