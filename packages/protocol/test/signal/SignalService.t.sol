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

    function test_SignalService_proveSignalReceived() public {
        // This specific value is used, do not change it.
        address Brecht = 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39;

        // known signal with known proof for known block header/signalRoot from
        // a known chain ID of 1336, since we cant generate merkle proofs with
        // foundry.
        bytes32 signal = bytes32(
            0xa99d658793daba4d352c77378e2d0f3b12ff47503518b3ec9ad61bb33ee7031d
        );
        bytes memory proof = "????????";

        crossChainSync.setSyncedData(
            0x986278442ae7469dbd55f478348b4547c399004c93325b18ed995d2bc008f98d,
            0x58900f5366437923bb250887d359d828a1a89e1837f9369f75c3e1bb238b854f
        );

        vm.chainId(destChainId);

        assertTrue(
            destSignalService.proveSignalReceived(1336, Brecht, signal, proof)
        );
    }
}
