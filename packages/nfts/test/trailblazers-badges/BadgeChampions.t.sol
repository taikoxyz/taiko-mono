// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { BadgeChampions } from "../../contracts/trailblazers-badges/BadgeChampions.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BadgeChampionsTest is Test {
    UtilsScript public utils;

    TrailblazersBadges public token;

    address public owner = vm.addr(0x5);

    address[8] public minters = [
        vm.addr(0x1),
        vm.addr(0x2),
        vm.addr(0x3),
        vm.addr(0x4),
        vm.addr(0x5),
        vm.addr(0x6),
        vm.addr(0x7),
        vm.addr(0x8)
    ];

    uint256 constant TOURNAMENT_SEED = 1_234_567_890;

    uint256[8] public BADGE_IDS = [0, 1, 2, 3, 4, 5, 6, 7];

    MockBlacklist public blacklist;

    address mintSigner;
    uint256 mintSignerPk;

    BadgeChampions public badgeChampions;

    mapping(address player => uint256 badgeId) public playersToBadgeIds;

    uint64 constant OPEN_TIME = 10_000;
    uint64 constant CLOSE_TIME = 20_000;
    uint64 constant START_TIME = 30_000;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        blacklist = new MockBlacklist();
        // create whitelist merkle tree
        vm.startPrank(owner);

        (mintSigner, mintSignerPk) = makeAddrAndKey("mintSigner");

        // deploy s1 badges token
        address impl = address(new TrailblazersBadges());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TrailblazersBadges.initialize, (owner, "ipfs://", mintSigner, blacklist)
                )
            )
        );

        token = TrailblazersBadges(proxy);

        // deploy badge champions
        impl = address(new BadgeChampions());
        proxy = address(
            new ERC1967Proxy(
                impl, abi.encodeCall(BadgeChampions.initialize, (address(token), address(0x0)))
            )
        );

        badgeChampions = BadgeChampions(proxy);
        vm.stopPrank();

        // mint some badges
        for (uint256 i = 0; i < minters.length; i++) {
            bytes32 _hash = token.getHash(minters[i], BADGE_IDS[i]);

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

            vm.startPrank(minters[i]);
            token.mint(abi.encodePacked(r, s, v), BADGE_IDS[i]);
            vm.stopPrank();

            playersToBadgeIds[minters[i]] = BADGE_IDS[i];
        }
    }

    function test_metadata_badges() public view {
        assertEq(token.BADGE_RAVERS(), 0);
        assertEq(token.BADGE_ROBOTS(), 1);
        assertEq(token.BADGE_BOUNCERS(), 2);
        assertEq(token.BADGE_MASTERS(), 3);
        assertEq(token.BADGE_MONKS(), 4);
        assertEq(token.BADGE_DRUMMERS(), 5);
        assertEq(token.BADGE_ANDROIDS(), 6);
        assertEq(token.BADGE_SHINTO(), 7);
    }

    function test_admin_createLeague() public {
        // create league
        vm.prank(owner);
        badgeChampions.createLeague(OPEN_TIME, CLOSE_TIME, START_TIME);

        // check league
        BadgeChampions.League memory league = badgeChampions.getCurrentLeague();

        assertEq(league.openTime, OPEN_TIME);
        assertEq(league.closeTime, CLOSE_TIME);
        assertEq(league.startTime, START_TIME);

        assertEq(league.seed, 0);
    }

    function test_revert_leagueNotOpen() public {
        test_admin_createLeague();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        badgeChampions.registerChampion(address(token), playersToBadgeIds[minters[0]]);
        vm.stopPrank();
    }

    function wait(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    function test_registerChampion() public {
        test_admin_createLeague();

        wait(OPEN_TIME + 1);
        // register champion
        vm.prank(minters[0]);
        badgeChampions.registerChampion(address(token), BADGE_IDS[0]);

        // check league
        BadgeChampions.League memory league = badgeChampions.getCurrentLeague();

        assertEq(league.openTime, OPEN_TIME);
        assertEq(league.closeTime, CLOSE_TIME);
        assertEq(league.startTime, START_TIME);

        assertEq(league.seed, 0);
    }

    function test_revert_registerChampion_notOwned() public {
        test_admin_createLeague();

        wait(OPEN_TIME + 1);
        // register champion
        vm.startPrank(minters[1]);
        vm.expectRevert();
        badgeChampions.registerChampion(address(token), playersToBadgeIds[minters[0]]);
        vm.stopPrank();
    }

    function test_registerChampion_all() public {
        test_admin_createLeague();

        wait(OPEN_TIME + 1);
        // register champion
        for (uint256 i = 0; i < minters.length; i++) {
            vm.prank(minters[i]);
            badgeChampions.registerChampion(address(token), BADGE_IDS[i]);
        }

        // check league
        BadgeChampions.League memory league = badgeChampions.getCurrentLeague();

        assertEq(league.openTime, OPEN_TIME);
        assertEq(league.closeTime, CLOSE_TIME);
        assertEq(league.startTime, START_TIME);

        assertEq(league.seed, 0);
    }

    function test_admin_startLeague() public {
        test_registerChampion_all();

        wait(CLOSE_TIME + 1);
        // start league
        vm.prank(owner);
        badgeChampions.startLeague(TOURNAMENT_SEED);

        // check league
        BadgeChampions.League memory league = badgeChampions.getCurrentLeague();

        assertEq(league.openTime, OPEN_TIME);
        assertEq(league.closeTime, CLOSE_TIME);
        assertEq(league.startTime, START_TIME);

        assertEq(league.seed, TOURNAMENT_SEED);
    }

    function test_revert_startLeague_notAdmin() public {
        test_registerChampion_all();

        wait(CLOSE_TIME + 1);
        // start league
        vm.startPrank(minters[0]);
        vm.expectRevert();
        badgeChampions.startLeague(TOURNAMENT_SEED);
        vm.stopPrank();
    }
}
