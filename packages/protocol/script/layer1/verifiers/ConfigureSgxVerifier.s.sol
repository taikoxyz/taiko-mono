// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/console2.sol";
import "script/BaseScript.sol";
import { BaseSgxVerifier } from "src/layer1/verifiers/BaseSgxVerifier.sol";

/// @title ConfigureSgxVerifier
/// @notice Minimal script to configure the SGX verifier: the trusted MRENCLAVE/MRSIGNER allowlist,
/// instance registration, and the local-report-check toggle.
/// @dev TCB info and QE identity are no longer configured on-chain by Taiko; they are sourced from
/// Automata's on-chain PCCS through the DCAP attestation entrypoint. The MRENCLAVE/MRSIGNER
/// allowlist now lives on the SGX verifier (previously on `AutomataDcapV3Attestation`). The config
/// functions called here live on the abstract `BaseSgxVerifier`, so any concrete subclass
/// (Mainnet/Testnet) can be configured through this base type.
/// @custom:security-contact security@taiko.xyz
contract ConfigureSgxVerifier is BaseScript {
    function run() external broadcast {
        address sgxVerifierAddr = vm.envAddress("SGX_VERIFIER_ADDRESS");
        require(sgxVerifierAddr != address(0), "SGX_VERIFIER_ADDRESS not set");
        BaseSgxVerifier sgxVerifier = BaseSgxVerifier(sgxVerifierAddr);

        console2.log("=== Configuring SGX Verifier ===");
        console2.log("SGX Verifier:", address(sgxVerifier));

        if (vm.envOr("SET_MRENCLAVE", false)) {
            bytes32 mrEnclave = vm.envBytes32("MRENCLAVE");
            bool enable = vm.envOr("MRENCLAVE_ENABLE", true);
            console2.log("Setting MRENCLAVE (enable):", enable);
            sgxVerifier.setMrEnclave(mrEnclave, enable);
        }

        if (vm.envOr("SET_MRSIGNER", false)) {
            bytes32 mrSigner = vm.envBytes32("MRSIGNER");
            bool enable = vm.envOr("MRSIGNER_ENABLE", true);
            console2.log("Setting MRSIGNER (enable):", enable);
            sgxVerifier.setMrSigner(mrSigner, enable);
        }

        if (vm.envOr("REGISTER_INSTANCE", false)) {
            bytes memory rawQuote = vm.envBytes("QUOTE_BYTES");
            console2.log("Registering SGX instance from a raw Intel DCAP quote");
            uint256 instanceId = sgxVerifier.registerInstance(rawQuote);
            console2.log("  Registered instanceId:", instanceId);
        }

        if (vm.envOr("TOGGLE_CHECK", false)) {
            console2.log("Toggling MRENCLAVE/MRSIGNER allowlist enforcement");
            sgxVerifier.toggleLocalReportCheck();
        }

        console2.log("=== Configuration Complete ===");
    }
}
