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

    uint256 constant OPEN_TIME = 10_000;
    uint256 constant CLOSE_TIME = 20_000;
    uint256 constant START_TIME = 30_000;
    uint256 constant END_TIME = 40_000;

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

    function test_admin_createTournament() public {
        // create tournament
        vm.prank(owner);
        badgeChampions.createTournament(OPEN_TIME, CLOSE_TIME, START_TIME, END_TIME);

        // check tournament
        (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        ) = badgeChampions.getCurrentTournament();

        assertEq(openTime, OPEN_TIME);
        assertEq(closeTime, CLOSE_TIME);
        assertEq(startTime, START_TIME);
        assertEq(endTime, END_TIME);
        assertEq(seed, 0);
        assertEq(participants.length, 0);
    }

    function test_revert_tournamentNotOpen() public {
        test_admin_createTournament();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        badgeChampions.registerChampion(address(token), playersToBadgeIds[minters[0]]);
        vm.stopPrank();
    }

    function wait(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    function test_registerChampion() public {
        test_admin_createTournament();

        wait(OPEN_TIME + 1);
        // register champion
        vm.prank(minters[0]);
        badgeChampions.registerChampion(address(token), BADGE_IDS[0]);

        // check tournament
        (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        ) = badgeChampions.getCurrentTournament();

        assertEq(openTime, OPEN_TIME);
        assertEq(closeTime, CLOSE_TIME);
        assertEq(startTime, START_TIME);
        assertEq(endTime, END_TIME);
        assertEq(seed, 0);
        assertEq(rounds, 0);
        assertEq(participants.length, 1);
        assertEq(participants[0], minters[0]);
    }

    function test_revert_registerChampion_notOwned() public {
        test_admin_createTournament();

        wait(OPEN_TIME + 1);
        // register champion
        vm.startPrank(minters[1]);
        vm.expectRevert();
        badgeChampions.registerChampion(address(token), playersToBadgeIds[minters[0]]);
        vm.stopPrank();
    }

    function test_registerChampion_all() public {
        test_admin_createTournament();

        wait(OPEN_TIME + 1);
        // register champion
        for (uint256 i = 0; i < minters.length; i++) {
            vm.prank(minters[i]);
            badgeChampions.registerChampion(address(token), BADGE_IDS[i]);
        }

        // check tournament
        (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        ) = badgeChampions.getCurrentTournament();

        assertEq(openTime, OPEN_TIME);
        assertEq(closeTime, CLOSE_TIME);
        assertEq(startTime, START_TIME);
        assertEq(endTime, END_TIME);
        assertEq(seed, 0);
        assertEq(rounds, 0);
        assertEq(participants.length, minters.length);
        for (uint256 i = 0; i < minters.length; i++) {
            assertEq(participants[i], minters[i]);
        }
    }

    function test_admin_startTournament() public {
        test_registerChampion_all();

        wait(CLOSE_TIME + 1);
        // start tournament
        vm.prank(owner);
        badgeChampions.startTournament(TOURNAMENT_SEED);

        // check tournament
        (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        ) = badgeChampions.getCurrentTournament();

        assertEq(openTime, OPEN_TIME);
        assertEq(closeTime, CLOSE_TIME);
        assertEq(startTime, START_TIME);
        assertEq(endTime, END_TIME);
        assertEq(seed, TOURNAMENT_SEED);
        assertEq(rounds, 3); // 3 for 8 participants
        assertEq(participants.length, minters.length);
        for (uint256 i = 0; i < minters.length; i++) {
            assertEq(participants[i], minters[i]);
        }
    }

    function test_revert_startTournament_notAdmin() public {
        test_registerChampion_all();

        wait(CLOSE_TIME + 1);
        // start tournament
        vm.startPrank(minters[0]);
        vm.expectRevert();
        badgeChampions.startTournament(TOURNAMENT_SEED);
        vm.stopPrank();
    }

    function test_getWinner_single() public {
        test_admin_startTournament();

        wait(START_TIME + 1);

        uint256 _round = 1;
        uint256 _match = 0;

        (address leftParticipant, address rightParticipant) =
            badgeChampions.getParticipants(_round, _match);

        (uint256 leftId, uint256 rightId) = badgeChampions.getMatchup(_round, _match);

        assertTrue(leftId != rightId);
        // get winner
        address winner = badgeChampions.getWinner(_round, _match);

        assertTrue(leftParticipant != rightParticipant);
        assertEq(winner, leftParticipant);
        assertFalse(winner == rightParticipant);
    }

    function test_getWinner_round() public {
        test_admin_startTournament();

        wait(START_TIME + 1);
        uint256 round = 1; // Assuming we are testing round 1
        uint256 numMatches = minters.length / 2; // Assuming we have an even number of participants

        for (uint256 matchIndex = 0; matchIndex < numMatches; matchIndex++) {
            // Retrieve participants for the match
            (address participant1, address participant2) =
                badgeChampions.getParticipants(round, matchIndex);

            // Simulate a battle and get the winner
            address winner = badgeChampions.getWinner(round, matchIndex);

            // Assertions to ensure correctness
            assertTrue(participant1 != participant2);
            assertTrue(participant1 == winner || participant2 == winner);
        }
    }

    function test_getWinner_tournament() public {
        test_admin_startTournament();

        wait(START_TIME + 1);
        // uint256 numRounds = 3; // Assuming we have 3 rounds
        // uint256 numMatches = minters.length / 2; // Assuming we have an even number of
        // participants

        (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        ) = badgeChampions.getCurrentTournament();

        uint256[] memory participantCount = new uint256[](rounds + 1);

        participantCount[1] = participants.length / 2;
        participantCount[2] = participantCount[1] / 2;
        participantCount[3] = participantCount[2] / 2;

        for (uint256 roundIndex = 1; roundIndex <= rounds; roundIndex++) {
            uint256 numMatches =
                badgeChampions.calculateMatchesInRound(roundIndex, participants.length);
            assertEq(numMatches, participantCount[roundIndex]);
            for (uint256 matchIndex = 0; matchIndex < numMatches; matchIndex++) {
                // Retrieve participants for the match
                (address participant1, address participant2) =
                    badgeChampions.getParticipants(roundIndex, matchIndex);

                // Simulate a battle and get the winner
                address winner = badgeChampions.getWinner(roundIndex, matchIndex);

                // Assertions to ensure correctness
                assertTrue(participant1 != participant2);
                assertTrue(participant1 == winner || participant2 == winner);
            }
        }
    }
}
