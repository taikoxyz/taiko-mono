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
import { QuotaManager } from "src/shared/bridge/QuotaManager.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title DeployHackRecoveryContracts
/// @notice Deploys mainnet implementation contracts for the hack recovery upgrade bundle.
/// @dev This script deploys new implementations only. It does not upgrade proxies or call
/// recovery initializers; those actions should be encoded in the DAO proposal after reviewing the
/// logged implementation addresses.
/// @custom:security-contact security@taiko.xyz
contract DeployHackRecoveryContracts is Script {
    uint104 private constant _ETH_QUOTA = 250 ether;
    uint104 private constant _WETH_QUOTA = 250 ether;
    uint104 private constant _TKO_QUOTA = 10_000_000 ether;
    uint104 private constant _USDT_QUOTA = 150_000_000_000;
    uint104 private constant _USDC_QUOTA = 150_000_000_000;

    struct Deployment {
        address signalServiceImpl;
        address quotaManager;
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
                LibL1Addrs.INBOX, LibL2Addrs.SIGNAL_SERVICE, LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
            )
        );

        deployment_.quotaManager = address(
            new QuotaManager(
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
                LibL1Addrs.BRIDGE,
                LibL1Addrs.ERC20_VAULT,
                24 hours,
                _quotaTokens(),
                _quotas()
            )
        );

        deployment_.mainnetBridgeImpl = address(
            new MainnetBridge(
                LibL1Addrs.SHARED_RESOLVER,
                LibL1Addrs.SIGNAL_SERVICE,
                deployment_.quotaManager,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
            )
        );

        deployment_.mainnetErc20VaultImpl =
            address(new MainnetERC20Vault(LibL1Addrs.SHARED_RESOLVER, deployment_.quotaManager));

        deployment_.sgxGethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                LibL1Addrs.SGXGETH_ATTESTER,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
            )
        );

        deployment_.sgxRethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                LibL1Addrs.SGXRETH_ATTESTER,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
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
        console2.log("QUOTA_MANAGER:", _deployment.quotaManager);
        console2.log("MAINNET_BRIDGE_NEW_IMPL:", _deployment.mainnetBridgeImpl);
        console2.log("MAINNET_ERC20_VAULT_NEW_IMPL:", _deployment.mainnetErc20VaultImpl);
        console2.log("NEW_SGXGETH_VERIFIER:", _deployment.sgxGethVerifier);
        console2.log("NEW_SGXRETH_VERIFIER:", _deployment.sgxRethVerifier);
        console2.log("MAINNET_VERIFIER:", _deployment.mainnetVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("PAUSER:", LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH);
        console2.log("QUOTA_MANAGER_OWNER:", LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH);
        console2.log("ETH_QUOTA:", _ETH_QUOTA);
        console2.log("WETH_QUOTA:", _WETH_QUOTA);
        console2.log("TKO_QUOTA:", _TKO_QUOTA);
        console2.log("USDT_QUOTA:", _USDT_QUOTA);
        console2.log("USDC_QUOTA:", _USDC_QUOTA);
    }

    function _quotaTokens() private pure returns (address[] memory tokens_) {
        tokens_ = new address[](5);
        tokens_[0] = address(0);
        tokens_[1] = LibL1Addrs.WETH_TOKEN;
        tokens_[2] = LibL1Addrs.TAIKO_TOKEN;
        tokens_[3] = LibL1Addrs.USDT_TOKEN;
        tokens_[4] = LibL1Addrs.USDC_TOKEN;
    }

    function _quotas() private pure returns (uint104[] memory quotas_) {
        quotas_ = new uint104[](5);
        quotas_[0] = _ETH_QUOTA;
        quotas_[1] = _WETH_QUOTA;
        quotas_[2] = _TKO_QUOTA;
        quotas_[3] = _USDT_QUOTA;
        quotas_[4] = _USDC_QUOTA;
    }
}
