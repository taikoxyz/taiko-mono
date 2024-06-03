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
                abi.encodeCall(TrailblazersBadges.initialize, (
                    owner, "ipfs://", mintSigner, blacklist))
            )
        );

        token = TrailblazersBadges(proxy);

        vm.stopBroadcast();
    }

    function test_metadata() public view {

    }

    function test_canMint() public view {
        bytes32 _hash = token.getHash(
            minters[0],
            BADGE_ID
        );

        (uint8 v, bytes32 r, bytes32 s)  = vm.sign(mintSignerPk, _hash);

        bool canMint = token.canMint(
            abi.encodePacked(v, r, s),
            minters[0],
            BADGE_ID
        );
        assertTrue(canMint);
    }

    function test_mint() public {
        /*
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        bool canMint = token.canMint(user, MAX_MINTS);
        assertEq(canMint, true);

        vm.startPrank(user);
        uint256[] memory tokenIds = token.mint(proof, MAX_MINTS);
        vm.stopPrank();

        assertEq(token.balanceOf(user), MAX_MINTS);
        assertEq(tokenIds.length, MAX_MINTS);
        assertFalse(token.canMint(user, MAX_MINTS));

        string memory tokenURI = token.tokenURI(tokenIds[0]);
        assertEq(tokenURI, "ipfs:///1.json");
        */
    }


}
