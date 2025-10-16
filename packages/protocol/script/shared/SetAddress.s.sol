// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "src/shared/common/DefaultResolver.sol";

contract SetAddress is Script {
    uint256 public adminPrivateKey = vm.envUint("PRIVATE_KEY");

    address public proxyAddress = vm.envAddress("PROXY_ADDRESS");

    uint64 public domain = uint64(vm.envUint("DOMAIN"));

    bytes32 public name = vm.envBytes32("NAME");

    address public addr = vm.envAddress("ADDRESS");

    DefaultResolver proxy;

    function run() external {
        require(adminPrivateKey != 0, "PRIVATE_KEY not set");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");
        require(domain != 0, "DOMAIN NOT SET");
        require(name != bytes32(0), "NAME NOT SET");
        require(addr != address(0), "ADDR NOT SET");

        vm.startBroadcast(adminPrivateKey);

        proxy = DefaultResolver(payable(proxyAddress));

        proxy.registerAddress(domain, name, addr);

        vm.stopBroadcast();
    }
}
