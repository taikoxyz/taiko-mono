// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeScript is Script {
    uint256 public deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address public proxyAddress = vm.envAddress("PROXY_ADDRESS");

    TransparentUpgradeableProxy proxy;

    modifier setUp() {
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");

        vm.startBroadcast(deployerPrivateKey);

        proxy = TransparentUpgradeableProxy(payable(proxyAddress));
        _;

        vm.stopBroadcast();
    }
}
