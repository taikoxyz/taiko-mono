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
import { HeklaVerifier } from "../../../contracts/layer1/hekla/verifiers/HeklaVerifier.sol";
import { HeklaInbox } from "../../../contracts/layer1/hekla/HeklaInbox.sol";

contract Test is Script { }
