// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import { Merkle } from "murky/Merkle.sol";
import { MerkleWhitelist } from "../contracts/MerkleWhitelist.sol";
import { Upgrades } from "@openzeppelin/foundry-upgrades/Upgrades.sol";

import { MerkleWhitelistTestWrapper } from "./MerkleWhitelistTestWrapper.sol";

contract MerkleWhitelistTest is Test {
    Merkle tree;

    using stdJson for string;

    bytes32[] leaves;

    address public owner = vm.addr(0x5);

    MerkleWhitelistTestWrapper whitelist;

    uint256 constant MAX_MINTS = 5;

    function createLeaf(address _minter, uint256 _freeMints) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(_minter, _freeMints))));
    }

    address[3] minters = [address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        vm.startBroadcast(owner);

        tree = new Merkle();

        leaves = new bytes32[](2);

        leaves[0] = createLeaf(minters[0], MAX_MINTS);
        leaves[1] = createLeaf(minters[1], MAX_MINTS);

        bytes32 root = tree.getRoot(leaves);

        address transparentProxy = Upgrades.deployTransparentProxy(
            "MerkleWhitelist.sol", owner, abi.encodeCall(MerkleWhitelist.initialize, (root))
        );

        Upgrades.upgradeProxy(transparentProxy, "MerkleWhitelistTestWrapper.sol", "");

        whitelist = MerkleWhitelistTestWrapper(transparentProxy);

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
}
