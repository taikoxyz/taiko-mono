// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Foundry
import "forge-std/src/Script.sol";

// Local imports
import "./common/AttestationLib.sol";

// Layer 1 contracts
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/EnclaveIdStruct.sol";
import "src/layer1/automata-attestation/lib/TCBInfoStruct.sol";
import "src/layer1/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import "src/layer1/verifiers/SgxVerifier.sol";

contract RegisterSGXInstance is Script {
    // Execution configuration
    // ---------------------------------------------------------------------------------------------
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // SGX configuration
    // ---------------------------------------------------------------------------------------------
    address public automataDcapAttestation = vm.envAddress("AUTOMATA_DCAP_ATTESTATION");
    address public sgxRethVerifier = vm.envAddress("SGX_RETH_VERIFIER");
    address public pemCertChainLib = vm.envAddress("PEM_CERT_CHAIN_LIB");
    bytes32 public mrEnclave = vm.envBytes32("MR_ENCLAVE");
    bytes32 public mrSigner = vm.envBytes32("MR_SIGNER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        AutomataDcapV3Attestation automataAttestation = AutomataDcapV3Attestation(automataDcapAttestation);

        // Set MR Enclave if provided
        if (mrEnclave != bytes32(0)) {
            automataAttestation.setMrEnclave(mrEnclave, true);
            console2.log("** MR_ENCLAVE set:", uint256(mrEnclave));
        }

        // Set MR Signer if provided
        if (mrSigner != bytes32(0)) {
            automataAttestation.setMrSigner(mrSigner, true);
            console2.log("** MR_SIGNER set:", uint256(mrSigner));
        }

        // Configure QE Identity if path provided
        string memory qeidPath = vm.envString("QEID_PATH");
        if (bytes(qeidPath).length > 0) {
            string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), qeidPath));
            (bool success, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
                AttestationLib.parseEnclaveIdentityJson(enclaveIdJson);
            require(success, "RegisterSGXInstance: failed to parse enclave id");
            automataAttestation.configureQeIdentityJson(parsedEnclaveId);
            console2.log("** QE_IDENTITY_JSON configured");
        }

        // Configure TCB Info if path provided
        string memory tcbInfoPath = vm.envString("TCB_INFO_PATH");
        if (bytes(tcbInfoPath).length > 0) {
            string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
            (bool success, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
                AttestationLib.parseTcbInfoJson(tcbInfoJson);
            require(success, "RegisterSGXInstance: failed to parse tcb info");
            string memory fmspc = LibString.lower(parsedTcbInfo.fmspc);
            automataAttestation.configureTcbInfoJson(fmspc, parsedTcbInfo);
            console2.log("** TCB_INFO_JSON configured");
        }

        // Register SGX instance with quote if provided
        bytes memory v3QuoteBytes = vm.envBytes("V3_QUOTE_BYTES");
        if (v3QuoteBytes.length > 0) {
            V3Struct.ParsedV3QuoteStruct memory v3quote =
                AttestationLib.parseV3QuoteBytes(pemCertChainLib, v3QuoteBytes);
            SgxVerifier(sgxRethVerifier).registerInstance(v3quote);
            console2.log("** SGX instance registered with quote");
        }

        // Toggle quote validity check
        automataAttestation.toggleLocalReportCheck();
        console2.log("** Quote validity check toggled");
    }
}
