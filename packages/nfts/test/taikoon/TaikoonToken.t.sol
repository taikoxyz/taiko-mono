// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TaikoonToken } from "../../contracts/taikoon/TaikoonToken.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";

contract TaikoonTokenTest is Test {
    UtilsScript public utils;

    TaikoonToken public token;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];
    bytes32[] public leaves = new bytes32[](minters.length);

    uint256 constant MAX_MINTS = 5;

    MockBlacklist public blacklist;

    Merkle tree = new Merkle();

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        blacklist = new MockBlacklist();
        // create whitelist merkle tree
        vm.startBroadcast(owner);
        bytes32 root = tree.getRoot(leaves);

        // deploy token with empty root
        address impl = address(new TaikoonToken());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(TaikoonToken.initialize, (address(0), "ipfs://", root, blacklist))
            )
        );

        token = TaikoonToken(proxy);
        // use the token to calculate leaves
        for (uint256 i = 0; i < minters.length; i++) {
            leaves[i] = token.leaf(minters[i], MAX_MINTS);
        }
        // update the root
        root = tree.getRoot(leaves);
        token.updateRoot(root);
        vm.stopBroadcast();
    }

    function test_metadata() public view {
        assertEq(token.name(), "Taikoon");
        assertEq(token.symbol(), "TKOON");
        assertEq(token.totalSupply(), 0);
        assertEq(token.maxSupply(), 888);
    }

    function test_mint() public {
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
    }

    function test_updateRoot() public {
        uint256 leafIndex = 2;
        bytes32[] memory _leaves = new bytes32[](3);

        _leaves[0] = token.leaf(minters[0], MAX_MINTS);
        _leaves[1] = token.leaf(minters[1], MAX_MINTS);
        _leaves[2] = token.leaf(minters[2], MAX_MINTS);

        Merkle _tree = new Merkle();
        bytes32 root = _tree.getRoot(_leaves);
        vm.startPrank(owner);
        token.updateRoot(root);
        vm.stopPrank();
        assertEq(token.root(), root);

        bool canMint = token.canMint(minters[leafIndex], MAX_MINTS);
        assertEq(canMint, true);
    }

    function test_mintOwner() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = token.mint(owner, 5);
        vm.stopPrank();

        assertEq(token.balanceOf(owner), 5);
        assertEq(tokenIds.length, 5);
    }

    function test_revert_mint_blacklisted() public {
        address blacklisted =
            vm.addr(0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6);
        vm.startBroadcast(blacklisted);
        bytes32[] memory fakeProof = tree.getProof(leaves, 0);
        vm.expectRevert();
        token.mint(fakeProof, MAX_MINTS);
        vm.stopBroadcast();
    }
}
