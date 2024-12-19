// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV6.sol";
import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV7.sol";

contract UpgradeS1BadgesV7 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address public s1TokenAddress = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;
    TrailblazersBadgesV7 public token;

    uint256 public SEASON_2_END_TS = 1_734_350_400;
    uint256 public SEASON_3_END_TS = 1_742_212_800;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        TrailblazersBadgesV6 tokenV6 = TrailblazersBadgesV6(s1TokenAddress);

        tokenV6.upgradeToAndCall(
            address(new TrailblazersBadgesV7()), abi.encodeCall(TrailblazersBadgesV7.version, ())
        );

        token = TrailblazersBadgesV7(address(tokenV6));

        console.log("Upgraded TrailblazersBadgesV7 on:", address(token));
    }
}
