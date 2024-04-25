// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

abstract contract TaikoL1TestBase is TaikoTest {
    AddressManager public addressManager;
    AssignmentHook public assignmentHook;
    TaikoToken public tko;
    SignalService public ss;
    TaikoL1 public L1;
    TaikoData.Config conf;
    uint256 internal logCount;
    RiscZeroVerifier public rv;
    SgxVerifier public sv;
    GuardianProver public gp;
    TierProviderV1 public cp;
    Bridge public bridge;

    bytes32 public GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");

    address public L2SS = randAddress();
    address public L2 = randAddress();
    // Bootstrapped SGX instances (by owner)
    address internal SGX_X_0 = vm.addr(0x4);
    address internal SGX_X_1 = vm.addr(0x5);

    function deployTaikoL1() internal virtual returns (TaikoL1 taikoL1);

    function tierProvider() internal view returns (ITierProvider) {
        return ITierProvider(L1.resolve(LibStrings.B_TIER_PROVIDER, false));
    }

    function setUp() public virtual {
        L1 = deployTaikoL1();
        conf = L1.getConfig();

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            })
        );

        ss = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, (address(0), address(addressManager)))
            })
        );
        ss.authorize(address(L1), true);

        sv = SgxVerifier(
            deployProxy({
                name: "tier_sgx",
                impl: address(new SgxVerifier()),
                data: abi.encodeCall(SgxVerifier.init, (address(0), address(addressManager)))
            })
        );

        address[] memory initSgxInstances = new address[](1);
        initSgxInstances[0] = SGX_X_0;
        sv.addInstances(initSgxInstances);

        gp = GuardianProver(
            deployProxy({
                name: "guardian_prover",
                impl: address(new GuardianProver()),
                data: abi.encodeCall(GuardianProver.init, (address(0), address(addressManager)))
            })
        );

        setupGuardianProverMultisig();

        cp = TierProviderV1(
            deployProxy({
                name: "tier_provider",
                impl: address(new TierProviderV1()),
                data: abi.encodeCall(TierProviderV1.init, (address(0)))
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

        assignmentHook = AssignmentHook(
            deployProxy({
                name: "assignment_hook",
                impl: address(new AssignmentHook()),
                data: abi.encodeCall(AssignmentHook.init, (address(0), address(addressManager)))
            })
        );

        registerAddress("taiko", address(L1));
        registerAddress("tier_sgx", address(sv));
        registerAddress("tier_guardian", address(gp));
        registerAddress("tier_provider", address(cp));
        registerAddress("signal_service", address(ss));
        registerAddress("guardian_prover", address(gp));
        registerL2Address("taiko", address(L2));
        registerL2Address("signal_service", address(L2SS));
        registerL2Address("taiko_l2", address(L2));

        tko = TaikoToken(
            deployProxy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (address(0), "Taiko Token", "TTKOk", address(this))
                    ),
                registerTo: address(addressManager)
            })
        );

        L1.init(address(0), address(addressManager), GENESIS_BLOCK_HASH);

        gp.enableTaikoTokenAllowance(true);
        printVariables("init  ");
    }

    function proposeBlock(
        address proposer,
        address prover,
        uint32 gasLimit,
        uint24 txListSize
    )
        internal
        returns (TaikoData.BlockMetadata memory meta, TaikoData.EthDeposit[] memory ethDeposits)
    {
        TaikoData.TierFee[] memory tierFees = new TaikoData.TierFee[](3);
        // Register the tier fees
        // Based on OPL2ConfigTier we need 3:
        // - LibTiers.TIER_SGX;
        // - LibTiers.TIER_OPTIMISTIC;
        // - LibTiers.TIER_GUARDIAN;
        tierFees[0] = TaikoData.TierFee(LibTiers.TIER_OPTIMISTIC, 1 ether);
        tierFees[1] = TaikoData.TierFee(LibTiers.TIER_SGX, 1 ether);
        tierFees[2] = TaikoData.TierFee(LibTiers.TIER_GUARDIAN, 0 ether);
        // For the test not to fail, set the message.value to the highest, the
        // rest will be returned
        // anyways
        uint256 msgValue = 2 ether;

        AssignmentHook.ProverAssignment memory assignment = AssignmentHook.ProverAssignment({
            feeToken: address(0),
            tierFees: tierFees,
            expiry: uint64(block.timestamp + 60 minutes),
            maxBlockId: 0,
            maxProposedIn: 0,
            metaHash: 0,
            parentMetaHash: 0,
            signature: new bytes(0)
        });

        assignment.signature = _signAssignment(
            prover, assignment, address(L1), proposer, keccak256(new bytes(txListSize))
        );

        (, TaikoData.SlotB memory b) = L1.getStateVariables();

        uint256 _difficulty;
        unchecked {
            _difficulty = block.prevrandao * b.numBlocks;
        }

        // TODO: why init meta here?
        meta.timestamp = uint64(block.timestamp);
        meta.l1Height = uint64(block.number - 1);
        meta.l1Hash = blockhash(block.number - 1);
        meta.difficulty = bytes32(_difficulty);
        meta.gasLimit = gasLimit;

        TaikoData.HookCall[] memory hookcalls = new TaikoData.HookCall[](1);

        hookcalls[0] = TaikoData.HookCall(address(assignmentHook), abi.encode(assignment));

        vm.prank(proposer, proposer);
        (meta, ethDeposits) = L1.proposeBlock{ value: msgValue }(
            abi.encode(TaikoData.BlockParams(prover, address(0), 0, 0, hookcalls, "")),
            new bytes(txListSize)
        );
    }

    function proveBlock(
        address prover,
        TaikoData.BlockMetadata memory meta,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tier,
        bytes4 revertReason
    )
        internal
        virtual
    {
        TaikoData.Transition memory tran = TaikoData.Transition({
            parentHash: parentHash,
            blockHash: blockHash,
            stateRoot: stateRoot,
            graffiti: 0x0
        });

        TaikoData.TierProof memory proof;
        proof.tier = tier;
        address newInstance;

        // Keep changing the pub key associated with an instance to avoid
        // attacks,
        // obviously just a mock due to 2 addresses changing all the time.
        (newInstance,) = sv.instances(0);
        if (newInstance == SGX_X_0) {
            newInstance = SGX_X_1;
        } else {
            newInstance = SGX_X_0;
        }

        if (tier == LibTiers.TIER_SGX) {
            bytes memory signature =
                createSgxSignatureProof(tran, newInstance, prover, keccak256(abi.encode(meta)));

            proof.data = bytes.concat(bytes4(0), bytes20(newInstance), signature);
        }

        if (tier == LibTiers.TIER_GUARDIAN) {
            proof.data = "";

            // Grant 2 signatures, 3rd might be a revert
            vm.prank(David, David);
            gp.approve(meta, tran, proof);
            vm.prank(Emma, Emma);
            gp.approve(meta, tran, proof);

            if (revertReason != "") {
                vm.prank(Frank, Frank);
                vm.expectRevert(); // Revert reason is 'wrapped' so will not be
                    // identical to the expectedRevert
                gp.approve(meta, tran, proof);
            } else {
                vm.prank(Frank, Frank);
                gp.approve(meta, tran, proof);
            }
        } else {
            if (revertReason != "") {
                vm.prank(prover);
                vm.expectRevert(revertReason);
                L1.proveBlock(meta.id, abi.encode(meta, tran, proof));
            } else {
                vm.prank(prover);
                L1.proveBlock(meta.id, abi.encode(meta, tran, proof));
            }
        }
    }

    function verifyBlock(uint64 count) internal {
        L1.verifyBlocks(count);
    }

    function setupGuardianProverMultisig() internal {
        address[] memory initMultiSig = new address[](5);
        initMultiSig[0] = David;
        initMultiSig[1] = Emma;
        initMultiSig[2] = Frank;
        initMultiSig[3] = Grace;
        initMultiSig[4] = Henry;

        gp.setGuardians(initMultiSig, 3);
    }

    function registerAddress(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(uint64(block.chainid), nameHash, addr);
        console2.log(block.chainid, uint256(nameHash), unicode"→", addr);
    }

    function registerL2Address(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(conf.chainId, nameHash, addr);
        console2.log(conf.chainId, string(abi.encodePacked(nameHash)), unicode"→", addr);
    }

    function _signAssignment(
        address prover,
        AssignmentHook.ProverAssignment memory assignment,
        address taikoAddr,
        address blockProposer,
        bytes32 blobHash
    )
        internal
        view
        returns (bytes memory signature)
    {
        uint256 signerPrivateKey;

        // In the test suite these are the 3 which acts as provers
        if (prover == Alice) {
            signerPrivateKey = 0x1;
        } else if (prover == Bob) {
            signerPrivateKey = 0x2;
        } else if (prover == Carol) {
            signerPrivateKey = 0x3;
        } else {
            revert("unexpected");
        }

        bytes32 assignmentHash =
            assignmentHook.hashAssignment(assignment, taikoAddr, blockProposer, prover, blobHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, assignmentHash);
        signature = abi.encodePacked(r, s, v);
    }

    function createSgxSignatureProof(
        TaikoData.Transition memory tran,
        address newInstance,
        address prover,
        bytes32 metaHash
    )
        internal
        view
        returns (bytes memory signature)
    {
        uint64 chainId = L1.getConfig().chainId;
        bytes32 digest = LibPublicInput.hashPublicInputs(
            tran, address(sv), newInstance, prover, metaHash, chainId
        );

        uint256 signerPrivateKey;

        // In the test suite these are the 3 which acts as provers
        if (SGX_X_0 == newInstance) {
            signerPrivateKey = 0x5;
        } else if (SGX_X_1 == newInstance) {
            signerPrivateKey = 0x4;
        }

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function giveEthAndTko(address to, uint256 amountTko, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        tko.transfer(to, amountTko);

        vm.prank(to, to);
        tko.approve(address(L1), amountTko);
        vm.prank(to, to);
        tko.approve(address(assignmentHook), amountTko);

        console2.log("TKO balance:", to, tko.balanceOf(to));
        console2.log("ETH balance:", to, to.balance);
    }

    function printVariables(string memory comment) internal view {
        (, TaikoData.SlotB memory b) = L1.getStateVariables();

        string memory str = string.concat(
            "---chain [",
            vm.toString(b.lastVerifiedBlockId),
            unicode"→",
            vm.toString(b.numBlocks),
            "] // ",
            comment
        );
        console2.log(str);
    }

    function mine(uint256 counts) internal {
        vm.warp(block.timestamp + 20 * counts);
        vm.roll(block.number + counts);
    }
}
