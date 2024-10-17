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
import { BadgeMigration } from "../../contracts/trailblazers-season-2/BadgeMigration.sol";

contract TrailblazersBadgesS2Test is Test {
    UtilsScript public utils;

    TrailblazersBadgesV4 public s1BadgesV4;
    TrailblazersBadgesS2 public s2Badges;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];

    uint256 public BADGE_ID;

    MockBlacklist public blacklist;

    address mintSigner;
    uint256 mintSignerPk;

    bool constant PINK_TAMPER = true;
    bool constant PURPLE_TAMPER = false;

    uint256 public MAX_TAMPERS = 3;
    uint256 public COOLDOWN_MIGRATION = 1 hours;
    uint256 public COOLDOWN_TAMPER = 5 minutes;
    uint256 public TAMPER_WEIGHT_PERCENT = 5;

    BadgeMigration public migration;

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

        TrailblazerBadgesS1MintTo s1BadgesMock = TrailblazerBadgesS1MintTo(address(s1BadgesV2));

        BADGE_ID = s1BadgesV2.BADGE_RAVERS();

        // upgrade s1 contract to v4
        s1BadgesV2.upgradeToAndCall(
            address(new TrailblazersBadgesV4()), abi.encodeCall(TrailblazersBadgesV4.version, ())
        );

        s1BadgesV4 = TrailblazersBadgesV4(address(s1BadgesV2));

        // deploy the s2 erc1155 token contract

        impl = address(new TrailblazersBadgesS2());
        proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(TrailblazersBadgesS2.initialize, (address(migration), "ipfs://"))
            )
        );
        s2Badges = TrailblazersBadgesS2(proxy);

        // deploy the migration contract

        BadgeMigration.Config memory config = BadgeMigration.Config(
            COOLDOWN_MIGRATION, COOLDOWN_TAMPER, TAMPER_WEIGHT_PERCENT, MAX_TAMPERS
        );

        impl = address(new BadgeMigration());
        proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    BadgeMigration.initialize,
                    (address(s1BadgesV2), address(s2Badges), mintSigner, config)
                )
            )
        );
        migration = BadgeMigration(proxy);
        s1BadgesV4.setMigrationContract(address(migration));
        s2Badges.setMinter(address(migration));
        // enable migration for BADGE_ID
        uint256[] memory enabledBadgeIds = new uint256[](1);
        enabledBadgeIds[0] = BADGE_ID;
        migration.enableMigrations(enabledBadgeIds);

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

    function test_startMigration() public {
        mint_s1(minters[0], BADGE_ID);

        uint256 tokenId = s1BadgesV4.tokenOfOwnerByIndex(minters[0], 0);

        vm.startPrank(minters[0]);
        s1BadgesV4.approve(address(migration), tokenId);
        migration.startMigration(BADGE_ID);
        vm.stopPrank();
        /*
        assertEq(s1BadgesV2.balanceOf(minters[0]), 0);
        assertEq(s1BadgesV2.balanceOf(address(s2Badges)), 1);

        assertEq(s1BadgesV2.ownerOf(tokenId), address(s2Badges));

        assertEq(migration.isMigrationActive(minters[0]), true);*/
    }

    function wait(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    // happy-path, make 3 pink tampers, and 2 purple ones
    function test_tamperMigration() public {
        test_startMigration();

        vm.startPrank(minters[0]);
        for (uint256 i = 0; i < MAX_TAMPERS; i++) {
            wait(COOLDOWN_TAMPER);
            migration.tamperMigration(PINK_TAMPER);
        }

        wait(COOLDOWN_TAMPER);
        migration.tamperMigration(PURPLE_TAMPER);
        wait(COOLDOWN_TAMPER);
        migration.tamperMigration(PURPLE_TAMPER);

        vm.stopPrank();

        assertEq(migration.isTamperActive(minters[0]), true);
        assertEq(migration.isMigrationActive(minters[0]), true);

        (uint256 pinkTampers, uint256 purpleTampers) = migration.getMigrationTampers(minters[0]);
        assertEq(pinkTampers, MAX_TAMPERS);
        assertEq(purpleTampers, 2);
    }

    function test_revert_tooManyTampers() public {
        test_tamperMigration();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        migration.tamperMigration(PINK_TAMPER);

        vm.stopPrank();
    }

    function test_resetTampers() public {
        test_tamperMigration();
        assertEq(migration.isTamperActive(minters[0]), true);
        (uint256 pinkTampers, uint256 purpleTampers) = migration.getMigrationTampers(minters[0]);
        assertEq(pinkTampers, MAX_TAMPERS);
        assertEq(purpleTampers, 2);

        vm.prank(minters[0]);
        migration.resetTampers();

        assertEq(migration.isTamperActive(minters[0]), false);
        (pinkTampers, purpleTampers) = migration.getMigrationTampers(minters[0]);
        assertEq(pinkTampers, 0);
        assertEq(purpleTampers, 0);
    }

    function test_endMigration() public {
        test_tamperMigration();

        wait(COOLDOWN_TAMPER);
        wait(COOLDOWN_MIGRATION);

        // generate the claim hash for the current migration
        bytes32 claimHash = migration.generateClaimHash(
            minters[0],
            0 // experience points
        );

        // simulate the backend signing the hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, claimHash);

        // exercise the randomFromSignature function

        vm.startPrank(minters[0]);
        migration.endMigration(claimHash, v, r, s, 0);
        vm.stopPrank();

        // check for s1 burn
        assertEq(s1BadgesV4.balanceOf(minters[0]), 0);
        assertEq(s1BadgesV4.balanceOf(address(s2Badges)), 0);

        // check for s2 state reset
        assertEq(migration.isMigrationActive(minters[0]), false);
        assertEq(migration.isTamperActive(minters[0]), false);

        // check for s2 mint
        assertEq(s2Badges.balanceOf(minters[0], 1), 1);
    }

    function test_revert_startMigrationTwice() public {
        test_startMigration();
        vm.startPrank(minters[0]);
        vm.expectRevert();
        migration.startMigration(BADGE_ID);
        vm.stopPrank();
    }

    function test_revert_migrateDisabled() public {
        uint256 badgeId = s1BadgesV4.BADGE_ROBOTS();
        mint_s1(minters[0], badgeId);

        uint256 tokenId = s1BadgesV4.tokenOfOwnerByIndex(minters[0], 0);

        vm.startPrank(minters[0]);
        s1BadgesV4.approve(address(migration), tokenId);
        vm.expectRevert();
        migration.startMigration(badgeId);
        vm.stopPrank();
        // ensure no values got changed/updated
        assertEq(s1BadgesV4.balanceOf(minters[0]), 1);
        assertEq(s1BadgesV4.balanceOf(address(s2Badges)), 0);
        assertEq(s1BadgesV4.ownerOf(tokenId), minters[0]);
        assertEq(migration.isMigrationActive(minters[0]), false);
    }

    function test_revert_pausedContract() public {
        // have the admin pause the contract
        // ensure no badges are mintable afterwards
        vm.startPrank(owner);
        migration.pause();
        vm.stopPrank();

        mint_s1(minters[0], BADGE_ID);

        uint256 tokenId = s1BadgesV4.tokenOfOwnerByIndex(minters[0], 0);

        vm.startPrank(minters[0]);
        s1BadgesV4.approve(address(migration), tokenId);
        vm.expectRevert();
        migration.startMigration(BADGE_ID);
        vm.stopPrank();
        // ensure no values got changed/updated
        assertEq(s1BadgesV4.balanceOf(minters[0]), 1);
        assertEq(s1BadgesV4.balanceOf(address(s2Badges)), 0);
        assertEq(s1BadgesV4.ownerOf(tokenId), minters[0]);
        assertEq(migration.isMigrationActive(minters[0]), false);
    }

    function test_randomFromSignature() public view {
        bytes32 signatureHash = keccak256(
            abi.encodePacked(
                keccak256("1234567890"), // should use the block's hash
                minters[0]
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, signatureHash);

        uint256 random = migration.randomFromSignature(signatureHash, v, r, s);

        assertEq(
            random,
            28_417_844_340_632_250_945_870_465_294_567_768_196_388_504_060_802_704_441_612_911_129_119_444_309_664
        );
    }

    function test_setConfig() public {
        BadgeMigration.Config memory config = BadgeMigration.Config(1 hours, 5 minutes, 5, 3);
        vm.prank(owner);
        migration.setConfig(config);

        BadgeMigration.Config memory newConfig = migration.getConfig();

        assertEq(newConfig.cooldownMigration, 1 hours);
        assertEq(newConfig.cooldownTamper, 5 minutes);
        assertEq(newConfig.tamperWeightPercent, 5);
        assertEq(newConfig.maxTampers, 3);
    }

    function test_setConfig_revert__notOwner() public {
        BadgeMigration.Config memory config = BadgeMigration.Config(1 hours, 5 minutes, 5, 3);

        vm.startPrank(minters[0]);
        vm.expectRevert();
        migration.setConfig(config);
        vm.stopPrank();
    }
}
