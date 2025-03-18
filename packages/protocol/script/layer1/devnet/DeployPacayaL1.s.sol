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
import "src/layer1/devnet/verifiers/OpVerifier.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";

contract DeployPacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public taikoInbox = vm.envAddress("TAIKO_INBOX");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");
    address public sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");
    address public taikoToken = vm.envAddress("TAIKO_TOKEN");
    uint256 public inclusionWindow = vm.envUint("INCLUSION_WINDOW");
    uint256 public inclusionFeeInGwei = vm.envUint("INCLUSION_FEE_IN_GWEI");
    address public quotaManager = vm.envAddress("QUOTA_MANAGER");
    uint64 public l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(taikoInbox != address(0), "invalid taiko inbox");
        require(rollupAddressManager != address(0), "invalid rollup address manager");
        require(sharedAddressManager != address(0), "invalid shared address manager");
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
        // Rollup resolver
        address rollupResolver = deployProxy({
            name: "rollup_address_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });
        // register unchanged contract
        register(sharedResolver, "taiko_token", taikoToken);
        register(sharedResolver, "bond_token", taikoToken);

        // register copy
        copyRegister(sharedResolver, sharedAddressManager, "bridge");
        copyRegister(sharedResolver, sharedAddressManager, "signal_service");
        copyRegister(sharedResolver, sharedAddressManager, "erc20_vault");
        copyRegister(sharedResolver, sharedAddressManager, "erc721_vault");
        copyRegister(sharedResolver, sharedAddressManager, "erc1155_vault");
        copyRegister(rollupResolver, sharedResolver, "taiko_token");
        copyRegister(rollupResolver, sharedResolver, "bond_token");
        copyRegister(rollupResolver, sharedResolver, "signal_service");
        copyRegister(rollupResolver, sharedResolver, "bridge");
        copyRegister(rollupResolver, rollupAddressManager, "risc0_groth16_verifier");
        copyRegister(rollupResolver, rollupAddressManager, "sp1_remote_verifier");
        copyRegister(rollupResolver, rollupAddressManager, "automata_dcap_attestation");
        // Bridge
        registerBridgedTokenContracts(sharedResolver);

        // OP verifier
        address opImpl = address(new OpVerifier(rollupResolver));
        address opVerifier = deployProxy({
            name: "op_verifier",
            impl: opImpl,
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

        // Register taiko
        register(rollupResolver, "taiko", taikoInbox);

        // Other verifiers
        deployVerifierContracts(rollupResolver, opVerifier, opImpl);
    }

    function deployVerifierContracts(
        address rollupResolver,
        address opProxy,
        address opImpl
    )
        internal
    {
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
        // In testing, use opVerifier impl as a pivotVerifier
        address pivotVerifier = deployProxy({
            name: "pivot_verifier",
            impl: opImpl,
            data: abi.encodeCall(OpVerifier.init, address(0)),
            registerTo: rollupResolver
        });

        (address sgxVerifier) = deployTEEVerifiers(rollupResolver, proofVerifier);
        (address risc0Verifier, address sp1Verifier) = deployZKVerifiers(rollupResolver);

        UUPSUpgradeable(proofVerifier).upgradeTo(
            address(
                new DevnetVerifier(
                    taikoInbox, pivotVerifier, opProxy, sgxVerifier, risc0Verifier, sp1Verifier
                )
            )
        );
    }

    function deployZKVerifiers(
        address rollupResolver
    )
        internal
        returns (address risc0Verifier, address sp1Verifier)
    {
        // Deploy r0 verifier
        address risc0Groth16Verifier = IResolver(rollupResolver).resolve(
            uint64(block.chainid), "risc0_groth16_verifier", false
        );

        risc0Verifier = deployProxy({
            name: "risc0_verifier",
            impl: address(new Risc0Verifier(l2ChainId, risc0Groth16Verifier)),
            data: abi.encodeCall(Risc0Verifier.init, (address(0))),
            registerTo: rollupResolver
        });

        // Deploy sp1 verifier
        address sp1RemoteVerifier =
            IResolver(rollupResolver).resolve(uint64(block.chainid), "sp1_remote_verifier", false);

        sp1Verifier = deployProxy({
            name: "sp1_verifier",
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
        address automataProxy = IResolver(rollupResolver).resolve(
            uint64(block.chainid), "automata_dcap_attestation", false
        );

        sgxVerifier = deployProxy({
            name: "sgx_verifier",
            impl: address(new SgxVerifier(l2ChainId, taikoInbox, proofVerifier, automataProxy)),
            data: abi.encodeCall(SgxVerifier.init, (address(0))),
            registerTo: rollupResolver
        });
    }

    function registerBridgedTokenContracts(address sharedResolver) internal {
        address erc20Vault =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "erc20_vault", false);
        address erc721Vault =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "erc721_vault", false);
        address erc1155Vault = IResolver(sharedResolver).resolve(uint64(block.chainid), "erc1155_vault", false);
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
