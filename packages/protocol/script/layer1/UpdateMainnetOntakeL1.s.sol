// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";
import "src/layer1/mainnet/multirollup/MainnetSharedAddressManager.sol";
import "src/layer1/mainnet/multirollup/MainnetSignalService.sol";
import "src/layer1/mainnet/multirollup/MainnetBridge.sol";
import "src/layer1/mainnet/rollup/MainnetRollupAddressManager.sol";
import "src/layer1/mainnet/rollup/MainnetTaikoL1.sol";
import "src/layer1/mainnet/rollup/MainnetTierRouter.sol";
import "src/layer1/mainnet/rollup/verifiers/MainnetSgxVerifier.sol";
import "src/layer1/provers/GuardianProver.sol";
import "src/layer1/mainnet/rollup/MainnetProverSet.sol";

contract UpgradeMainnetOntakeL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // MainnetSharedAddressManager
        console2.log(address(new MainnetSharedAddressManager()));
        // MainnetSignalService
        console2.log(address(new MainnetSignalService()));
        // MainnetBridge
        console2.log(address(new MainnetBridge()));
        // MainnetRollupAddressManager
        console2.log(address(new MainnetRollupAddressManager()));
        // MainnetTaikoL1
        console2.log(address(new MainnetTaikoL1()));
        // MainnetTierRouter
        console2.log(address(new MainnetTierRouter(0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9)));
        // MainnetSgxVerifier
        console2.log(address(new MainnetSgxVerifier()));
        // GuardianProver
        console2.log(address(new GuardianProver()));
        // MainnetProverSet
        console2.log(address(new MainnetProverSet()));
    }
}
