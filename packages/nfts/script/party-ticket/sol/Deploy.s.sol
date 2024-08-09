// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TaikoPartyTicket } from "../../../contracts/party-ticket/TaikoPartyTicket.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // Hardhat Testnet Values
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeighqzbsghqsnlo2ksf2afvbhyym6xde7cdoz2nri2xcoctuy7rya4";
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

    uint256 mintFee = 0.03 ether;
    address payoutWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

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

        string memory finalJson = vm.serializeAddress(jsonRoot, "TaikoPartyTicket", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
