// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "test/shared/bridge/helpers/MessageReceiver_SendingHalfEtherBalance.sol";

// A contract which is not our registered ERCXXXVault. In such case, the sent funds are still
// recoverable, but not via the onMessageRecall() but Bridge will send it back
contract UnregisteredVault {
    function sendMessage(
        address bridge,
        IBridge.Message memory message,
        uint256 message_value
    )
        public
        returns (bytes32 msgHash, IBridge.Message memory updatedMessage)
    {
        return IBridge(bridge).sendMessage{ value: message_value }(message);
    }
}

contract EmptyContract_WithFallback {
    fallback() external payable { }
}

contract EmptyContract_WithInfiniteFallback {
    fallback() external payable {
        while (true) { } // infinite loop
    }
}

contract TestBridge1 is CommonTest {
    // Contracts on Ethereum
    MessageReceiver_SendingHalfEtherBalance private eMessageReceiver;
    SignalService private eSignalService;
    Bridge private eBridge;

    // Contracts on Taiko
    SignalService private tSignalService;
    Bridge private tBridge;

    function setUpOnEthereum() internal override {
        eMessageReceiver = new MessageReceiver_SendingHalfEtherBalance();

        eSignalService = _deployMockSignalService();
        eBridge = deployBridge(address(new Bridge(address(resolver), address(eSignalService))));

        vm.deal(Alice, 100 ether);
    }

    function setUpOnTaiko() internal override {
        tSignalService = _deployMockSignalService();
        tBridge = deployBridge(address(new Bridge(address(resolver), address(tSignalService))));
        vm.deal(address(tBridge), 100 ether);
    }

    function test_bridge1_send_ether_to_to_with_value() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(eBridge),
            srcChainId: ethereumChainId,
            destChainId: taikoChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: Alice,
            value: 10_000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = tBridge.hashMessage(message);

        vm.chainId(taikoChainId);
        vm.prank(Bob);
        tBridge.processMessage(message, proof);

        IBridge.Status status = tBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);
        // Alice has 100 ether + 1000 wei balance, because we did not use the
        // 'sendMessage'
        // since we mocking the proof, so therefore the 1000 wei
        // deduction/transfer did not happen
        assertTrue(Alice.balance >= 100 ether + 10_000);
        assertTrue(Alice.balance <= 100 ether + 10_000 + 1000);
        assertTrue(Bob.balance >= 0 && Bob.balance <= 1000);
    }

    function test_bridge1_send_ether_to_contract_with_value_simple() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(eBridge),
            srcChainId: ethereumChainId,
            destChainId: taikoChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(eMessageReceiver),
            value: 10_000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = tBridge.hashMessage(message);

        vm.chainId(taikoChainId);
        vm.prank(Bob);
        tBridge.processMessage(message, proof);

        IBridge.Status status = tBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);

        // Bob (relayer) and goodContract has 1000 wei balance
        assertEq(address(eMessageReceiver).balance, 10_000);
        console2.log("Bob.balance:", Bob.balance);
        assertTrue(Bob.balance >= 0 && Bob.balance <= 1000);
    }

    function test_bridge1_send_ether_to_contract_with_value_and_message_data() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(eBridge),
            srcChainId: ethereumChainId,
            destChainId: taikoChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(eMessageReceiver),
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: abi.encodeCall(
                MessageReceiver_SendingHalfEtherBalance.onMessageInvocation, abi.encode(Carol)
            )
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = tBridge.hashMessage(message);

        vm.chainId(taikoChainId);
        vm.prank(Bob);
        tBridge.processMessage(message, proof);

        IBridge.Status status = tBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);

        // Carol and goodContract has 500 wei balance
        assertEq(address(eMessageReceiver).balance, 500);
        assertEq(Carol.balance, 500);
    }

    function test_bridge1_send_message_ether_reverts_if_value_doesnt_match_expected() public {
        // uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 1_000_000,
            fee: 1_000_000,
            destChain: taikoChainId
        });

        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        eBridge.sendMessage(message);
    }

    function test_bridge1_send_message_ether_reverts_when_owner_is_zero_address() public {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: address(0), to: Alice, value: 0, gasLimit: 0, fee: 0, destChain: taikoChainId
        });

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        eBridge.sendMessage{ value: amount }(message);
    }

    function test_bridge1_send_message_ether_reverts_when_dest_chain_is_not_enabled() public {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice, to: Alice, value: 0, gasLimit: 0, fee: 0, destChain: taikoChainId + 1
        });

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.sendMessage{ value: amount }(message);
    }

    function test_bridge1_send_message_ether_reverts_when_dest_chain_same_as_block_chainid()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice, to: Alice, value: 0, gasLimit: 0, fee: 0, destChain: ethereumChainId
        });

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.sendMessage{ value: amount }(message);
    }

    function test_bridge1_send_message_ether_with_no_processing_fee() public {
        uint256 amount = 0 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice, to: Alice, value: 0, gasLimit: 0, fee: 0, destChain: taikoChainId
        });

        (, IBridge.Message memory _message) = eBridge.sendMessage{ value: amount }(message);
        assertEq(eBridge.isMessageSent(_message), true);
    }

    function test_bridge1_send_message_ether_with_processing_fee() public {
        uint256 amount = 0 wei;
        uint64 fee = 1_000_000 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 1_000_000,
            fee: fee,
            destChain: taikoChainId
        });

        (, IBridge.Message memory _message) = eBridge.sendMessage{ value: amount + fee }(message);
        assertEq(eBridge.isMessageSent(_message), true);
    }

    function test_bridge1_recall_message_ether() public {
        uint256 amount = 1 ether;
        uint64 fee = 0 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice, to: Alice, value: amount, gasLimit: 0, fee: fee, destChain: taikoChainId
        });

        uint256 starterBalanceVault = address(eBridge).balance;
        uint256 starterBalanceAlice = Alice.balance;

        vm.prank(Alice);
        (, IBridge.Message memory _message) = eBridge.sendMessage{ value: amount + fee }(message);
        assertEq(eBridge.isMessageSent(_message), true);

        assertEq(address(eBridge).balance, (starterBalanceVault + amount + fee));
        assertEq(Alice.balance, (starterBalanceAlice - (amount + fee)));
        eBridge.recallMessage(message, "");

        assertEq(address(eBridge).balance, (starterBalanceVault + fee));
        assertEq(Alice.balance, (starterBalanceAlice - fee));
    }

    function test_bridge1_recall_message_but_not_supports_recall_interface() public {
        // In this test we expect that the 'message value is still refundable,
        // just not via
        // ERCXXTokenVault (message.from) but directly from the Bridge

        uint256 amount = 1 ether;
        uint64 fee = 0 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice, to: Alice, value: amount, gasLimit: 0, fee: fee, destChain: taikoChainId
        });

        uint256 starterBalanceVault = address(eBridge).balance;

        UnregisteredVault unregisteredVault = new UnregisteredVault();
        vm.deal(address(unregisteredVault), 10 ether);

        (, message) = unregisteredVault.sendMessage(address(eBridge), message, amount + fee);

        assertEq(address(eBridge).balance, (starterBalanceVault + amount + fee));

        eBridge.recallMessage(message, "");

        assertEq(address(eBridge).balance, (starterBalanceVault + fee));
    }

    function test_bridge1_send_message_ether_with_processing_fee_invalid_amount() public {
        uint256 amount = 0 wei;
        uint64 fee = 1_000_000 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 1_000_000,
            fee: fee,
            destChain: taikoChainId
        });

        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        eBridge.sendMessage{ value: amount }(message);
    }

    function test_processMessage_InvokeMessageCall_DoS1() public {
        EmptyContract_WithFallback to = new EmptyContract_WithFallback();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(this),
            srcChainId: ethereumChainId,
            destChainId: taikoChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(to),
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: ""
        });

        bytes memory proof = hex"00";
        bytes32 msgHash = tBridge.hashMessage(message);
        vm.chainId(taikoChainId);
        vm.prank(Bob);

        tBridge.processMessage(message, proof);

        IBridge.Status status = tBridge.messageStatus(msgHash);
        assertEq(status == IBridge.Status.DONE, true); // test pass check
    }

    function test_processMessage_InvokeMessageCall_DoS2_testfail() public {
        EmptyContract_WithInfiniteFallback to = new EmptyContract_WithInfiniteFallback();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(this),
            srcChainId: ethereumChainId,
            destChainId: taikoChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(to),
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: ""
        });

        bytes memory proof = hex"00";
        bytes32 msgHash = tBridge.hashMessage(message);
        vm.chainId(taikoChainId);
        vm.prank(Bob);

        tBridge.processMessage(message, proof);

        IBridge.Status status = tBridge.messageStatus(msgHash);
        assertEq(status == IBridge.Status.RETRIABLE, true); //Test fail check
    }

    function retry_message_reverts_when_status_non_retriable() public {
        IBridge.Message memory message = newMessage({
            owner: Alice, to: Alice, value: 0, gasLimit: 10_000, fee: 1, destChain: taikoChainId
        });

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        tBridge.retryMessage(message, true);
    }

    function retry_message_reverts_when_last_attempt_and_message_is_not_owner() public {
        vm.startPrank(Alice);
        IBridge.Message memory message = newMessage({
            owner: Bob, to: Alice, value: 0, gasLimit: 10_000, fee: 1, destChain: taikoChainId
        });

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        tBridge.retryMessage(message, true);
    }

    function newMessage(
        address owner,
        address to,
        uint256 value,
        uint32 gasLimit,
        uint64 fee,
        uint64 destChain
    )
        internal
        view
        returns (IBridge.Message memory)
    {
        return IBridge.Message({
            srcOwner: owner,
            destOwner: owner,
            destChainId: destChain,
            to: to,
            value: value,
            fee: fee,
            id: 0, // placeholder, will be overwritten
            from: owner, // placeholder, will be overwritten
            srcChainId: ethereumChainId, // will be overwritten
            gasLimit: gasLimit,
            data: ""
        });
    }

    function _deployMockSignalService() private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE")))), deployer
        );
    }
}
