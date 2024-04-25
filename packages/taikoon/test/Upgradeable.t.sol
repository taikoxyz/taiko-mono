// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { TaikoonToken } from "../contracts/TaikoonToken.sol";
import { Merkle } from "murky/Merkle.sol";
import { MerkleMintersScript } from "../script/MerkleMinters.s.sol";
import "forge-std/StdJson.sol";

import { Upgrades } from "@openzeppelin/foundry-upgrades/Upgrades.sol";

contract UpgradeableTest is Test {
    using stdJson for string;

    TaikoonToken public token;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];
    bytes32[] public leaves = new bytes32[](minters.length);

    MerkleMintersScript merkleMinters = new MerkleMintersScript();

    uint256 constant FREE_MINTS = 5;

    Merkle tree = new Merkle();

    function setUp() public {
        // create whitelist merkle tree
        vm.startPrank(owner);
        bytes32 root = tree.getRoot(leaves);

        // deploy token with empty root
        address proxy = Upgrades.deployUUPSProxy(
            "TaikoonToken.sol", abi.encodeCall(TaikoonToken.initialize, ("ipfs://", root))
        );

        token = TaikoonToken(proxy);
        // use the token to calculate leaves
        for (uint256 i = 0; i < minters.length; i++) {
            leaves[i] = token.leaf(minters[i], FREE_MINTS);
        }
        // update the root
        root = tree.getRoot(leaves);
        token.updateRoot(root);
        vm.stopPrank();
    }
}
