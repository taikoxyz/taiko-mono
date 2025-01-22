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

    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiep3ju3glnzsrqdzaibv7v5ifa7dy4bkyprwkjz6wytl37oqwcmya";
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xfA5EA6f9A13532cd64e805996a941F101CCaAc9a);

    uint256 mintFee = 0.002 ether;
    address payoutWallet = 0x2e44474B7F5726908ef509B6C8d561fA40a52f90;

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
        address impl = address(new TaikoPartyTicket());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TaikoPartyTicket.initialize, (payoutWallet, mintFee, baseURI, blacklist)
                )
            )
        );

        TaikoPartyTicket token = TaikoPartyTicket(proxy);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed TaikoPartyTicket to:", address(token));
        /*
        token.upgradeToAndCall(
        address(new TaikoPartyTicketV2()), abi.encodeCall(TaikoPartyTicketV2.version, ())
        );

        TaikoPartyTicketV2 tokenV2 = TaikoPartyTicketV2(address(token));

        */
        string memory finalJson = vm.serializeAddress(jsonRoot, "TaikoPartyTicket", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
