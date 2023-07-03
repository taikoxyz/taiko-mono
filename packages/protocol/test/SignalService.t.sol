// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AddressManager} from "../contracts/common/AddressManager.sol";
import {AddressResolver} from "../contracts/common/AddressResolver.sol";
import {Bridge} from "../contracts/bridge/Bridge.sol";
import {BridgedERC20} from "../contracts/bridge/BridgedERC20.sol";
import {BridgeErrors} from "../contracts/bridge/BridgeErrors.sol";
import {console2} from "forge-std/console2.sol";
import {FreeMintERC20} from "../contracts/test/erc20/FreeMintERC20.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Test} from "forge-std/Test.sol";
import {ICrossChainSync} from "../contracts/common/ICrossChainSync.sol";

contract PrankCrossChainSync is ICrossChainSync {
    bytes32 private _blockHash;
    bytes32 private _signalRoot;

    function setCrossChainBlockHeader(bytes32 blockHash) external {
        _blockHash = blockHash;
    }

    function setCrossChainSignalRoot(bytes32 signalRoot) external {
        _signalRoot = signalRoot;
    }

    function getCrossChainBlockHash(uint256) external view returns (bytes32) {
        return _blockHash;
    }

    function getCrossChainSignalRoot(uint256) external view returns (bytes32) {
        return _signalRoot;
    }
}

contract TestSignalService is Test {
    AddressManager addressManager;

    SignalService signalService;
    SignalService destSignalService;
    PrankCrossChainSync crossChainSync;
    uint256 destChainId = 7;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;
    address public Carol = 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39;

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

        crossChainSync = new PrankCrossChainSync();

        addressManager.setAddress(block.chainid, "signal_service", address(signalService));

        addressManager.setAddress(destChainId, "signal_service", address(destSignalService));

        addressManager.setAddress(block.chainid, "signal_service", address(signalService));

        addressManager.setAddress(destChainId, "taiko", address(crossChainSync));

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

    function test_get_signal_slot_returns_expected_slot_for_app_and_signal() public {
        vm.startPrank(Alice);
        for (uint8 i = 1; i < 100; i++) {
            bytes32 signal = bytes32(block.difficulty + i);
            signalService.sendSignal(signal);

            bool isSent = signalService.isSignalSent(Alice, signal);
            assertEq(isSent, true);

            bytes32 slot = signalService.getSignalSlot(Alice, signal);

            // confirm our assembly gives same output as expected native solidity hash/packing
            bytes32 expectedSlot = keccak256(abi.encodePacked(Alice, signal));
            assertEq(slot, expectedSlot);
        }
    }

    function test_is_signal_received_reverts_if_src_chain_id_is_same_as_block_chain_id() public {
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

    function test_is_signal_received() public {
        // known signal with known proof for known block header/signalRoot from a known chain ID
        // of 1336, since we cant generate merkle proofs with foundry.
        bytes32 signal = bytes32(0xa99d658793daba4d352c77378e2d0f3b12ff47503518b3ec9ad61bb33ee7031d);
        bytes memory proof =
            hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e0d5c45a5c0fabac05a887ad983965a225214df2cecd77adc216d3b1172866b1e91dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d493470000000000000000000000000000000000000000000000000000000000000000cba38a70215ae3eeba2e97f9b6c3c804541484202953760c1cfe734df6dfce7cf7f7ed1e57a053e1c79765d6b76305193cae04261538400724837787437e621c9e6a8ea258a11278cf2e54d0e4845843837a1da42483ebe1dddf3eed1d33088b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000099c8ac000000000000000000000000000000000000000000000000000000000000ac7500000000000000000000000000000000000000000000000000000000644311c100000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000164c61e700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010a1a846765746888676f312e31382e38856c696e757800000000000000def5020e30ddc20e32151adb608a5d8367d817a707ae8d520c98ac13de04bce35f95ef795a9c4fd13d3e5daf713525521043125bde66aa71eed7ca715f05c720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dbf8d9b8b3f8b18080a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a02b70a98baa2507beffe8c266006cae52064dccf4fd1998af774ab3399029b38380808080a07394a09684ef3b2c87e9e2a753eb4ac78e2047b980e16d2e2133aee78946370d8080a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd7a00f6329feca1549bd3bf7ab9a2e474bde37cb4f81366fca1dfdd9257c7305b5b880808080a3e2a037a8317247f2d3e645fa68570a9ae97a73b5568fe0578b90197316c654138997010000000000";

        crossChainSync.setCrossChainBlockHeader(
            0x986278442ae7469dbd55f478348b4547c399004c93325b18ed995d2bc008f98d
        );
        crossChainSync.setCrossChainSignalRoot(
            0x58900f5366437923bb250887d359d828a1a89e1837f9369f75c3e1bb238b854f
        );

        vm.chainId(destChainId);

        bool isReceived = destSignalService.isSignalReceived(1336, Carol, signal, proof);

        assertEq(isReceived, true);
    }
}
