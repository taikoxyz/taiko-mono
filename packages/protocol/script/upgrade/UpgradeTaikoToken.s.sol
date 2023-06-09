// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "../../contracts/L1/TaikoToken.sol";

contract UpgradeTaikoToken is Script {
    using SafeCastUpgradeable for uint256;

    uint256 public deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address public proxyAddress = vm.envAddress("PROXY_ADDRESS");

    function run() external {
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");

        vm.startBroadcast(deployerPrivateKey);

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(proxyAddress));

        TaikoToken newTaikoToken = new ProxiedTaikoToken();
        proxy.upgradeTo(address(newTaikoToken));
        console2.log(
            "proxy upgraded TaikoToken implementation to",
            address(newTaikoToken)
        );
    }
}
