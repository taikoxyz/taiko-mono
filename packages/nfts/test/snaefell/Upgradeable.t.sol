// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/src/Test.sol";
import { SnaefellToken } from "../../contracts/snaefell/SnaefellToken.sol";
import { Merkle } from "murky/Merkle.sol";
import "forge-std/src/StdJson.sol";
import { UtilsScript } from "../../script/snaefell/sol/Utils.s.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeableTest is Test {
    using stdJson for string;

    UtilsScript public utils;

    SnaefellToken public token;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];
    bytes32[] public leaves = new bytes32[](minters.length);

    uint256 constant FREE_MINTS = 5;

    Merkle tree = new Merkle();

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        // create whitelist merkle tree
        vm.startPrank(owner);
        bytes32 root = tree.getRoot(leaves);

        // deploy token with empty root
        address impl = address(new SnaefellToken());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    SnaefellToken.initialize, (address(0), "ipfs://", root, utils.getBlacklist())
                )
            )
        );

        token = SnaefellToken(proxy);
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
