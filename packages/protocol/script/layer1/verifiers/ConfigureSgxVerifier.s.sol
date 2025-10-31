// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/console2.sol";
import "script/BaseScript.sol";
import "solady/src/utils/LibString.sol";
import "test/layer1/automata-attestation/AttestationBase.sol";

/// @title ConfigureSgxVerifier
/// @notice Minimal script to configure DCAP SGX verifier with essential information
/// @dev Extends AttestationBase to reuse JSON parsing utilities
contract ConfigureSgxVerifier is BaseScript, AttestationBase {
    using LibString for string;

    // Required addresses
    address public attestationAddr;
    address public sgxVerifierAddr;

    function run() external broadcast {
        // Load addresses from environment
        attestationAddr = vm.envAddress("ATTESTATION_ADDRESS");
        sgxVerifierAddr = vm.envAddress("SGX_VERIFIER_ADDRESS");

        console2.log("=== Configuring SGX Verifier ===");
        console2.log("Attestation:", attestationAddr);
        console2.log("SGX Verifier:", sgxVerifierAddr);

        // Configure based on environment flags
        if (vm.envOr("SET_MRENCLAVE", false)) {
            _configureMrEnclave();
        }

        if (vm.envOr("SET_MRSIGNER", false)) {
            _configureMrSigner();
        }

        if (vm.envOr("CONFIG_QEID", false)) {
            _configureQeId();
        }

        if (vm.envOr("CONFIG_TCB", false)) {
            _configureTcb();
        }

        if (vm.envOr("REGISTER_INSTANCE", false)) {
            _registerInstance();
        }

        if (vm.envOr("TOGGLE_CHECK", false)) {
            _toggleCheck();
        }

        console2.log("=== Configuration Complete ===");
    }

    function _configureMrEnclave() internal {
        bytes32 mrEnclaveValue = vm.envBytes32("MRENCLAVE");
        bool enable = vm.envOr("MRENCLAVE_ENABLE", true);

        console2.log("Setting MRENCLAVE:", uint256(mrEnclaveValue));
        console2.log("  Enable:", enable);

        setMrEnclave(attestationAddr, mrEnclaveValue, enable);
        console2.log("  Done");
    }

    function _configureMrSigner() internal {
        bytes32 mrSignerValue = vm.envBytes32("MRSIGNER");
        bool enable = vm.envOr("MRSIGNER_ENABLE", true);

        console2.log("Setting MRSIGNER:", uint256(mrSignerValue));
        console2.log("  Enable:", enable);

        setMrSigner(attestationAddr, mrSignerValue, enable);
        console2.log("  Done");
    }

    function _configureQeId() internal {
        string memory qeidPath = vm.envString("QEID_PATH");
        console2.log("Configuring QE Identity from:", qeidPath);

        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), qeidPath));
        configureQeIdentityJson(attestationAddr, enclaveIdJson);

        console2.log("  Done");
    }

    function _configureTcb() internal {
        string memory tcbPathsStr = vm.envString("TCB_PATHS");
        string[] memory tcbPaths = _splitByComma(tcbPathsStr);

        console2.log("Configuring", tcbPaths.length, "TCB files");

        for (uint256 i = 0; i < tcbPaths.length; i++) {
            string memory tcbPath = tcbPaths[i];
            console2.log("  [", i + 1, "]", tcbPath);

            string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbPath));
            configureTcbInfoJson(attestationAddr, tcbInfoJson);
        }

        console2.log("  Done");
    }

    function _registerInstance() internal {
        bytes memory quoteBytes = vm.envBytes("QUOTE_BYTES");
        address pemCertLib = vm.envAddress("PEM_CERTCHAIN_ADDRESS");

        console2.log("Registering SGX instance");
        registerSgxInstanceWithQuoteBytes(pemCertLib, sgxVerifierAddr, quoteBytes);
        console2.log("  Done");
    }

    function _toggleCheck() internal {
        console2.log("Toggling local report check");
        toggleCheckQuoteValidity(attestationAddr);
        console2.log("  Done");
    }

    /// @dev Split comma-separated string into array
    function _splitByComma(string memory str) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) return new string[](0);

        // Count commas
        uint256 count = 1;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == ",") count++;
        }

        string[] memory result = new string[](count);
        uint256 idx = 0;
        uint256 start = 0;

        for (uint256 i = 0; i <= strBytes.length; i++) {
            if (i == strBytes.length || strBytes[i] == ",") {
                // Extract substring
                bytes memory part = new bytes(i - start);
                for (uint256 j = start; j < i; j++) {
                    part[j - start] = strBytes[j];
                }
                result[idx++] = string(part);
                start = i + 1;
            }
        }

        return result;
    }
}
