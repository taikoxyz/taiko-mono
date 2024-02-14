// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract MockSignalService is SignalService {
    function _verifyHopProof(
        uint64, /*chainId*/
        address, /*app*/
        bytes32, /*signal*/
        HopProof memory, /*hop*/
        address /*relay*/
    )
        internal
        pure
        override
        returns (bytes32)
    {
        // Skip verifying the merkle proof entirely
        return bytes32(uint256(789));
    }
}

contract TestSignalService is TaikoTest {
    AddressManager addressManager;
    MockSignalService signalService;
    uint64 public destChainId = 7;
    address taiko;

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

        signalService = MockSignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new MockSignalService()),
                data: abi.encodeCall(SignalService.init, (address(addressManager)))
            })
        );

        taiko = randAddress();
        addressManager.setAddress(uint64(block.chainid), "taiko", taiko);
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

    function test_SignalService_SignalService_getSignalSlot() public {
        vm.startPrank(Alice);
        for (uint8 i = 1; i < 100; ++i) {
            bytes32 signal = bytes32(block.prevrandao + i);
            signalService.sendSignal(signal);

            assertTrue(signalService.isSignalSent(Alice, signal));
        }
    }

    function test_SignalService_proveSignalReceived_revert_invalid_chainid_or_signal() public {
        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        // app being address(0) will revert
        vm.expectRevert(SignalService.SS_INVALID_PARAMS.selector);
        signalService.proveSignalReceived({
            chainId: 1,
            app: address(0),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // signal being 0 will revert
        vm.expectRevert(SignalService.SS_INVALID_PARAMS.selector);
        signalService.proveSignalReceived({
            chainId: uint64(block.chainid),
            app: randAddress(),
            signal: 0,
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_malformat_proof() public {
        // "undecodable proof" is not decodeable into SignalService.HopProof[] memory
        vm.expectRevert();
        signalService.proveSignalReceived({
            chainId: 0,
            app: randAddress(),
            signal: randBytes32(),
            proof: "undecodable proof"
        });
    }

    function test_SignalService_proveSignalReceived_revert_src_signal_service_not_registered()
        public
    {
        uint64 srcChainId = uint64(block.chainid - 1);

        // Did not call the following, so revert with RESOLVER_ZERO_ADDR
        //   vm.prank(Alice);
        //   addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        vm.expectRevert();
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_zero_size_proof() public {
        uint64 srcChainId = uint64(block.chainid - 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        // proofs.length must > 0 in order not to revert
        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](0);

        vm.expectRevert(SignalService.SS_EMPTY_PROOF.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_last_hop_incorrect_chainid() public {
        uint64 srcChainId = uint64(block.chainid - 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        // proofs[0].chainId must be block.chainid in order not to revert
        proofs[0].chainId = uint64(block.chainid + 1);

        vm.expectRevert(SignalService.SS_INVALID_LAST_HOP_CHAINID.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_mid_hop_incorrect_chainid() public {
        uint64 srcChainId = uint64(block.chainid - 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](2);

        // proofs[0].chainId must NOT be block.chainid in order not to revert
        proofs[0].chainId = uint64(block.chainid);

        vm.expectRevert(SignalService.SS_INVALID_MID_HOP_CHAINID.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_revert_mid_hop_not_registered() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](2);

        // proofs[0].chainId must NOT be block.chainid in order not to revert
        proofs[0].chainId = srcChainId + 1;

        // RESOLVER_ZERO_ADDR
        vm.expectRevert();
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_local_chaindata_not_found() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);

        // the proof is a storage proof
        proofs[0].accountProof = new bytes[](0);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_LOCAL_CHAIN_DATA_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // the proof is a full proof
        proofs[0].accountProof = new bytes[](1);

        vm.expectRevert(SignalService.SS_LOCAL_CHAIN_DATA_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_one_hop_cacheSIGNAL_ROOT() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].rootHash = randBytes32();
        proofs[0].cacheChainData = false;

        // the proof is a storage proof
        proofs[0].accountProof = new bytes[](0);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_LOCAL_CHAIN_DATA_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // relay the signal root
        vm.prank(taiko);
        signalService.relayChainData(srcChainId, LibSignals.SIGNAL_ROOT, proofs[0].rootHash);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_one_hopSTATE_ROOT() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].rootHash = randBytes32();

        // the proof is a full merkle proof
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_LOCAL_CHAIN_DATA_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // relay the state root
        vm.prank(taiko);
        signalService.relayChainData(srcChainId, LibSignals.STATE_ROOT, proofs[0].rootHash);

        // Should not revert
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        bytes32 signal = signalService.signalForChainData(
            srcChainId, LibSignals.SIGNAL_ROOT, bytes32(uint256(789))
        );
        assertEq(signalService.isSignalSent(address(signalService), signal), false);

        // enable cache
        proofs[0].cacheChainData = true;
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
        assertEq(signalService.isSignalSent(address(signalService), signal), true);
    }

    function test_SignalService_proveSignalReceived_multiple_hops() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](3);

        // first hop with full merkle proof
        proofs[0].chainId = uint64(block.chainid + 2);
        proofs[0].rootHash = bytes32(uint256(1001));
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);

        // second hop with storage merkle proof
        proofs[1].chainId = uint64(block.chainid + 3);
        proofs[1].rootHash = bytes32(uint256(1002));
        proofs[1].accountProof = new bytes[](0);
        proofs[1].storageProof = new bytes[](10);

        // third/last hop with full merkle proof
        proofs[2].chainId = uint64(block.chainid);
        proofs[2].rootHash = bytes32(uint256(1003));
        proofs[2].accountProof = new bytes[](1);
        proofs[2].storageProof = new bytes[](10);

        // expect RESOLVER_ZERO_ADDR
        vm.expectRevert();
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // Add two trusted hop relayers
        vm.startPrank(Alice);
        addressManager.setAddress(proofs[0].chainId, "signal_service", randAddress() /*relay1*/ );
        addressManager.setAddress(proofs[1].chainId, "signal_service", randAddress() /*relay2*/ );
        vm.stopPrank();

        vm.expectRevert(SignalService.SS_LOCAL_CHAIN_DATA_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        vm.prank(taiko);
        signalService.relayChainData(proofs[1].chainId, LibSignals.STATE_ROOT, proofs[2].rootHash);

        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }
}
