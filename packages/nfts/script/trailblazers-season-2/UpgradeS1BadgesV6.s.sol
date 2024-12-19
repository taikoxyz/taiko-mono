// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV5.sol";
import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV6.sol";

contract UpgradeS1BadgesV6 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address public s1TokenAddress = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;
    TrailblazersBadgesV6 public token;

    uint256 public SEASON_2_END_TS = 1_734_350_400;
    uint256 public SEASON_3_END_TS = 1_742_212_800;
    //1_734_387_911

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        TrailblazersBadgesV5 tokenV5 = TrailblazersBadgesV5(s1TokenAddress);

        tokenV5.upgradeToAndCall(
            address(new TrailblazersBadgesV6()), abi.encodeCall(TrailblazersBadgesV6.version, ())
        );

        token = TrailblazersBadgesV6(address(tokenV5));

        console.log("Upgraded TrailblazersBadgesV6 on:", address(token));

        token.setSeason2EndTimestamp(SEASON_2_END_TS);
        console.log("Updated s2 end timestamp to:", SEASON_2_END_TS);
        token.setSeason3EndTimestamp(SEASON_3_END_TS);
        console.log("Updated s3 end timestamp to:", SEASON_3_END_TS);
    }
}
