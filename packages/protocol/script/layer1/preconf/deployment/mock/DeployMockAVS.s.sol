// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../../BaseScript.sol";
import {EmptyContract} from "../../misc/EmptyContract.sol";

import {MockPreconfRegistry} from "src/layer1/preconf/mock/MockPreconfRegistry.sol";
import {PreconfServiceManager} from "src/layer1/preconf/avs/PreconfServiceManager.sol";
import {PreconfTaskManager} from "src/layer1/preconf/avs/PreconfTaskManager.sol";
import {IPreconfRegistry} from "src/layer1/preconf/interfaces/IPreconfRegistry.sol";
import {IPreconfServiceManager} from "src/layer1/preconf/interfaces/IPreconfServiceManager.sol";
import {IPreconfTaskManager} from "src/layer1/preconf/interfaces/IPreconfTaskManager.sol";
import {IAVSDirectory} from "src/layer1/preconf/interfaces/eigenlayer-mvp/IAVSDirectory.sol";
import {ISlasher} from "src/layer1/preconf/interfaces/eigenlayer-mvp/ISlasher.sol";
import {ITaikoL1} from "src/layer1/preconf/interfaces/taiko/ITaikoL1.sol";

import {console2} from "forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployMockAVS is BaseScript {
    // Required by service manager
    address public avsDirectory = vm.envAddress("AVS_DIRECTORY");
    address public slasher = vm.envAddress("SLASHER");

    // Required by task manager
    address public taikoL1 = vm.envAddress("TAIKO_L1");
    address public taikoToken = vm.envAddress("TAIKO_TOKEN");
    uint256 public beaconGenesisTimestamp = vm.envUint("BEACON_GENESIS_TIMESTAMP");
    address public beaconBlockRootContract = vm.envAddress("BEACON_BLOCK_ROOT_CONTRACT");

    function run() external broadcast {
        EmptyContract emptyContract = new EmptyContract();
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // Deploy proxies with empty implementations
        address preconfRegistry = deployProxy(address(emptyContract), address(proxyAdmin), "");
        address preconfServiceManager = deployProxy(address(emptyContract), address(proxyAdmin), "");
        address preconfTaskManager = deployProxy(address(emptyContract), address(proxyAdmin), "");

        // Deploy implementations
        MockPreconfRegistry preconfRegistryImpl = new MockPreconfRegistry(IPreconfServiceManager(preconfServiceManager));
        PreconfServiceManager preconfServiceManagerImpl = new PreconfServiceManager(
            preconfRegistry, preconfTaskManager, IAVSDirectory(avsDirectory), ISlasher(slasher)
        );
        PreconfTaskManager preconfTaskManagerImpl = new PreconfTaskManager(
            IPreconfServiceManager(preconfServiceManager),
            IPreconfRegistry(preconfRegistry),
            ITaikoL1(taikoL1),
            beaconGenesisTimestamp,
            beaconBlockRootContract
        );

        // Upgrade proxies with implementations
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(preconfRegistry),
            address(preconfRegistryImpl),
            abi.encodeCall(MockPreconfRegistry.initialize, ())
        );
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(preconfServiceManager), address(preconfServiceManagerImpl));
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(preconfTaskManager),
            address(preconfTaskManagerImpl),
            abi.encodeCall(PreconfTaskManager.initialize, IERC20(taikoToken))
        );

        console2.log("Proxy admin: ", address(proxyAdmin));
        console2.log("Preconf Registry: ", preconfRegistry);
        console2.log("Preconf Service Manager: ", preconfServiceManager);
        console2.log("Preconf Task Manager: ", preconfTaskManager);
    }
}
