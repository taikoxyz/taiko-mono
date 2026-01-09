// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AzureTDX } from "azure-tdx-verifier/AzureTDX.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import "solady/src/utils/Base64.sol";
import { AzureTDXVerifier } from "src/layer1/surge/ccip/AzureTDXVerifier.sol";
import { CCIPStateStore } from "src/layer1/surge/ccip/CCIPStateStore.sol";

/// @title DeployAndSetupSurgeCCIP
/// @notice Script to deploy and setup CCIPStateStore contract
contract DeployAndSetupSurgeCCIP is Script {
    // Deployer configuration
    // ---------------------------------------------------------------
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Owner configuration
    // ---------------------------------------------------------------
    address internal immutable contractOwner = vm.envAddress("CONTRACT_OWNER");

    // Automata DCAP Attestation contract address
    // ---------------------------------------------------------------
    address internal immutable automataDcapAttestation = vm.envAddress("AUTOMATA_DCAP_ATTESTATION");

    // Trusted params configuration
    // ---------------------------------------------------------------
    uint256 internal immutable trustedParamsIndex = vm.envUint("TRUSTED_PARAMS_INDEX");
    bytes16 internal immutable teeTcbSvn = bytes16(vm.envBytes32("TEE_TCB_SVN"));
    uint24 internal immutable pcrBitmap = uint24(vm.envUint("PCR_BITMAP"));

    modifier broadcast() {
        require(privateKey != 0, "config: invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(contractOwner != address(0), "config: CONTRACT_OWNER");
        require(automataDcapAttestation != address(0), "config: AUTOMATA_DCAP_ATTESTATION");

        console2.log("=====================================");
        console2.log("Deploying Surge CCIP State Store");
        console2.log("=====================================");
        console2.log("** Contract owner: ", contractOwner);
        console2.log("** Automata DCAP Attestation: ", automataDcapAttestation);

        // Deploy CCIPStateStore
        // ---------------------------------------------------------------
        address ccipStateStore = deployCCIPStateStore();

        // Setup trusted params
        // ---------------------------------------------------------------
        setupTrustedParams(ccipStateStore);

        // Register instance via attestation
        // ---------------------------------------------------------------
        registerInstanceWithAttestation(ccipStateStore);

        // Transfer ownership to external owner
        // ---------------------------------------------------------------
        transferOwnership(ccipStateStore);

        // Verify deployment
        // ---------------------------------------------------------------
        verifyDeployment(ccipStateStore);

        console2.log("=====================================");
        console2.log("Surge CCIP Deployment Complete");
        console2.log("=====================================");
    }

    /// @dev Deploys the CCIPStateStore contract with proxy pattern
    function deployCCIPStateStore() internal returns (address proxy) {
        // Deploy implementation
        CCIPStateStore impl = new CCIPStateStore(automataDcapAttestation);
        console2.log("** Deployed CCIPStateStore implementation:", address(impl));

        // Deploy proxy with deployer as initial owner
        proxy = address(
            new ERC1967Proxy(address(impl), abi.encodeCall(AzureTDXVerifier.init, (msg.sender)))
        );
        console2.log("** Deployed CCIPStateStore proxy:", proxy);

        writeJson("ccip_state_store", proxy);
        writeJson("ccip_state_store_impl", address(impl));
    }

    /// @dev Sets up trusted params for TDX verification
    function setupTrustedParams(address _ccipStateStore) internal {
        console2.log("** Setting up trusted params at index:", trustedParamsIndex);

        // Get mrSeam and mrTd from environment (base64 encoded)
        string memory mrSeamBase64 = vm.envString("MR_SEAM_BASE64");
        string memory mrTdBase64 = vm.envString("MR_TD_BASE64");

        bytes memory mrSeam = Base64.decode(mrSeamBase64);
        bytes memory mrTd = Base64.decode(mrTdBase64);

        console2.log("** mrSeam length:", mrSeam.length);
        console2.log("** mrTd length:", mrTd.length);

        // Get PCRs from environment (comma-separated base64 values)
        bytes32[] memory pcrs = getPcrsFromEnv();
        console2.log("** PCRs count:", pcrs.length);

        AzureTDXVerifier.TrustedParams memory params = AzureTDXVerifier.TrustedParams({
            teeTcbSvn: teeTcbSvn, pcrBitmap: pcrBitmap, mrSeam: mrSeam, mrTd: mrTd, pcrs: pcrs
        });

        CCIPStateStore(_ccipStateStore).setTrustedParams(trustedParamsIndex, params);
        console2.log("** Trusted params set successfully");
    }

    /// @dev Registers an instance using TDX attestation
    function registerInstanceWithAttestation(address _ccipStateStore) internal {
        console2.log("** Registering instance via attestation...");

        // Load attestation data from JSON file
        string memory attestationFilePath = vm.envString("ATTESTATION_FILE_PATH");
        console2.log("** Loading attestation from:", attestationFilePath);

        string memory json = vm.readFile(attestationFilePath);

        // Parse attestation document components
        AzureTDX.AttestationDocument memory attestationDocument = parseAttestationDocument(json);

        // Parse PCRs array
        AzureTDX.PCR[] memory pcrs = parsePcrs(json);

        // Parse nonce
        bytes memory nonce = vm.parseJsonBytes(json, ".nonce");

        // Construct VerifyParams
        AzureTDX.VerifyParams memory verifyParams = AzureTDX.VerifyParams({
            attestationDocument: attestationDocument, pcrs: pcrs, nonce: nonce
        });

        // Register the instance using the same trusted params index
        CCIPStateStore(_ccipStateStore).registerInstance(trustedParamsIndex, verifyParams);

        // Get the registered instance address from userData
        address instanceAddr = address(bytes20(attestationDocument.userData));
        console2.log("** Instance registered successfully:", instanceAddr);
    }

    /// @dev Parses AttestationDocument from JSON
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

    /// @dev Parses Attestation from JSON
    function parseAttestation(string memory _json)
        internal
        pure
        returns (AzureTDX.Attestation memory)
    {
        return AzureTDX.Attestation({ tpmQuote: parseTPMQuote(_json) });
    }

    /// @dev Parses TPMQuote from JSON
    function parseTPMQuote(string memory _json) internal pure returns (AzureTDX.TPMQuote memory) {
        return AzureTDX.TPMQuote({
            quote: vm.parseJsonBytes(_json, ".attestationDocument.attestation.tpmQuote.quote"),
            rsaSignature: vm.parseJsonBytes(
                _json, ".attestationDocument.attestation.tpmQuote.rsaSignature"
            ),
            pcrs: parseTpmPcrs(_json)
        });
    }

    /// @dev Parses InstanceInfo from JSON
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

    /// @dev Parses RuntimeData from JSON
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

    /// @dev Parses AkPub from JSON
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

    /// @dev Parses TPM PCRs (fixed array of 24 bytes32) from JSON
    function parseTpmPcrs(string memory _json) internal pure returns (bytes32[24] memory pcrs) {
        for (uint256 i = 0; i < 24; ++i) {
            string memory path = string.concat(
                ".attestationDocument.attestation.tpmQuote.pcrs[", vm.toString(i), "]"
            );
            pcrs[i] = vm.parseJsonBytes32(_json, path);
        }
    }

    /// @dev Parses PCRs array from JSON
    function parsePcrs(string memory _json) internal pure returns (AzureTDX.PCR[] memory) {
        // pcrsLength must be provided in the JSON
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

    /// @dev Transfers ownership to the external owner
    function transferOwnership(address _ccipStateStore) internal {
        console2.log("** Transferring ownership to:", contractOwner);

        Ownable2StepUpgradeable(_ccipStateStore).transferOwnership(contractOwner);
        console2.log("** Ownership transfer initiated (requires acceptance)");
    }

    /// @dev Verifies the deployment
    function verifyDeployment(address _ccipStateStore) internal view {
        CCIPStateStore store = CCIPStateStore(_ccipStateStore);

        // Verify Automata DCAP attestation address
        require(
            store.automataDcapAttestation() == automataDcapAttestation,
            "verify: automataDcapAttestation mismatch"
        );

        // Verify pending owner
        address pendingOwner = Ownable2StepUpgradeable(_ccipStateStore).pendingOwner();
        require(pendingOwner == contractOwner, "verify: pending owner mismatch");

        console2.log("** Deployment verified successfully");
    }

    /// @dev Parses PCRs from environment variable
    function getPcrsFromEnv() internal view returns (bytes32[] memory) {
        string memory pcrsEnv = vm.envString("PCRS_BASE64");

        // Split by comma and decode each base64 value
        string[] memory pcrsBase64 = vm.split(pcrsEnv, ",");
        bytes32[] memory pcrs = new bytes32[](pcrsBase64.length);

        for (uint256 i = 0; i < pcrsBase64.length; ++i) {
            bytes memory decoded = Base64.decode(pcrsBase64[i]);
            require(decoded.length == 32, "PCR must be 32 bytes");
            pcrs[i] = bytes32(decoded);
        }

        return pcrs;
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/deploy_ccip.json")
        );
    }
}
