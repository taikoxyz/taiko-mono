// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Bridge } from "../../../contracts/shared/bridge/Bridge.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title UpgradeBridge
/// @notice Script to deploy a new Bridge implementation and upgrade the proxy
contract UpgradeBridge is Script {
    address constant BRIDGE_PROXY = 0x7633740000000000000000000000000000000001;
    address constant SHARED_RESOLVER = 0x7633740000000000000000000000000000000006;
    address constant SIGNAL_SERVICE = 0x7633740000000000000000000000000000000005;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying new Bridge implementation...");
        console2.log("Constructor args:");
        console2.log("  Shared Resolver:", SHARED_RESOLVER);
        console2.log("  Signal Service:", SIGNAL_SERVICE);

        // Deploy new Bridge implementation
        Bridge newBridgeImpl = new Bridge(SHARED_RESOLVER, SIGNAL_SERVICE);

        console2.log("New Bridge implementation deployed at:", address(newBridgeImpl));
        console2.log("");
        console2.log("To upgrade the proxy, call upgradeTo on the proxy:");
        console2.log("  Proxy:", BRIDGE_PROXY);
        console2.log("  New Implementation:", address(newBridgeImpl));

        vm.stopBroadcast();
    }
}
