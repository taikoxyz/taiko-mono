// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { IBridge, Bridge } from "../../contracts/bridge/Bridge.sol";
import { BridgeErrors } from "../../contracts/bridge/BridgeErrors.sol";
import { EtherVault } from "../../contracts/bridge/EtherVault.sol";
import { console2 } from "forge-std/console2.sol";
import { LibBridgeStatus } from
    "../../contracts/bridge/libs/LibBridgeStatus.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";
import {
    TestBase,
    SkipProofCheckBridge,
    DummyCrossChainSync,
    GoodReceiver,
    BadReceiver
} from "../TestBase.sol";

contract BridgeTest is TestBase {
    AddressManager addressManager;
    BadReceiver badReceiver;
    GoodReceiver goodReceiver;
    Bridge bridge;
    Bridge destChainBridge;
    EtherVault etherVault;
    SignalService signalService;
    DummyCrossChainSync crossChainSync;
    SkipProofCheckBridge mockProofBridge;
    uint256 destChainId = 19_389;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 100 ether);
        addressManager = new AddressManager();
        addressManager.init();

        bridge = new Bridge();
        bridge.init(address(addressManager));

        destChainBridge = new Bridge();
        destChainBridge.init(address(addressManager));

        vm.deal(address(destChainBridge), 100 ether);

        mockProofBridge = new SkipProofCheckBridge();
        mockProofBridge.init(address(addressManager));

        vm.deal(address(mockProofBridge), 100 ether);

        signalService = new SignalService();
        signalService.init(address(addressManager));

        etherVault = new EtherVault();
        etherVault.init(address(addressManager));

        crossChainSync = new DummyCrossChainSync();

        addressManager.setAddress(
            block.chainid, "signal_service", address(signalService)
        );

        addressManager.setAddress(
            destChainId, "bridge", address(destChainBridge)
        );

        addressManager.setAddress(block.chainid, "bridge", address(bridge));

        vm.stopPrank();
    }

    function test_Bridge_send_ether_to_to_with_value() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: block.chainid,
            destChainId: destChainId,
            user: Alice,
            to: Alice,
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // coresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        vm.chainId(destChainId);
        vm.prank(Bob, Bob);
        mockProofBridge.processMessage(message, proof);

        LibBridgeStatus.MessageStatus status =
            mockProofBridge.getMessageStatus(msgHash);

        assertEq(status == LibBridgeStatus.MessageStatus.DONE, true);
        // Alice has 100 ether + 1000 wei balance, because we did not use the
        // 'sendMessage'
        // since we mocking the proof, so therefore the 1000 wei
        // deduction/transfer did
        // not happen
        assertEq(Alice.balance, 100_000_000_000_000_001_000);
        assertEq(Bob.balance, 1000);
    }

    function test_Bridge_send_ether_to_contract_with_value() public {
        goodReceiver = new GoodReceiver();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: block.chainid,
            destChainId: destChainId,
            user: Alice,
            to: address(goodReceiver),
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // coresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        vm.chainId(destChainId);

        vm.prank(Bob, Bob);
        mockProofBridge.processMessage(message, proof);

        LibBridgeStatus.MessageStatus status =
            mockProofBridge.getMessageStatus(msgHash);

        assertEq(status == LibBridgeStatus.MessageStatus.DONE, true);

        // Bob (relayer) and goodContract has 1000 wei balance
        assertEq(address(goodReceiver).balance, 1000);
        assertEq(Bob.balance, 1000);
    }

    function test_Bridge_send_ether_to_contract_with_value_and_message_data()
        public
    {
        goodReceiver = new GoodReceiver();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: block.chainid,
            destChainId: destChainId,
            user: Alice,
            to: address(goodReceiver),
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: abi.encodeWithSelector(GoodReceiver.forward.selector, Carol),
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // coresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        vm.chainId(destChainId);

        vm.prank(Bob, Bob);
        mockProofBridge.processMessage(message, proof);

        LibBridgeStatus.MessageStatus status =
            mockProofBridge.getMessageStatus(msgHash);

        assertEq(status == LibBridgeStatus.MessageStatus.DONE, true);

        // Carol and goodContract has 500 wei balance
        assertEq(address(goodReceiver).balance, 500);
        assertEq(Carol.balance, 500);
    }

    function test_Bridge_send_message_ether_reverts_if_value_doesnt_match_expected(
    )
        public
    {
        //uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 1,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_INCORRECT_VALUE.selector);
        bridge.sendMessage(message);
    }

    function test_Bridge_send_message_ether_reverts_when_owner_is_zero_address()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            user: address(0),
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_USER_IS_NULL.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_reverts_when_dest_chain_is_not_enabled(
    )
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId + 1
        });

        vm.expectRevert(BridgeErrors.B_WRONG_CHAIN_ID.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_reverts_when_dest_chain_same_as_block_chainid(
    )
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: block.chainid
        });

        vm.expectRevert(BridgeErrors.B_WRONG_CHAIN_ID.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_reverts_when_to_is_zero_address()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: address(0),
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_WRONG_TO_ADDRESS.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_with_no_processing_fee() public {
        uint256 amount = 0 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId
        });

        bytes32 msgHash = bridge.sendMessage{ value: amount }(message);

        bool isMessageSent = bridge.isMessageSent(msgHash);
        assertEq(isMessageSent, true);
    }

    function test_Bridge_send_message_ether_with_processing_fee() public {
        uint256 amount = 0 wei;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        bytes32 msgHash = bridge.sendMessage{ value: amount + fee }(message);

        bool isMessageSent = bridge.isMessageSent(msgHash);
        assertEq(isMessageSent, true);
    }

    function test_Bridge_send_message_ether_with_processing_fee_invalid_amount()
        public
    {
        uint256 amount = 0 wei;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_INCORRECT_VALUE.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    // test with a known good merkle proof / message since we cant generate
    // proofs via rpc
    // in foundry
    function test_Bridge_process_message() public {
        /* DISCALIMER: From now on we do not need to have real
        proofs because we cna bypass with overriding shouldCheckProof()
        in a mockBirdge AND proof system already 'battle tested'.*/
        // This predefined successful process message call fails now
        // since we modified the iBridge.Message struct and cut out
        // depositValue
        vm.startPrank(Alice);
        (IBridge.Message memory message, bytes memory proof) =
            setUpPredefinedSuccessfulProcessMessageCall();

        bytes32 msgHash = destChainBridge.hashMessage(message);

        mockProofBridge.processMessage(message, proof);

        LibBridgeStatus.MessageStatus status =
            mockProofBridge.getMessageStatus(msgHash);

        assertEq(status == LibBridgeStatus.MessageStatus.DONE, true);
    }

    // test with a known good merkle proof / message since we cant generate
    // proofs via rpc
    // in foundry
    function test_Bridge_retry_message_and_end_up_in_failed_status() public {
        /* DISCALIMER: From now on we do not need to have real
        proofs because we cna bypass with overriding shouldCheckProof()
        in a mockBirdge AND proof system already 'battle tested'.*/
        vm.startPrank(Alice);
        (IBridge.Message memory message, bytes memory proof) =
            setUpPredefinedSuccessfulProcessMessageCall();

        // etch bad receiver at the to address, so it fails.
        vm.etch(message.to, address(badReceiver).code);

        bytes32 msgHash = destChainBridge.hashMessage(message);

        mockProofBridge.processMessage(message, proof);

        LibBridgeStatus.MessageStatus status =
            mockProofBridge.getMessageStatus(msgHash);

        assertEq(status == LibBridgeStatus.MessageStatus.RETRIABLE, true);

        vm.stopPrank();
        vm.prank(message.user);

        mockProofBridge.retryMessage(message, true);

        LibBridgeStatus.MessageStatus postRetryStatus =
            mockProofBridge.getMessageStatus(msgHash);

        assertEq(postRetryStatus == LibBridgeStatus.MessageStatus.FAILED, true);
    }

    function retry_message_reverts_when_status_non_retriable() public {
        IBridge.Message memory message = newMessage({
            user: Alice,
            to: Alice,
            value: 0,
            gasLimit: 10_000,
            fee: 1,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_MSG_NON_RETRIABLE.selector);
        destChainBridge.retryMessage(message, true);
    }

    function retry_message_reverts_when_last_attempt_and_message_is_not_owner()
        public
    {
        vm.startPrank(Alice);
        IBridge.Message memory message = newMessage({
            user: Bob,
            to: Alice,
            value: 0,
            gasLimit: 10_000,
            fee: 1,
            destChain: destChainId
        });

        vm.expectRevert(BridgeErrors.B_DENIED.selector);
        destChainBridge.retryMessage(message, true);
    }

    /* DISCALIMER: From now on we do not need to have real
    proofs because we cna bypass with overriding shouldCheckProof()
    in a mockBirdge AND proof system already 'battle tested'.*/
    function setUpPredefinedSuccessfulProcessMessageCall()
        internal
        returns (IBridge.Message memory, bytes memory)
    {
        badReceiver = new BadReceiver();

        uint256 dest = 1337;
        addressManager.setAddress(dest, "taiko", address(crossChainSync));

        addressManager.setAddress(
            1336, "bridge", 0x564540a26Fb667306b3aBdCB4ead35BEb88698ab
        );

        addressManager.setAddress(dest, "bridge", address(destChainBridge));

        addressManager.setAddress(dest, "ether_vault", address(etherVault));

        etherVault.authorize(address(destChainBridge), true);
        etherVault.authorize(address(mockProofBridge), true);

        vm.deal(address(etherVault), 100 ether);

        addressManager.setAddress(
            dest, "signal_service", address(signalService)
        );

        crossChainSync.setCrossChainBlockHeader(
            0xd5f5d8ac6bc37139c97389b00e9cf53e89c153ad8a5fc765ffe9f44ea9f3d31e
        );

        crossChainSync.setCrossChainSignalRoot(
            0x631b214fb030d82847224f0b3d3b906a6764dded176ad3c7262630204867ba85
        );

        vm.deal(address(destChainBridge), 1 ether);

        vm.chainId(dest);

        // known message that corresponds with below proof.
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            srcChainId: 1336,
            destChainId: dest,
            user: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            to: 0x200708D76eB1B69761c23821809d53F65049939e,
            refundTo: 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });

        bytes memory proof =
            hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e0f7ff3b519ec113138509a5b1b6f54761cebc6891bc0ba4f904b89688b1ef8e051dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d493470000000000000000000000000000000000000000000000000000000000000000a85358ff57974db8c9ce2ecabe743d44133f9d11e5da97e386111073f1a2f92c345bd00c2ef9db5726d84c184af67fdbad0be00921eb1dcbca674c427abb5c3ebda7d1e94e5b2b3d5e6a54c9a42423b1746afa4b264e7139877c0523c3397ec4000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000002000800002000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000001000040000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001500000000000000000000000000000000000000000000000000000000009bbf55000000000000000000000000000000000000000000000000000000000001d4fb0000000000000000000000000000000000000000000000000000000064435d130000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d2e85500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061d883010a1a846765746888676f312e31382e38856c696e75780000000000000015b1ca61fbe1aa968ab60a461913aa40046b5357162466a4134d195647c14dd7488dd438abb39d6574e7d9d752fa2381bbd9dc780efc3fcc66af5285ebcb117b010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dbf8d9b8b3f8b18080a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28a02b70a98baa2507beffe8c266006cae52064dccf4fd1998af774ab3399029b38380808080a07394a09684ef3b2c87e9e2a753eb4ac78e2047b980e16d2e2133aee78946370d8080a0f4984a11f61a2921456141df88de6e1a710d28681b91af794c5a721e47839cd78080a09248167635e6f0eb40f782a6bbd237174104259b6af88b3c52086214098f0e2c8080a3e2a03ecd5e1f251bf1676a367f6b16e92ffe6b2638b4a27b3d31870d25442bd59ef4010000000000";

        return (message, proof);
    }

    function newMessage(
        address user,
        address to,
        uint256 value,
        uint256 gasLimit,
        uint256 fee,
        uint256 destChain
    )
        internal
        view
        returns (IBridge.Message memory)
    {
        return IBridge.Message({
            user: user,
            destChainId: destChain,
            to: to,
            value: value,
            fee: fee,
            id: 0, // placeholder, will be overwritten
            from: user, // placeholder, will be overwritten
            srcChainId: block.chainid, // will be overwritten
            refundTo: user,
            gasLimit: gasLimit,
            data: "",
            memo: ""
        });
    }
}
