// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { TrailblazersBadgesS2 } from
    "../../contracts/trailblazers-season-2/TrailblazersBadgesS2.sol";
import { TrailblazerBadgesS1MintTo } from "../util/TrailblazerBadgesS1MintTo.sol";
import { TrailblazersBadgesV4 } from
    "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV4.sol";
import { BadgeRecruitment } from "../../contracts/trailblazers-season-2/BadgeRecruitment.sol";
import { BadgeRecruitmentV2 } from "../../contracts/trailblazers-season-2/BadgeRecruitmentV2.sol";

contract BadgeRecruitmentV2Test is Test {
    UtilsScript public utils;

    TrailblazersBadgesV4 public s1BadgesV4;
    TrailblazersBadgesS2 public s2Badges;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];

    uint256 public BADGE_ID;

    MockBlacklist public blacklist;

    address mintSigner;
    uint256 mintSignerPk;

    uint256 public MAX_INFLUENCES = 3;
    uint256 public COOLDOWN_RECRUITMENT = 1 hours;
    uint256 public COOLDOWN_INFLUENCE = 5 minutes;
    uint256 public INFLUENCE_WEIGHT_PERCENT = 5;
    uint256 public MAX_INFLUENCES_DIVIDER = 100;
    uint256 public DEFAULT_CYCLE_DURATION = 7 days;

    BadgeRecruitment public recruitmentV1;
    BadgeRecruitmentV2 public recruitment;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        blacklist = new MockBlacklist();
        // create whitelist merkle tree
        vm.startBroadcast(owner);

        (mintSigner, mintSignerPk) = makeAddrAndKey("mintSigner");

        // deploy token with empty root
        address impl = address(new TrailblazersBadges());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TrailblazersBadges.initialize, (owner, "ipfs://", mintSigner, blacklist)
                )
            )
        );

        TrailblazersBadges s1BadgesV2 = TrailblazersBadges(proxy);

        // upgrade s1 badges contract to use the mock version

        s1BadgesV2.upgradeToAndCall(
            address(new TrailblazerBadgesS1MintTo()),
            abi.encodeCall(TrailblazerBadgesS1MintTo.call, ())
        );

        BADGE_ID = s1BadgesV2.BADGE_RAVERS();

        // upgrade s1 contract to v4
        s1BadgesV2.upgradeToAndCall(
            address(new TrailblazersBadgesV4()), abi.encodeCall(TrailblazersBadgesV4.version, ())
        );

        s1BadgesV4 = TrailblazersBadgesV4(address(s1BadgesV2));

        // set cooldown recruitment
        s1BadgesV4.setRecruitmentLockDuration(365 days);

        // deploy the s2 erc1155 token contract

        impl = address(new TrailblazersBadgesS2());
        proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(TrailblazersBadgesS2.initialize, (address(recruitmentV1), "ipfs://"))
            )
        );
        s2Badges = TrailblazersBadgesS2(proxy);

        // deploy the recruitment contract

        BadgeRecruitment.Config memory config = BadgeRecruitment.Config(
            COOLDOWN_RECRUITMENT,
            COOLDOWN_INFLUENCE,
            INFLUENCE_WEIGHT_PERCENT,
            MAX_INFLUENCES,
            MAX_INFLUENCES_DIVIDER,
            DEFAULT_CYCLE_DURATION
        );

        impl = address(new BadgeRecruitment());
        proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    BadgeRecruitment.initialize,
                    (address(s1BadgesV2), address(s2Badges), mintSigner, config)
                )
            )
        );
        recruitmentV1 = BadgeRecruitment(proxy);

        // upgrade to V2
        recruitmentV1.upgradeToAndCall(
            address(new BadgeRecruitmentV2()), abi.encodeCall(BadgeRecruitmentV2.version, ())
        );

        recruitment = BadgeRecruitmentV2(address(recruitmentV1));

        s1BadgesV4.setRecruitmentContract(address(recruitment));
        s2Badges.setMinter(address(recruitment));
        // enable recruitment for BADGE_ID
        uint256[] memory enabledBadgeIds = new uint256[](1);
        enabledBadgeIds[0] = BADGE_ID;
        recruitment.enableRecruitments(enabledBadgeIds);

        vm.stopBroadcast();
    }

    function mint_s1(address minter, uint256 badgeId) public {
        bytes32 _hash = s1BadgesV4.getHash(minter, badgeId);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = s1BadgesV4.canMint(abi.encodePacked(r, s, v), minter, badgeId);
        assertTrue(canMint);

        vm.startPrank(minter);
        s1BadgesV4.mint(abi.encodePacked(r, s, v), badgeId);
        vm.stopPrank();
    }

    function test_mint_s1() public {
        mint_s1(minters[0], s1BadgesV4.BADGE_RAVERS());
        mint_s1(minters[0], s1BadgesV4.BADGE_ROBOTS());
        assertEq(s1BadgesV4.balanceOf(minters[0]), 2);

        mint_s1(minters[1], s1BadgesV4.BADGE_BOUNCERS());
        mint_s1(minters[1], s1BadgesV4.BADGE_MASTERS());
        assertEq(s1BadgesV4.balanceOf(minters[1]), 2);

        mint_s1(minters[2], s1BadgesV4.BADGE_MONKS());
        mint_s1(minters[2], s1BadgesV4.BADGE_DRUMMERS());
        assertEq(s1BadgesV4.balanceOf(minters[2]), 2);
    }

    function test_startRecruitment() public {
        mint_s1(minters[0], BADGE_ID);

        vm.prank(minters[0]);
        wait(100);
        s1BadgesV4.startRecruitment(BADGE_ID);

        uint256 tokenId = s1BadgesV4.getTokenId(minters[0], BADGE_ID);
        assertEq(s1BadgesV4.balanceOf(minters[0]), 1);
        assertEq(recruitment.isRecruitmentActive(minters[0]), true);
        assertEq(s1BadgesV4.unlockTimestamps(tokenId), block.timestamp + 365 days);
    }

    function wait(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    // happy-path, make 3 pink influences, and 2 purple ones
    function test_influenceRecruitment() public {
        test_startRecruitment();

        vm.startPrank(minters[0]);

        uint256 points = 0;
        bytes32 _hash =
            recruitment.generateClaimHash(BadgeRecruitment.HashType.Influence, minters[0], points);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        wait(COOLDOWN_INFLUENCE);

        recruitment.influenceRecruitment(
            _hash, v, r, s, points, BadgeRecruitment.InfluenceColor.Minnow
        );
        wait(COOLDOWN_INFLUENCE);

        recruitment.influenceRecruitment(
            _hash, v, r, s, points, BadgeRecruitment.InfluenceColor.Minnow
        );

        for (uint256 i = 0; i < MAX_INFLUENCES; i++) {
            wait(COOLDOWN_INFLUENCE);
            recruitment.influenceRecruitment(
                _hash, v, r, s, points, BadgeRecruitment.InfluenceColor.Whale
            );
        }

        vm.stopPrank();

        assertEq(recruitment.isInfluenceActive(minters[0]), true);
        assertEq(recruitment.isRecruitmentActive(minters[0]), true);

        (uint256 whaleInfluences, uint256 minnowInfluences) =
            recruitment.getRecruitmentInfluences(minters[0]);

        assertEq(whaleInfluences, MAX_INFLUENCES);
        assertEq(minnowInfluences, 0);
    }

    function test_revert_tooManyInfluences() public {
        uint256 points = 0;
        bytes32 _hash =
            recruitment.generateClaimHash(BadgeRecruitment.HashType.Influence, minters[0], points);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        test_influenceRecruitment();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        recruitment.influenceRecruitment(
            _hash, v, r, s, points, BadgeRecruitment.InfluenceColor.Whale
        );

        vm.stopPrank();
    }

    function test_endRecruitment() public {
        test_influenceRecruitment();

        wait(COOLDOWN_INFLUENCE);
        wait(COOLDOWN_RECRUITMENT);

        // generate the claim hash for the current recruitment
        bytes32 claimHash = recruitment.generateClaimHash(
            BadgeRecruitment.HashType.End,
            minters[0],
            0 // experience points
        );

        // simulate the backend signing the hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, claimHash);

        // exercise the randomFromSignature function

        vm.prank(minters[0]);
        recruitment.endRecruitment(claimHash, v, r, s, 0);

        // check for s2 state reset
        assertEq(recruitment.isRecruitmentActive(minters[0]), false);
        assertEq(recruitment.isInfluenceActive(minters[0]), false);

        // check for s2 mint
        assertEq(s2Badges.balanceOf(minters[0], 1), 1);
    }

    function test_startRecruitment_expBased() public {
        uint256 points = 100;
        bytes32 _hash =
            recruitment.generateClaimHash(BadgeRecruitment.HashType.Start, minters[0], points);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        vm.prank(minters[0]);
        recruitment.startRecruitment(_hash, v, r, s, points);

        assertEq(recruitment.isRecruitmentActive(minters[0]), true);
    }

    function test_startRecruitment_expBased_revert_hashMismatch() public {
        mint_s1(minters[0], BADGE_ID);

        uint256 points = 100;
        bytes32 _hash =
            recruitment.generateClaimHash(BadgeRecruitment.HashType.Start, minters[0], points);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        vm.prank(minters[0]);
        vm.expectRevert(BadgeRecruitment.HASH_MISMATCH.selector);
        recruitment.startRecruitment(_hash, v, s, r, points + 1);
    }

    function test_startRecruitment_expBased_revert_hashAlreadyClaimed() public {
        vm.startPrank(minters[0]);

        uint256 points = 100;
        bytes32 _hash =
            recruitment.generateClaimHash(BadgeRecruitment.HashType.Start, minters[0], points);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        recruitment.startRecruitment(_hash, v, r, s, points);

        assertEq(recruitment.isRecruitmentActive(minters[0]), true);

        // complete the migration
        wait(COOLDOWN_INFLUENCE);
        wait(COOLDOWN_RECRUITMENT);

        // generate the claim hash for the current recruitment
        bytes32 claimHash = recruitment.generateClaimHash(
            BadgeRecruitment.HashType.End,
            minters[0],
            0 // experience points
        );

        // simulate the backend signing the hash
        (v, r, s) = vm.sign(mintSignerPk, claimHash);

        // exercise the randomFromSignature function

        recruitment.endRecruitment(claimHash, v, r, s, 0);

        // check for s2 state reset
        assertEq(recruitment.isRecruitmentActive(minters[0]), false);
        assertEq(recruitment.isInfluenceActive(minters[0]), false);

        // check for s2 mint
        assertEq(s2Badges.balanceOf(minters[0], 1), 1);

        // fail to re-use the same claim hash
        bytes32 _hash2 =
            recruitment.generateClaimHash(BadgeRecruitment.HashType.Start, minters[0], points);

        assertEq(_hash, _hash2);
        vm.expectRevert(BadgeRecruitmentV2.HASH_ALREADY_CLAIMED.selector);
        recruitment.startRecruitment(_hash, v, r, s, points);
    }
}
