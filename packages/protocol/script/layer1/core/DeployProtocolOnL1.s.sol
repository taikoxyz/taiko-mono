// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/v6.1.0/SP1VerifierPlonk.sol";

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";
import { DevnetInbox } from "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/devnet/DevnetVerifier.sol";
import "src/layer1/devnet/OpVerifier.sol";
import "src/layer1/mainnet/MainnetBridge.sol";
import "src/layer1/mainnet/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/MainnetERC20Vault.sol";
import "src/layer1/mainnet/MainnetERC721Vault.sol";
import "src/layer1/mainnet/TaikoToken.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { InsecureSgxVerifier } from "src/layer1/verifiers/InsecureSgxVerifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
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
        address ejectorManager;
        address proverManager;
        bytes32 l2GenesisHash;
        uint64 l2ChainId;
        address sharedResolver;
        address remoteSigSvc;
        address signalServicePauser;
        address bridgePauser;
        address preconfWhitelist;
        address taikoToken;
        address taikoTokenPremintRecipient;
        address proposerAddress;
        address automataDcap;
        bool useDummyVerifiers;
        bool pauseBridge;
        // When true, deploy the lenient InsecureSgxVerifier; otherwise deploy the strict
        // SgxVerifier. The secure default (false) selects the strict mainnet policy.
        bool useInsecureSgxPolicy;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set or invalid");
        vm.startBroadcast(privateKey);
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
        config.ejectorManager = vm.envOr("EJECTOR_MANAGER", config.contractOwner);
        config.proverManager = vm.envOr("PROVER_MANAGER", config.contractOwner);
        config.l2GenesisHash = vm.envBytes32("L2_GENESIS_HASH");
        config.l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
        config.sharedResolver = vm.envAddress("SHARED_RESOLVER");
        config.remoteSigSvc = vm.envOr("REMOTE_SIGNAL_SERVICE", msg.sender);
        config.signalServicePauser = vm.envOr("SIGNAL_SERVICE_PAUSER", address(0));
        config.bridgePauser = vm.envOr("BRIDGE_PAUSER", address(0));
        config.preconfWhitelist = vm.envOr("PRECONF_WHITELIST", address(0));
        config.taikoToken = vm.envAddress("TAIKO_TOKEN");
        config.taikoTokenPremintRecipient = vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");
        config.proposerAddress = vm.envAddress("PROPOSER_ADDRESS");
        config.preconfWhitelist = vm.envOr("PRECONF_WHITELIST", address(0));
        // Taiko-owned Automata DCAP attestation entrypoint for the SGX verifiers. Deploy one from
        // the layer1o artifacts (see DeployUnzenContracts._deployAttestation; `pnpm compile:l1o`
        // first) and pass its address here. Optional for dummy-verifier deployments, which don't
        // exercise real attestation.
        config.automataDcap = vm.envOr("DCAP_ATTESTATION", address(0));
        config.useDummyVerifiers = vm.envBool("DUMMY_VERIFIERS");
        config.pauseBridge = vm.envBool("PAUSE_BRIDGE");
        // Secure default: when INSECURE_SGX_VERIFIER is unset or false, deploy the strict
        // SgxVerifier. Only an explicit true selects the lenient InsecureSgxVerifier.
        config.useInsecureSgxPolicy = vm.envOr("INSECURE_SGX_VERIFIER", false);

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

        // Taiko-owned Automata DCAP attestation entrypoint (deployed separately from the layer1o
        // artifacts), shared by both SGX verifier instances; each SgxVerifier
        // enforces its own MRENCLAVE/MRSIGNER allowlist (configured post-deployment). Required for
        // real deployments; dummy deployments don't exercise real attestation.
        address automataDcap = config.automataDcap;
        if (!config.useDummyVerifiers) {
            require(automataDcap != address(0), "DCAP_ATTESTATION not set");
        }

        // Deploy SGX verifiers. Mainnet AND all (public) testnets MUST use SecureSgxVerifier (strict
        // TCB-status policy + per-MRENCLAVE ATTRIBUTES pin); the strict SecureSgxVerifier is the
        // secure default, and only an explicit `useInsecureSgxPolicy` selects the lenient
        // InsecureSgxVerifier, which relaxes the TCB-status policy for lagging dev hardware and MUST
        // be used by local devnets ONLY — never by a public testnet or mainnet.
        // The registrar is set to address(0), leaving `registerInstance` permissionless; set a
        // non-zero registrar to restrict instance registration (a non-zero registrar may also
        // fail-close a compromised enclave via `removeEnclaveAttributePolicy`). The 24h
        // instance-validity delay gives off-chain monitoring time to evict a rogue self-registered
        // instance before it can prove (owner `addInstances` registrations are not delayed); it
        // applies to SecureSgxVerifier only.
        // NOTE: with registrar == address(0) the quote-freshness gate is enforced (permissionless
        // registration fails closed): `registerInstance` reverts with SGX_STALE_QUOTE unless the
        // prover embeds the recent-block commitment in reportData and the registration lands within
        // the 256-block window. Deploy with a non-zero registrar (or use owner `addInstances`) if
        // the prover does not embed the commitment yet.
        verifiers.sgx = config.useInsecureSgxPolicy
            ? address(
                new InsecureSgxVerifier(
                    config.l2ChainId, config.contractOwner, automataDcap, address(0)
                )
            )
            : address(
                new SecureSgxVerifier(
                    config.l2ChainId, config.contractOwner, automataDcap, address(0), 24 hours
                )
            );
        console2.log("SgxVerifier deployed:", verifiers.sgx);

        verifiers.sgxGeth = config.useInsecureSgxPolicy
            ? address(
                new InsecureSgxVerifier(
                    config.l2ChainId, config.contractOwner, automataDcap, address(0)
                )
            )
            : address(
                new SecureSgxVerifier(
                    config.l2ChainId, config.contractOwner, automataDcap, address(0), 24 hours
                )
            );
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
        address whitelist = config.preconfWhitelist;
        if (whitelist == address(0)) {
            whitelist = deployProxy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist(config.ejectorManager)),
                data: abi.encodeCall(PreconfWhitelist.init, (config.contractOwner))
            });
        } else {
            PreconfWhitelist(whitelist)
                .upgradeTo(address(new PreconfWhitelist(config.ejectorManager)));
        }

        PreconfWhitelist(whitelist).addOperator(config.proposerAddress, config.proposerAddress);

        // Deploy prover whitelist
        address proverWhitelist = deployProxy({
            name: "prover_whitelist",
            impl: address(new ProverWhitelist(config.proverManager)),
            data: abi.encodeCall(ProverWhitelist.init, (config.contractOwner))
        });
        console2.log("ProverWhitelist deployed:", proverWhitelist);

        // Get dependencies
        address signalService =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "signal_service", true);

        if (signalService == address(0)) {
            SignalService signalServiceImpl =
                new SignalService(msg.sender, config.remoteSigSvc, config.signalServicePauser);
            signalService = deployProxy({
                name: "signal_service",
                impl: address(signalServiceImpl),
                data: abi.encodeCall(SignalService.init, (msg.sender))
            });
            register(sharedResolver, "signal_service", signalService);
            console2.log("SignalService deployed:", signalService);
        }

        address taikoToken =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "taiko_token", true);

        // Deploy inbox
        shastaInbox = deployProxy({
            name: "shasta_inbox",
            impl: address(
                new DevnetInbox(
                    proofVerifier, whitelist, proverWhitelist, signalService, taikoToken
                )
            ),
            data: abi.encodeCall(Inbox.init, (msg.sender))
        });

        if (vm.envBool("ACTIVATE_INBOX")) {
            Inbox(payable(shastaInbox)).activate(config.l2GenesisHash);
        }
        console2.log("ShastaInbox deployed:", shastaInbox);

        SignalService(signalService)
            .upgradeTo(
                address(
                    new SignalService(shastaInbox, config.remoteSigSvc, config.signalServicePauser)
                )
            );
        console2.log("SignalService upgraded with Shasta inbox authorized syncer");

        if (config.contractOwner != msg.sender) {
            Ownable2StepUpgradeable(signalService).transferOwnership(config.contractOwner);
            console2.log("SignalService ownership transfer initiated to:", config.contractOwner);
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
    }

    function _deployBridge(address sharedResolver, DeploymentConfig memory config) private {
        address signalService = IResolver(sharedResolver)
            .resolve(uint64(block.chainid), LibNames.B_SIGNAL_SERVICE, false);

        // The quota manager is wired in via a later upgrade once it is deployed; the bridge is
        // bootstrapped with address(0), which disables the Ether quota check.
        address quotaManager = address(0);

        address bridge = deployProxy({
            name: "bridge",
            impl: address(
                new MainnetBridge(
                    address(sharedResolver), signalService, quotaManager, config.bridgePauser
                )
            ),
            data: abi.encodeCall(Bridge.init, (address(0))),
            registerTo: sharedResolver
        });

        if (config.pauseBridge) {
            Bridge(payable(bridge)).pause();
        }

        Bridge(payable(bridge)).transferOwnership(config.contractOwner);
    }

    function _deployVaults(address sharedResolver, address owner) private {
        // The quota manager is wired in via a later upgrade once it is deployed; the vault is
        // bootstrapped with address(0), which disables the token quota check.
        address quotaManager = address(0);

        // Deploy ERC20 Vault
        address erc20Vault = deployProxy({
            name: "erc20_vault",
            impl: address(new MainnetERC20Vault(address(sharedResolver), quotaManager)),
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
