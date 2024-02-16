// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract MockSignalService is SignalService {
    function _verifyHopProof(
        uint64, /*chainId*/
        address, /*app*/
        bytes32, /*signal*/
        bytes32, /*value*/
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
        signalService.authorizeRelayer(taiko, true);
        vm.stopPrank();
    }

    function test_SignalService_sendSignal_revert() public {
        vm.expectRevert(SignalService.SS_INVALID_VALUE.selector);
        signalService.sendSignal(0);
    }

    function test_SignalService_isSignalSent_revert() public {
        bytes32 signal = bytes32(uint256(1));
        vm.expectRevert(SignalService.SS_INVALID_SENDER.selector);
        signalService.isSignalSent(address(0), signal);

        signal = bytes32(uint256(0));
        vm.expectRevert(SignalService.SS_INVALID_VALUE.selector);
        signalService.isSignalSent(Alice, signal);
    }

    function test_SignalService_sendSignal_isSignalSent() public {
        vm.startPrank(Alice);
        bytes32 signal = bytes32(uint256(1));
        signalService.sendSignal(signal);

        assertTrue(signalService.isSignalSent(Alice, signal));
    }

    function test_SignalService_proveSignalReceived_revert_invalid_chainid_or_signal() public {
        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        // app being address(0) will revert
        vm.expectRevert(SignalService.SS_INVALID_SENDER.selector);
        signalService.proveSignalReceived({
            chainId: 1,
            app: address(0),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // signal being 0 will revert
        vm.expectRevert(SignalService.SS_INVALID_VALUE.selector);
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

        vm.expectRevert(
            abi.encodeWithSelector(
                AddressResolver.RESOLVER_ZERO_ADDR.selector,
                srcChainId,
                strToBytes32("signal_service")
            )
        );
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
        proofs[0].blockId = 1;

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
        proofs[0].blockId = 1;

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
        proofs[0].blockId = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AddressResolver.RESOLVER_ZERO_ADDR.selector,
                proofs[0].chainId,
                strToBytes32("signal_service")
            )
        );

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
        proofs[0].blockId = 1;

        // the proof is a storage proof
        proofs[0].accountProof = new bytes[](0);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // the proof is a full proof
        proofs[0].accountProof = new bytes[](1);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_one_hop_cache_signal_root() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();

        // the proof is a storage proof
        proofs[0].accountProof = new bytes[](0);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // relay the signal root
        vm.prank(taiko);
        signalService.relayChainData(
            srcChainId, proofs[0].blockId, LibSignals.SIGNAL_ROOT, proofs[0].rootHash
        );
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        vm.prank(Alice);
        signalService.authorizeRelayer(taiko, false);

        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        vm.prank(taiko);
        signalService.relayChainData(
            srcChainId, proofs[0].blockId, LibSignals.SIGNAL_ROOT, proofs[0].rootHash
        );
    }

    function test_SignalService_proveSignalReceived_one_hop_state_root() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](1);

        proofs[0].chainId = uint64(block.chainid);
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();

        // the proof is a full merkle proof
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // relay the state root
        vm.prank(taiko);
        signalService.relayChainData(
            srcChainId, proofs[0].blockId, LibSignals.STATE_ROOT, proofs[0].rootHash
        );

        // Should not revert
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        assertEq(
            signalService.isChainDataRelayed(
                srcChainId, proofs[0].blockId, LibSignals.SIGNAL_ROOT, bytes32(uint256(789))
            ),
            false
        );
    }

    function test_SignalService_proveSignalReceived_multiple_hops_no_caching() public {
        uint64 srcChainId = uint64(block.chainid + 1);

        vm.prank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](3);

        // first hop with full merkle proof
        proofs[0].chainId = uint64(block.chainid + 2);
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);

        // second hop with storage merkle proof
        proofs[1].chainId = uint64(block.chainid + 3);
        proofs[1].blockId = 2;
        proofs[1].rootHash = randBytes32();
        proofs[1].accountProof = new bytes[](0);
        proofs[1].storageProof = new bytes[](10);

        // third/last hop with full merkle proof
        proofs[2].chainId = uint64(block.chainid);
        proofs[2].blockId = 3;
        proofs[2].rootHash = randBytes32();
        proofs[2].accountProof = new bytes[](1);
        proofs[2].storageProof = new bytes[](10);

        // expect RESOLVER_ZERO_ADDR
        vm.expectRevert(
            abi.encodeWithSelector(
                AddressResolver.RESOLVER_ZERO_ADDR.selector,
                proofs[0].chainId,
                strToBytes32("signal_service")
            )
        );
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

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_FOUND.selector);
        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        vm.prank(taiko);
        signalService.relayChainData(
            proofs[1].chainId, proofs[2].blockId, LibSignals.STATE_ROOT, proofs[2].rootHash
        );

        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });
    }

    function test_SignalService_proveSignalReceived_multiple_hops_caching() public {
        uint64 srcChainId = uint64(block.chainid + 1);
        uint64 nextChainId = srcChainId + 100;

        SignalService.HopProof[] memory proofs = new SignalService.HopProof[](9);

        // hop 1:  full merkle proof, CACHE_NOTHING
        proofs[0].chainId = nextChainId++;
        proofs[0].blockId = 1;
        proofs[0].rootHash = randBytes32();
        proofs[0].accountProof = new bytes[](1);
        proofs[0].storageProof = new bytes[](10);
        proofs[0].cacheOption = SignalService.CacheOption.CACHE_NOTHING;

        // hop 2:  full merkle proof, CACHE_STATE_ROOT
        proofs[1].chainId = nextChainId++;
        proofs[1].blockId = 2;
        proofs[1].rootHash = randBytes32();
        proofs[1].accountProof = new bytes[](1);
        proofs[1].storageProof = new bytes[](10);
        proofs[1].cacheOption = SignalService.CacheOption.CACHE_STATE_ROOT;

        // hop 3:  full merkle proof, CACHE_SIGNAL_ROOT
        proofs[2].chainId = nextChainId++;
        proofs[2].blockId = 3;
        proofs[2].rootHash = randBytes32();
        proofs[2].accountProof = new bytes[](1);
        proofs[2].storageProof = new bytes[](10);
        proofs[2].cacheOption = SignalService.CacheOption.CACHE_SIGNAL_ROOT;

        // hop 4:  full merkle proof, CACHE_BOTH
        proofs[3].chainId = nextChainId++;
        proofs[3].blockId = 4;
        proofs[3].rootHash = randBytes32();
        proofs[3].accountProof = new bytes[](1);
        proofs[3].storageProof = new bytes[](10);
        proofs[3].cacheOption = SignalService.CacheOption.CACHE_BOTH;

        // hop 5:  storage merkle proof, CACHE_NOTHING
        proofs[4].chainId = nextChainId++;
        proofs[4].blockId = 5;
        proofs[4].rootHash = randBytes32();
        proofs[4].accountProof = new bytes[](0);
        proofs[4].storageProof = new bytes[](10);
        proofs[4].cacheOption = SignalService.CacheOption.CACHE_NOTHING;

        // hop 6:  storage merkle proof, CACHE_STATE_ROOT
        proofs[5].chainId = nextChainId++;
        proofs[5].blockId = 6;
        proofs[5].rootHash = randBytes32();
        proofs[5].accountProof = new bytes[](0);
        proofs[5].storageProof = new bytes[](10);
        proofs[5].cacheOption = SignalService.CacheOption.CACHE_STATE_ROOT;

        // hop 7:  storage merkle proof, CACHE_SIGNAL_ROOT
        proofs[6].chainId = nextChainId++;
        proofs[6].blockId = 7;
        proofs[6].rootHash = randBytes32();
        proofs[6].accountProof = new bytes[](0);
        proofs[6].storageProof = new bytes[](10);
        proofs[6].cacheOption = SignalService.CacheOption.CACHE_SIGNAL_ROOT;

        // hop 8:  storage merkle proof, CACHE_BOTH
        proofs[7].chainId = nextChainId++;
        proofs[7].blockId = 8;
        proofs[7].rootHash = randBytes32();
        proofs[7].accountProof = new bytes[](0);
        proofs[7].storageProof = new bytes[](10);
        proofs[7].cacheOption = SignalService.CacheOption.CACHE_BOTH;

        // last hop, 9:  full merkle proof, CACHE_BOTH
        proofs[8].chainId = uint64(block.chainid);
        proofs[8].blockId = 9;
        proofs[8].rootHash = randBytes32();
        proofs[8].accountProof = new bytes[](1);
        proofs[8].storageProof = new bytes[](10);
        proofs[8].cacheOption = SignalService.CacheOption.CACHE_BOTH;

        // Add two trusted hop relayers
        vm.startPrank(Alice);
        addressManager.setAddress(srcChainId, "signal_service", randAddress());
        for (uint256 i; i < proofs.length; ++i) {
            addressManager.setAddress(
                proofs[i].chainId, "signal_service", randAddress() /*relay1*/
            );
        }
        vm.stopPrank();

        vm.prank(taiko);
        signalService.relayChainData(
            proofs[7].chainId, proofs[8].blockId, LibSignals.STATE_ROOT, proofs[8].rootHash
        );

        signalService.proveSignalReceived({
            chainId: srcChainId,
            app: randAddress(),
            signal: randBytes32(),
            proof: abi.encode(proofs)
        });

        // hop 1:  full merkle proof, CACHE_NOTHING
        _verifyCache(srcChainId, proofs[0].blockId, proofs[0].rootHash, false, false);
        // hop 2:  full merkle proof, CACHE_STATE_ROOT
        _verifyCache(proofs[0].chainId, proofs[1].blockId, proofs[1].rootHash, true, false);
        // hop 3:  full merkle proof, CACHE_SIGNAL_ROOT
        _verifyCache(proofs[1].chainId, proofs[2].blockId, proofs[2].rootHash, false, true);
        // hop 4:  full merkle proof, CACHE_BOTH
        _verifyCache(proofs[2].chainId, proofs[3].blockId, proofs[3].rootHash, true, true);
        // hop 5:  storage merkle proof, CACHE_NOTHING
        _verifyCache(proofs[3].chainId, proofs[4].blockId, proofs[4].rootHash, false, false);
        // hop 6:  storage merkle proof, CACHE_STATE_ROOT
        _verifyCache(proofs[4].chainId, proofs[5].blockId, proofs[5].rootHash, false, false);
        // hop 7:  storage merkle proof, CACHE_SIGNAL_ROOT
        _verifyCache(proofs[5].chainId, proofs[6].blockId, proofs[6].rootHash, false, true);
        // hop 8:  storage merkle proof, CACHE_BOTH
        _verifyCache(proofs[6].chainId, proofs[7].blockId, proofs[7].rootHash, false, true);
        // last hop, 9:  full merkle proof, CACHE_BOTH
        // last hop's state root is already cached even before the proveSignalReceived call.
        _verifyCache(proofs[7].chainId, proofs[8].blockId, proofs[8].rootHash, true, true);
    }

    function _verifyCache(
        uint64 chainId,
        uint64 blockId,
        bytes32 stateRoot,
        bool stateRootCached,
        bool signalRootCached
    )
        private
    {
        assertEq(
            signalService.isChainDataRelayed(chainId, blockId, LibSignals.STATE_ROOT, stateRoot),
            stateRootCached
        );

        assertEq(
            signalService.isChainDataRelayed(
                chainId, blockId, LibSignals.SIGNAL_ROOT, bytes32(uint256(789))
            ),
            signalRootCached
        );
    }
}
