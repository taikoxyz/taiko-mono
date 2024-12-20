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
import { TrailblazersBadgesV7 } from
    "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV7.sol";
import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV8.sol";
import { BadgeRecruitment } from "../../contracts/trailblazers-season-2/BadgeRecruitment.sol";
import { BadgeRecruitmentV2 } from "../../contracts/trailblazers-season-2/BadgeRecruitmentV2.sol";
import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV7.sol";

contract TrailblazersS1BadgesV8 is Test {
    UtilsScript public utils;

    TrailblazersBadgesV8 public s1BadgesV8;
    TrailblazersBadgesV7 public s1BadgesV7;
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

    uint256 public SEASON_2_END = 2_000_000_000;
    uint256 public SEASON_3_END = 3_000_000_000;

    uint256 public TOKEN_ID = 1;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        blacklist = new MockBlacklist();
        // create whitelist merkle tree
        vm.startPrank(owner);

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
            address(new TrailblazersBadgesV7()), abi.encodeCall(TrailblazersBadgesV7.version, ())
        );

        s1BadgesV7 = TrailblazersBadgesV7(address(s1BadgesV2));

        // upgrade to v7
        s1BadgesV7.upgradeToAndCall(
            address(new TrailblazersBadgesV7()), abi.encodeCall(TrailblazersBadgesV7.version, ())
        );

        s1BadgesV7 = TrailblazersBadgesV7(address(s1BadgesV7));

        // set cooldown recruitment
        s1BadgesV7.setRecruitmentLockDuration(7 days);

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

        s1BadgesV7.setRecruitmentContract(address(recruitmentV1));
        s2Badges.setMinter(address(recruitmentV1));
        // enable recruitment for BADGE_ID
        uint256[] memory enabledBadgeIds = new uint256[](1);
        enabledBadgeIds[0] = BADGE_ID;
        recruitmentV1.enableRecruitments(enabledBadgeIds);

        recruitmentV1.upgradeToAndCall(
            address(new BadgeRecruitmentV2()), abi.encodeCall(BadgeRecruitmentV2.version, ())
        );

        recruitment = BadgeRecruitmentV2(address(recruitmentV1));

        assertEq(recruitment.version(), "V2");

        s1BadgesV7.setRecruitmentContractV2(address(recruitment));

        vm.stopPrank();
    }

    function wait(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    function test_upgrade() public {
        vm.startPrank(owner);
        s1BadgesV7.upgradeToAndCall(
            address(new TrailblazersBadgesV8()), abi.encodeCall(TrailblazersBadgesV8.version, ())
        );

        s1BadgesV8 = TrailblazersBadgesV8(address(s1BadgesV7));
        s1BadgesV8.setSeason2EndTimestamp(SEASON_2_END);
        s1BadgesV8.setSeason3EndTimestamp(SEASON_3_END);
        assertEq(s1BadgesV8.version(), "V8");
        vm.stopPrank();
    }

    function test_migrateS2_transferAfter() public {
        //   vm.warp(0);
        // mint a badge
        test_upgrade();

        address minter = minters[0];
        vm.startPrank(minter);

        // mint the s1 badge
        bytes32 _hash = s1BadgesV8.getHash(minter, BADGE_ID);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = s1BadgesV8.canMint(abi.encodePacked(r, s, v), minter, BADGE_ID);
        assertTrue(canMint);

        s1BadgesV8.mint(abi.encodePacked(r, s, v), BADGE_ID);
        uint256 tokenId = s1BadgesV8.tokenOfOwnerByIndex(minter, 0);

        // mint and transfer to minter a secondary badge with id 0

        vm.startPrank(minters[1]);
        _hash = s1BadgesV8.getHash(minters[1], BADGE_ID);
        (v, r, s) = vm.sign(mintSignerPk, _hash);
        canMint = s1BadgesV8.canMint(abi.encodePacked(r, s, v), minters[1], BADGE_ID);
        assertTrue(canMint);

        s1BadgesV8.mint(abi.encodePacked(r, s, v), BADGE_ID);
        uint256 secondTokenId = s1BadgesV8.tokenOfOwnerByIndex(minters[1], 0);

        s1BadgesV8.transferFrom(minters[1], minter, secondTokenId);

        // ensure balances
        assertEq(s1BadgesV8.balanceOf(minter), 2);
        assertEq(s1BadgesV8.balanceOf(minters[1]), 0);
        vm.stopPrank();

        // start migration with first badge, using v1 methods
        vm.startPrank(minter);
        wait(100);
        s1BadgesV8.startRecruitment(BADGE_ID, tokenId);
        assertEq(recruitment.isRecruitmentActive(minter), true);
        assertEq(s1BadgesV8.balanceOf(minter), 2);
        assertEq(s1BadgesV8.unlockTimestamps(tokenId), SEASON_2_END);

        // and end it
        wait(COOLDOWN_INFLUENCE);
        wait(COOLDOWN_RECRUITMENT);

        // generate the claim hash for the current recruitment
        bytes32 claimHash = recruitment.generateClaimHash(
            BadgeRecruitment.HashType.End,
            minter,
            0 // experience points
        );

        // simulate the backend signing the hash
        (v, r, s) = vm.sign(mintSignerPk, claimHash);

        // exercise the randomFromSignature function
        recruitment.endRecruitment(claimHash, v, r, s, 0);

        // check for s2 state reset
        assertEq(recruitment.isRecruitmentActive(minter), false);
        assertEq(recruitment.isInfluenceActive(minter), false);

        // check for s2 mint
        assertEq(s2Badges.balanceOf(minter, 1), 1);

        // open a second migration cycle
        vm.stopPrank();
        vm.startPrank(owner);

        // enable recruitment for BADGE_ID
        uint256[] memory enabledBadgeIds = new uint256[](1);
        enabledBadgeIds[0] = BADGE_ID;
        recruitment.forceDisableAllRecruitments();
        recruitment.enableRecruitments(enabledBadgeIds);
        vm.stopPrank();

        // expect legacy method to fail
        vm.startPrank(minter);
        wait(100);
        vm.expectRevert(TrailblazersBadgesV4.BADGE_LOCKED.selector);
        s1BadgesV8.startRecruitment(BADGE_ID, tokenId);
        // time to start the second migration
        wait(100);

        s1BadgesV8.startRecruitment(BADGE_ID, secondTokenId);
        assertEq(recruitment.isRecruitmentActive(minter), true);
        assertEq(s1BadgesV8.balanceOf(minter), 2);
        assertEq(s1BadgesV8.unlockTimestamps(secondTokenId), SEASON_2_END);

        // ensure badge is frozen during season 2
        vm.warp(SEASON_2_END - block.timestamp - 1);
        vm.expectRevert(TrailblazersBadgesV4.BADGE_LOCKED.selector);
        s1BadgesV8.transferFrom(minter, minters[1], tokenId);
        vm.expectRevert(TrailblazersBadgesV4.BADGE_LOCKED.selector);
        s1BadgesV8.transferFrom(minter, minters[1], secondTokenId);

        // finish the cycle
        vm.stopPrank();
        vm.startPrank(owner);
        recruitment.forceDisableAllRecruitments();

        // finish the season
        vm.warp(SEASON_2_END + 1);

        // start recruitments
        recruitment.enableRecruitments(enabledBadgeIds);
        vm.stopPrank();

        vm.startPrank(minter);
        // properly transfer secondTokenId
        s1BadgesV8.transferFrom(minter, minters[1], secondTokenId);

        // run full recruitment with s1 badge again
        wait(100);
        s1BadgesV8.startRecruitment(BADGE_ID, tokenId);
        assertEq(recruitment.isRecruitmentActive(minter), true);
        assertEq(s1BadgesV8.unlockTimestamps(tokenId), SEASON_3_END);

        // and end it
        wait(COOLDOWN_INFLUENCE);
        wait(COOLDOWN_RECRUITMENT);

        // generate the claim hash for the current recruitment
        claimHash = recruitment.generateClaimHash(
            BadgeRecruitment.HashType.End,
            minter,
            0 // experience points
        );

        // simulate the backend signing the hash
        (v, r, s) = vm.sign(mintSignerPk, claimHash);

        // exercise the randomFromSignature function
        recruitment.endRecruitment(claimHash, v, r, s, 0);

        // ensure the badge is frozen during s2
        vm.expectRevert(TrailblazersBadgesV6.BADGE_LOCKED_SEASON_2.selector);
        s1BadgesV8.transferFrom(minter, minters[1], tokenId);

        // end s3 now
        vm.warp(SEASON_3_END + 1);

        // ensure the badge can be transfered
        s1BadgesV8.transferFrom(minter, minters[1], tokenId);
        assertEq(s1BadgesV8.balanceOf(minters[1]), 2);
        assertEq(s1BadgesV8.balanceOf(minter), 0);

        vm.stopPrank();
    }
}
