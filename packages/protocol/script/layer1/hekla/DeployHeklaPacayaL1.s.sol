// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
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
import "src/layer1/devnet/verifiers/OpVerifier.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import "src/layer1/hekla/verifiers/HeklaVerifier.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/hekla/HeklaInbox.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import { HeklaVerifier } from "../../../contracts/layer1/hekla/verifiers/HeklaVerifier.sol";
import { HeklaInbox } from "../../../contracts/layer1/hekla/HeklaInbox.sol";

contract DeployHeklaPacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public taikoInbox = vm.envAddress("TAIKO_INBOX");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");
    address public sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");
    address public taikoToken = vm.envAddress("TAIKO_TOKEN");
    uint256 public inclusionWindow = vm.envUint("INCLUSION_WINDOW");
    uint256 public inclusionFeeInGwei = vm.envUint("INCLUSION_FEE_IN_GWEI");
    address public quotaManager = vm.envAddress("QUOTA_MANAGER");
    uint64 public l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
    address public bridgeL1 = vm.envAddress("BRIDGE_L1");
    address public bridgeL2 = vm.envAddress("BRIDGE_L2");
    address public signalService = vm.envAddress("SIGNAL_SERVICE");
    address public erc20Vault = vm.envAddress("ERC20_VAULT");
    address public erc721Vault = vm.envAddress("ERC721_VAULT");
    address public erc1155Vault = vm.envAddress("ERC1155_VAULT");
    address public erc20VaultL2 = vm.envAddress("ERC20_VAULT_L2");
    address public erc721VaultL2 = vm.envAddress("ERC721_VAULT_L2");
    address public erc1155VaultL2 = vm.envAddress("ERC1155_VAULT_L2");
    address public risc0Groth16Verifier = vm.envAddress("RISC0_GROTH16_VERIFIER");
    address public sp1RemoteVerifier = vm.envAddress("SP1_REMOTE_VERIFIER");
    address public automata = vm.envAddress("AUTOMATA_DCAP_ATTESTATION");
    address public oldFork = vm.envAddress("OLD_FORK");
    address public proverSet = vm.envAddress("PROVER_SET");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(taikoInbox != address(0), "invalid taiko inbox");
        require(rollupAddressManager != address(0), "invalid rollup address manager");
        require(sharedAddressManager != address(0), "invalid shared address manager");
        require(taikoToken != address(0), "invalid taiko token");
        require(oldFork != address(0), "invalid old fork");
        require(proverSet != address(0), "invalid prover set");
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
        register(sharedResolver, "erc20_vault", erc20Vault);
        register(sharedResolver, "erc721_vault", erc721Vault);
        register(sharedResolver, "erc1155_vault", erc1155Vault);
        register(sharedResolver, "erc20_vault", erc20VaultL2, l2ChainId);
        register(sharedResolver, "erc721_vault", erc721VaultL2, l2ChainId);
        register(sharedResolver, "erc1155_vault", erc1155VaultL2, l2ChainId);
        register(rollupResolver, "risc0_groth16_verifier", risc0Groth16Verifier);
        register(rollupResolver, "sp1_remote_verifier", sp1RemoteVerifier);
        register(rollupResolver, "automata_dcap_attestation", automata);

        // register copy
        copyRegister(rollupResolver, sharedResolver, "taiko_token");
        copyRegister(rollupResolver, sharedResolver, "bond_token");
        copyRegister(rollupResolver, sharedResolver, "signal_service");
        copyRegister(rollupResolver, sharedResolver, "bridge");

        // OP verifier
        address opImpl = address(new OpVerifier(rollupResolver));

        // Initializable ForcedInclusionStore with empty TaikoWrapper at first.
        address store = deployProxy({
            name: "forced_inclusion_store",
            impl: address(
                new ForcedInclusionStore(
                    uint8(inclusionWindow), uint64(inclusionFeeInGwei), taikoInbox, address(1)
                )
            ),
            data: abi.encodeCall(ForcedInclusionStore.init, (address(0))),
            registerTo: rollupResolver
        });

        // TaikoWrapper
        address taikoWrapper = deployProxy({
            name: "taiko_wrapper",
            impl: address(new TaikoWrapper(taikoInbox, store, address(0))),
            data: abi.encodeCall(TaikoWrapper.init, (address(0))),
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
            impl: address(new HeklaVerifier(address(0), address(0), address(0), address(0), address(0))),
            data: abi.encodeCall(ComposeVerifier.init, (address(0))),
            registerTo: rollupResolver
        });

        // Register taiko
        address newFork =
            address(new HeklaInbox(taikoWrapper, proofVerifier, taikoToken, signalService));
        UUPSUpgradeable(taikoInbox).upgradeTo(address(new PacayaForkRouter(oldFork, newFork)));
        register(rollupResolver, "taiko", taikoInbox);

        // Prover set
        UUPSUpgradeable(proverSet).upgradeTo(
            address(new ProverSet(rollupResolver, taikoInbox, taikoToken, taikoWrapper))
        );

        // SignalService
        UUPSUpgradeable(signalService).upgradeTo(address(new SignalService(sharedResolver)));

        // Other verifiers
        deployVerifierContracts(rollupResolver, opImpl, proofVerifier);
    }

    function deployVerifierContracts(
        address rollupResolver,
        address opImpl,
        address proofVerifier
    )
        internal
    {
        // In testing, use opVerifier impl as a sgxGethVerifier
        address sgxGethVerifier = deployProxy({
            name: "sgxGeth_verifier",
            impl: opImpl,
            data: abi.encodeCall(OpVerifier.init, address(0)),
            registerTo: rollupResolver
        });

        (address sgxRethVerifier) = deployTEEVerifiers(rollupResolver, proofVerifier);
        (address risc0RethVerifier, address sp1RethVerifier) = deployZKVerifiers(rollupResolver);

        UUPSUpgradeable(proofVerifier).upgradeTo(
            address(
                new HeklaVerifier(
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
            data: abi.encodeCall(Risc0Verifier.init, (address(0))),
            registerTo: rollupResolver
        });

        // Deploy sp1 verifier
        sp1Verifier = deployProxy({
            name: "sp1_reth_verifier",
            impl: address(new SP1Verifier(l2ChainId, sp1RemoteVerifier)),
            data: abi.encodeCall(SP1Verifier.init, (address(0))),
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
            data: abi.encodeCall(SgxVerifier.init, (address(0))),
            registerTo: rollupResolver
        });
    }
}
