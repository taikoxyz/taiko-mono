// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {IBridge, Bridge} from "../contracts/bridge/Bridge.sol";
import {BridgeErrors} from "../contracts/bridge/BridgeErrors.sol";
import {console2} from "forge-std/console2.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Test} from "forge-std/Test.sol";

contract BridgeTest is Test {
    AddressManager addressManager;
    Bridge bridge;
    Bridge destChainBridge;
    SignalService signalService;
    uint256 destChainId = 19389;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;

    function setUp() public {
        vm.deal(Alice, 100 ether);
        addressManager = new AddressManager();
        addressManager.init();

        bridge = new Bridge();
        bridge.init(address(addressManager));

        destChainBridge = new Bridge();
        destChainBridge.init(address(addressManager));

        signalService = new SignalService();
        signalService.init(address(addressManager));

        addressManager.setAddress(
            string(
                bytes.concat(bytes32(block.chainid), bytes("signal_service"))
            ),
            address(signalService)
        );

        addressManager.setAddress(
            string(bytes.concat(bytes32(destChainId), bytes("bridge"))),
            address(destChainBridge)
        );

        addressManager.setAddress(
            string(bytes.concat(bytes32(uint256(1337)), bytes("bridge"))),
            address(destChainBridge)
        );
    }

    function test_send_message_ether_reverts_if_value_doesnt_match_expected()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: 0,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_INCORRECT_VALUE.selector);
        bridge.sendMessage(message);
    }

    function test_send_message_ether_reverts_when_owner_is_zero_address()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: address(0),
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: 0,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_OWNER_IS_NULL.selector);
        bridge.sendMessage{value: amount}(message);
    }

    function test_send_message_ether_reverts_when_dest_chain_is_not_enabled()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: 0,
            destChain: destChainId + 1
        });

        vm.expectRevert(BridgeErrors.B_WRONG_CHAIN_ID.selector);
        bridge.sendMessage{value: amount}(message);
    }

    function test_send_message_ether_reverts_when_dest_chain_same_as_block_chainid()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: 0,
            destChain: block.chainid
        });

        vm.expectRevert(BridgeErrors.B_WRONG_CHAIN_ID.selector);
        bridge.sendMessage{value: amount}(message);
    }

    function test_send_message_ether_reverts_when_to_is_zero_address() public {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: address(0),
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: 0,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_WRONG_TO_ADDRESS.selector);
        bridge.sendMessage{value: amount}(message);
    }

    function test_send_message_ether_with_no_processing_fee() public {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: 0,
            destChain: destChainId
        });

        bytes32 msgHash = bridge.sendMessage{value: amount}(message);

        bool isMessageSent = bridge.isMessageSent(msgHash);
        assertEq(isMessageSent, true);
    }

    function test_send_message_ether_with_processing_fee() public {
        uint256 amount = 1 wei;
        uint256 processingFee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: processingFee,
            destChain: destChainId
        });

        bytes32 msgHash = bridge.sendMessage{value: amount + processingFee}(
            message
        );

        bool isMessageSent = bridge.isMessageSent(msgHash);
        assertEq(isMessageSent, true);
    }

    function test_send_message_ether_with_processing_fee_invalid_amount()
        public
    {
        uint256 amount = 1 wei;
        uint256 processingFee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            depositValue: amount,
            callValue: 0,
            gasLimit: 0,
            processingFee: processingFee,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_INCORRECT_VALUE.selector);
        bridge.sendMessage{value: amount}(message);
    }

    function test_process_message() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            sender: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            srcChainId: 1336,
            destChainId: 1337,
            owner: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            to: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            refundAddress: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            depositValue: 1000,
            callValue: 1000,
            processingFee: 1000,
            gasLimit: 10000,
            data: hex"00",
            memo: ""
        });

        bytes
            memory proof = hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e0c4b24484730e28d2cc1206ecc1392e7ecdaae118f8a56f995c6fa555d47cf40b1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d493470000000000000000000000000000000000000000000000000000000000000000256b72a39b388182df1d81743a57af88f768344e665c3c046b75cbf0ce8975268ff152ed082bc5cf91a6d6b566514991977764fbc18561d76b516e8e595d269d2a8d7e3c436c44838ac62cbf6415cb4f08255636c380d104ab522ee6805c0979000000000000000000000000000000000000000000000010000000000000000000000000000000000000001000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000001000040000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000008000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001500000000000000000000000000000000000000000000000000000000009bbf55000000000000000000000000000000000000000000000000000000000001d4ef0000000000000000000000000000000000000000000000000000000064434c790000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d2e85500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010a1a846765746888676f312e31382e38856c696e757800000000000000b977c5d801216ced729f871f7b4a262158b1e384d5b1aecdcbd24ae16fc941650f29d5bd3bf63d398162e9be51825565e2dfa37ee58a3a60e4f9a78a368fbcf5010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dbf8d9b8b3f8b180a0e33150b0e1421da116abdbc6ba0c767419250211fa366692db4837bceb979c06a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a02b70a98baa2507beffe8c266006cae52064dccf4fd1998af774ab3399029b38380808080a07394a09684ef3b2c87e9e2a753eb4ac78e2047b980e16d2e2133aee78946370d8080a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd78080808080a3e2a030ffafb74b6b961d2b14bf88a2bdeef114031417b70261a9be7ed6dcf3a32191010000000000";

        destChainBridge.processMessage(message, proof);
    }

    function newMessage(
        address owner,
        address to,
        uint256 depositValue,
        uint256 callValue,
        uint256 gasLimit,
        uint256 processingFee,
        uint256 destChain
    ) internal view returns (IBridge.Message memory) {
        return
            IBridge.Message({
                owner: owner,
                destChainId: destChain,
                to: to,
                depositValue: depositValue,
                callValue: callValue,
                processingFee: processingFee,
                id: 0, // placeholder, will be overwritten
                sender: owner, // placeholder, will be overwritten
                srcChainId: block.chainid, // will be overwritten
                refundAddress: owner,
                gasLimit: gasLimit,
                data: "",
                memo: ""
            });
    }
}
