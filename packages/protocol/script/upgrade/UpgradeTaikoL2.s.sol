// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../test/DeployCapability.sol";
import "../../contracts/L2/TaikoL2.sol";

contract UpgradeTaikoL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public proxy = vm.envAddress("PROXY_ADDRESS");

    function run() external {
        vm.startBroadcast(privateKey);

        UUPSUpgradeable(payable(proxy)).upgradeTo(address(new TaikoL2()));

        vm.stopBroadcast();
    }
}
