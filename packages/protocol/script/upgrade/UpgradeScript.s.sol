// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";

contract UpgradeScript is Script {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public proxyAddress = vm.envAddress("PROXY_ADDRESS");

    UUPSUpgradeable proxy;

    modifier setUp() {
        require(privateKey != 0, "PRIVATE_KEY not set");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");

        proxy = UUPSUpgradeable(payable(proxyAddress));
        vm.startBroadcast(privateKey);

        _;

        vm.stopBroadcast();
    }

    function upgrade(string memory name, address newImpl) public {
        console2.log("Upgrading", name, proxyAddress);
        proxy.upgradeTo(newImpl);
        console2.log("Upgraded", proxyAddress, "to", newImpl);
    }
}
