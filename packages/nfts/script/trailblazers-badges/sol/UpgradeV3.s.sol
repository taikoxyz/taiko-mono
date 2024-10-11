// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TrailblazersBadgesV3 } from
    "../../../contracts/trailblazers-badges/TrailblazersBadgesV3.sol";

contract UpgradeV3 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address tokenV2Address = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;
    TrailblazersBadges public tokenV2;
    TrailblazersBadgesV3 public tokenV3;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        tokenV2 = TrailblazersBadges(tokenV2Address);

        tokenV2.upgradeToAndCall(
            address(new TrailblazersBadgesV3()), abi.encodeCall(TrailblazersBadgesV3.version, ())
        );

        tokenV3 = TrailblazersBadgesV3(address(tokenV2));

        console.log("Upgraded TrailblazersBadgesV3 to:", address(tokenV3));
    }
}
