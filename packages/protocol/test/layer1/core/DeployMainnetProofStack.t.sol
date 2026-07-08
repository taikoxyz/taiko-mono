// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/src/Test.sol";
import { DeployMainnetProofStack } from "script/layer1/core/DeployMainnetProofStack.s.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @dev Exposes `_deployProofStack` (explicit params) and `_config()` so tests avoid process-global
/// `vm.setEnv` (forge runs tests concurrently; env is shared, unreverted state). The base `run()`
/// env plumbing is covered by DeployHoodiProofStackTest; here we assert the mainnet config + the
/// fresh-deploy default.
contract DeployMainnetProofStackHarness is DeployMainnetProofStack {
    function deployWith(
        address dcap,
        address registrar,
        address r0Groth16,
        address sp1Plonk
    )
        external
        returns (ProofStack memory)
    {
        Config memory c = _config();
        c.r0Groth16 = r0Groth16;
        c.sp1Plonk = sp1Plonk;
        return _deployProofStack(c, dcap, registrar);
    }

    function exposedConfig() external pure returns (Config memory) {
        return _config();
    }
}

contract DeployMainnetProofStackTest is Test {
    DeployMainnetProofStackHarness internal harness;

    function setUp() public {
        harness = new DeployMainnetProofStackHarness();
    }

    function test_config_hasMainnetDefaults() public view {
        DeployMainnetProofStack.Config memory c = harness.exposedConfig();
        assertEq(c.chainId, LibNetwork.TAIKO_MAINNET, "chainId");
        assertEq(c.owner, LibL1Addrs.DAO_CONTROLLER, "owner");
        assertEq(c.validityDelay, 24 hours, "validity delay");
        // Mainnet defaults to fresh-deploying the underlying verifiers.
        assertEq(c.r0Groth16, address(0), "r0Groth16 defaults to fresh");
        assertEq(c.sp1Plonk, address(0), "sp1Plonk defaults to fresh");
    }

    function test_deploysFreshR0AndSp1ByDefault() public {
        address entrypoint = address(0xDCA9);
        DeployMainnetProofStack.ProofStack memory s =
            harness.deployWith(entrypoint, address(0xA11CE), address(0), address(0));

        // Both SGX verifiers point at the shared entrypoint; aggregation intact.
        assertEq(
            SecureSgxVerifier(s.sgxReth).automataDcapAttestation(), entrypoint, "reth -> entrypoint"
        );
        assertEq(
            SecureSgxVerifier(s.sgxGeth).automataDcapAttestation(), entrypoint, "geth -> entrypoint"
        );
        MainnetVerifier mv = MainnetVerifier(s.mainnetVerifier);
        assertEq(mv.risc0RethVerifier(), s.risc0, "mv.risc0");
        assertEq(mv.sp1RethVerifier(), s.sp1, "mv.sp1");

        // Fresh underlying R0 Groth16 + SP1 Plonk verifiers were actually deployed (have code).
        assertGt(Risc0Verifier(s.risc0).riscoGroth16Verifier().code.length, 0, "fresh R0 deployed");
        assertGt(SP1Verifier(s.sp1).sp1RemoteVerifier().code.length, 0, "fresh SP1 deployed");

        // Mainnet constants.
        assertEq(SecureSgxVerifier(s.sgxReth).taikoChainId(), LibNetwork.TAIKO_MAINNET, "chainId");
        assertEq(SecureSgxVerifier(s.sgxReth).owner(), LibL1Addrs.DAO_CONTROLLER, "owner");
        assertEq(SecureSgxVerifier(s.sgxReth).instanceValidityDelay(), 24 hours, "validity delay");
    }

    function test_referencesR0AndSp1WhenProvided() public {
        address r0 = address(0xF00D);
        address sp1 = address(0xD00D);
        DeployMainnetProofStack.ProofStack memory s =
            harness.deployWith(address(0xDCA9), address(0xA11CE), r0, sp1);

        // Provided addresses are wrapped verbatim — no fresh deploy.
        assertEq(Risc0Verifier(s.risc0).riscoGroth16Verifier(), r0, "R0 referenced");
        assertEq(SP1Verifier(s.sp1).sp1RemoteVerifier(), sp1, "SP1 referenced");
    }
}
