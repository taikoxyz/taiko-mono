// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../contracts/thirdparty/AddressManager.sol";

// forge script script/deploy.s.sol:DeployOnL1 \
// --rpc-url [url] \
// --broadcast --verify -vvvv \
contract DeployOnL1 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // AddressManager am = new AddressManager();

        vm.stopBroadcast();
    }
}
