// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/src/Script.sol";
import { RegisterGalxePoints } from "../../../contracts/galxe/RegisterGalxePoints.sol";

contract DeployRegisterMyGalaxyPointScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        RegisterGalxePoints registerGalxePoints = new RegisterGalxePoints();

        console.log(
            "Deployed RegisterGalxePoints to:",
            address(registerGalxePoints),
            "from",
            deployerAddress
        );

        vm.stopBroadcast();
    }
}
