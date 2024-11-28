// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TrailblazersBadgesV3 } from "../../contracts/trailblazers-badges/TrailblazersBadgesV3.sol";
import { TrailblazersBadgesV4 } from
    "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV4.sol";

contract UpgradeV4 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address tokenV3Address = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;
    TrailblazersBadgesV3 public tokenV3;
    TrailblazersBadgesV4 public tokenV4;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        tokenV3 = TrailblazersBadgesV3(tokenV3Address);

        tokenV3.upgradeToAndCall(
            address(new TrailblazersBadgesV4()), abi.encodeCall(TrailblazersBadgesV4.version, ())
        );

        tokenV4 = TrailblazersBadgesV4(address(tokenV3));

        console.log("Upgraded TrailblazersBadgesV3 to:", address(tokenV4));

        // update uri
        tokenV4.setUri(
            "https://taikonfts.4everland.link/ipfs/bafybeiatuzeeeznd3hi5qiulslxcjd22ebu45t4fra2jvi3smhocr2c66a"
        );
        console.log("Updated token URI");
    }
}
