// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TrailblazersBadges } from "../../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { TrailblazersBadgesS2 } from
    "../../../contracts/trailblazers-badges/TrailblazersBadgesS2.sol";
import { BadgeChampions } from "../../../contracts/trailblazers-badges/BadgeChampions.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    TrailblazersBadges public trailblazersBadges;
    TrailblazersBadgesS2 public trailblazersBadgesS2;
    BadgeChampions public badgeChampions;

    // Hekla
    address constant S1_ADDRESS = 0x075B858dA6eaf29b157925F4243135C565075842;
    address constant S2_ADDRESS = 0x3B20B6c42EDa78355beC5126cD4abB1fF4C218dd;
    address constant CHAMPIONS_ADDRESS = 0x854f29e8b3cE90521eEDBaC9BC3B50c92C32f00e;

    address[] public participants = [
        // @bearni - taiko:hekla
        0x4100a9B680B1Be1F10Cb8b5a57fE59eA77A8184e,
        address(0x1),
        address(0x2),
        address(0x3)
    ];

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();

        trailblazersBadges = TrailblazersBadges(S1_ADDRESS);
        trailblazersBadgesS2 = TrailblazersBadgesS2(S2_ADDRESS);
        badgeChampions = BadgeChampions(CHAMPIONS_ADDRESS);
    }

    function createFreshTournament() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 OPEN_TIME = block.timestamp - 3 minutes;
        uint256 CLOSE_TIME = block.timestamp - 2 minutes;
        uint256 START_TIME = block.timestamp - 1 minutes;

        badgeChampions.createLeague(OPEN_TIME, CLOSE_TIME, START_TIME);

        for (uint256 i = 0; i < participants.length; i++) {
            uint256 badgeId = i % 7;
            trailblazersBadges.mintTo(participants[i], badgeId);
            badgeChampions.registerChampionFor(
                participants[i], address(trailblazersBadges), badgeId
            );
        }

        vm.stopBroadcast();
    }

    function run() public {
        createFreshTournament();

        // close signups and start the tournament
        vm.startBroadcast(deployerPrivateKey);

        uint256 TOURNAMENT_SEED = block.number * 123_456_789;
        badgeChampions.startLeague(TOURNAMENT_SEED);
        vm.stopBroadcast();
    }
}
