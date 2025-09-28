// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/EnclaveIdStruct.sol";
import "src/layer1/automata-attestation/lib/TCBInfoStruct.sol";
import "src/layer1/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import "src/shared/libs/LibStrings.sol";
import "./common/AttestationLib.sol";
import "test/shared/DeployCapability.sol";

/// @title SetupSGXVerifier
/// @notice Script to setup SGX verifier with attestation configuration and transfer ownership
contract SetupSGXVerifier is Script, DeployCapability {
    // Configuration
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // SGX verifier configuration
    address internal immutable sgxVerifierAddress = vm.envAddress("SGX_VERIFIER_ADDRESS");
    address internal immutable automataProxyAddress = vm.envAddress("AUTOMATA_PROXY_ADDRESS");
    address internal immutable pemCertChainLibAddr = vm.envAddress("PEM_CERT_CHAIN_LIB_ADDRESS");

    // SGX attestation configuration
    bytes32 internal immutable mrEnclave = vm.envOr("MR_ENCLAVE", bytes32(0));
    bytes32 internal immutable mrSigner = vm.envOr("MR_SIGNER", bytes32(0));

    // Ownership transfer
    address internal immutable newOwner = vm.envAddress("NEW_OWNER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(sgxVerifierAddress != address(0), "config: SGX_VERIFIER_ADDRESS");
        require(automataProxyAddress != address(0), "config: AUTOMATA_PROXY_ADDRESS");
        require(pemCertChainLibAddr != address(0), "config: PEM_CERT_CHAIN_LIB_ADDRESS");
        require(newOwner != address(0), "config: NEW_OWNER");

        SgxVerifier sgxVerifier = SgxVerifier(sgxVerifierAddress);
        AutomataDcapV3Attestation automataAttestation =
            AutomataDcapV3Attestation(automataProxyAddress);

        // Verify current ownership
        require(sgxVerifier.owner() == msg.sender, "SetupSGXVerifier: sgx verifier not owner");
        require(automataAttestation.owner() == msg.sender, "SetupSGXVerifier: automata not owner");

        // Setup MR Enclave if provided
        if (mrEnclave != bytes32(0)) {
            automataAttestation.setMrEnclave(mrEnclave, true);
            console2.log("** MR_ENCLAVE set:", uint256(mrEnclave));
        }

        // Setup MR Signer if provided
        if (mrSigner != bytes32(0)) {
            automataAttestation.setMrSigner(mrSigner, true);
            console2.log("** MR_SIGNER set:", uint256(mrSigner));
        }

        // Configure QE Identity if path provided
        string memory qeidPath = vm.envOr("QEID_PATH", string(""));
        if (bytes(qeidPath).length > 0) {
            // Parse input json
            string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), qeidPath));
            (bool success, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
                AttestationLib.parseEnclaveIdentityJson(enclaveIdJson);
            require(success, "SetupSGXVerifier: failed to parse enclave id");

            // Configure QE identity
            automataAttestation.configureQeIdentityJson(parsedEnclaveId);
            console2.log("** QE_IDENTITY_JSON configured");
        }

        // Configure TCB Info if path provided
        string memory tcbInfoPath = vm.envOr("TCB_INFO_PATH", string(""));
        if (bytes(tcbInfoPath).length > 0) {
            // Parse input json
            string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
            (bool success, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
                AttestationLib.parseTcbInfoJson(tcbInfoJson);
            require(success, "SetupSGXVerifier: failed to parse tcb info");

            // Configure TCB info
            string memory fmspc = LibString.lower(parsedTcbInfo.fmspc);
            automataAttestation.configureTcbInfoJson(fmspc, parsedTcbInfo);
            console2.log("** TCB_INFO_JSON configured");
        }

        // Register SGX instance with quote if provided
        bytes memory v3QuoteBytes = vm.envOr("V3_QUOTE_BYTES", bytes(""));
        if (v3QuoteBytes.length > 0) {
            // Parse bytes input
            V3Struct.ParsedV3QuoteStruct memory v3quote =
                AttestationLib.parseV3QuoteBytes(pemCertChainLibAddr, v3QuoteBytes);
            
            // Log the instance id to Json
            vm.writeJson(
                vm.serializeUint(
                    "sgx_instance_ids",
                    "sgx_instance_id",
                    SgxVerifier(sgxVerifierAddress).nextInstanceId()
                ),
                string.concat(vm.projectRoot(), "/deployments/sgx_instances.json")
            );

            // Log the instance id to Json
            uint256 instanceId = sgxVerifier.nextInstanceId();

            // Register instance
            sgxVerifier.registerInstance(v3quote);
            console2.log("** SGX instance registered with ID:", instanceId);
        }

        // Toggle quote validity check
        automataAttestation.toggleLocalReportCheck();
        console2.log("** Quote validity check toggled");

        // Transfer ownership
        sgxVerifier.transferOwnership(newOwner);
        console2.log("** SGXVerifier ownership transferred to:", newOwner);

        automataAttestation.transferOwnership(newOwner);
        console2.log("** AutomataDcapV3Attestation ownership transferred to:", newOwner);

        console2.log("** SGX verifier setup complete **");
    }
}
