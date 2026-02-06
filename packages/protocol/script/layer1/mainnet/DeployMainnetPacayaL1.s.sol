// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from
    "@sp1-contracts/src/v4.0.0-rc.3/SP1VerifierPlonk.sol";
import "@p256-verifier/contracts/P256Verifier.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import { ERC20VaultOriginal as ERC20Vault } from "src/shared/tokenvault/ERC20VaultOriginal.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/mainnet/verifiers/MainnetVerifier.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";

contract DeployMainnetPacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public taikoInbox = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    address public taikoToken = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    uint256 public inclusionWindow = vm.envUint("INCLUSION_WINDOW");
    uint256 public inclusionFeeInGwei = vm.envUint("INCLUSION_FEE_IN_GWEI");
    uint64 public l2ChainId = 167_000;
    address public bridgeL1 = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address public bridgeL2 = 0x1670000000000000000000000000000000000001;
    address public signalService = 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
    address public signalServiceL2 = 0x1670000000000000000000000000000000000005;
    address public erc20Vault = 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab;
    address public erc721Vault = 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa;
    address public erc1155Vault = 0xaf145913EA4a56BE22E120ED9C24589659881702;
    address public erc20VaultL2 = 0x1670000000000000000000000000000000000002;
    address public erc721VaultL2 = 0x1670000000000000000000000000000000000003;
    address public erc1155VaultL2 = 0x1670000000000000000000000000000000000004;
    address public risc0Groth16Verifier = 0xf31DE43cc0cF75245adE63d3Dabf58d4332855e9;
    address public sp1RemoteVerifier = 0x68593ad19705E9Ce919b2E368f5Cb7BAF04f7371;
    address public automata = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
    address public oldFork = 0x5110634593Ccb8072d161A7d260A409A7E74D7Ca;
    address public proverSet = 0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9;
    address public contractOwner = vm.envAddress("CONTRACT_OWNER");
    address public sigVerifyLib = 0x47bB416ee947fE4a4b655011aF7d6E3A1B80E6e9;
    address public pemCertChainLib = 0x02772b7B3a5Bea0141C993Dbb8D0733C19F46169;

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Shared resolver
        address sharedResolver = deployProxy({
            name: "shared_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });
        // Rollup resolver
        address rollupResolver = deployProxy({
            name: "rollup_address_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });
        // register unchanged contract
        register(sharedResolver, "taiko_token", taikoToken);
        register(sharedResolver, "bond_token", taikoToken);
        register(sharedResolver, "bridge", bridgeL1);
        register(sharedResolver, "bridge", bridgeL2, l2ChainId);
        register(sharedResolver, "signal_service", signalService);
        register(sharedResolver, "signal_service", signalServiceL2, l2ChainId);
        register(sharedResolver, "erc20_vault", erc20Vault);
        register(sharedResolver, "erc721_vault", erc721Vault);
        register(sharedResolver, "erc1155_vault", erc1155Vault);
        register(sharedResolver, "bridge_watchdog", 0x00000291AB79c55dC4Fcd97dFbA4880DF4b93624);
        register(sharedResolver, "bridged_erc20", 0x65666141a541423606365123Ed280AB16a09A2e1);
        register(sharedResolver, "bridged_erc721", 0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7);
        register(sharedResolver, "bridged_erc1155", 0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40);
        register(sharedResolver, "erc20_vault", erc20VaultL2, l2ChainId);
        register(sharedResolver, "erc721_vault", erc721VaultL2, l2ChainId);
        register(sharedResolver, "erc1155_vault", erc1155VaultL2, l2ChainId);
        register(rollupResolver, "risc0_groth16_verifier", risc0Groth16Verifier);
        register(rollupResolver, "sp1_remote_verifier", sp1RemoteVerifier);
        register(rollupResolver, "automata_dcap_attestation", automata);
        register(rollupResolver, "prover_set", 0x280eAbfd252f017B78e15b69580F249F45FB55Fa);

        // register copy
        copyRegister(rollupResolver, sharedResolver, "taiko_token");
        copyRegister(rollupResolver, sharedResolver, "bond_token");
        copyRegister(rollupResolver, sharedResolver, "signal_service");
        copyRegister(rollupResolver, sharedResolver, "bridge");

        // Initializable ForcedInclusionStore with empty TaikoWrapper at first.
        address store = deployProxy({
            name: "forced_inclusion_store",
            impl: address(
                new ForcedInclusionStore(
                    uint8(inclusionWindow), uint64(inclusionFeeInGwei), taikoInbox, address(1)
                )
            ),
            data: abi.encodeCall(ForcedInclusionStore.init, (contractOwner)),
            registerTo: rollupResolver
        });

        // TaikoWrapper
        address taikoWrapper = deployProxy({
            name: "taiko_wrapper",
            impl: address(new TaikoWrapper(taikoInbox, store, address(0))),
            data: abi.encodeCall(TaikoWrapper.init, (contractOwner)),
            registerTo: rollupResolver
        });

        // Upgrade ForcedInclusionStore to use the real TaikoWrapper address.
        UUPSUpgradeable(store).upgradeTo(
            address(
                new ForcedInclusionStore(
                    uint8(inclusionWindow), uint64(inclusionFeeInGwei), taikoInbox, taikoWrapper
                )
            )
        );

        // Proof verifier
        address proofVerifier = deployProxy({
            name: "proof_verifier",
            impl: address(
                new MainnetVerifier(address(0), address(0), address(0), address(0), address(0))
            ),
            data: abi.encodeCall(ComposeVerifier.init, (address(0))),
            registerTo: rollupResolver
        });

        // Register taiko
        address newFork =
            address(
                new MainnetInbox(
                    taikoWrapper,
                    proofVerifier,
                    taikoToken,
                    signalService,
                    uint64(vm.envOr("SHASTA_FORK_TIMESTAMP", uint256(type(uint64).max)))
                )
            );
        address forkRouter = address(new PacayaForkRouter(oldFork, newFork));
        console2.log("forkRouter:", forkRouter);
        address newProverSetImpl =
            address(new ProverSet(rollupResolver, taikoInbox, taikoToken, taikoWrapper));
        console2.log("newProverSetImpl:", newProverSetImpl);
        address newSignalServiceImpl = address(new SignalService(sharedResolver));
        console2.log("newSignalServiceImpl:", newSignalServiceImpl);
        register(rollupResolver, "taiko", taikoInbox);
        // Other verifiers
        deployVerifierContracts(rollupResolver, proofVerifier);

        // Transfer ownership
        Ownable2StepUpgradeable(sharedResolver).transferOwnership(contractOwner);
        Ownable2StepUpgradeable(rollupResolver).transferOwnership(contractOwner);
        Ownable2StepUpgradeable(proofVerifier).transferOwnership(contractOwner);

        // Note: The following operations must be performed by a multi-signature wallet.
        UUPSUpgradeable(taikoInbox).upgradeTo(forkRouter);
        UUPSUpgradeable(proverSet).upgradeTo(newProverSetImpl);
        UUPSUpgradeable(signalService).upgradeTo(newSignalServiceImpl);
    }

    function deployVerifierContracts(address rollupResolver, address proofVerifier) internal {
        address sgxGethAutomataProxy = deployProxy({
            name: "sgx_geth_automata",
            impl: address(new AutomataDcapV3Attestation()),
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init, (contractOwner, sigVerifyLib, pemCertChainLib)
            ),
            registerTo: rollupResolver
        });
        address sgxGethVerifier = deployProxy({
            name: "sgx_geth_verifier",
            impl: address(new SgxVerifier(l2ChainId, taikoInbox, proofVerifier, sgxGethAutomataProxy)),
            data: abi.encodeCall(SgxVerifier.init, (contractOwner)),
            registerTo: rollupResolver
        });

        (address sgxRethVerifier) = deployTEEVerifiers(rollupResolver, proofVerifier);
        (address risc0RethVerifier, address sp1RethVerifier) = deployZKVerifiers(rollupResolver);

        UUPSUpgradeable(proofVerifier).upgradeTo(
            address(
                new MainnetVerifier(
                    taikoInbox, sgxGethVerifier, sgxRethVerifier, risc0RethVerifier, sp1RethVerifier
                )
            )
        );
    }

    function deployZKVerifiers(address rollupResolver)
        internal
        returns (address risc0Verifier, address sp1Verifier)
    {
        risc0Verifier = deployProxy({
            name: "risc0_reth_verifier",
            impl: address(new Risc0Verifier(l2ChainId, risc0Groth16Verifier)),
            data: abi.encodeCall(Risc0Verifier.init, (contractOwner)),
            registerTo: rollupResolver
        });

        // Deploy sp1 verifier
        sp1Verifier = deployProxy({
            name: "sp1_reth_verifier",
            impl: address(new SP1Verifier(l2ChainId, sp1RemoteVerifier)),
            data: abi.encodeCall(SP1Verifier.init, (contractOwner)),
            registerTo: rollupResolver
        });
    }

    function deployTEEVerifiers(
        address rollupResolver,
        address proofVerifier
    )
        internal
        returns (address sgxVerifier)
    {
        sgxVerifier = deployProxy({
            name: "sgx_reth_verifier",
            impl: address(new SgxVerifier(l2ChainId, taikoInbox, proofVerifier, automata)),
            data: abi.encodeCall(SgxVerifier.init, (contractOwner)),
            registerTo: rollupResolver
        });
    }
}
