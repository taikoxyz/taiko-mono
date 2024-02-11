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
        uint64, /*srcChainId*/
        address, /*srcApp*/
        bytes32, /*srcSignal*/
        bytes32, /*rootHash*/
        bool, /*isStateRoot*/
        bytes memory /*merkleProof*/
    )
        public
        view
        override
        returns (bytes32)
    {
        if (!_skipVerifyMerkleProof) revert("verifyMerkleProof failed");
    }

    function isMultiHopEnabled() public view override returns (bool) {
        return _multiHopEnabled;
    }
}

contract TestSignalService is TaikoTest {
// AddressManager addressManager;
// SignalServiceForTest signalService;
// SignalService destSignalService;
// HopRelayRegistry hopRelayRegistry;
// DummyCrossChainSync crossChainSync;
// uint64 public destChainId = 7;

// function setUp() public {
//     vm.startPrank(Alice);
//     vm.deal(Alice, 1 ether);
//     vm.deal(Bob, 1 ether);

//     addressManager = AddressManager(
//         deployProxy({
//             name: "address_manager",
//             impl: address(new AddressManager()),
//             data: abi.encodeCall(AddressManager.init, ()),
//             registerTo: address(addressManager),
//             owner: address(0)
//         })
//     );

//     signalService = SignalServiceForTest(
//         deployProxy({
//             name: "signal_service",
//             impl: address(new SignalServiceForTest()),
//             data: abi.encodeCall(SignalService.init, (address(addressManager)))
//         })
//     );

//     hopRelayRegistry = HopRelayRegistry(
//         deployProxy({
//             name: "hop_relay_registry",
//             impl: address(new HopRelayRegistry()),
//             data: abi.encodeCall(HopRelayRegistry.init, ()),
//             registerTo: address(addressManager),
//             owner: address(0)
//         })
//     );

//     destSignalService = SignalService(
//         deployProxy({
//             name: "signal_service",
//             impl: address(new SignalServiceForTest()),
//             data: abi.encodeCall(SignalService.init, (address(addressManager)))
//         })
//     );

//     crossChainSync = DummyCrossChainSync(
//         deployProxy({
//             name: "taiko", // must be named so
//             impl: address(new DummyCrossChainSync()),
//             data: ""
//         })
//     );

//     vm.stopPrank();
// }

// function test_SignalService_sendSignal_revert() public {
//     vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
//     signalService.sendSignal(0);
// }

// function test_SignalService_isSignalSent_revert() public {
//     bytes32 signal = bytes32(uint256(1));
//     vm.expectRevert(SignalService.SS_INVALID_APP.selector);
//     signalService.isSignalSent(address(0), signal);

//     signal = bytes32(uint256(0));
//     vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
//     signalService.isSignalSent(Alice, signal);
// }

// function test_SignalService_sendSignal_isSignalSent() public {
//     vm.startPrank(Alice);
//     bytes32 signal = bytes32(uint256(1));
//     signalService.sendSignal(signal);

//     assertTrue(signalService.isSignalSent(Alice, signal));
// }

// function test_SignalService_getSignalSlot() public {
//     vm.startPrank(Alice);
//     for (uint8 i = 1; i < 100; ++i) {
//         bytes32 signal = bytes32(block.prevrandao + i);
//         signalService.sendSignal(signal);

//         assertTrue(signalService.isSignalSent(Alice, signal));
//     }
// }

// function test_SignalService_proveSignalReceived_L1_L2() public {
//     signalService.setSkipMerkleProofCheck(true);
//     signalService.setMultiHopEnabled(false);

//     bytes32 stateRoot = randBytes32();
//     crossChainSync.setSyncedData("", stateRoot);

//     uint64 thisChainId = uint64(block.chainid);

//     uint64 srcChainId = thisChainId + 1;
//     address app = randAddress();
//     bytes32 signal = randBytes32();

//     SignalService.Proof memory p;
//     p.height = 10;
//     // p.merkleProof = "doesn't matter";

//     vm.expectRevert(); // cannot resolve "taiko"
//     signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

//     vm.startPrank(Alice);
//     register(address(addressManager), "taiko", address(crossChainSync), thisChainId);
//     assertEq(signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p)), true);

//     signalService.setSkipMerkleProofCheck(false);

//     vm.expectRevert(); // cannot decode the proof
//     signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));
// }

// function test_SignalService_proveSignalReceived_multi_hop_L2_L2() public {
//     signalService.setSkipMerkleProofCheck(true);
//     signalService.setMultiHopEnabled(false);

//     bytes32 stateRoot = randBytes32();
//     crossChainSync.setSyncedData("", stateRoot);

//     uint64 thisChainId = uint64(block.chainid);

//     uint64 srcChainId = thisChainId + 1;

//     uint64 hop1ChainId = thisChainId + 2;
//     address hop1Relay = randAddress();
//     bytes32 hop1StateRoot = randBytes32();

//     uint64 hop2ChainId = thisChainId + 3;
//     address hop2Relay = randAddress();
//     bytes32 hop2StateRoot = randBytes32();

//     address app = randAddress();
//     bytes32 signal = randBytes32();

//     SignalService.Proof memory p;
//     p.height = 10;
//     p.hops = new SignalService.Hop[](2);

//     p.hops[0] = SignalService.Hop({
//         chainId: hop1ChainId,
//         relay: hop1Relay,
//         stateRoot: hop1StateRoot,
//         merkleProof: "dummy proof1"
//     });

//     p.hops[1] = SignalService.Hop({
//         chainId: hop2ChainId,
//         relay: hop2Relay,
//         stateRoot: hop2StateRoot,
//         merkleProof: "dummy proof2"
//     });

//     vm.startPrank(Alice);
//     register(address(addressManager), "taiko", address(crossChainSync), thisChainId);

//     // Multiple is disabled, shall revert
//     vm.expectRevert(SignalService.SS_MULTIHOP_DISABLED.selector);
//     signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

//     // Enable multi-hop
//     vm.startPrank(Alice);
//     signalService.setMultiHopEnabled(true);

//     // Neither relay is registered
//     vm.expectRevert(SignalService.SS_INVALID_RELAY.selector);
//     signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

//     // Register both relays
//     vm.startPrank(Alice);
//     hopRelayRegistry.registerRelay(srcChainId, hop1ChainId, hop1Relay);
//     hopRelayRegistry.registerRelay(hop1ChainId, hop2ChainId, hop2Relay);
//     vm.stopPrank();

//     signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

//     // Deregister the first relay and register it again with incorrect chainIds
//     vm.startPrank(Alice);
//     hopRelayRegistry.deregisterRelay(srcChainId, hop1ChainId, hop1Relay);
//     hopRelayRegistry.registerRelay(999, 888, hop1Relay);
//     vm.stopPrank();

//     // Still revert
//     vm.expectRevert(SignalService.SS_INVALID_RELAY.selector);
//     signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));
// }
}
