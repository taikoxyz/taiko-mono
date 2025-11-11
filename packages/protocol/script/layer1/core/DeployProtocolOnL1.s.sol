// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@p256-verifier/contracts/P256Verifier.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import { CodecOptimized } from "src/layer1/core/impl/CodecOptimized.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { DevnetInbox } from "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/devnet/DevnetVerifier.sol";
import "src/layer1/devnet/OpVerifier.sol";
import "src/layer1/mainnet/MainnetBridge.sol";
import "src/layer1/mainnet/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/MainnetERC20Vault.sol";
import "src/layer1/mainnet/MainnetERC721Vault.sol";
import "src/layer1/mainnet/TaikoToken.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/vault/BridgedERC1155.sol";
import "src/shared/vault/BridgedERC20.sol";
import "src/shared/vault/BridgedERC721.sol";
import { MockProofVerifier } from "test/layer1/core/inbox/mocks/MockContracts.sol";
import "test/shared/DeployCapability.sol";
import "test/shared/helpers/FreeMintERC20Token.sol";
import "test/shared/helpers/FreeMintERC20Token_With50PctgMintAndTransferFailure.sol";

/// @title DeployProtocolOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployProtocolOnL1 is DeployCapability {
    struct VerifierAddresses {
        address sgx;
        address risc0;
        address sp1;
        address op;
        address sgxGeth;
    }

    struct DeploymentConfig {
        address contractOwner;
        bytes32 l2GenesisHash;
        uint64 l2ChainId;
        address sharedResolver;
        address remoteSigSvc;
        address taikoToken;
        address taikoTokenPremintRecipient;
        address proposerAddress;
        bool useDummyVerifiers;
        bool pauseBridge;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set or invalid");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        DeploymentConfig memory config = _loadConfig();

        // Deploy shared infrastructure
        address sharedResolver = deploySharedContracts(config);
        console2.log("SharedResolver deployed:", sharedResolver);

        // Deploy all verifiers
        VerifierAddresses memory verifiers = _deployAllVerifiers(config);

        // Deploy main proof verifier (DevnetVerifier)
        address proofVerifier = _deployProofVerifier(verifiers, config.useDummyVerifiers);

        // Deploy rollup contracts (handles SignalService deployment/registration)
        address shastaInbox = _deployRollupContracts(sharedResolver, config, proofVerifier);

        // Deploy bridge and vaults now that SignalService is finalized
        _deployBridge(sharedResolver, config);
        _deployVaults(sharedResolver, config.contractOwner);

        // Deploy test tokens on non-mainnet chains
        if (block.chainid != 1) {
            deployAuxContracts();
        }

        // Transfer ownership to contract owner
        _transferOwnerships(sharedResolver, shastaInbox, config.contractOwner);
    }

    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.contractOwner = vm.envAddress("CONTRACT_OWNER");
        config.l2GenesisHash = vm.envBytes32("L2_GENESIS_HASH");
        config.l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
        config.sharedResolver = vm.envAddress("SHARED_RESOLVER");
        config.remoteSigSvc = vm.envOr("REMOTE_SIGNAL_SERVICE", msg.sender);
        config.taikoToken = vm.envAddress("TAIKO_TOKEN");
        config.taikoTokenPremintRecipient = vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");
        config.proposerAddress = vm.envAddress("PROPOSER_ADDRESS");
        config.useDummyVerifiers = vm.envBool("DUMMY_VERIFIERS");
        config.pauseBridge = vm.envBool("PAUSE_BRIDGE");

        require(config.contractOwner != address(0), "CONTRACT_OWNER not set");
        require(config.l2GenesisHash != bytes32(0), "L2_GENESIS_HASH not set");
    }

    function _deployAllVerifiers(DeploymentConfig memory config)
        private
        returns (VerifierAddresses memory verifiers)
    {
        // Deploy OpVerifier (used in all configurations)
        verifiers.op = address(new OpVerifier());
        console2.log("OpVerifier deployed:", verifiers.op);

        // Deploy automata attestation for SGX
        (address automataProxy, address sgxGethAutomataProxy) =
            _deployAutomataAttestation(config.contractOwner);

        // Deploy SGX verifier
        verifiers.sgx =
            address(new SgxVerifier(config.l2ChainId, config.contractOwner, automataProxy));
        console2.log("SgxVerifier deployed:", verifiers.sgx);

        verifiers.sgxGeth =
            address(new SgxVerifier(config.l2ChainId, config.contractOwner, sgxGethAutomataProxy));
        console2.log("SgxGethVerifier deployed:", verifiers.sgxGeth);

        // Deploy ZK verifiers (RISC0 and SP1)
        (verifiers.risc0, verifiers.sp1) =
            _deployZKVerifiers(config.contractOwner, config.l2ChainId);
    }

    function _deployProofVerifier(
        VerifierAddresses memory verifiers,
        bool useDummyVerifiers
    )
        private
        returns (address proofVerifier)
    {
        if (useDummyVerifiers) {
            proofVerifier = address(new MockProofVerifier());
            return proofVerifier;
        }
        // DevnetVerifier is stateless with immutable verifier addresses (no proxy needed)
        proofVerifier = address(
            new DevnetVerifier(verifiers.sgxGeth, verifiers.sgx, verifiers.risc0, verifiers.sp1)
        );

        console2.log(
            useDummyVerifiers ? "DevnetVerifier (DUMMY MODE):" : "DevnetVerifier:", proofVerifier
        );
    }

    function _deployRollupContracts(
        address sharedResolver,
        DeploymentConfig memory config,
        address proofVerifier
    )
        private
        returns (address shastaInbox)
    {
        // Deploy whitelist
        address whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (config.contractOwner))
        });

        PreconfWhitelist(whitelist).addOperator(config.proposerAddress, config.proposerAddress);

        // Get dependencies
        address bondToken =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "bond_token", false);

        address signalService;
        bool signalServiceExists = true;
        try IResolver(sharedResolver)
            .resolve(uint64(block.chainid), "signal_service", false) returns (
            address existing
        ) {
            signalService = existing;
        } catch {
            signalServiceExists = false;
        }

        if (!signalServiceExists) {
            SignalService signalServiceImpl = new SignalService(msg.sender, config.remoteSigSvc);
            signalService = deployProxy({
                name: "signal_service",
                impl: address(signalServiceImpl),
                data: abi.encodeCall(SignalService.init, (msg.sender))
            });
            register(sharedResolver, "signal_service", signalService);
            console2.log("SignalService deployed:", signalService);
        }

        address codec = address(new CodecOptimized());

        // Deploy inbox
        shastaInbox = deployProxy({
            name: "shasta_inbox",
            impl: address(
                new DevnetInbox(codec, proofVerifier, whitelist, bondToken, signalService)
            ),
            data: abi.encodeCall(Inbox.init, (msg.sender))
        });

        if (vm.envBool("ACTIVATE_INBOX")) {
            Inbox(payable(shastaInbox)).activate(config.l2GenesisHash);
        }
        console2.log("ShastaInbox deployed:", shastaInbox);

        if (!signalServiceExists) {
            SignalService upgradedSignalServiceImpl =
                new SignalService(shastaInbox, config.remoteSigSvc);
            SignalService(signalService).upgradeTo(address(upgradedSignalServiceImpl));
            console2.log("SignalService upgraded with Shasta inbox authorized syncer");

            if (config.contractOwner != msg.sender) {
                Ownable2StepUpgradeable(signalService).transferOwnership(config.contractOwner);
                console2.log("SignalService ownership transfer initiated to:", config.contractOwner);
            }
        }
    }

    function _transferOwnerships(
        address sharedResolver,
        address shastaInbox,
        address newOwner
    )
        private
    {
        if (DefaultResolver(sharedResolver).owner() == msg.sender) {
            DefaultResolver(sharedResolver).transferOwnership(newOwner);
            console2.log("SharedResolver ownership transferred to:", newOwner);
        }

        Ownable2StepUpgradeable(shastaInbox).transferOwnership(newOwner);
        console2.log("ShastaInbox ownership transferred to:", newOwner);
    }

    function deploySharedContracts(DeploymentConfig memory config)
        internal
        returns (address sharedResolver)
    {
        require(config.contractOwner != address(0), "Invalid owner address");

        // Deploy or reuse resolver
        sharedResolver = config.sharedResolver;
        if (sharedResolver == address(0)) {
            sharedResolver = deployProxy({
                name: "shared_resolver",
                impl: address(new DefaultResolver()),
                data: abi.encodeCall(DefaultResolver.init, (address(0)))
            });
        }

        // Deploy or register Taiko token
        _deployOrRegisterTaikoToken(sharedResolver, config);
    }

    function _deployOrRegisterTaikoToken(
        address sharedResolver,
        DeploymentConfig memory config
    )
        private
    {
        address taikoToken = config.taikoToken;

        if (taikoToken == address(0)) {
            taikoToken = deployProxy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (config.contractOwner, config.taikoTokenPremintRecipient)
                ),
                registerTo: sharedResolver
            });
        } else {
            register(sharedResolver, "taiko_token", taikoToken);
        }

        // Register as bond token as well
        register(sharedResolver, "bond_token", taikoToken);
    }

    function _deployBridge(address sharedResolver, DeploymentConfig memory config) private {
        address signalService = IResolver(sharedResolver)
            .resolve(uint64(block.chainid), LibNames.B_SIGNAL_SERVICE, false);

        address bridge = deployProxy({
            name: "bridge",
            impl: address(new MainnetBridge(address(sharedResolver), signalService)),
            data: abi.encodeCall(Bridge.init, (address(0))),
            registerTo: sharedResolver
        });

        if (config.pauseBridge) {
            Bridge(payable(bridge)).pause();
        }

        Bridge(payable(bridge)).transferOwnership(config.contractOwner);
    }

    function _deployVaults(address sharedResolver, address owner) private {
        // Deploy ERC20 Vault
        address erc20Vault = deployProxy({
            name: "erc20_vault",
            impl: address(new MainnetERC20Vault(address(sharedResolver))),
            data: abi.encodeCall(ERC20Vault.init, (owner)),
            registerTo: sharedResolver
        });

        // Deploy ERC721 Vault
        address erc721Vault = deployProxy({
            name: "erc721_vault",
            impl: address(new MainnetERC721Vault(address(sharedResolver))),
            data: abi.encodeCall(ERC721Vault.init, (owner)),
            registerTo: sharedResolver
        });

        // Deploy ERC1155 Vault
        address erc1155Vault = deployProxy({
            name: "erc1155_vault",
            impl: address(new MainnetERC1155Vault(address(sharedResolver))),
            data: abi.encodeCall(ERC1155Vault.init, (owner)),
            registerTo: sharedResolver
        });

        // Deploy bridged token implementations
        register(sharedResolver, "bridged_erc20", address(new BridgedERC20(erc20Vault)));
        register(sharedResolver, "bridged_erc721", address(new BridgedERC721(address(erc721Vault))));
        register(
            sharedResolver, "bridged_erc1155", address(new BridgedERC1155(address(erc1155Vault)))
        );
    }

    function _deployAutomataAttestation(address owner)
        private
        returns (address automataProxy, address automataProxySgxGeth)
    {
        // Deploy library dependencies
        SigVerifyLib sigVerifyLib = new SigVerifyLib(address(new P256Verifier()));
        PEMCertChainLib pemCertChainLib = new PEMCertChainLib();

        console2.log("SigVerifyLib deployed:", address(sigVerifyLib));
        console2.log("PEMCertChainLib deployed:", address(pemCertChainLib));

        // Deploy automata attestation proxy
        automataProxy = deployProxy({
            name: "automata_dcap_attestation",
            impl: address(new AutomataDcapV3Attestation()),
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init,
                (owner, address(sigVerifyLib), address(pemCertChainLib))
            )
        });
        // Deploy sgx-geth automata attestation proxy
        automataProxySgxGeth = deployProxy({
            name: "sgx_geth_automata_dcap_attestation",
            impl: address(new AutomataDcapV3Attestation()),
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init,
                (owner, address(sigVerifyLib), address(pemCertChainLib))
            )
        });
    }

    function _deployZKVerifiers(
        address owner,
        uint64 l2ChainId
    )
        private
        returns (address risc0Verifier, address sp1Verifier)
    {
        // Deploy RISC0 verifier
        RiscZeroGroth16Verifier risc0Groth16 =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        risc0Verifier = address(new Risc0Verifier(l2ChainId, address(risc0Groth16), owner));
        console2.log("Risc0Verifier deployed:", risc0Verifier);

        // Deploy SP1 verifier
        SuccinctVerifier sp1Plonk = new SuccinctVerifier();
        sp1Verifier = address(new SP1Verifier(l2ChainId, address(sp1Plonk), owner));
        console2.log("SP1Verifier deployed:", sp1Verifier);
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20Token("Horse Token", "HORSE"));
        address bullToken =
            address(new FreeMintERC20Token_With50PctgMintAndTransferFailure("Bull Token", "BULL"));

        console2.log("Test tokens deployed:");
        console2.log("  HorseToken:", horseToken);
        console2.log("  BullToken:", bullToken);
    }
}
