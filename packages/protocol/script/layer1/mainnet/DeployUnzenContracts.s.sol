// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";

/// @title DeployUnzenContracts
/// @notice Deploys the mainnet implementation contracts for the Unzen hardfork bundle.
/// @dev This script deploys new contracts only. It does not upgrade proxies or call initializers.
///
/// The SGX legs are the verifiers Proposal0017 already deployed
/// (`LibL1Addrs.SGXGETH_VERIFIER`, `LibL1Addrs.SGXRETH_VERIFIER`), reused unchanged: both are
/// already owned by the DAO controller and each carries a registered raiko instance, so SGX
/// proving continues across the fork with no registration step and no ownership handover.
///
/// Unzen therefore deploys just two contracts:
///
/// 1. `ZkRequiredVerifier` replaces `MainnetVerifier`. It takes the same four sub-verifiers the
///    live `MainnetVerifier` already wires, and narrows the accepted combinations to those
///    containing at least one ZK proof ((SGX_GETH|SGX_RETH)+RISC0, (SGX_GETH|SGX_RETH)+SP1, or
///    RISC0+SP1). The SGX_GETH + SGX_RETH pair — the combination that finalized the June 2026
///    forged proofs — no longer satisfies it.
/// 2. A new `MainnetInbox` implementation with forced inclusions re-enabled, wired to that
///    verifier. `Inbox` holds its proof verifier as an immutable, which is why swapping the
///    verifier requires a new implementation rather than a setter.
/// @custom:security-contact security@taiko.xyz
contract DeployUnzenContracts is Script {
    struct Deployment {
        address zkRequiredVerifier;
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

    /// @dev Deploys `ZkRequiredVerifier` then the `MainnetInbox` implementation that bakes it in.
    /// @return deployment_ The two newly deployed addresses.
    function _deployImplementations() private returns (Deployment memory deployment_) {
        // Same four sub-verifiers as the live MainnetVerifier; only the accepted combinations
        // change. The two SGX verifiers are the Proposal0017 deployments, reused as-is.
        deployment_.zkRequiredVerifier = address(
            new ZkRequiredVerifier(
                LibL1Addrs.SGXGETH_VERIFIER,
                LibL1Addrs.SGXRETH_VERIFIER,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                LibL1Addrs.SP1_RETH_VERIFIER
            )
        );

        deployment_.mainnetInboxImpl = address(
            new MainnetInbox(
                deployment_.zkRequiredVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                LibL1Addrs.PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );
    }

    /// @dev Logs the two constants Proposal0019 needs, plus the reused sub-verifiers so the
    /// proposal author can cross-check them against the deployed verifier's immutables.
    /// @param _deployment The deployed addresses.
    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("ZK_REQUIRED_VERIFIER:", _deployment.zkRequiredVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("SGXGETH_VERIFIER (reused):", LibL1Addrs.SGXGETH_VERIFIER);
        console2.log("SGXRETH_VERIFIER (reused):", LibL1Addrs.SGXRETH_VERIFIER);
        console2.log("RISC0_RETH_VERIFIER (reused):", LibL1Addrs.RISC0_RETH_VERIFIER);
        console2.log("SP1_RETH_VERIFIER (reused):", LibL1Addrs.SP1_RETH_VERIFIER);
    }
}
