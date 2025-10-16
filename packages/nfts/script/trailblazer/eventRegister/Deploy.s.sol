// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/src/Script.sol";
import { EventRegister } from "../../../contracts/eventRegister/EventRegister.sol";

contract DeployEventRegisterScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        EventRegister eventRegister = new EventRegister();

        console.log("Deployed EventRegister to:", address(eventRegister), "from", deployerAddress);

        // Initialize the contract
        eventRegister.initialize();

        console.log("Initialized EventRegister contract.");

        vm.stopBroadcast();
    }
}
