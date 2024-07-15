// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/src/Test.sol";
import { TaikoonToken } from "../../contracts/taikoon/TaikoonToken.sol";
import { Merkle } from "murky/Merkle.sol";
import "forge-std/src/StdJson.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeableTest is Test {
    using stdJson for string;

    UtilsScript public utils;

    TaikoonToken public token;
    TaikoonToken public tokenV2;

    address public owner = vm.addr(0x5);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];
    bytes32[] public leaves = new bytes32[](minters.length);

    uint256 constant FREE_MINTS = 5;

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
        token = new TaikoonToken();
        address impl = address(token);

        ERC1967Proxy proxy = new ERC1967Proxy(
            impl, abi.encodeCall(TaikoonToken.initialize, (owner, "ipfs://", root, blacklist))
        );
        token = TaikoonToken(address(proxy));

        // mint tokens on the v1 deployment
        token.mint(minters[0], 5);

        // upgrade to v2

        token.upgradeToAndCall(
            address(new TaikoonToken()), abi.encodeCall(TaikoonToken.updateBaseURI, ("ipfs://v2//"))
        );

        tokenV2 = TaikoonToken(address(proxy));

        vm.stopBroadcast();
    }

    function test_upgraded_v2() public view {
        assertEq(tokenV2.name(), token.name());
        assertEq(tokenV2.symbol(), token.symbol());
        assertEq(tokenV2.totalSupply(), token.totalSupply());
        assertEq(tokenV2.maxSupply(), token.maxSupply());
    }

    function test_tokenURI() public view {
        assertEq(tokenV2.baseURI(), "ipfs://v2//");
        string memory uri = tokenV2.tokenURI(0);
        assertEq(uri, "ipfs://v2///0.json");
    }

    function test_updateBaseURI() public {
        vm.startBroadcast(owner);
        tokenV2.updateBaseURI("ipfs://test//");
        vm.stopBroadcast();

        assertEq(tokenV2.baseURI(), "ipfs://test//");
    }
}
