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
import { Bridge } from "../../../contracts/shared/bridge/Bridge.sol";

contract UpgradePacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public oldFork = vm.envAddress("OLD_FORK");
    address public taikoInbox = vm.envAddress("TAIKO_INBOX");
    address public proverSet = vm.envAddress("PROVER_SET");
    address public rollupResolver = vm.envAddress("ROLLUP_RESOLVER");
    address public sharedResolver = vm.envAddress("SHARED_RESOLVER");
    address public quotaManager = vm.envAddress("QUOTA_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(taikoInbox != address(0), "invalid taiko inbox");
        require(oldFork != address(0), "invalid old fork");
        require(proverSet != address(0), "invalid prover set");
        require(rollupResolver != address(0), "invalid rollup resolver");
        require(sharedResolver != address(0), "invalid shared resolver");

        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address signalService =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "signal_service", false);
        address taikoWrapper =
            IResolver(rollupResolver).resolve(uint64(block.chainid), "taiko_wrapper", false);
        address proofVerifier =
            IResolver(rollupResolver).resolve(uint64(block.chainid), "proof_verifier", false);
        address taikoToken =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "taiko_token", false);
        // TaikoInbox
        address newFork =
            address(new DevnetInbox(taikoWrapper, proofVerifier, taikoToken, signalService));
        UUPSUpgradeable(taikoInbox).upgradeTo(address(new PacayaForkRouter(oldFork, newFork)));
        // Prover set
        UUPSUpgradeable(proverSet).upgradeTo(
            address(new ProverSet(rollupResolver, taikoInbox, taikoToken, taikoWrapper))
        );
        upgradeBridgeContracts(signalService);
    }

    function upgradeBridgeContracts(address signalService) internal {
        address bridgeL1 = IResolver(sharedResolver).resolve(uint64(block.chainid), "bridge", false);
        address erc20Vault =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "erc20_vault", false);
        address erc721Vault =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "erc721_vault", false);
        address erc1155Vault =
            IResolver(sharedResolver).resolve(uint64(block.chainid), "erc1155_vault", false);
        // Bridge
        UUPSUpgradeable(bridgeL1).upgradeTo(
            address(new Bridge(sharedResolver, signalService, quotaManager))
        );
        // SignalService
        UUPSUpgradeable(signalService).upgradeTo(address(new SignalService(sharedResolver)));
        // Vault
        UUPSUpgradeable(erc20Vault).upgradeTo(address(new ERC20Vault(sharedResolver)));
        UUPSUpgradeable(erc721Vault).upgradeTo(address(new ERC721Vault(sharedResolver)));
        UUPSUpgradeable(erc1155Vault).upgradeTo(address(new ERC1155Vault(sharedResolver)));
    }
}
