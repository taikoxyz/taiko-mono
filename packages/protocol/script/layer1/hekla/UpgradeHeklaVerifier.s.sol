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
import "src/layer1/hekla/verifiers/HeklaVerifier.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/hekla/HeklaInbox.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";

contract UpgradeHeklaVerifier is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address proofVerifier = 0x9A919115127ed338C3bFBcdfBE72D4F167Fa9E1D;
        address taikoInbox = 0x79C9109b764609df928d16fC4a91e9081F7e87DB;
        address sgxGethVerifier = 0x4361B85093720bD50d25236693CA58FD6e1b3a53;
        address sgxRethVerifier = 0xa8cD459E3588D6edE42177193284d40332c3bcd4;
        address risc0RethVerifier = 0xCDdf353C838542834E443C3c9dE3ab3F81F27aF2;
        address sp1RethVerifier = 0x1138aA994477f0880001aa1E8106D749035b6250;
        address rollupResolver = 0x3C82907B5895DB9713A0BB874379eF8A37aA2A68;
        uint64 l2ChainId = 167_009;
        address taikoWrapper = 0x8698690dEeDB923fA0A674D3f65896B0031BF7c9;
        address taikoToken = 0x6490E12d480549D333499236fF2Ba6676C296011;
        address signalService = 0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D;
        address oldFork = 0x6e15d2049480C7E339C6B398774166e1ddbCd43e;


        // TaikoInbox
        address newFork = address(new HeklaInbox(taikoWrapper, proofVerifier, taikoToken, signalService));
        UUPSUpgradeable(taikoInbox).upgradeTo(address(new PacayaForkRouter(oldFork, newFork)));
    }
}
