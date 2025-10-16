// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TaikoPartyTicket } from "../../../contracts/party-ticket/TaikoPartyTicket.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TaikoPartyTicketV2 } from "../../../contracts/party-ticket/TaikoPartyTicketV2.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // hekla
    //address tokenV1 = 0x1d504615c42130F4fdbEb87775585B250BA78422;
    // mainnet
    address tokenV1 = 0x00E6dc8B0a58d505de61309df3568Ba3f9734a6C;

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

        TaikoPartyTicket token = TaikoPartyTicket(tokenV1);

        console.log("Deployed TaikoPartyTicket to:", address(token));

        token.upgradeToAndCall(
            address(new TaikoPartyTicketV2()), abi.encodeCall(TaikoPartyTicketV2.version, ())
        );

        TaikoPartyTicketV2 tokenV2 = TaikoPartyTicketV2(address(token));
        console.log("Upgraded token to:", address(tokenV2));
        console.log("Version:", tokenV2.version());

        string memory finalJson = vm.serializeAddress(jsonRoot, "TaikoPartyTicket", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
