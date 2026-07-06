// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/src/Test.sol";
import { DeployShastaContracts } from "script/layer1/core/DeployShastaContracts.s.sol";
import { DeployShastaHoodi } from "script/layer1/core/DeployShastaHoodi.s.sol";

/// @dev Exposes the internal `_loadConfig()` so the test can assert the SGX-proxy wiring without
/// running the full broadcast deploy (`run()` returns nothing and `_deployAllVerifiers` is private).
contract DeployShastaHoodiHarness is DeployShastaHoodi {
    function exposedLoadConfig() external view returns (DeploymentConfig memory) {
        return _loadConfig();
    }
}

contract DeployShastaHoodiWiringTest is Test {
    DeployShastaHoodiHarness internal harness;

    function setUp() public {
        harness = new DeployShastaHoodiHarness();
        // _loadConfig reads these unconditionally (both before and after the change).
        vm.setEnv("ACTIVATOR", vm.toString(address(0xAC71)));
        vm.setEnv("PROVERS", vm.toString(address(0x9401)));
        vm.setEnv("SHASTA_FORK_TIMESTAMP", "1700000000");
    }

    function test_loadConfig_wiresBothSgxProxiesToDcapAttestation() public {
        address entrypoint = address(0xDCA9);
        vm.setEnv("DCAP_ATTESTATION", vm.toString(entrypoint));

        DeployShastaContracts.DeploymentConfig memory c = harness.exposedLoadConfig();

        assertEq(c.sgxGethAutomataProxy, entrypoint, "geth proxy must be the DCAP entrypoint");
        assertEq(c.sgxRethAutomataProxy, entrypoint, "reth proxy must be the DCAP entrypoint");
    }
}
