// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "src/layer1/preconf/eigenlayer-mvp/AVSDirectory.sol";
import "src/layer1/preconf/eigenlayer-mvp/DelegationManager.sol";
import "src/layer1/preconf/eigenlayer-mvp/StrategyManager.sol";
import "src/layer1/preconf/eigenlayer-mvp/Slasher.sol";
import "src/layer1/preconf/interfaces/eigenlayer-mvp/IDelegationManager.sol";
import "src/layer1/preconf/interfaces/eigenlayer-mvp/IStrategyManager.sol";

import "../BaseScript.sol";
import "../misc/EmptyContract.sol";

contract DeployEigenlayerMVP is BaseScript {
    function run() external broadcast {
        EmptyContract emptyContract = new EmptyContract();
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // Deploy proxies with empty implementations
        address avsDirectory = deployProxy(address(emptyContract), address(proxyAdmin), "");
        address delegationManager = deployProxy(address(emptyContract), address(proxyAdmin), "");
        address strategyManager = deployProxy(address(emptyContract), address(proxyAdmin), "");
        address slasher = deployProxy(address(emptyContract), address(proxyAdmin), "");

        // Deploy implementations
        AVSDirectory avsDirectoryImpl = new AVSDirectory();
        DelegationManager delegationManagerImpl =
            new DelegationManager(IStrategyManager(strategyManager));
        StrategyManager strategyManagerImpl =
            new StrategyManager(IDelegationManager(delegationManager));
        Slasher slasherImpl = new Slasher();

        // Upgrade proxies with implementations
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(avsDirectory), address(avsDirectoryImpl));
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(delegationManager), address(delegationManagerImpl)
        );
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(strategyManager), address(strategyManagerImpl)
        );
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(slasher), address(slasherImpl));

        console2.log("AVS Directory: ", avsDirectory);
        console2.log("Delegation Manager: ", delegationManager);
        console2.log("Strategy Manager: ", strategyManager);
        console2.log("Slasher: ", slasher);
    }
}
