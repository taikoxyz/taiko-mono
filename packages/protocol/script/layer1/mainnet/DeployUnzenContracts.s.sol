// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { AnyTwoVerifier } from "src/layer1/verifiers/compose/AnyTwoVerifier.sol";

/// @title DeployUnzenContracts
/// @notice Deploys mainnet implementation contracts for the Unzen hardfork bundle.
/// @dev This script deploys new implementations only. It does not upgrade proxies or call
/// initializers; the DAO proposal performs `upgradeToAndCall(init3)` on the Inbox proxy after
/// reviewing the logged implementation addresses.
///
/// The bundle:
/// 1. `AnyTwoVerifier` replaces `MainnetVerifier` as the proof verifier. It requires two
///    sub-proofs where at least one is a ZK proof (SGX+RISC0, SGX+SP1, or RISC0+SP1), removing
///    the SGX-geth + SGX-reth (zero ZK) combination.
/// 2. A new `MainnetInbox` implementation with forced inclusions re-enabled, wired to the new
///    verifier. `init3` voids the stale pre-incident forced inclusion queue entries whose blobs
///    have expired from the blob retention window.
/// @custom:security-contact security@taiko.xyz
contract DeployUnzenContracts is Script {
    struct Deployment {
        address anyTwoVerifier;
        address mainnetInboxImpl;
    }

    /// @notice Deploys the implementation contracts and logs their addresses.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployImplementations();
        vm.stopBroadcast();

        _logDeployment(deployment);
    }

    function _deployImplementations() private returns (Deployment memory deployment_) {
        deployment_.anyTwoVerifier = address(
            new AnyTwoVerifier(
                LibL1Addrs.SGXRETH_VERIFIER,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                LibL1Addrs.SP1_RETH_VERIFIER
            )
        );

        deployment_.mainnetInboxImpl = address(
            new MainnetInbox(
                deployment_.anyTwoVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                LibL1Addrs.PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );
    }

    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("ANY_TWO_VERIFIER:", _deployment.anyTwoVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("SGXRETH_VERIFIER (reused):", LibL1Addrs.SGXRETH_VERIFIER);
        console2.log("RISC0_RETH_VERIFIER (reused):", LibL1Addrs.RISC0_RETH_VERIFIER);
        console2.log("SP1_RETH_VERIFIER (reused):", LibL1Addrs.SP1_RETH_VERIFIER);
    }
}
