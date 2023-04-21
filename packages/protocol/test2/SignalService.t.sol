// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {AddressResolver} from "../contracts/common/AddressResolver.sol";
import {Bridge} from "../contracts/bridge/Bridge.sol";
import {BridgedERC20} from "../contracts/bridge/BridgedERC20.sol";
import {BridgeErrors} from "../contracts/bridge/BridgeErrors.sol";
import {console2} from "forge-std/console2.sol";
import {FreeMintERC20} from "../contracts/test/erc20/FreeMintERC20.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Test} from "forge-std/Test.sol";

contract TestSignalService is Test {
    AddressManager addressManager;

    SignalService signalService;
    SignalService destSignalService;
    uint256 destChainId = 7;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;

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

        addressManager.setAddress(
            string(
                bytes.concat(bytes32(block.chainid), bytes("signal_service"))
            ),
            address(signalService)
        );

        addressManager.setAddress(
            string(bytes.concat(bytes32(destChainId), bytes("signal_service"))),
            address(destSignalService)
        );

        addressManager.setAddress(
            string(
                bytes.concat(bytes32(block.chainid), bytes("signal_service"))
            ),
            address(signalService)
        );

        vm.stopPrank();
    }

    function test_send_signal_reverts_if_signal_is_zero() public {
        vm.expectRevert(SignalService.B_ZERO_SIGNAL.selector);
        signalService.sendSignal(0);
    }

    function test_is_signal_sent_reverts_if_address_is_zero() public {
        bytes32 signal = bytes32(uint256(1));
        vm.expectRevert(SignalService.B_NULL_APP_ADDR.selector);
        signalService.isSignalSent(address(0), signal);
    }

    function test_is_signal_sent_reverts_if_signal_is_zero() public {
        bytes32 signal = bytes32(uint256(0));
        vm.expectRevert(SignalService.B_ZERO_SIGNAL.selector);
        signalService.isSignalSent(Alice, signal);
    }

    function test_send_signal_and_signal_is_sent_correctly() public {
        vm.startPrank(Alice);
        bytes32 signal = bytes32(uint256(1));
        signalService.sendSignal(signal);

        bool isSent = signalService.isSignalSent(Alice, signal);
        assertEq(isSent, true);
    }

    function test_get_signal_slot_returns_expected_slot_for_app_and_signal()
        public
    {
        vm.startPrank(Alice);
        for (uint8 i = 1; i < 100; i++) {
            bytes32 signal = bytes32(block.prevrandao + i);
            signalService.sendSignal(signal);

            bool isSent = signalService.isSignalSent(Alice, signal);
            assertEq(isSent, true);

            bytes32 slot = signalService.getSignalSlot(Alice, signal);

            // confirm our assembly gives same output as expected native solidity hash/packing
            bytes32 expectedSlot = keccak256(abi.encodePacked(Alice, signal));
            assertEq(slot, expectedSlot);
        }
    }

    function test_is_signal_received_reverts_if_src_chain_id_is_same_as_block_chain_id()
        public
    {
        bytes32 signal = bytes32(uint256(1));
        bytes memory proof = new bytes(1);
        vm.expectRevert(SignalService.B_WRONG_CHAIN_ID.selector);
        signalService.isSignalReceived(block.chainid, Alice, signal, proof);
    }

    function test_is_signal_received_reverts_if_app_is_zero_address() public {
        bytes32 signal = bytes32(uint256(1));
        bytes memory proof = new bytes(1);
        vm.expectRevert(SignalService.B_NULL_APP_ADDR.selector);
        signalService.isSignalReceived(destChainId, address(0), signal, proof);
    }

    function test_is_signal_received_reverts_if_signal_is_zero() public {
        bytes32 signal = bytes32(uint256(0));
        bytes memory proof = new bytes(1);
        vm.expectRevert(SignalService.B_ZERO_SIGNAL.selector);
        signalService.isSignalReceived(destChainId, Alice, signal, proof);
    }

    function test_is_signal_received_reverts_if_proof_is_invalid() public {
        bytes32 signal = bytes32(uint256(1));
        bytes memory proof = new bytes(1);
        vm.expectRevert();
        signalService.isSignalReceived(destChainId, Alice, signal, proof);
    }
}
