// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";

contract EmptyContract_WithInfiniteFallback {
    fallback() external payable {
        while (true) { } // infinite loop forces the invocation to run out of gas
    }
}

contract TestBridge1Init3 is CommonTest {
    SignalService private eSignalService;
    Bridge private eBridge;

    SignalService private tSignalService;
    Bridge private tBridge;

    EmptyContract_WithInfiniteFallback private infiniteContract;

    function setUpOnEthereum() internal override {
        eSignalService = _deployMockSignalService();
        eBridge = deployBridge(address(new Bridge(address(resolver), address(eSignalService))));
    }

    function setUpOnTaiko() internal override {
        tSignalService = _deployMockSignalService();
        tBridge = deployBridge(address(new Bridge(address(resolver), address(tSignalService))));
        vm.deal(address(tBridge), 100 ether);
        infiniteContract = new EmptyContract_WithInfiniteFallback();
    }

    function test_init3_deletesMessageStatus() public {
        bytes32 msgHash1 = _processMessageToRetriable(0, 1000);
        bytes32 msgHash2 = _processMessageToRetriable(1, 2000);

        assertTrue(tBridge.messageStatus(msgHash1) == IBridge.Status.RETRIABLE);
        assertTrue(tBridge.messageStatus(msgHash2) == IBridge.Status.RETRIABLE);

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = msgHash1;
        hashes[1] = msgHash2;

        vm.expectEmit();
        emit IBridge.MessageStatusReset(msgHash1);
        vm.expectEmit();
        emit IBridge.MessageStatusReset(msgHash2);

        vm.prank(_owner());
        tBridge.init3(hashes);

        assertTrue(tBridge.messageStatus(msgHash1) == IBridge.Status.NEW);
        assertTrue(tBridge.messageStatus(msgHash2) == IBridge.Status.NEW);
    }

    function test_init3_RevertWhen_NotOwner() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = randBytes32();

        vm.prank(Alice);
        vm.expectRevert();
        tBridge.init3(hashes);
    }

    function test_init3_RevertWhen_StatusNotRetriable() public {
        // A random hash has status NEW (0), which is not RETRIABLE.
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = randBytes32();

        // Called as owner so the revert comes from the status check, not ownership.
        vm.prank(_owner());
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        tBridge.init3(hashes);
    }

    function test_init3_RevertWhen_CalledTwice() public {
        // First call uses an empty array so it succeeds trivially and consumes
        // the reinitializer(3), durably bumping the version to 3.
        bytes32[] memory empty = new bytes32[](0);
        vm.prank(_owner());
        tBridge.init3(empty);

        // reinitializer(3) is consumed; OZ reverts with InvalidInitialization().
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = randBytes32();
        vm.prank(_owner());
        vm.expectRevert();
        tBridge.init3(hashes);
    }

    function test_init3_emptyArray() public {
        bytes32[] memory hashes = new bytes32[](0);

        vm.prank(_owner());
        tBridge.init3(hashes);

        // reinitializer(3) is consumed even with an empty array; a second call reverts.
        vm.prank(_owner());
        vm.expectRevert();
        tBridge.init3(hashes);
    }

    function _owner() private view returns (address) {
        return Ownable2StepUpgradeable(address(tBridge)).owner();
    }

    /// @dev Drives a message to Status.RETRIABLE by sending it to a contract whose
    ///      fallback loops forever, so the bounded-gas invocation runs out of gas.
    function _processMessageToRetriable(
        uint64 id,
        uint256 value
    )
        private
        returns (bytes32 msgHash_)
    {
        IBridge.Message memory message = IBridge.Message({
            id: id,
            from: address(eBridge),
            srcChainId: ethereumChainId,
            destChainId: taikoChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(infiniteContract),
            value: value,
            fee: 1000,
            gasLimit: 1_000_000,
            data: ""
        });

        msgHash_ = tBridge.hashMessage(message);

        vm.chainId(taikoChainId);
        vm.prank(Bob);
        tBridge.processMessage(message, hex"00");
        vm.chainId(ethereumChainId);

        require(tBridge.messageStatus(msgHash_) == IBridge.Status.RETRIABLE, "setup failed");
    }

    function _deployMockSignalService() private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE")))), deployer
        );
    }
}
