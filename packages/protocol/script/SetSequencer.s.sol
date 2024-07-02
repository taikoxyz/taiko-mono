// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../contracts/L1/SequencerRegistry.sol";
import "../contracts/common/AddressManager.sol";

contract SetSequencer is Script {
    uint256 public ownerPrivateKey = vm.envUint("PRIVATE_KEY");

    address public proxyAddress = vm.envAddress("PROXY_ADDRESS");

    address public addr = vm.envAddress("ADDRESS");

    bool public enabled = vm.envBool("ENABLED");

    SequencerRegistry proxy;

    function run() external {
        require(ownerPrivateKey != 0, "PRIVATE_KEY not set");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");
        require(addr != address(0), "ADDR NOT SET");

        vm.startBroadcast(ownerPrivateKey);

        proxy = SequencerRegistry(payable(proxyAddress));

        address[] memory addresses = [addr];
        bool[] memory enabledAddresses = [enabled];
        proxy.setSequencers(addresses, enabledAddresses);

        vm.stopBroadcast();
    }
}
