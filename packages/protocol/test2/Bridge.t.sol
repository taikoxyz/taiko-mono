// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {IBridge, Bridge} from "../contracts/bridge/Bridge.sol";
import {BridgeErrors} from "../contracts/bridge/BridgeErrors.sol";
import {EtherVault} from "../contracts/bridge/EtherVault.sol";
import {console2} from "forge-std/console2.sol";
import {LibBridgeStatus} from "../contracts/bridge/libs/LibBridgeStatus.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Test} from "forge-std/Test.sol";
import {IXchainSync} from "../contracts/common/IXchainSync.sol";

contract PrankXchainSync is IXchainSync {
    bytes32 private _blockHash;
    bytes32 private _signalRoot;

    function setXchainBlockHeader(bytes32 blockHash) external {
        _blockHash = blockHash;
    }

    function setXchainSignalRoot(bytes32 signalRoot) external {
        _signalRoot = signalRoot;
    }

    function getXchainBlockHash(uint256) external view returns (bytes32) {
        return _blockHash;
    }

    function getXchainSignalRoot(uint256) external view returns (bytes32) {
        return _signalRoot;
    }
}

contract BridgeTest is Test {
    AddressManager addressManager;
    Bridge bridge;
    Bridge destChainBridge;
    EtherVault etherVault;
    SignalService signalService;
    PrankXchainSync xChainSync;
    uint256 destChainId = 19389;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 100 ether);
        addressManager = new AddressManager();
        addressManager.init();

        bridge = new Bridge();
        bridge.init(address(addressManager));

        destChainBridge = new Bridge();
        destChainBridge.init(address(addressManager));

        signalService = new SignalService();
        signalService.init(address(addressManager));

        etherVault = new EtherVault();
        etherVault.init(address(addressManager));

        xChainSync = new PrankXchainSync();

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

        vm.stopPrank();
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

    // test with a known good merkle proof / message since we cant generate proofs via rpc
    // in foundry
    function test_process_message() public {
        vm.startPrank(Alice);
        uint256 dest = 1337;
        addressManager.setAddress(
            string(bytes.concat(bytes32(dest), bytes("taiko"))),
            address(xChainSync)
        );

        addressManager.setAddress(
            string(bytes.concat(bytes32(uint256(1336)), bytes("bridge"))),
            0x564540a26Fb667306b3aBdCB4ead35BEb88698ab
        );

        addressManager.setAddress(
            string(bytes.concat(bytes32(dest), bytes("bridge"))),
            address(destChainBridge)
        );

        addressManager.setAddress(
            string(bytes.concat(bytes32(dest), bytes("ether_vault"))),
            address(etherVault)
        );

        etherVault.authorize(address(destChainBridge), true);

        vm.deal(address(etherVault), 100 ether);

        addressManager.setAddress(
            string(bytes.concat(bytes32(dest), bytes("signal_service"))),
            address(signalService)
        );

        xChainSync.setXchainBlockHeader(
            0x2f0658a880e7e1af9df5b00e67ff83613b97f6a8e58b33eab0a113441362b58c
        );

        xChainSync.setXchainSignalRoot(
            0x09e1101bda6748ec95ef9c9d8ec487dc87beea5ffd326d0899f18f81dadae581
        );

        vm.deal(address(destChainBridge), 1 ether);

        vm.chainId(dest);

        // known message that corresponds with below proof.
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            sender: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            srcChainId: 1336,
            destChainId: dest,
            owner: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            to: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            refundAddress: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            depositValue: 1000,
            callValue: 1000,
            processingFee: 1000,
            gasLimit: 1000000,
            data: "",
            memo: ""
        });

        bytes
            memory proof = hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e099947564d975df220911a6c6beb31446915da1d84ce3fc27bacbf8363feb45b71dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d493470000000000000000000000000000000000000000000000000000000000000000c4e85c67809eb78115a206d1bf1d7e0ed6db3a6d945682b3da1ed67b82346fa332f43e008aa70ea5b0408ea1b5de805d742a7a14b3634b92e947b899017cf137dcac3b5f5ee1380b22eecc9c0567455fb63db11d7c468935a15ae478d7415d09800000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000001000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000400000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001500000000000000000000000000000000000000000000000000000000009bbf55000000000000000000000000000000000000000000000000000000000001d4fb000000000000000000000000000000000000000000000000000000006443530c0000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d2e85500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010a1a846765746888676f312e31382e38856c696e757800000000000000de2acd1f67a1c084d8a3c4d8b0176fb6cfee96d4656f8fafc5230f74490f36a32540f0f5ce89e486dcf49aff7e6d11a7877cc49297a34a837ebe53dbcbc418d1010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dbf8d9b8b3f8b180a0ec28972d98f2fc53a982dae8f72427ed74dfba2d3383cf2c7b18bafeeacc96b0a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a02b70a98baa2507beffe8c266006cae52064dccf4fd1998af774ab3399029b38380808080a07394a09684ef3b2c87e9e2a753eb4ac78e2047b980e16d2e2133aee78946370d8080a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd78080808080a3e2a03030d8e8a13da56640e5b3267b60970c536c784b94d2014ac7ed4d6c0df88e34010000000000";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        bool isMessageReceived = destChainBridge.isMessageReceived(
            msgHash,
            1336,
            proof
        );

        assertEq(isMessageReceived, true);

        destChainBridge.processMessage(message, proof);

        LibBridgeStatus.MessageStatus status = destChainBridge.getMessageStatus(
            msgHash
        );

        assertEq(status == LibBridgeStatus.MessageStatus.DONE, true);
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
