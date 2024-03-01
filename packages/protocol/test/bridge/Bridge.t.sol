// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

// A contract which is not our ErcXXXTokenVault
// Which in such case, the sent funds are still recoverable, but not via the
// onMessageRecall() but Bridge will send it back
contract UntrustedSendMessageRelayer {
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

contract TwoStepBridge is Bridge {
    function getInvocationDelays()
        public
        pure
        override
        returns (uint256 invocationDelay, uint256 invocationExtraDelay)
    {
        return (10 hours, 2 hours);
    }
}

contract BridgeTest is TaikoTest {
    AddressManager addressManager;
    BadReceiver badReceiver;
    GoodReceiver goodReceiver;
    Bridge bridge;
    Bridge destChainBridge;
    TwoStepBridge dest2StepBridge;
    SignalService signalService;
    SkipProofCheckSignal mockProofSignalService;
    UntrustedSendMessageRelayer untrustedSenderContract;
    uint64 destChainId = 19_389;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 100 ether);

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            })
        );

        bridge = Bridge(
            payable(
                deployProxy({
                    name: "bridge",
                    impl: address(new Bridge()),
                    data: abi.encodeCall(Bridge.init, (address(0), address(addressManager))),
                    registerTo: address(addressManager)
                })
            )
        );

        destChainBridge = Bridge(
            payable(
                deployProxy({
                    name: "bridge",
                    impl: address(new Bridge()),
                    data: abi.encodeCall(Bridge.init, (address(0), address(addressManager)))
                })
            )
        );

        dest2StepBridge = TwoStepBridge(
            payable(
                deployProxy({
                    name: "2_step_bridge",
                    impl: address(new TwoStepBridge()),
                    data: abi.encodeCall(Bridge.init, (address(0), address(addressManager)))
                })
            )
        );

        mockProofSignalService = SkipProofCheckSignal(
            deployProxy({
                name: "signal_service",
                impl: address(new SkipProofCheckSignal()),
                data: abi.encodeCall(SignalService.init, (address(0), address(addressManager))),
                registerTo: address(addressManager)
            })
        );

        signalService = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, (address(0), address(addressManager)))
            })
        );

        vm.deal(address(destChainBridge), 100 ether);
        vm.deal(address(dest2StepBridge), 100 ether);

        untrustedSenderContract = new UntrustedSendMessageRelayer();
        vm.deal(address(untrustedSenderContract), 10 ether);

        register(
            address(addressManager), "signal_service", address(mockProofSignalService), destChainId
        );

        register(address(addressManager), "bridge", address(destChainBridge), destChainId);

        register(address(addressManager), "taiko", address(uint160(123)), destChainId);
        vm.stopPrank();
    }

    function test_Bridge_send_ether_to_to_with_value() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: Alice,
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        vm.chainId(destChainId);
        vm.prank(Bob, Bob);
        destChainBridge.processMessage(message, proof);

        IBridge.Status status = destChainBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);
        // Alice has 100 ether + 1000 wei balance, because we did not use the
        // 'sendMessage'
        // since we mocking the proof, so therefore the 1000 wei
        // deduction/transfer did
        // not happen
        assertEq(Alice.balance, 100_000_000_000_000_001_000);
        assertEq(Bob.balance, 1000);
    }

    function test_Bridge_processMessage_with_2_steps() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: Alice,
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = dest2StepBridge.hashMessage(message);

        vm.chainId(destChainId);
        // This in is the first transaction setting the proofReceipt
        vm.prank(Bob, Bob);
        dest2StepBridge.processMessage(message, proof);

        IBridge.Status status = dest2StepBridge.messageStatus(msgHash);
        // Still new ! Because of the delay, no processing happened
        assertEq(status == IBridge.Status.NEW, true);
        // Alice has 100 ether
        assertEq(Alice.balance, 100_000_000_000_000_000_000);

        // Go in the future, 5 hours, still not processable
        vm.warp(block.timestamp + 5 hours);

        vm.expectRevert(Bridge.B_INVOCATION_TOO_EARLY.selector);
        vm.prank(Bob, Bob);
        dest2StepBridge.processMessage(message, proof);

        // Go in the future, +6 hours, all in all 11 hours from first processing
        // Carol cannot process (as not preferred executor)
        vm.warp(block.timestamp + 6 hours);

        // Too eraly for Carol
        vm.expectRevert(Bridge.B_INVOCATION_TOO_EARLY.selector);
        vm.prank(Carol, Carol);
        dest2StepBridge.processMessage(message, proof);

        // Not too early for Bob
        vm.prank(Bob, Bob);
        dest2StepBridge.processMessage(message, proof);

        // Alice has 100 ether + 1000 wei balance
        assertEq(Alice.balance, 100_000_000_000_000_001_000);
    }

    function test_Bridge_processMessage_with_2_steps_and_not_preferred() public {
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: Alice,
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = dest2StepBridge.hashMessage(message);

        vm.chainId(destChainId);
        // This in is the first transaction setting the proofReceipt
        vm.prank(Bob, Bob);
        dest2StepBridge.processMessage(message, proof);

        IBridge.Status status = dest2StepBridge.messageStatus(msgHash);
        // Still new ! Because of the delay, no processing happened
        assertEq(status == IBridge.Status.NEW, true);
        // Alice has 100 ether
        assertEq(Alice.balance, 100_000_000_000_000_000_000);

        // Go in the future, 11 hours, still not processable
        vm.warp(block.timestamp + 11 hours);

        vm.expectRevert(Bridge.B_INVOCATION_TOO_EARLY.selector);
        vm.prank(Carol, Carol);
        dest2StepBridge.processMessage(message, proof);

        // Go in the future, +2 hours, all in all 13 hours
        vm.warp(block.timestamp + 2 hours);

        vm.prank(Carol, Carol);
        dest2StepBridge.processMessage(message, proof);

        // Alice has 100 ether + 1000 wei balance
        assertEq(Alice.balance, 100_000_000_000_000_001_000);
    }

    function test_Bridge_send_ether_to_contract_with_value() public {
        goodReceiver = new GoodReceiver();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(goodReceiver),
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        vm.chainId(destChainId);

        vm.prank(Bob, Bob);
        destChainBridge.processMessage(message, proof);

        IBridge.Status status = destChainBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);

        // Bob (relayer) and goodContract has 1000 wei balance
        assertEq(address(goodReceiver).balance, 1000);
        assertEq(Bob.balance, 1000);
    }

    function test_Bridge_send_ether_to_contract_with_value_and_message_data() public {
        goodReceiver = new GoodReceiver();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(goodReceiver),
            refundTo: Alice,
            value: 1000,
            fee: 1000,
            gasLimit: 1_000_000,
            data: abi.encodeCall(GoodReceiver.onMessageInvocation, abi.encode(Carol)),
            memo: ""
        });
        // Mocking proof - but obviously it needs to be created in prod
        // corresponding to the message
        bytes memory proof = hex"00";

        bytes32 msgHash = destChainBridge.hashMessage(message);

        vm.chainId(destChainId);

        vm.prank(Bob, Bob);
        destChainBridge.processMessage(message, proof);

        IBridge.Status status = destChainBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);

        // Carol and goodContract has 500 wei balance
        assertEq(address(goodReceiver).balance, 500);
        assertEq(Carol.balance, 500);
    }

    function test_Bridge_send_message_ether_reverts_if_value_doesnt_match_expected() public {
        // uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 1,
            destChain: destChainId
        });

        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        bridge.sendMessage(message);
    }

    function test_Bridge_send_message_ether_reverts_when_owner_is_zero_address() public {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: address(0),
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId
        });

        vm.expectRevert(Bridge.B_INVALID_USER.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_reverts_when_dest_chain_is_not_enabled() public {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId + 1
        });

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_reverts_when_dest_chain_same_as_block_chainid()
        public
    {
        uint256 amount = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: uint64(block.chainid)
        });

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    function test_Bridge_send_message_ether_with_no_processing_fee() public {
        uint256 amount = 0 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: 0,
            destChain: destChainId
        });

        (, IBridge.Message memory _message) = bridge.sendMessage{ value: amount }(message);
        assertEq(bridge.isMessageSent(_message), true);
    }

    function test_Bridge_send_message_ether_with_processing_fee() public {
        uint256 amount = 0 wei;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        (, IBridge.Message memory _message) = bridge.sendMessage{ value: amount + fee }(message);
        assertEq(bridge.isMessageSent(_message), true);
    }

    function test_Bridge_recall_message_ether() public {
        uint256 amount = 1 ether;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: amount,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        uint256 starterBalanceVault = address(bridge).balance;
        uint256 starterBalanceAlice = Alice.balance;

        vm.prank(Alice, Alice);
        (, IBridge.Message memory _message) = bridge.sendMessage{ value: amount + fee }(message);
        assertEq(bridge.isMessageSent(_message), true);

        assertEq(address(bridge).balance, (starterBalanceVault + amount + fee));
        assertEq(Alice.balance, (starterBalanceAlice - (amount + fee)));
        bridge.recallMessage(message, "");

        assertEq(address(bridge).balance, (starterBalanceVault + fee));
        assertEq(Alice.balance, (starterBalanceAlice - fee));
    }

    function test_Bridge_recall_message_ether_with_2_steps() public {
        uint256 amount = 1 ether;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: amount,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        uint256 starterBalanceVault = address(dest2StepBridge).balance;
        uint256 starterBalanceAlice = Alice.balance;

        vm.prank(Alice, Alice);
        (, IBridge.Message memory _message) =
            dest2StepBridge.sendMessage{ value: amount + fee }(message);
        assertEq(dest2StepBridge.isMessageSent(_message), true);

        assertEq(address(dest2StepBridge).balance, (starterBalanceVault + amount + fee));
        assertEq(Alice.balance, (starterBalanceAlice - (amount + fee)));

        vm.prank(Bob, Bob);
        dest2StepBridge.recallMessage(message, "");
        // Go in the future, 5 hours, still not processable
        vm.warp(block.timestamp + 5 hours);

        vm.expectRevert(Bridge.B_INVOCATION_TOO_EARLY.selector);
        vm.prank(Bob, Bob);
        dest2StepBridge.recallMessage(message, "");

        // Go in the future, +6 hours, all in all 11 hours from first processing
        vm.warp(block.timestamp + 6 hours);

        // Not too early anymore
        vm.prank(Bob, Bob);
        dest2StepBridge.recallMessage(message, "");

        assertEq(address(dest2StepBridge).balance, (starterBalanceVault + fee));
        assertEq(Alice.balance, (starterBalanceAlice - fee));
    }

    function test_Bridge_recall_message_but_not_supports_recall_interface() public {
        // In this test we expect that the 'message value is still refundable,
        // just not via
        // ERCXXTokenVault (message.from) but directly from the Bridge

        uint256 amount = 1 ether;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: amount,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        uint256 starterBalanceVault = address(bridge).balance;

        (, message) = untrustedSenderContract.sendMessage(address(bridge), message, amount + fee);

        assertEq(address(bridge).balance, (starterBalanceVault + amount + fee));

        bridge.recallMessage(message, "");

        assertEq(address(bridge).balance, (starterBalanceVault + fee));
    }

    function test_Bridge_send_message_ether_with_processing_fee_invalid_amount() public {
        uint256 amount = 0 wei;
        uint256 fee = 1 wei;
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 0,
            fee: fee,
            destChain: destChainId
        });

        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        bridge.sendMessage{ value: amount }(message);
    }

    // test with a known good merkle proof / message since we cant generate
    // proofs via rpc
    // in foundry
    function test_Bridge_process_message() public {
        // This predefined successful process message call fails now
        // since we modified the iBridge.Message struct and cut out
        // depositValue
        vm.startPrank(Alice);
        (IBridge.Message memory message, bytes memory proof) =
            setUpPredefinedSuccessfulProcessMessageCall();

        bytes32 msgHash = destChainBridge.hashMessage(message);

        destChainBridge.processMessage(message, proof);

        IBridge.Status status = destChainBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);
    }

    // test with a known good merkle proof / message since we cant generate
    // proofs via rpc
    // in foundry
    function test_Bridge_retry_message_and_end_up_in_failed_status() public {
        vm.startPrank(Alice);
        (IBridge.Message memory message, bytes memory proof) =
            setUpPredefinedSuccessfulProcessMessageCall();

        // etch bad receiver at the to address, so it fails.
        vm.etch(message.to, address(badReceiver).code);

        bytes32 msgHash = destChainBridge.hashMessage(message);

        destChainBridge.processMessage(message, proof);

        IBridge.Status status = destChainBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.RETRIABLE, true);

        vm.stopPrank();

        vm.prank(message.destOwner);
        destChainBridge.retryMessage(message, false);
        IBridge.Status postRetryStatus = destChainBridge.messageStatus(msgHash);
        assertEq(postRetryStatus == IBridge.Status.RETRIABLE, true);

        vm.prank(message.destOwner);
        destChainBridge.retryMessage(message, true);
        postRetryStatus = destChainBridge.messageStatus(msgHash);
        assertEq(postRetryStatus == IBridge.Status.FAILED, true);
    }

    function retry_message_reverts_when_status_non_retriable() public {
        IBridge.Message memory message = newMessage({
            owner: Alice,
            to: Alice,
            value: 0,
            gasLimit: 10_000,
            fee: 1,
            destChain: destChainId
        });

        vm.expectRevert(Bridge.B_NON_RETRIABLE.selector);
        destChainBridge.retryMessage(message, true);
    }

    function retry_message_reverts_when_last_attempt_and_message_is_not_owner() public {
        vm.startPrank(Alice);
        IBridge.Message memory message = newMessage({
            owner: Bob,
            to: Alice,
            value: 0,
            gasLimit: 10_000,
            fee: 1,
            destChain: destChainId
        });

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        destChainBridge.retryMessage(message, true);
    }

    function setUpPredefinedSuccessfulProcessMessageCall()
        internal
        returns (IBridge.Message memory, bytes memory)
    {
        badReceiver = new BadReceiver();

        uint64 dest = 1337;
        addressManager.setAddress(1336, "bridge", 0x564540a26Fb667306b3aBdCB4ead35BEb88698ab);

        addressManager.setAddress(dest, "bridge", address(destChainBridge));

        vm.deal(address(bridge), 100 ether);

        addressManager.setAddress(dest, "signal_service", address(mockProofSignalService));

        vm.deal(address(destChainBridge), 1 ether);

        vm.chainId(dest);

        // known message that corresponds with below proof.
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            srcChainId: 1336,
            destChainId: dest,
            srcOwner: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
            destOwner: 0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39,
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
        address owner,
        address to,
        uint256 value,
        uint256 gasLimit,
        uint256 fee,
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
            srcChainId: uint64(block.chainid), // will be overwritten
            refundTo: owner,
            gasLimit: gasLimit,
            data: "",
            memo: ""
        });
    }
}
