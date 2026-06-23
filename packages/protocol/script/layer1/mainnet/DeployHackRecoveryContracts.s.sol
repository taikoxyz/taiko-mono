// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/src/Script.sol";
import {LibL1Addrs} from "src/layer1/mainnet/LibL1Addrs.sol";
import {MainnetBridge} from "src/layer1/mainnet/MainnetBridge.sol";
import {MainnetInbox} from "src/layer1/mainnet/MainnetInbox.sol";
import {MainnetVerifier} from "src/layer1/mainnet/MainnetVerifier.sol";
import {SecureSgxVerifier} from "src/layer1/verifiers/SecureSgxVerifier.sol";
import {LibL2Addrs} from "src/layer2/mainnet/LibL2Addrs.sol";
import {LibNetwork} from "src/shared/libs/LibNetwork.sol";
import {SignalService} from "src/shared/signal/SignalService.sol";

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
        address sgxGethVerifier;
        address sgxRethVerifier;
        address mainnetVerifier;
        address mainnetInboxImpl;
    }

    address public constant SECURITY_COUNCIL_SEAT_MULTISIG = 0xb47fE76aC588101BFBdA9E68F66433bA51E8029a;
    address public constant PROVER_WHITELIST = 0xEa798547d97e345395dA071a0D7ED8144CD612Ae;
    address public constant SHARED_RESOLVER = 0x8Efa01564425692d0a0838DC10E300BD310Cb43e;
    address public constant QUOTA_MANAGER = 0x91f67118DD47d502B1f0C354D0611997B022f29E;
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

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
        deployment_.signalServiceImpl =
            address(new SignalService(LibL1Addrs.INBOX, LibL2Addrs.SIGNAL_SERVICE, SECURITY_COUNCIL_SEAT_MULTISIG));

        deployment_.mainnetBridgeImpl = address(
            new MainnetBridge(SHARED_RESOLVER, LibL1Addrs.SIGNAL_SERVICE, QUOTA_MANAGER, SECURITY_COUNCIL_SEAT_MULTISIG)
        );

        deployment_.sgxGethVerifier = address(
            new SecureSgxVerifier(LibNetwork.TAIKO_MAINNET, LibL1Addrs.DAO_CONTROLLER, SGXGETH_ATTESTER, address(0))
        );

        deployment_.sgxRethVerifier = address(
            new SecureSgxVerifier(LibNetwork.TAIKO_MAINNET, LibL1Addrs.DAO_CONTROLLER, SGXRETH_ATTESTER, address(0))
        );

        deployment_.mainnetVerifier = address(
            new MainnetVerifier(
                deployment_.sgxGethVerifier, deployment_.sgxRethVerifier, RISC0_RETH_VERIFIER, SP1_RETH_VERIFIER
            )
        );

        deployment_.mainnetInboxImpl = address(
            new MainnetInbox(
                deployment_.mainnetVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );
    }

    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("SIGNAL_SERVICE_NEW_IMPL:", _deployment.signalServiceImpl);
        console2.log("MAINNET_BRIDGE_NEW_IMPL:", _deployment.mainnetBridgeImpl);
        console2.log("NEW_SGXGETH_VERIFIER:", _deployment.sgxGethVerifier);
        console2.log("NEW_SGXRETH_VERIFIER:", _deployment.sgxRethVerifier);
        console2.log("MAINNET_VERIFIER:", _deployment.mainnetVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("PAUSER:", SECURITY_COUNCIL_SEAT_MULTISIG);
        console2.log("EXISTING_QUOTA_MANAGER:", QUOTA_MANAGER);
    }
}
