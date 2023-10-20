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
}
