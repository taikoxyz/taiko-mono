// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployMainnetInboxWithNewSP1Verifier
/// @notice Deploys a new mainnet SP1 verifier, MainnetVerifier, and MainnetInbox implementation.
/// @dev The non-SP1 verifier inputs and Inbox constructor inputs match the MainnetInbox
/// implementation deployed for taikoxyz/taiko-mono#21833.
/// @custom:security-contact security@taiko.xyz
contract DeployMainnetInboxWithNewSP1Verifier is Script {
    address private constant _PR21833_SGXGETH_VERIFIER = 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee;
    address private constant _PR21833_SGXRETH_VERIFIER = 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8;
    address private constant _SP1_REMOTE_VERIFIER = 0x3B6041173B80E77f038f3F2C0f9744f04837185e;

    struct Deployment {
        address sp1Verifier;
        address mainnetVerifier;
        address mainnetInboxImpl;
    }

    /// @notice Deploys the contracts and logs the addresses needed by the upgrade proposal.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployImplementations();
        vm.stopBroadcast();

        _logDeployment(deployment);
    }

    /// @dev Deploys the new verifier chain and the new Inbox implementation.
    /// @return deployment_ Addresses of the newly deployed contracts.
    function _deployImplementations() private returns (Deployment memory deployment_) {
        deployment_.sp1Verifier = address(
            new SP1Verifier(
                LibNetwork.TAIKO_MAINNET, _SP1_REMOTE_VERIFIER, LibL1Addrs.DAO_CONTROLLER
            )
        );

        deployment_.mainnetVerifier = address(
            new MainnetVerifier(
                _PR21833_SGXGETH_VERIFIER,
                _PR21833_SGXRETH_VERIFIER,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                deployment_.sp1Verifier
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

    /// @dev Logs deployed addresses and constructor inputs for proposal copy/paste.
    /// @param _deployment Addresses of the newly deployed contracts.
    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("NEW_SP1_RETH_VERIFIER:", _deployment.sp1Verifier);
        console2.log("MAINNET_VERIFIER:", _deployment.mainnetVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("SP1_REMOTE_VERIFIER:", _SP1_REMOTE_VERIFIER);
        console2.log("SP1_VERIFIER_OWNER:", LibL1Addrs.DAO_CONTROLLER);
        console2.log("SGXGETH_VERIFIER:", _PR21833_SGXGETH_VERIFIER);
        console2.log("SGXRETH_VERIFIER:", _PR21833_SGXRETH_VERIFIER);
        console2.log("RISC0_RETH_VERIFIER:", LibL1Addrs.RISC0_RETH_VERIFIER);
        console2.log("PRECONF_WHITELIST:", LibL1Addrs.PRECONF_WHITELIST);
        console2.log("PROVER_WHITELIST:", LibL1Addrs.PROVER_WHITELIST);
        console2.log("SIGNAL_SERVICE:", LibL1Addrs.SIGNAL_SERVICE);
        console2.log("TAIKO_TOKEN:", LibL1Addrs.TAIKO_TOKEN);
    }
}
