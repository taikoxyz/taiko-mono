// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract UpgradeV2 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address tokenV1 = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;
    TrailblazersBadges public token;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        token = TrailblazersBadges(tokenV1);
        vm.startBroadcast(deployerPrivateKey);

        token.upgradeToAndCall(
            address(new TrailblazersBadges()), abi.encodeCall(TrailblazersBadges.baseURI, ())
        );

        token = TrailblazersBadges(token);

        console.log("Upgraded TrailblazersBadges to:", address(token));
    }
}
