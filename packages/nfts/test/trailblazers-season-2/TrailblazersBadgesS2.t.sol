// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { TrailblazersBadgesS2 } from
    "../../contracts/trailblazers-season-2/TrailblazersBadgesS2.sol";

contract TrailblazersBadgesS2Test is Test {
    UtilsScript public utils;

    address public owner = vm.addr(0x5);
    address public authorizedMinter = vm.addr(0x6);
    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];

    string public uriTemplate = "ipfs://hash/";

    TrailblazersBadgesS2 public nft;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        // create whitelist merkle tree
        vm.startBroadcast(owner);

        address impl = address(new TrailblazersBadgesS2());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(TrailblazersBadgesS2.initialize, (authorizedMinter, uriTemplate))
            )
        );

        nft = TrailblazersBadgesS2(proxy);

        vm.stopBroadcast();
    }

    function test_mint() public {
        vm.prank(authorizedMinter);
        nft.mint(
            minters[0],
            TrailblazersBadgesS2.BadgeType.Ravers,
            TrailblazersBadgesS2.MovementType.Minnow
        );

        assertEq(nft.balanceOf(minters[0], 1), 1);
    }

    function test_mint_revert__notAuthorizedMinter() public {
        vm.prank(minters[1]);
        vm.expectRevert();
        nft.mint(
            minters[1],
            TrailblazersBadgesS2.BadgeType.Ravers,
            TrailblazersBadgesS2.MovementType.Minnow
        );
    }
}
