// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/src/Test.sol";
import { DeployHoodiProofStack } from "script/layer1/core/DeployHoodiProofStack.s.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

contract DeployHoodiProofStackTest is Test {
    DeployHoodiProofStack internal deployScript;

    function setUp() public {
        deployScript = new DeployHoodiProofStack();
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(0xA11CE)));
    }

    function test_run_deploysProofStackWiredToEntrypoint() public {
        address entrypoint = address(0xDCA9);
        vm.setEnv("DCAP_ATTESTATION", vm.toString(entrypoint));

        DeployHoodiProofStack.ProofStack memory s = deployScript.run();

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

        // Chain id + owner baked in from Hoodi constants.
        assertEq(SecureSgxVerifier(s.sgxReth).taikoChainId(), LibNetwork.TAIKO_HOODI, "chainId");
        assertEq(
            SecureSgxVerifier(s.sgxReth).owner(), LibL1HoodiAddrs.HOODI_CONTRACT_OWNER, "owner"
        );
    }
}
