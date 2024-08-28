// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../test/DeployCapability.sol";
import "../../contracts/L1/tiers/DevnetTierProvider.sol";

contract UpgradeTierRouter is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public addressManager = vm.envAddress("ADDRESS_MANAGER_ADDRESS");

    function run() external {
        vm.startBroadcast(privateKey);
        address impl = address(new DevnetTierProvider());
        AddressManager(addressManager).setAddress(uint64(block.chainid), "tier_router", impl);
        vm.stopBroadcast();
        console2.log("> tier_router@", addressManager);
        console2.log("\t addr : ", impl);
    }
}
