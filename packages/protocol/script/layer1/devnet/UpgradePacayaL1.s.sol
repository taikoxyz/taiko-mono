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
import "src/layer1/alethia-hoodi/AlethiaHoodiInbox.sol";
import { Bridge } from "../../../contracts/shared/bridge/Bridge.sol";

contract UpgradePacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoInbox = 0xf6eA848c7d7aC83de84db45Ae28EAbf377fe0eF9;
        address wrapper = 0xB843132A26C13D751470a6bAf5F926EbF5d0E4b8;
        address proofVerifier = 0xd9F11261AE4B873bE0f09D0Fc41d2E3F70CD8C59;
        address taikoToken = 0xf3b83e226202ECf7E7bb2419a4C6e3eC99e963DA;
        address signalService = 0x4c70b7F5E153D497faFa0476575903F9299ed811;
        bytes32 genesisHash = 0x8e3d16acf3ecc1fbe80309b04e010b90c9ccb3da14e98536cfe66bb93407d228;

    UUPSUpgradeable(taikoInbox).upgradeTo(address(new AlethiaHoodiInbox(
        wrapper,
            proofVerifier,
        taikoToken,
        signalService
        )));
    }
}
