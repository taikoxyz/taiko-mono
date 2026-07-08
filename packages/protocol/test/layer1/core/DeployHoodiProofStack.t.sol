// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/src/Test.sol";
import { DeployHoodiProofStack } from "script/layer1/core/DeployHoodiProofStack.s.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @dev Exposes the internal `_deployProofStack` with explicit params and `_config()` so tests
/// exercise the deploy logic WITHOUT process-global `vm.setEnv`: forge runs tests concurrently and
/// env vars are shared, unreverted process state, so routing per-test variation through env would
/// race. One test still drives the real `run()` to cover the env plumbing — it is the sole
/// env-touching test in this suite.
contract DeployHoodiProofStackHarness is DeployHoodiProofStack {
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

contract DeployHoodiProofStackTest is Test {
    DeployHoodiProofStackHarness internal harness;

    address internal constant HOODI_R0 = 0x32Db7dc407AC886807277636a1633A1381748DD8;
    address internal constant HOODI_SP1 = 0x2a5A70409Ee9F057503a50E0F4614A6d8CcBb462;

    function setUp() public {
        harness = new DeployHoodiProofStackHarness();
    }

    function test_config_hasHoodiDefaults() public view {
        DeployHoodiProofStack.Config memory c = harness.exposedConfig();
        assertEq(c.chainId, LibNetwork.TAIKO_HOODI, "chainId");
        assertEq(c.owner, LibL1HoodiAddrs.HOODI_CONTRACT_OWNER, "owner");
        assertEq(c.validityDelay, 1 hours, "validity delay");
        assertEq(c.r0Groth16, HOODI_R0, "r0Groth16 default");
        assertEq(c.sp1Plonk, HOODI_SP1, "sp1Plonk default");
    }

    function test_deploysProofStackWiredToEntrypoint() public {
        address entrypoint = address(0xDCA9);
        address registrar = address(0xA11CE);
        DeployHoodiProofStack.ProofStack memory s =
            harness.deployWith(entrypoint, registrar, HOODI_R0, HOODI_SP1);

        // Both SGX verifiers point at the shared entrypoint.
        assertEq(
            SecureSgxVerifier(s.sgxReth).automataDcapAttestation(), entrypoint, "reth -> entrypoint"
        );
        assertEq(
            SecureSgxVerifier(s.sgxGeth).automataDcapAttestation(), entrypoint, "geth -> entrypoint"
        );

        // MainnetVerifier aggregates exactly the four deployed tiers.
        MainnetVerifier mv = MainnetVerifier(s.mainnetVerifier);
        assertEq(mv.sgxGethVerifier(), s.sgxGeth, "mv.sgxGeth");
        assertEq(mv.sgxRethVerifier(), s.sgxReth, "mv.sgxReth");
        assertEq(mv.risc0RethVerifier(), s.risc0, "mv.risc0");
        assertEq(mv.sp1RethVerifier(), s.sp1, "mv.sp1");

        // Hoodi constants + explicit registrar + referenced (not fresh) R0/SP1.
        assertEq(SecureSgxVerifier(s.sgxReth).taikoChainId(), LibNetwork.TAIKO_HOODI, "chainId");
        assertEq(
            SecureSgxVerifier(s.sgxReth).owner(), LibL1HoodiAddrs.HOODI_CONTRACT_OWNER, "owner"
        );
        assertEq(SecureSgxVerifier(s.sgxReth).instanceValidityDelay(), 1 hours, "validity delay");
        assertEq(SecureSgxVerifier(s.sgxReth).registrar(), registrar, "reth registrar");
        assertEq(SecureSgxVerifier(s.sgxGeth).registrar(), registrar, "geth registrar");
        assertEq(Risc0Verifier(s.risc0).riscoGroth16Verifier(), HOODI_R0, "R0 wrapped");
        assertEq(SP1Verifier(s.sp1).sp1RemoteVerifier(), HOODI_SP1, "SP1 wrapped");
    }

    /// @dev The real `run()` reads every knob from env. This is the ONLY test in this file that
    /// touches process env (all others use the harness), and `SGX_REGISTRAR`/`R0_GROTH16`/`SP1_PLONK`
    /// are set nowhere else in the suite, so it cannot race with parallel siblings.
    function test_run_readsEnvConfig() public {
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(0xA11CE)));
        vm.setEnv("DCAP_ATTESTATION", vm.toString(address(0xDCA9)));
        vm.setEnv("SGX_REGISTRAR", vm.toString(address(0xBEEF)));
        vm.setEnv("R0_GROTH16", vm.toString(address(0xF00D)));
        vm.setEnv("SP1_PLONK", vm.toString(address(0xD00D)));

        DeployHoodiProofStack.ProofStack memory s = harness.run();

        assertEq(SecureSgxVerifier(s.sgxReth).registrar(), address(0xBEEF), "registrar from env");
        assertEq(
            SecureSgxVerifier(s.sgxGeth).registrar(), address(0xBEEF), "geth registrar from env"
        );
        assertEq(Risc0Verifier(s.risc0).riscoGroth16Verifier(), address(0xF00D), "R0 from env");
        assertEq(SP1Verifier(s.sp1).sp1RemoteVerifier(), address(0xD00D), "SP1 from env");
    }
}
