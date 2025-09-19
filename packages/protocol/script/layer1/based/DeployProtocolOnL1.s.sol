// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
import "@p256-verifier/contracts/P256Verifier.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/devnet/verifiers/OpVerifier.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "src/layer1/based/TaikoInbox.sol";
import "src/layer1/fork-router/ShastaForkRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import { ForcedInclusionStore } from "contracts/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/layer1/mainnet/multirollup/MainnetBridge.sol";
import "src/layer1/mainnet/multirollup/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC20Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC721Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetSignalService.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/TaikoRisc0Verifier.sol";
import "src/layer1/verifiers/TaikoSP1Verifier.sol";
import "src/layer1/verifiers/TaikoSgxVerifier.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { DevnetShastaInbox } from "contracts/layer1/shasta/impl/DevnetShastaInbox.sol";
import "src/shared/based/impl/CheckpointManager.sol";
import "test/shared/helpers/FreeMintERC20Token.sol";
import "test/shared/helpers/FreeMintERC20Token_With50PctgMintAndTransferFailure.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployProtocolOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployProtocolOnL1 is DeployCapability {
    uint24 constant PRECONF_COOLDOWN_WINDOW = 0 hours;
    uint24 constant DEVNET_COOLDOWN_WINDOW = 2 hours;

    struct VerifierAddresses {
        address sgxGethVerifier;
        address opGethVerifier;
        address opRethVerifier;
        address sgxRethVerifier;
        address risc0RethVerifier;
        address sp1RethVerifier;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        addressNotNull(vm.envAddress("TAIKO_ANCHOR_ADDRESS"), "TAIKO_ANCHOR_ADDRESS");
        addressNotNull(vm.envAddress("L2_SIGNAL_SERVICE"), "L2_SIGNAL_SERVICE");
        addressNotNull(vm.envAddress("CONTRACT_OWNER"), "CONTRACT_OWNER");

        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");
        address contractOwner = vm.envAddress("CONTRACT_OWNER");

        // ---------------------------------------------------------------
        // Deploy shared contracts
        address sharedResolver = deploySharedContracts(contractOwner);
        console2.log("sharedResolver: ", sharedResolver);
        // ---------------------------------------------------------------
        // Deploy rollup contracts
        (address taikoInboxAddr, address proofVerifier, address whitelist) =
            deployRollupContracts(sharedResolver, contractOwner);

        // Deploy verifiers
        OpVerifier opImpl = new OpVerifier(taikoInboxAddr, proofVerifier);
        VerifierAddresses memory verifiers =
            deployVerifiers(contractOwner, proofVerifier, taikoInboxAddr, address(opImpl));
        if (vm.envBool("DUMMY_VERIFIERS")) {
            UUPSUpgradeable(proofVerifier).upgradeTo({
                newImplementation: address(
                    new DevnetVerifier(
                        taikoInboxAddr,
                        verifiers.opGethVerifier,
                        verifiers.opRethVerifier,
                        address(0),
                        verifiers.risc0RethVerifier,
                        verifiers.sp1RethVerifier
                    )
                )
            });
        } else {
            UUPSUpgradeable(proofVerifier).upgradeTo({
                newImplementation: address(
                    new DevnetVerifier(
                        taikoInboxAddr,
                        verifiers.sgxGethVerifier,
                        verifiers.opRethVerifier,
                        verifiers.sgxRethVerifier,
                        verifiers.risc0RethVerifier,
                        verifiers.sp1RethVerifier
                    )
                )
            });
        }

        Ownable2StepUpgradeable(proofVerifier).transferOwnership(contractOwner);
        // ---------------------------------------------------------------
        // Signal service need to authorize the new rollup
        address signalServiceAddr = IResolver(sharedResolver).resolve(
            uint64(block.chainid), LibNames.B_SIGNAL_SERVICE, false
        );
        SignalService signalService = SignalService(signalServiceAddr);

        TaikoInbox taikoInbox = TaikoInbox(payable(taikoInboxAddr));

        if (vm.envAddress("SHARED_RESOLVER") == address(0)) {
            SignalService(signalServiceAddr).authorize(taikoInboxAddr, true);
        }

        uint64 l2ChainId = taikoInbox.v4GetConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        console2.log("------------------------------------------");
        console2.log("msg.sender: ", msg.sender);
        console2.log("signalService.owner(): ", signalService.owner());
        console2.log("------------------------------------------");

        if (signalService.owner() == msg.sender) {
            signalService.transferOwnership(contractOwner);
        } else {
            console2.log("------------------------------------------");
            console2.log("Warning - you need to transact manually:");
            console2.log("signalService.authorize(taikoInboxAddr, bytes32(block.chainid))");
            console2.log("- signalService : ", signalServiceAddr);
            console2.log("- taikoInboxAddr   : ", taikoInboxAddr);
            console2.log("- chainId       : ", block.chainid);
        }

        // ---------------------------------------------------------------
        // Deploy other contracts
        if (block.chainid != 1) {
            deployAuxContracts();
        }

        if (vm.envBool("DEPLOY_PRECONF_CONTRACTS")) {
            deployPreconfContracts(
                contractOwner, sharedResolver, address(taikoInbox), proofVerifier, whitelist
            );
        }

        if (DefaultResolver(sharedResolver).owner() == msg.sender) {
            DefaultResolver(sharedResolver).transferOwnership(contractOwner);
            console2.log("** sharedResolver ownership transferred to:", contractOwner);
        }

        Ownable2StepUpgradeable(taikoInboxAddr).transferOwnership(contractOwner);
    }

    function deploySharedContracts(address owner) internal returns (address sharedResolver) {
        addressNotNull(owner, "owner");

        sharedResolver = vm.envAddress("SHARED_RESOLVER");
        if (sharedResolver == address(0)) {
            sharedResolver = deployProxy({
                name: "shared_resolver",
                impl: address(new DefaultResolver()),
                data: abi.encodeCall(DefaultResolver.init, (address(0)))
            });
        }

        address taikoToken = vm.envAddress("TAIKO_TOKEN");
        if (taikoToken == address(0)) {
            taikoToken = deployProxy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (owner, vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT"))
                ),
                registerTo: sharedResolver
            });
        } else {
            register(sharedResolver, "taiko_token", taikoToken);
        }
        register(sharedResolver, "bond_token", taikoToken);

        // Deploy Bridging contracts
        address signalService = deployProxy({
            name: "signal_service",
            impl: address(new MainnetSignalService(address(sharedResolver))),
            data: abi.encodeCall(SignalService.init, (address(0))),
            registerTo: sharedResolver
        });

        address bridge = deployProxy({
            name: "bridge",
            impl: address(new MainnetBridge(address(sharedResolver), signalService)),
            data: abi.encodeCall(Bridge.init, (address(0))),
            registerTo: sharedResolver
        });

        if (vm.envBool("PAUSE_BRIDGE")) {
            Bridge(payable(bridge)).pause();
        }

        Bridge(payable(bridge)).transferOwnership(owner);

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty bridges to enable multi-hop bridging:"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, 'bridge', address(remoteBridge))"
        );
        console2.log("- sharedResolver : ", sharedResolver);

        // Deploy Vaults
        address erc20Vault = deployProxy({
            name: "erc20_vault",
            impl: address(new MainnetERC20Vault(address(sharedResolver))),
            data: abi.encodeCall(ERC20Vault.init, (owner)),
            registerTo: sharedResolver
        });

        address erc721Vault = deployProxy({
            name: "erc721_vault",
            impl: address(new MainnetERC721Vault(address(sharedResolver))),
            data: abi.encodeCall(ERC721Vault.init, (owner)),
            registerTo: sharedResolver
        });

        address erc1155Vault = deployProxy({
            name: "erc1155_vault",
            impl: address(new MainnetERC1155Vault(address(sharedResolver))),
            data: abi.encodeCall(ERC1155Vault.init, (owner)),
            registerTo: sharedResolver
        });

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty vaults to enable multi-hop bridging:"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, 'erc20_vault', address(remoteERC20Vault))"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, 'erc721_vault', address(remoteERC721Vault))"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, 'erc1155_vault', address(remoteERC1155Vault))"
        );
        console2.log("- sharedResolver : ", sharedResolver);

        // Deploy Bridged token implementations
        register(sharedResolver, "bridged_erc20", address(new BridgedERC20(erc20Vault)));
        register(sharedResolver, "bridged_erc721", address(new BridgedERC721(address(erc721Vault))));
        register(
            sharedResolver, "bridged_erc1155", address(new BridgedERC1155(address(erc1155Vault)))
        );
    }

    function deployRollupContracts(
        address _sharedResolver,
        address owner
    )
        internal
        returns (address taikoInboxAddr, address proofVerifier, address whitelist)
    {
        addressNotNull(_sharedResolver, "sharedResolver");
        addressNotNull(owner, "owner");

        // Initializable the proxy for proofVerifier to get the contract address at first.
        // Proof verifier
        proofVerifier = deployProxy({
            name: "proof_verifier",
            impl: address(
                new DevnetVerifier(
                    address(0), address(0), address(0), address(0), address(0), address(0)
                )
            ),
            data: abi.encodeCall(ComposeVerifier.init, (address(0)))
        });
        whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (owner, 2, 2))
        });
        address proposer = vm.envAddress("PROPOSER_ADDRESS");
        PreconfWhitelist(whitelist).addOperator(proposer, proposer);

        address bondToken =
            IResolver(_sharedResolver).resolve(uint64(block.chainid), "bond_token", false);

        address oldFork = vm.envAddress("OLD_FORK_TAIKO_INBOX");
        if (oldFork == address(0)) {
            oldFork = address(
                new DevnetInbox(
                    LibNetwork.TAIKO_DEVNET,
                    DEVNET_COOLDOWN_WINDOW,
                    address(0),
                    proofVerifier,
                    bondToken,
                    IResolver(_sharedResolver).resolve(
                        uint64(block.chainid), "signal_service", false
                    )
                )
            );
        }
        address tempFork =
            address(new DevnetShastaInbox(address(0), proofVerifier, whitelist, bondToken));
        taikoInboxAddr = deployProxy({
            name: "taiko",
            impl: address(new ShastaForkRouter(oldFork, tempFork)),
            data: abi.encodeCall(Inbox.initV3, (msg.sender, vm.envBytes32("L2_GENESIS_HASH")))
        });

        address checkPointManager = deployProxy({
            name: "checkpoint_manager",
            impl: address(
                new CheckpointManager(
                    taikoInboxAddr,
                    2400 // refer to DevnetShastaInbox._RING_BUFFER_SIZE
                )
            ),
            data: abi.encodeCall(CheckpointManager.init, (address(0)))
        });

        address newFork =
            address(new DevnetShastaInbox(checkPointManager, proofVerifier, whitelist, bondToken));

        console2.log("  oldFork       :", oldFork);
        console2.log("  newFork       :", newFork);

        UUPSUpgradeable(taikoInboxAddr).upgradeTo({
            newImplementation: address(new ShastaForkRouter(oldFork, newFork))
        });
    }

    function deployVerifiers(
        address owner,
        address proofVerifier,
        address taikoInboxAddr,
        address opImplAddr
    )
        private
        returns (VerifierAddresses memory)
    {
        VerifierAddresses memory verifiers;
        // OP verifier
        verifiers.opRethVerifier = deployProxy({
            name: "op_verifier",
            impl: opImplAddr,
            data: abi.encodeCall(OpVerifier.init, (owner))
        });

        // Other verifiers
        // No need to proxy these, because they are 3rd party. If we want to modify, we simply
        // change the registerAddress("automata_dcap_attestation", address(attestation));
        SigVerifyLib sigVerifyLib = new SigVerifyLib(address(new P256Verifier()));
        PEMCertChainLib pemCertChainLib = new PEMCertChainLib();
        // Log addresses for the user to register sgx instance
        console2.log("SigVerifyLib", address(sigVerifyLib));
        console2.log("PemCertChainLib", address(pemCertChainLib));
        address automataDcapV3AttestationImpl = address(new AutomataDcapV3Attestation());
        address automataProxy = deployProxy({
            name: "automata_dcap_attestation",
            impl: automataDcapV3AttestationImpl,
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init, (owner, address(sigVerifyLib), address(pemCertChainLib))
            )
        });
        uint64 l2ChainId = TaikoInbox(payable(taikoInboxAddr)).v4GetConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        verifiers.sgxRethVerifier = deployProxy({
            name: "sgx_reth_verifier",
            impl: address(new TaikoSgxVerifier(taikoInboxAddr, proofVerifier, automataProxy)),
            data: abi.encodeCall(TaikoSgxVerifier.init, owner)
        });

        (verifiers.risc0RethVerifier, verifiers.sp1RethVerifier) =
            deployZKVerifiers(owner, l2ChainId);
        verifiers.opGethVerifier = deployProxy({
            name: "op_geth_verifier",
            impl: opImplAddr,
            data: abi.encodeCall(OpVerifier.init, (owner))
        });
        address sgxGethAutomataProxy = deployProxy({
            name: "sgx_geth_automata",
            impl: automataDcapV3AttestationImpl,
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init, (owner, address(sigVerifyLib), address(pemCertChainLib))
            )
        });
        verifiers.sgxGethVerifier = deployProxy({
            name: "sgx_geth_verifier",
            impl: address(new TaikoSgxVerifier(taikoInboxAddr, proofVerifier, sgxGethAutomataProxy)),
            data: abi.encodeCall(TaikoSgxVerifier.init, owner)
        });
        return verifiers;
    }

    function deployZKVerifiers(
        address owner,
        uint64 l2ChainId
    )
        private
        returns (address taikoRisc0Verifier, address taikoSP1Verifier)
    {
        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);

        taikoRisc0Verifier = deployProxy({
            name: "risc0_reth_verifier",
            impl: address(new TaikoRisc0Verifier(l2ChainId, address(verifier))),
            data: abi.encodeCall(TaikoRisc0Verifier.init, (owner))
        });

        // Deploy sp1 plonk verifier
        SuccinctVerifier succinctVerifier = new SuccinctVerifier();

        taikoSP1Verifier = deployProxy({
            name: "sp1_reth_verifier",
            impl: address(new TaikoSP1Verifier(l2ChainId, address(succinctVerifier))),
            data: abi.encodeCall(TaikoSP1Verifier.init, (owner))
        });
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20Token("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken =
            address(new FreeMintERC20Token_With50PctgMintAndTransferFailure("Bull Token", "BULL"));
        console2.log("BullToken", bullToken);
    }

    // TODO: to be re-implemented
    function deployPreconfContracts(
        address owner,
        address sharedResolver,
        address taikoInbox,
        address verifier,
        address whitelist
    )
        private
        returns (address router, address store, address taikoWrapper)
    {
        // Initializable a forced inclusion store with a fake address for TaikoWrapper at first,
        // to be used for deploying TaikoWrapper, then upgrade it to the real TaikoWrapper address.
        store = deployProxy({
            name: "forced_inclusion_store",
            impl: address(
                new ForcedInclusionStore(
                    uint8(vm.envUint("INCLUSION_WINDOW")),
                    uint64(vm.envUint("INCLUSION_FEE_IN_GWEI")),
                    taikoInbox,
                    address(1)
                )
            ),
            data: abi.encodeCall(ForcedInclusionStore.init, (address(0)))
        });

        taikoWrapper = deployProxy({
            name: "taiko_wrapper",
            impl: address(new TaikoWrapper(taikoInbox, store, router)),
            data: abi.encodeCall(TaikoWrapper.init, (msg.sender))
        });

        address oldFork = vm.envAddress("OLD_FORK_TAIKO_INBOX");
        if (oldFork == address(0)) {
            oldFork = address(
                new DevnetInbox(
                    LibNetwork.TAIKO_DEVNET,
                    DEVNET_COOLDOWN_WINDOW,
                    address(0),
                    verifier,
                    IResolver(sharedResolver).resolve(uint64(block.chainid), "bond_token", false),
                    IResolver(sharedResolver).resolve(
                        uint64(block.chainid), "signal_service", false
                    )
                )
            );
        }

        address newFork;

        if (vm.envBool("PRECONF_INBOX")) {
            newFork = address(
                new DevnetInbox(
                    LibNetwork.TAIKO_PRECONF,
                    PRECONF_COOLDOWN_WINDOW,
                    taikoWrapper,
                    verifier,
                    IResolver(sharedResolver).resolve(uint64(block.chainid), "bond_token", false),
                    IResolver(sharedResolver).resolve(
                        uint64(block.chainid), "signal_service", false
                    )
                )
            );
        } else {
            newFork = address(
                new DevnetInbox(
                    LibNetwork.TAIKO_DEVNET,
                    DEVNET_COOLDOWN_WINDOW,
                    taikoWrapper,
                    verifier,
                    IResolver(sharedResolver).resolve(uint64(block.chainid), "bond_token", false),
                    IResolver(sharedResolver).resolve(
                        uint64(block.chainid), "signal_service", false
                    )
                )
            );
        }

        UUPSUpgradeable(taikoInbox).upgradeTo({
            newImplementation: address(
                new ShastaForkRouter(
                    oldFork, // dont need old fork, we are using pacaya fork height 0 here
                    newFork
                )
            )
        });

        UUPSUpgradeable(store).upgradeTo(
            address(
                new ForcedInclusionStore(
                    uint8(vm.envUint("INCLUSION_WINDOW")),
                    uint64(vm.envUint("INCLUSION_FEE_IN_GWEI")),
                    taikoInbox,
                    taikoWrapper
                )
            )
        );

        Ownable2StepUpgradeable(store).transferOwnership(owner);
        console2.log("** forced_inclusion_store ownership transferred to:", owner);

        router = deployProxy({
            name: "preconf_router",
            impl: address(new PreconfRouter(taikoWrapper, whitelist)),
            data: abi.encodeCall(PreconfRouter.init, (owner))
        });

        UUPSUpgradeable(taikoWrapper).upgradeTo({
            newImplementation: address(new TaikoWrapper(taikoInbox, store, router))
        });

        Ownable2StepUpgradeable(taikoWrapper).transferOwnership(owner);
        console2.log("** taiko_wrapper ownership transferred to:", owner);

        return (router, store, taikoWrapper);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
