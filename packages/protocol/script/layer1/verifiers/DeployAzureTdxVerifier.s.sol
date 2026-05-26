// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AzureTDX } from "azure-tdx-verifier/AzureTDX.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import "solady/src/utils/Base64.sol";
import { AzureTdxVerifier } from "src/layer1/verifiers/AzureTdxVerifier.sol";

/// @title DeployAzureTdxVerifier
/// @notice Deploys AzureTdxVerifier (proxy + impl), optionally sets trusted params + registers an
/// initial TDX instance, and hands ownership to a final owner.
///
/// Trusted params and instance registration are now usually handled by the
/// `raiko2 tdx register` CLI against a running prover. This script only performs them
/// inline if the corresponding env vars are present, so the on-chain registry can be
/// bootstrapped before the prover VM is live (and updated later through raiko2).
///
/// Required env:
///   PRIVATE_KEY                  — deployer key
///   CONTRACT_OWNER               — final owner address (Ownable2Step pendingOwner)
///   AUTOMATA_DCAP_ATTESTATION    — already-deployed Automata DCAP attestation contract
///   TAIKO_CHAIN_ID               — uint64 L2 chain id bound to proof signatures
///
/// Optional env (set together to seed trusted params inline):
///   TRUSTED_PARAMS_INDEX         — slot to write trusted params into
///   TEE_TCB_SVN                  — bytes32 (top 16 bytes used)
///   PCR_BITMAP                   — uint (24-bit mask of PCR indices to validate)
///   MR_SEAM_BASE64               — base64 of mrSeam bytes
///   MR_TD_BASE64                 — base64 of mrTd bytes
///   PCRS_BASE64                  — comma-separated base64 PCR digests (32 bytes each)
///
/// Optional env:
///   ATTESTATION_FILE_PATH        — if set (and trusted params are set), register the
///                                  initial instance from this JSON file
contract DeployAzureTdxVerifier is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable contractOwner = vm.envAddress("CONTRACT_OWNER");
    address internal immutable automataDcapAttestation = vm.envAddress("AUTOMATA_DCAP_ATTESTATION");
    uint64 internal immutable taikoChainId = uint64(vm.envUint("TAIKO_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "config: invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(contractOwner != address(0), "config: CONTRACT_OWNER");
        require(automataDcapAttestation != address(0), "config: AUTOMATA_DCAP_ATTESTATION");
        require(taikoChainId != 0, "config: TAIKO_CHAIN_ID");

        console2.log("=====================================");
        console2.log("Deploying AzureTdxVerifier");
        console2.log("=====================================");
        console2.log("** Contract owner:", contractOwner);
        console2.log("** Automata DCAP Attestation:", automataDcapAttestation);
        console2.log("** Taiko chain id:", taikoChainId);

        address tdxVerifier = deployAzureTdxVerifier();

        if (bytes(vm.envOr("MR_SEAM_BASE64", string(""))).length != 0) {
            setupTrustedParams(tdxVerifier);

            if (bytes(vm.envOr("ATTESTATION_FILE_PATH", string(""))).length != 0) {
                registerInstanceWithAttestation(tdxVerifier);
            } else {
                console2.log("** ATTESTATION_FILE_PATH not set, skipping initial instance register");
            }
        } else {
            console2.log("** MR_SEAM_BASE64 not set, skipping trusted params + registration");
            console2.log(
                "**   (use `raiko2 tdx register` after the prover VM is live, or rerun with the"
                " trusted-param env vars)"
            );
        }

        transferOwnership(tdxVerifier);
        verifyDeployment(tdxVerifier);

        console2.log("=====================================");
        console2.log("AzureTdxVerifier deployment complete");
        console2.log("=====================================");
    }

    /// @dev Deploys the AzureTdxVerifier behind an ERC1967 proxy.
    function deployAzureTdxVerifier() internal returns (address proxy) {
        AzureTdxVerifier impl = new AzureTdxVerifier(taikoChainId, automataDcapAttestation);
        console2.log("** Deployed AzureTdxVerifier implementation:", address(impl));

        proxy = address(
            new ERC1967Proxy(
                address(impl), abi.encodeCall(AzureTdxVerifier.init, (vm.addr(privateKey)))
            )
        );
        console2.log("** Deployed AzureTdxVerifier proxy:", proxy);

        writeJson("tdx_verifier", proxy);
        writeJson("tdx_verifier_impl", address(impl));
    }

    /// @dev Sets up trusted params for TDX verification
    function setupTrustedParams(address _tdxVerifier) internal {
        uint256 trustedParamsIndex = vm.envUint("TRUSTED_PARAMS_INDEX");
        bytes16 teeTcbSvn = bytes16(vm.envBytes32("TEE_TCB_SVN"));
        uint24 pcrBitmap = uint24(vm.envUint("PCR_BITMAP"));

        console2.log("** Setting up trusted params at index:", trustedParamsIndex);

        bytes memory mrSeam = Base64.decode(vm.envString("MR_SEAM_BASE64"));
        bytes memory mrTd = Base64.decode(vm.envString("MR_TD_BASE64"));

        console2.log("** mrSeam length:", mrSeam.length);
        console2.log("** mrTd length:", mrTd.length);

        bytes32[] memory pcrs = getPcrsFromEnv();
        console2.log("** PCRs count:", pcrs.length);

        AzureTdxVerifier.TrustedParams memory params = AzureTdxVerifier.TrustedParams({
            teeTcbSvn: teeTcbSvn, pcrBitmap: pcrBitmap, mrSeam: mrSeam, mrTd: mrTd, pcrs: pcrs
        });

        AzureTdxVerifier(_tdxVerifier).setTrustedParams(trustedParamsIndex, params);
        console2.log("** Trusted params set");
    }

    /// @dev Registers an instance using TDX attestation loaded from JSON.
    function registerInstanceWithAttestation(address _tdxVerifier) internal {
        uint256 trustedParamsIndex = vm.envUint("TRUSTED_PARAMS_INDEX");
        string memory attestationFilePath = vm.envString("ATTESTATION_FILE_PATH");
        console2.log("** Registering instance from:", attestationFilePath);

        string memory json = vm.readFile(attestationFilePath);

        AzureTDX.AttestationDocument memory attestationDocument = parseAttestationDocument(json);
        AzureTDX.PCR[] memory pcrs = parsePcrs(json);
        bytes memory nonce = vm.parseJsonBytes(json, ".nonce");

        AzureTDX.VerifyParams memory verifyParams = AzureTDX.VerifyParams({
            attestationDocument: attestationDocument, pcrs: pcrs, nonce: nonce
        });

        AzureTdxVerifier(_tdxVerifier).registerInstance(trustedParamsIndex, verifyParams);

        address instanceAddr = address(bytes20(attestationDocument.userData));
        console2.log("** Instance registered:", instanceAddr);
    }

    function parseAttestationDocument(string memory _json)
        internal
        pure
        returns (AzureTDX.AttestationDocument memory)
    {
        return AzureTDX.AttestationDocument({
            attestation: parseAttestation(_json),
            instanceInfo: parseInstanceInfo(_json),
            userData: vm.parseJsonBytes(_json, ".attestationDocument.userData")
        });
    }

    function parseAttestation(string memory _json)
        internal
        pure
        returns (AzureTDX.Attestation memory)
    {
        return AzureTDX.Attestation({ tpmQuote: parseTPMQuote(_json) });
    }

    function parseTPMQuote(string memory _json) internal pure returns (AzureTDX.TPMQuote memory) {
        return AzureTDX.TPMQuote({
            quote: vm.parseJsonBytes(_json, ".attestationDocument.attestation.tpmQuote.quote"),
            rsaSignature: vm.parseJsonBytes(
                _json, ".attestationDocument.attestation.tpmQuote.rsaSignature"
            ),
            pcrs: parseTpmPcrs(_json)
        });
    }

    function parseInstanceInfo(string memory _json)
        internal
        pure
        returns (AzureTDX.InstanceInfo memory)
    {
        return AzureTDX.InstanceInfo({
            attestationReport: vm.parseJsonBytes(
                _json, ".attestationDocument.instanceInfo.attestationReport"
            ),
            runtimeData: parseRuntimeData(_json)
        });
    }

    function parseRuntimeData(string memory _json)
        internal
        pure
        returns (AzureTDX.RuntimeData memory)
    {
        return AzureTDX.RuntimeData({
            raw: vm.parseJsonBytes(_json, ".attestationDocument.instanceInfo.runtimeData.raw"),
            hclAkPub: parseAkPub(_json)
        });
    }

    function parseAkPub(string memory _json) internal pure returns (AzureTDX.AkPub memory) {
        return AzureTDX.AkPub({
            exponentRaw: uint24(
                vm.parseJsonUint(
                    _json, ".attestationDocument.instanceInfo.runtimeData.hclAkPub.exponentRaw"
                )
            ),
            modulusRaw: vm.parseJsonBytes(
                _json, ".attestationDocument.instanceInfo.runtimeData.hclAkPub.modulusRaw"
            )
        });
    }

    function parseTpmPcrs(string memory _json) internal pure returns (bytes32[24] memory pcrs) {
        for (uint256 i = 0; i < 24; ++i) {
            string memory path = string.concat(
                ".attestationDocument.attestation.tpmQuote.pcrs[", vm.toString(i), "]"
            );
            pcrs[i] = vm.parseJsonBytes32(_json, path);
        }
    }

    function parsePcrs(string memory _json) internal pure returns (AzureTDX.PCR[] memory) {
        uint256 pcrsLength = vm.parseJsonUint(_json, ".pcrsLength");
        AzureTDX.PCR[] memory pcrs = new AzureTDX.PCR[](pcrsLength);

        for (uint256 i = 0; i < pcrsLength; ++i) {
            string memory indexPath = string.concat(".pcrs[", vm.toString(i), "].index");
            string memory digestPath = string.concat(".pcrs[", vm.toString(i), "].digest");

            uint8 index = uint8(vm.parseJsonUint(_json, indexPath));
            bytes32 digest = vm.parseJsonBytes32(_json, digestPath);

            pcrs[i] = AzureTDX.PCR({ index: index, digest: digest });
        }

        return pcrs;
    }

    function transferOwnership(address _tdxVerifier) internal {
        console2.log("** Transferring ownership to:", contractOwner);
        Ownable2StepUpgradeable(_tdxVerifier).transferOwnership(contractOwner);
        console2.log("** Ownership transfer initiated (requires acceptance)");
    }

    function verifyDeployment(address _tdxVerifier) internal view {
        AzureTdxVerifier v = AzureTdxVerifier(_tdxVerifier);

        require(
            v.automataDcapAttestation() == automataDcapAttestation,
            "verify: automataDcapAttestation mismatch"
        );
        require(v.taikoChainId() == taikoChainId, "verify: taikoChainId mismatch");

        address pendingOwner = Ownable2StepUpgradeable(_tdxVerifier).pendingOwner();
        require(pendingOwner == contractOwner, "verify: pending owner mismatch");

        console2.log("** Deployment verified");
    }

    function getPcrsFromEnv() internal view returns (bytes32[] memory) {
        string memory pcrsEnv = vm.envString("PCRS_BASE64");

        string[] memory pcrsBase64 = vm.split(pcrsEnv, ",");
        bytes32[] memory pcrs = new bytes32[](pcrsBase64.length);

        for (uint256 i = 0; i < pcrsBase64.length; ++i) {
            bytes memory decoded = Base64.decode(pcrsBase64[i]);
            require(decoded.length == 32, "PCR must be 32 bytes");
            pcrs[i] = bytes32(decoded);
        }

        return pcrs;
    }

    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/deploy_tdx_verifier.json")
        );
    }
}
