// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

import { TrailblazersBadgesS2 } from
    "../../contracts/trailblazers-season-2/TrailblazersBadgesS2.sol";

contract UpgradeV2 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address tokenAddress = 0x52A7dBeC10B404548066F59DE89484e27b4181dA;
    TrailblazersBadgesS2 public token;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        token = TrailblazersBadgesS2(tokenAddress);

        token.upgradeToAndCall(
            address(new TrailblazersBadgesS2()), abi.encodeCall(TrailblazersBadgesS2.version, ())
        );

        token = TrailblazersBadgesS2(address(token));

        console.log("Upgraded TrailblazersBadgesV3 to:", address(token));

        // update uri
        token.setUri(
            "https://taikonfts.4everland.link/ipfs/bafybeief7o4u6f676e6uz4yt4cv34ai4mesd7motoq6y4xxaoyjfbna5de"
        );
        console.log("Updated token URI");
    }
}
