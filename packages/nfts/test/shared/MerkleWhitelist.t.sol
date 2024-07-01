// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/src/Test.sol";
import "forge-std/src/StdJson.sol";
import { Merkle } from "murky/Merkle.sol";
import { MerkleWhitelist } from "../../contracts/taikoon/MerkleWhitelist.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";

/// @custom:oz-upgrades-from MerkleWhitelist
contract MerkleWhitelistForTest is MerkleWhitelist {
    function updateRoot(bytes32 _root) external {
        _updateRoot(_root);
    }

    function consumeMint(bytes32[] calldata _proof, uint256 _freeMints) external {
        _consumeMint(_proof, _freeMints);
    }
}

contract MerkleWhitelistTest is Test {
    Merkle tree;
    UtilsScript public utils;

    using stdJson for string;

    bytes32[] leaves;

    address public owner = vm.addr(0x5);

    MerkleWhitelistForTest whitelist;

    uint256 constant MAX_MINTS = 5;
    MockBlacklist public blacklist;

    function createLeaf(address _minter, uint256 _freeMints) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(_minter, _freeMints))));
    }

    address[3] minters = [address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        vm.startBroadcast(owner);
        blacklist = new MockBlacklist();

        tree = new Merkle();

        leaves = new bytes32[](2);

        leaves[0] = createLeaf(minters[0], MAX_MINTS);
        leaves[1] = createLeaf(minters[1], MAX_MINTS);

        bytes32 root = tree.getRoot(leaves);

        address impl = address(new MerkleWhitelistForTest());
        address proxy = address(
            new ERC1967Proxy(
                impl, abi.encodeCall(MerkleWhitelist.initialize, (address(0), root, blacklist))
            )
        );

        whitelist = MerkleWhitelistForTest(proxy);

        vm.stopBroadcast();
    }

    function test_canFreeMint() public {
        uint256 leafIndex = 0;
        bytes32[] memory proof = tree.getProof(leaves, leafIndex);
        bool initialCanMint = whitelist.canMint(minters[leafIndex], MAX_MINTS);
        assertEq(initialCanMint, true);

        vm.startPrank(minters[leafIndex]);

        whitelist.consumeMint(proof, MAX_MINTS);

        vm.stopPrank();
        bool finalCanMint = whitelist.canMint(minters[leafIndex], MAX_MINTS);
        assertEq(finalCanMint, false);
    }

    function test_updateRoot() public {
        tree = new Merkle();

        uint256 leafIndex = 2;

        leaves = new bytes32[](3);

        leaves[0] = createLeaf(minters[0], MAX_MINTS);
        leaves[1] = createLeaf(minters[1], MAX_MINTS);
        leaves[2] = createLeaf(minters[2], MAX_MINTS);

        bytes32 root = tree.getRoot(leaves);

        whitelist.updateRoot(root);
        assertEq(whitelist.root(), root);

        bool canMint = whitelist.canMint(minters[leafIndex], MAX_MINTS);
        assertEq(canMint, true);
    }

    function test_revert_freeMintsExceeded() public {
        uint256 leafIndex = 0;
        bytes32[] memory proof = tree.getProof(leaves, leafIndex);

        vm.startPrank(minters[leafIndex]);

        whitelist.consumeMint(proof, MAX_MINTS);

        vm.stopPrank();

        bool canMint = whitelist.canMint(minters[leafIndex], MAX_MINTS);
        assertEq(canMint, false);

        vm.startBroadcast(minters[leafIndex]);
        vm.expectRevert();
        whitelist.consumeMint(proof, MAX_MINTS);

        vm.stopBroadcast();
    }

    function test_revert_canMint_blacklisted() public {
        address blacklisted = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        vm.expectRevert();
        whitelist.canMint(blacklisted, MAX_MINTS);
    }
}
