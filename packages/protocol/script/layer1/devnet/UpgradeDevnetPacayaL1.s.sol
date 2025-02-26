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
import "src/shared/tokenvault/ERC20Vault.sol";
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
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";

contract UpgradeDevnetPacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public oldFork = vm.envAddress("OLD_FORK");
    address public taikoInbox = vm.envAddress("TAIKO_INBOX");
    address public proverSet = vm.envAddress("PROVER_SET");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER");
    address public risc0Verifier = vm.envAddress("RISC0_VERIFIER");
    address public sp1Verifier = vm.envAddress("SP1_VERIFIER");
    address public bridgeL1 = vm.envAddress("BRIDGE_L1");
    address public signalService = vm.envAddress("SIGNAL_SERVICE");
    address public erc20Vault = vm.envAddress("ERC20_VAULT");
    address public erc721Vault = vm.envAddress("ERC721_VAULT");
    address public erc1155Vault = vm.envAddress("ERC1155_VAULT");
    address public taikoToken = vm.envAddress("TAIKO_TOKEN");
    uint256 public inclusionWindow = vm.envUint("INCLUSION_WINDOW");
    uint256 public inclusionFeeInGwei = vm.envUint("INCLUSION_FEE_IN_GWEI");
    address public quotaManager = vm.envAddress("QUOTA_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(oldFork != address(0), "invalid old fork");
        require(taikoInbox != address(0), "invalid taiko inbox");
        require(proverSet != address(0), "invalid prover set");
        require(sgxVerifier != address(0), "invalid sgx verifier");
        require(risc0Verifier != address(0), "invalid risc0 verifier");
        require(sp1Verifier != address(0), "invalid sp1 verifier");
        require(bridgeL1 != address(0), "invalid bridge");
        require(signalService != address(0), "invalid signal service");
        require(erc20Vault != address(0), "invalid erc20 vault");
        require(erc721Vault != address(0), "invalid erc721 vault");
        require(erc1155Vault != address(0), "invalid erc1155 vault");
        require(taikoToken != address(0), "invalid taiko token");
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
        // Bridge
        upgradeBridgeContracts(sharedResolver);

        // register unchanged contract
        register(sharedResolver, "taiko_token", taikoToken);
        register(sharedResolver, "bond_token", taikoToken);
        // Rollup resolverpro
        address rollupResolver = deployProxy({
            name: "rollup_address_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });
        // register copy
        copyRegister(rollupResolver, sharedResolver, "taiko_token");
        copyRegister(rollupResolver, sharedResolver, "bond_token");
        copyRegister(rollupResolver, sharedResolver, "signal_service");
        copyRegister(rollupResolver, sharedResolver, "bridge");

        // Proof verifier
        address proofVerifier = deployProxy({
            name: "proof_verifier",
            impl: address(
                new DevnetVerifier(
                    address(0), address(0), address(0), address(0), address(0), address(0)
                )
            ),
            data: abi.encodeCall(ComposeVerifier.init, (address(0))),
            registerTo: rollupResolver
        });

        // OP verifier

        address opVerifier = deployProxy({
            name: "op_verifier",
            impl: address(new OpVerifier(rollupResolver)),
            data: abi.encodeCall(OpVerifier.init, (address(0))),
            registerTo: rollupResolver
        });

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

        // TaikoInbox
        address newFork =
            address(new DevnetInbox(taikoWrapper, proofVerifier, taikoToken, signalService));
        UUPSUpgradeable(taikoInbox).upgradeTo(address(new PacayaForkRouter(oldFork, newFork)));
        register(rollupResolver, "taiko", taikoInbox);
        // Prover set
        UUPSUpgradeable(proverSet).upgradeTo(
            address(new ProverSet(rollupResolver, taikoInbox, taikoToken, taikoWrapper))
        );
        TaikoInbox taikoInboxImpl = TaikoInbox(newFork);
        uint64 l2ChainId = taikoInboxImpl.pacayaConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        // Other verifiers
        upgradeVerifierContracts(rollupResolver, opVerifier, proofVerifier, l2ChainId);
    }

    function upgradeVerifierContracts(
        address rollupResolver,
        address opVerifier,
        address proofVerifier,
        uint64 l2ChainId
    )
        internal
    {
        P256Verifier p256Verifier = new P256Verifier();
        SigVerifyLib sigVerifyLib = new SigVerifyLib(address(p256Verifier));
        PEMCertChainLib pemCertChainLib = new PEMCertChainLib();
        address automataDcapV3AttestationImpl = address(new AutomataDcapV3Attestation());

        address automataProxy = deployProxy({
            name: "automata_dcap_attestation",
            impl: automataDcapV3AttestationImpl,
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init,
                (address(0), address(sigVerifyLib), address(pemCertChainLib))
            ),
            registerTo: rollupResolver
        });
        address sgxImpl =
            address(new SgxVerifier(l2ChainId, taikoInbox, proofVerifier, automataProxy));
        UUPSUpgradeable(sgxVerifier).upgradeTo(sgxImpl);
        register(rollupResolver, "sgx_verifier", sgxVerifier);
        address trustedVerifier = deployProxy({
            name: "trusted_verifier",
            impl: sgxVerifier,
            data: abi.encodeCall(SgxVerifier.init, address(0)),
            registerTo: rollupResolver
        });

        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier risc0Groth16Verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        register(rollupResolver, "risc0_groth16_verifier", address(risc0Groth16Verifier));
        UUPSUpgradeable(risc0Verifier).upgradeTo(
            address(new Risc0Verifier(l2ChainId, address(risc0Groth16Verifier)))
        );
        register(rollupResolver, "risc0_verifier", risc0Verifier);

        // Deploy sp1 plonk verifier
        SuccinctVerifier sp1RemoteVerifier = new SuccinctVerifier();
        register(rollupResolver, "sp1_remote_verifier", address(sp1RemoteVerifier));
        UUPSUpgradeable(sp1Verifier).upgradeTo(
            address(new SP1Verifier(l2ChainId, address(sp1RemoteVerifier)))
        );
        register(rollupResolver, "sp1_verifier", sp1Verifier);

        UUPSUpgradeable(proofVerifier).upgradeTo(
            address(
                new DevnetVerifier(
                    taikoInbox, trustedVerifier, opVerifier, sgxVerifier, risc0Verifier, sp1Verifier
                )
            )
        );
    }

    function upgradeBridgeContracts(address sharedResolver) internal {
        UUPSUpgradeable(bridgeL1).upgradeTo(
            address(new Bridge(sharedResolver, signalService, quotaManager))
        );
        register(sharedResolver, "bridge", bridgeL1);
        // SignalService
        UUPSUpgradeable(signalService).upgradeTo(address(new SignalService(sharedResolver)));
        register(sharedResolver, "signal_service", signalService);
        // Vault
        UUPSUpgradeable(erc20Vault).upgradeTo(address(new ERC20Vault(sharedResolver)));
        register(sharedResolver, "erc20_vault", erc20Vault);
        UUPSUpgradeable(erc721Vault).upgradeTo(address(new ERC721Vault(sharedResolver)));
        register(sharedResolver, "erc721_vault", erc721Vault);
        UUPSUpgradeable(erc1155Vault).upgradeTo(address(new ERC1155Vault(sharedResolver)));
        register(sharedResolver, "erc1155_vault", erc1155Vault);
        // Bridged Token
        register(sharedResolver, "bridged_erc20", address(new BridgedERC20(address(erc20Vault))));
        register(
            sharedResolver, "bridged_erc721", address(new BridgedERC721(address(sharedResolver)))
        );
        register(
            sharedResolver, "bridged_erc1155", address(new BridgedERC1155(address(sharedResolver)))
        );
    }
}
