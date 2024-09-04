// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RegisterProfilePicture } from "../../contracts/profile/RegisterProfilePicture.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        string memory jsonRoot = "root";

        vm.startBroadcast(deployerPrivateKey);

        // deploy token with empty root
        address impl = address(new RegisterProfilePicture());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    RegisterProfilePicture.initialize, ()
                )
            )
        );

        RegisterProfilePicture profile = RegisterProfilePicture(proxy);

        console.log("Deployed TaikoPartyTicket to:", address(profile));

        string memory finalJson = vm.serializeAddress(jsonRoot, "RegisterProfilePicture", address(profile));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
