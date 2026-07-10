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
/// env plumbing is covered by DeployHoodiProofStackTest; here we assert the mainnet config + that
/// the live R0/SP1 verifiers are referenced rather than redeployed.
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

    address internal constant MAINNET_R0 = 0x8EaB2D97Dfce405A1692a21b3ff3A172d593D319;
    address internal constant MAINNET_SP1 = 0x3B6041173B80E77f038f3F2C0f9744f04837185e;

    function setUp() public {
        harness = new DeployMainnetProofStackHarness();
    }

    function test_config_hasMainnetDefaults() public view {
        DeployMainnetProofStack.Config memory c = harness.exposedConfig();
        assertEq(c.chainId, LibNetwork.TAIKO_MAINNET, "chainId");
        assertEq(c.owner, LibL1Addrs.DAO_CONTROLLER, "owner");
        assertEq(c.validityDelay, 24 hours, "validity delay");
        assertEq(c.r0Groth16, MAINNET_R0, "r0Groth16 default");
        assertEq(c.sp1Plonk, MAINNET_SP1, "sp1Plonk default");
    }

    function test_referencesLiveR0AndSp1ByDefault() public {
        address entrypoint = address(0xDCA9);
        // Drive the deploy off the config defaults, so this covers default -> deployed wiring.
        DeployMainnetProofStack.Config memory c = harness.exposedConfig();
        DeployMainnetProofStack.ProofStack memory s =
            harness.deployWith(entrypoint, address(0xA11CE), c.r0Groth16, c.sp1Plonk);

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

        // The live mainnet R0 Groth16 + SP1 Plonk verifiers are wrapped, not redeployed.
        assertEq(Risc0Verifier(s.risc0).riscoGroth16Verifier(), MAINNET_R0, "R0 wrapped");
        assertEq(SP1Verifier(s.sp1).sp1RemoteVerifier(), MAINNET_SP1, "SP1 wrapped");

        // Mainnet constants.
        assertEq(SecureSgxVerifier(s.sgxReth).taikoChainId(), LibNetwork.TAIKO_MAINNET, "chainId");
        assertEq(SecureSgxVerifier(s.sgxReth).owner(), LibL1Addrs.DAO_CONTROLLER, "owner");
        assertEq(SecureSgxVerifier(s.sgxReth).instanceValidityDelay(), 24 hours, "validity delay");
    }

    function test_deploysFreshR0AndSp1WhenZero() public {
        DeployMainnetProofStack.ProofStack memory s =
            harness.deployWith(address(0xDCA9), address(0xA11CE), address(0), address(0));

        // A zero override means deploy fresh: the wrapped verifiers exist and are not the live ones.
        address r0 = Risc0Verifier(s.risc0).riscoGroth16Verifier();
        address sp1 = SP1Verifier(s.sp1).sp1RemoteVerifier();
        assertGt(r0.code.length, 0, "fresh R0 deployed");
        assertGt(sp1.code.length, 0, "fresh SP1 deployed");
        assertTrue(r0 != MAINNET_R0, "R0 not the live one");
        assertTrue(sp1 != MAINNET_SP1, "SP1 not the live one");
    }
}
