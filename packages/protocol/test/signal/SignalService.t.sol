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
        uint64, /*chainId*/
        address, /*app*/
        bytes32, /*signal*/
        HopProof memory /*hopProof*/
    )
        public
        view
        override
        returns (bytes32)
    {
        if (!_skipVerifyMerkleProof) revert("verifyMerkleProof failed");
        return bytes32(uint256(23));
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
    uint64 public destChainId = 7;
    address taiko = address(123);

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

    function test_SignalService_proveSignalReceived_L1_L2_full_proof() public {
        signalService.setSkipMerkleProofCheck(true);
        signalService.setMultiHopEnabled(false);

        uint64 localChainId = uint64(block.chainid);
        vm.prank(Alice);
        addressManager.setAddress(localChainId, "taiko", taiko);

        uint64 srcChainId = localChainId + 1;

        bytes32 stateRoot = randBytes32();
        address app = randAddress();
        bytes32 signal = randBytes32();

        vm.prank(taiko);
        signalService.relayStateRoot(srcChainId, stateRoot);

        SignalService.MultiHopProof memory p;
        p.proof.rootHash = stateRoot;
        p.proof.accountProof = new bytes[](1); // length > 0 to indicate this is a full proof
        p.proof.storageProof = new bytes[](1);

        assertEq(signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p)), true);

        p.proof.accountProof = new bytes[](0);
        vm.expectRevert();
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

        signalService.setSkipMerkleProofCheck(false);
        vm.expectRevert();
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));
    }

    function test_SignalService_proveSignalReceived_L1_L2_storage_proof() public {
        signalService.setSkipMerkleProofCheck(true);
        signalService.setMultiHopEnabled(false);

        uint64 localChainId = uint64(block.chainid);
        vm.prank(Alice);
        addressManager.setAddress(localChainId, "taiko", taiko);

        uint64 srcChainId = localChainId + 1;

        bytes32 signalRoot = randBytes32();
        address app = randAddress();
        bytes32 signal = randBytes32();

        vm.prank(taiko);
        signalService.relaySignalRoot(srcChainId, signalRoot);

        SignalService.MultiHopProof memory p;
        p.proof.rootHash = signalRoot;
        p.proof.accountProof = new bytes[](0); // sroage proof
        p.proof.storageProof = new bytes[](1);

        assertEq(signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p)), true);

        p.proof.accountProof = new bytes[](1);
        vm.expectRevert();
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

        signalService.setSkipMerkleProofCheck(false);
        vm.expectRevert();
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));
    }

    function test_SignalService_proveSignalReceived_multi_hops() public {
        signalService.setSkipMerkleProofCheck(true);
        signalService.setMultiHopEnabled(false);


        uint64 localChainId = uint64(block.chainid);

        vm.prank(Alice);
        addressManager.setAddress(localChainId, "taiko", taiko);

        uint64 srcChainId = localChainId + 1;

        uint64 hop1ChainId = localChainId + 2;
        address hop1Relay = randAddress();
        bytes32 hop1StateRoot = randBytes32();

        uint64 hop2ChainId = localChainId + 3;
        address hop2Relay = randAddress();
        bytes32 hop2StateRoot = randBytes32();

        bytes32 localCachedStateRoot = randBytes32();
        address app = randAddress();
        bytes32 signal = randBytes32();

        SignalService.MultiHopProof memory p;
        // p.height = 10;
        p.hops = new SignalService.Hop[](2);

        p.hops[0].chainId = hop1ChainId;
        p.hops[0].relay = hop1Relay;
        p.hops[0].proof = SignalService.HopProof({
            rootHash: hop1StateRoot,
            accountProof: new bytes[](1),
            storageProof: new bytes[](1),
            cacheLocally: true
            });

            p.hops[1].chainId = hop2ChainId;
        p.hops[1].relay = hop2Relay;
        p.hops[1].proof = SignalService.HopProof({
            rootHash: hop2StateRoot,
            accountProof: new bytes[](0),
            storageProof: new bytes[](1),
            cacheLocally: true
            });

        p.proof = SignalService.HopProof({
            rootHash: localCachedStateRoot,
            accountProof: new bytes[](1),
            storageProof: new bytes[](1),
            cacheLocally: true
            });
    

        // Multiple is disabled, shall revert
        vm.expectRevert(SignalService.SS_MULTIHOP_DISABLED.selector);
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

        // Enable multi-hop
        vm.startPrank(Alice);
        signalService.setMultiHopEnabled(true);

        // Neither relay is registered
        vm.expectRevert(SignalService.SS_INVALID_RELAY.selector);
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

        // Register both relays
        vm.startPrank(Alice);
        hopRelayRegistry.registerRelay(srcChainId, hop1ChainId, hop1Relay);
        hopRelayRegistry.registerRelay(hop1ChainId, hop2ChainId, hop2Relay);
        vm.stopPrank();

vm.expectRevert(SignalService.SS_INVALID_ROOT_HASH.selector);
        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

 vm.prank(taiko);
        signalService.relaySignalRoot(hop2ChainId, localCachedStateRoot);

        signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));

        // // Deregister the first relay and register it again with incorrect chainIds
        // vm.startPrank(Alice);
        // hopRelayRegistry.deregisterRelay(srcChainId, hop1ChainId, hop1Relay);
        // hopRelayRegistry.registerRelay(999, 888, hop1Relay);
        // vm.stopPrank();

        // // Still revert
        // vm.expectRevert(SignalService.SS_INVALID_RELAY.selector);
        // signalService.proveSignalReceived(srcChainId, app, signal, abi.encode(p));
    }
}
