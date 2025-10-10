// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
import "@p256-verifier/contracts/P256Verifier.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/vault/BridgedERC1155.sol";
import "src/shared/vault/BridgedERC20.sol";
import "src/shared/vault/BridgedERC721.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import "src/layer1/mainnet/MainnetBridge.sol";
import "src/layer1/mainnet/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/MainnetERC20Vault.sol";
import "src/layer1/mainnet/MainnetERC721Vault.sol";
import "src/shared/signal/SignalService.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/mainnet/TaikoToken.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/devnet/OpVerifier.sol";
import "src/layer1/devnet/DevnetVerifier.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { DevnetInbox } from "src/layer1/devnet/DevnetInbox.sol";
import { CodecOptimized } from "src/layer1/core/impl/CodecOptimized.sol";
import "test/shared/helpers/FreeMintERC20Token.sol";
import "test/shared/helpers/FreeMintERC20Token_With50PctgMintAndTransferFailure.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployProtocolOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployProtocolOnL1 is DeployCapability {
    struct VerifierAddresses {
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
        addressNotNull(vm.envAddress("CONTRACT_OWNER"), "CONTRACT_OWNER");

        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");
        address contractOwner = vm.envAddress("CONTRACT_OWNER");

        // ---------------------------------------------------------------
        // Deploy shared contracts
        address sharedResolver = deploySharedContracts(contractOwner);
        console2.log("sharedResolver: ", sharedResolver);

        // ---------------------------------------------------------------
        // Deploy verifiers first
        VerifierAddresses memory verifiers = deployVerifiers(contractOwner);

        // Deploy OpVerifier (always deployed, available in both modes)
        address opVerifier = address(new OpVerifier());
        console2.log("Deployed OpVerifier:", opVerifier);

        // Deploy proof verifier based on mode
        // Note: DevnetVerifier is stateless with immutable verifier addresses,
        // so no proxy is needed (cannot be upgraded anyway)
        address proofVerifier;
        if (vm.envBool("DUMMY_VERIFIERS")) {
            // DUMMY MODE: Use OpVerifier for SGX slot (allows fast testing)
            // Accepts: OP (as "sgx") + (OP or RISC0 or SP1)
            proofVerifier = address(
                new DevnetVerifier(
                    opVerifier,
                    opVerifier, // OpVerifier in SGX slot (dummy anchor)
                    verifiers.risc0RethVerifier,
                    verifiers.sp1RethVerifier
                )
            );
        } else {
            // Accepts: SGX + (OP or RISC0 or SP1)
            proofVerifier = address(
                new DevnetVerifier(
                    opVerifier,
                    verifiers.sgxRethVerifier,
                    verifiers.risc0RethVerifier,
                    verifiers.sp1RethVerifier
                )
            );
        }
        console2.log("Deployed DevnetVerifier:", proofVerifier);

        // ---------------------------------------------------------------
        // Deploy rollup contracts
        (address shastaInboxAddr,) =
            deployRollupContracts(sharedResolver, contractOwner, proofVerifier);

        // Upgrade SignalService with actual inbox address
        address signalServiceAddr = IResolver(sharedResolver).resolve(
            uint64(block.chainid), LibNames.B_SIGNAL_SERVICE, false
        );
        address remoteSignalService = vm.envOr("REMOTE_SIGNAL_SERVICE", msg.sender);
        address newImpl = address(new SignalService(shastaInboxAddr, remoteSignalService));

        SignalService(signalServiceAddr).upgradeTo(newImpl);

        if (SignalService(signalServiceAddr).owner() == msg.sender) {
            SignalService(signalServiceAddr).transferOwnership(contractOwner);
        }

        // ---------------------------------------------------------------
        // Deploy other contracts
        if (block.chainid != 1) {
            deployAuxContracts();
        }

        if (DefaultResolver(sharedResolver).owner() == msg.sender) {
            DefaultResolver(sharedResolver).transferOwnership(contractOwner);
            console2.log("** sharedResolver ownership transferred to:", contractOwner);
        }

        Ownable2StepUpgradeable(shastaInboxAddr).transferOwnership(contractOwner);
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

        // Deploy SignalService with dummy inbox address
        address remoteSignalService = vm.envOr("REMOTE_SIGNAL_SERVICE", msg.sender);

        address signalService;
        try IResolver(sharedResolver).resolve(
            uint64(block.chainid), LibNames.B_SIGNAL_SERVICE, false
        ) returns (address existing) {
            signalService = existing;
        } catch {
            signalService = deployProxy({
                name: "signal_service",
                impl: address(new SignalService(address(1), remoteSignalService)),
                data: abi.encodeCall(SignalService.init, owner),
                registerTo: sharedResolver
            });
        }

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
        address owner,
        address _proofVerifier
    )
        internal
        returns (address shastaInboxAddr, address whitelist)
    {
        addressNotNull(_sharedResolver, "sharedResolver");
        addressNotNull(owner, "owner");
        addressNotNull(_proofVerifier, "proofVerifier");
        address proposer = vm.envAddress("PROPOSER_ADDRESS");

        whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (owner, 0, 0))
        });
        PreconfWhitelist(whitelist).addOperator(proposer, proposer);

        address bondToken =
            IResolver(_sharedResolver).resolve(uint64(block.chainid), "bond_token", false);

        address codec = address(new CodecOptimized());
        address signalService =
            IResolver(_sharedResolver).resolve(uint64(block.chainid), "signal_service", false);

        shastaInboxAddr = deployProxy({
            name: "shasta_inbox",
            impl: address(new DevnetInbox(codec, _proofVerifier, whitelist, bondToken, signalService)),
            data: abi.encodeCall(Inbox.init, (address(0), msg.sender))
        });

        Inbox(payable(shastaInboxAddr)).activate(vm.envBytes32("L2_GENESIS_HASH"));

        console2.log("  shasta_inbox       :", shastaInboxAddr);
    }

    function deployVerifiers(address owner) private returns (VerifierAddresses memory) {
        VerifierAddresses memory verifiers;

        // Deploy automata attestation for SGX verifier (always deployed)
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

        // Deploy SGX Reth verifier (always deployed)
        verifiers.sgxRethVerifier =
            address(new SgxVerifier(uint64(vm.envUint("L2_CHAIN_ID")), owner, automataProxy));
        console2.log("Deployed SgxVerifier:", verifiers.sgxRethVerifier);

        // Deploy ZK verifiers (RISC0 and SP1) - always deployed in both modes
        // Note: Even in DUMMY mode, we deploy real ZK verifiers (matching old behavior)
        (verifiers.risc0RethVerifier, verifiers.sp1RethVerifier) =
            deployZKVerifiers(owner, uint64(vm.envUint("L2_CHAIN_ID")));

        return verifiers;
    }

    function deployZKVerifiers(
        address owner,
        uint64 l2ChainId
    )
        private
        returns (address risc0Verifier, address sp1Verifier)
    {
        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);

        risc0Verifier = address(new Risc0Verifier(l2ChainId, address(verifier), owner));

        // Deploy sp1 plonk verifier
        SuccinctVerifier succinctVerifier = new SuccinctVerifier();

        sp1Verifier = address(new SP1Verifier(l2ChainId, address(succinctVerifier), owner));
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20Token("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken =
            address(new FreeMintERC20Token_With50PctgMintAndTransferFailure("Bull Token", "BULL"));
        console2.log("BullToken", bullToken);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
