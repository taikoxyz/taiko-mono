// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadges } from "../../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../../util/Blacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { TrailblazersBadgesV3 } from
    "../../../contracts/trailblazers-badges/TrailblazersBadgesV3.sol";

contract TrailblazersBadgesV3Test is Test {
    UtilsScript public utils;

    TrailblazersBadges public tokenV2;
    TrailblazersBadgesV3 public tokenV3;

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

        tokenV2 = TrailblazersBadges(proxy);
        // upgrade to v3
        tokenV2.upgradeToAndCall(
            address(new TrailblazersBadgesV3()), abi.encodeCall(TrailblazersBadgesV3.version, ())
        );

        tokenV3 = TrailblazersBadgesV3(address(proxy));
        vm.stopBroadcast();
    }

    function test_mint() public {
        bytes32 _hash = tokenV3.getHash(minters[0], BADGE_ID);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mintSignerPk, _hash);

        bool canMint = tokenV3.canMint(abi.encodePacked(r, s, v), minters[0], BADGE_ID);
        assertTrue(canMint);

        vm.startPrank(minters[0]);
        tokenV3.mint(abi.encodePacked(r, s, v), BADGE_ID);
        vm.stopPrank();

        assertEq(tokenV3.balanceOf(minters[0]), 1);
    }

    function test_blacklist_mint_revert() public {
        test_mint();
        assertEq(tokenV3.balanceOf(minters[0]), 1);
        blacklist.add(minters[0]);

        vm.prank(minters[0]);
        vm.expectRevert();
        tokenV3.transferFrom(minters[0], minters[1], BADGE_ID);
    }
}
