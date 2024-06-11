// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TrailblazersBadgesTest is Test {
    UtilsScript public utils;

    TrailblazersBadges public token;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];

    uint256 constant BADGE_ID = 5;

    MockBlacklist public blacklist;

    Merkle tree = new Merkle();

    address mintSigner;
    uint256 mintSignerPk;

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

        token = TrailblazersBadges(proxy);

        vm.stopBroadcast();
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

    function test_canMint_true() public view {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);
    }

    // send the signature for minters[0] but check for minters[1]
    function test_canMint_false() public view {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[1], BADGE_ID);
        assertFalse(canMint);
    }

    function test_mint() public {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);

        vm.startPrank(minters[0]);
        token.mint(abi.encodePacked(r, s, v), BADGE_ID);
        vm.stopPrank();

        assertEq(token.balanceOf(minters[0]), 1);
    }

    function test_mint_revert_notAuthorized() public {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);

        vm.expectRevert();
        token.mint(abi.encodePacked(r, s, v), minters[1], BADGE_ID);
    }

    function test_mint_revert_invalidBadgeId() public {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);

        vm.expectRevert();
        token.mint(abi.encodePacked(r, s, v), minters[0], 8);
    }

    function test_mint_owner() public {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);

        vm.startPrank(owner);
        token.mint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        vm.stopPrank();

        assertEq(token.balanceOf(minters[0]), 1);
    }

    function test_mint_revert_remintSameSignature() public {
        bytes32 _hash = token.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);

        vm.startBroadcast(minters[0]);
        token.mint(abi.encodePacked(r, s, v), BADGE_ID);
        assertEq(token.balanceOf(minters[0]), 1);

        // fail re-minting
        vm.expectRevert();
        token.mint(abi.encodePacked(r, s, v), BADGE_ID);
        vm.stopBroadcast();
    }

    function test_setMovement_selfWallet() public {
        vm.startBroadcast(minters[0]);

        token.setMovement(token.MOVEMENT_BASED());
        assertEq(token.movements(minters[0]), token.MOVEMENT_BASED());
        vm.stopBroadcast();
    }

    function test_setMovement_owner() public {
        vm.startBroadcast(owner);

        token.setMovement(minters[0], token.MOVEMENT_BASED());
        assertEq(token.movements(minters[0]), token.MOVEMENT_BASED());
        vm.stopBroadcast();
    }

    function test_revert_setMovement_notOwner() public {
        uint256 movement = token.MOVEMENT_BASED();
        vm.startBroadcast(minters[0]);
        vm.expectRevert();
        token.setMovement(minters[0], movement);
        vm.stopBroadcast();
    }

    function test_uri() public {
        uint256 badgeId = token.BADGE_DRUMMERS();
        uint256 movementId = token.MOVEMENT_BASED();

        // mint the badge

        vm.startBroadcast(owner);
        bytes32 _hash = token.getHash(minters[0], badgeId);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], badgeId);
        assertTrue(canMint);

        token.mint(abi.encodePacked(r, s, v), minters[0], badgeId);

        // set the user state to based
        token.setMovement(minters[0], movementId);

        vm.stopBroadcast();

        // check the token URI

        uint256 tokenId = token.getTokenId(minters[0], badgeId);
        vm.assertEq(tokenId, 1);

        string memory uri = token.tokenURI(tokenId);

        vm.assertEq(uri, "ipfs:///1/5");
    }

    function test_badgeBalances() public {
        // mint a token to minter 0
        uint256 badgeId = token.BADGE_DRUMMERS();

        // mint the badge

        vm.startBroadcast(owner);
        bytes32 _hash = token.getHash(minters[0], badgeId);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], badgeId);
        assertTrue(canMint);

        token.mint(abi.encodePacked(r, s, v), minters[0], badgeId);
        vm.stopBroadcast();

        bool[] memory badges = token.badgeBalances(minters[0]);
        // ensure only badgeId = 5 (Drummers) is true
        vm.assertFalse(badges[token.BADGE_RAVERS()]);
        vm.assertFalse(badges[token.BADGE_ROBOTS()]);
        vm.assertFalse(badges[token.BADGE_BOUNCERS()]);
        vm.assertFalse(badges[token.BADGE_MASTERS()]);
        vm.assertFalse(badges[token.BADGE_MONKS()]);
        vm.assertTrue(badges[token.BADGE_DRUMMERS()]);
        vm.assertFalse(badges[token.BADGE_ANDROIDS()]);
        vm.assertFalse(badges[token.BADGE_SHINTO()]);
    }

    function test_transfer_dataConsistency() public {
        // TODO: ensure the values are properly re-assigned after a transfer

        // mint the token for minters[0]

        // mint a token to minter 0
        uint256 badgeId = token.BADGE_DRUMMERS();

        // mint the badge

        vm.startBroadcast(owner);
        bytes32 _hash = token.getHash(minters[0], badgeId);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(abi.encodePacked(r, s, v), minters[0], badgeId);
        assertTrue(canMint);

        token.mint(abi.encodePacked(r, s, v), minters[0], badgeId);
        vm.stopBroadcast();

        // transfer to minters[1]
        vm.startBroadcast(minters[0]);
        token.safeTransferFrom(minters[0], minters[1], 1);

        // ensure the badge balances are consistent
        bool[] memory badges = token.badgeBalances(minters[1]);

        // ensure only badgeId = 5 (Drummers) is true
        vm.assertFalse(badges[token.BADGE_RAVERS()]);
        vm.assertFalse(badges[token.BADGE_ROBOTS()]);
        vm.assertFalse(badges[token.BADGE_BOUNCERS()]);
        vm.assertFalse(badges[token.BADGE_MASTERS()]);
        vm.assertFalse(badges[token.BADGE_MONKS()]);
        vm.assertTrue(badges[token.BADGE_DRUMMERS()]);
        vm.assertFalse(badges[token.BADGE_ANDROIDS()]);
        vm.assertFalse(badges[token.BADGE_SHINTO()]);

        vm.stopBroadcast();

        // ensure wallets[0] has no badges
        badges = token.badgeBalances(minters[0]);

        vm.assertFalse(badges[token.BADGE_RAVERS()]);
        vm.assertFalse(badges[token.BADGE_ROBOTS()]);
        vm.assertFalse(badges[token.BADGE_BOUNCERS()]);
        vm.assertFalse(badges[token.BADGE_MASTERS()]);
        vm.assertFalse(badges[token.BADGE_MONKS()]);
        vm.assertFalse(badges[token.BADGE_DRUMMERS()]);
        vm.assertFalse(badges[token.BADGE_ANDROIDS()]);
        vm.assertFalse(badges[token.BADGE_SHINTO()]);

        // check the token IDs
        vm.assertEq(token.getTokenId(minters[0], badgeId), 0);
        vm.assertEq(token.getTokenId(minters[1], badgeId), 1);
    }
}
