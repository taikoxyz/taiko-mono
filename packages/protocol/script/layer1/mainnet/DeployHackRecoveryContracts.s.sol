// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetBridge } from "src/layer1/mainnet/MainnetBridge.sol";
import { MainnetERC20Vault } from "src/layer1/mainnet/MainnetERC20Vault.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title DeployHackRecoveryContracts
/// @notice Deploys mainnet implementation contracts for the hack recovery upgrade bundle.
/// @dev This script deploys new implementations only. It does not upgrade proxies or call
/// recovery initializers; those actions should be encoded in the DAO proposal after reviewing the
/// logged implementation addresses.
/// @custom:security-contact security@taiko.xyz
contract DeployHackRecoveryContracts is Script {
    struct Deployment {
        address signalServiceImpl;
        address mainnetBridgeImpl;
        address mainnetErc20VaultImpl;
        address sgxGethVerifier;
        address sgxRethVerifier;
        address mainnetVerifier;
        address mainnetInboxImpl;
    }

    /// @notice Deploys the implementation contracts and writes their addresses to JSON.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployImplementations();
        vm.stopBroadcast();

        _logDeployment(deployment);
    }

    function _deployImplementations() private returns (Deployment memory deployment_) {
        deployment_.signalServiceImpl = address(
            new SignalService(
                LibL1Addrs.INBOX,
                LibL2Addrs.SIGNAL_SERVICE,
                LibL1Addrs.SECURITY_COUNCIL_SEAT_MULTISIG
            )
        );

        deployment_.mainnetBridgeImpl = address(
            new MainnetBridge(
                LibL1Addrs.SHARED_RESOLVER,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.QUOTA_MANAGER,
                LibL1Addrs.SECURITY_COUNCIL_SEAT_MULTISIG
            )
        );

        deployment_.mainnetErc20VaultImpl =
            address(new MainnetERC20Vault(LibL1Addrs.SHARED_RESOLVER, LibL1Addrs.QUOTA_MANAGER));

        deployment_.sgxGethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                LibL1Addrs.SGXGETH_ATTESTER,
                address(0)
            )
        );

        deployment_.sgxRethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                LibL1Addrs.SGXRETH_ATTESTER,
                address(0)
            )
        );

        deployment_.mainnetVerifier = address(
            new MainnetVerifier(
                deployment_.sgxGethVerifier,
                deployment_.sgxRethVerifier,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                LibL1Addrs.SP1_RETH_VERIFIER
            )
        );

        deployment_.mainnetInboxImpl = address(
            new MainnetInbox(
                deployment_.mainnetVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                LibL1Addrs.PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );
    }

    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("SIGNAL_SERVICE_NEW_IMPL:", _deployment.signalServiceImpl);
        console2.log("MAINNET_BRIDGE_NEW_IMPL:", _deployment.mainnetBridgeImpl);
        console2.log("MAINNET_ERC20_VAULT_NEW_IMPL:", _deployment.mainnetErc20VaultImpl);
        console2.log("NEW_SGXGETH_VERIFIER:", _deployment.sgxGethVerifier);
        console2.log("NEW_SGXRETH_VERIFIER:", _deployment.sgxRethVerifier);
        console2.log("MAINNET_VERIFIER:", _deployment.mainnetVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("PAUSER:", LibL1Addrs.SECURITY_COUNCIL_SEAT_MULTISIG);
        console2.log("QUOTA_MANAGER_PROXY:", LibL1Addrs.QUOTA_MANAGER);
    }
}
