// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract SignalServiceForTest is SignalService {
    bool private _skipVerifyMerkleProof;
    bool private _multiHopEnabled;

    function setSkipMerkleProofCheck(bool skip) external {
        _skipVerifyMerkleProof = skip;
    }

    function setMultiHopEnabled(bool enabled) external {
        _multiHopEnabled = enabled;
    }

    function verifyMerkleProof(
        bytes32, /*stateRoot*/
        uint64, /*srcChainId*/
        address, /*srcApp*/
        bytes32, /*srcSignal*/
        bytes memory /*merkleProof*/
    )
        public
        view
        override
    {
        if (!_skipVerifyMerkleProof) revert("verifyMerkleProof failed");
    }

    function isMultiHopEnabled() public view override returns (bool) {
        return _multiHopEnabled;
    }
}

contract TestSignalService is TaikoTest {
    AddressManager addressManager;
    SignalServiceForTest signalService;
    SignalService destSignalService;
    HopRelayRegistry hopRelayRegistry;
    DummyCrossChainSync crossChainSync;
    uint64 public destChainId = 7;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, ()),
                registerTo: address(addressManager),
                owner: address(0)
            })
        );

        signalService = SignalServiceForTest(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalServiceForTest()),
                data: abi.encodeCall(SignalService.init, (address(addressManager)))
            })
        );

        hopRelayRegistry = HopRelayRegistry(
            deployProxy({
                name: "hop_relay_registry",
                impl: address(new HopRelayRegistry()),
                data: abi.encodeCall(HopRelayRegistry.init, ()),
                registerTo: address(addressManager),
                owner: address(0)
            })
        );

        destSignalService = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalServiceForTest()),
                data: abi.encodeCall(SignalService.init, (address(addressManager)))
            })
        );

        crossChainSync = DummyCrossChainSync(
            deployProxy({
                name: "taiko", // must be named so
                impl: address(new DummyCrossChainSync()),
                data: ""
            })
        );

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
        signalService.setSkipMerkleProofCheck(true);
        signalService.setMultiHopEnabled(false);

        bytes32 stateRoot = randBytes32();
        crossChainSync.setSyncedData("", stateRoot);

        uint64 thisChainId = uint64(block.chainid);

        uint64 srcChainId = thisChainId + 1;
        address app = randAddress();
        bytes32 signal = randBytes32();

        SignalService.Proof memory p;
        p.height = 10;
        // p.merkleProof = "doesn't matter";

        vm.expectRevert(); // cannot resolve "taiko"
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

        vm.startPrank(Alice);
        register(address(addressManager), "taiko", address(crossChainSync), thisChainId);
        assertEq(signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p)), true);

        signalService.setSkipMerkleProofCheck(false);

        vm.expectRevert(); // cannot decode the proof
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));
    }
}
