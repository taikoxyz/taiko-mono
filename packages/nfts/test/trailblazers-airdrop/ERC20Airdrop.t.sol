// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { ERC20Airdrop } from "../../contracts/trailblazers-airdrop/ERC20Airdrop.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UtilsScript } from "../../script/taikoon/sol/Utils.s.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ERC20Mock } from "../util/MockTokens.sol";

contract ERC20AirdropTest is Test {
    UtilsScript public utils;

    ERC20Airdrop public airdrop;

    address public owner = vm.addr(0x5);

    address[3] public minters = [
        vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80),
        vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d),
        vm.addr(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a)
    ];

    bytes32[] public leaves = [
        bytes32(0xbe00dd3c5d43551e03bf9a60316bee19ede94bf34486c39398c4f9f3b309d7a3),
        bytes32(0xa097cea9c873bd65b34c8d7d543e90ac1e18e5ec72c17cd95dedd0b52f02022e)
    ];

    Merkle tree = new Merkle();

    address mintSigner;
    uint256 mintSignerPk;

    ///////////////////////////////
    uint64 constant CLAIM_START = 100;
    uint64 constant CLAIM_END = 200;

    ERC20Mock public erc20;

    MockBlacklist public blacklist;

    uint256 constant TOTAL_AVAILABLE_FUNDS = 1000 ether;

    uint256 constant CLAIM_AMOUNT = 1 ether;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        // create whitelist merkle tree
        vm.startBroadcast(owner);

        // mock tree
        bytes32 merkleRoot = tree.getRoot(leaves);

        // deploy supplementary contracts
        erc20 = new ERC20Mock();

        blacklist = new MockBlacklist();

        // deploy airdrop with empty root
        address impl = address(new ERC20Airdrop());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    ERC20Airdrop.init,
                    (owner, CLAIM_START, CLAIM_END, merkleRoot, erc20, address(blacklist))
                )
            )
        );

        airdrop = ERC20Airdrop(proxy);

        // fund the airdrop contract
        erc20.mint(owner, TOTAL_AVAILABLE_FUNDS);
        erc20.transfer(address(airdrop), TOTAL_AVAILABLE_FUNDS);

        vm.stopBroadcast();
    }

    function test_revert_claim_beforeClaimStart() public {
        vm.warp(CLAIM_START - 1);
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(user, CLAIM_AMOUNT, proof);
    }

    function test_revert_claim_afterClaimEnd() public {
        vm.warp(CLAIM_END + 1);
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(user, CLAIM_AMOUNT, proof);
    }

    function test_claim() public {
        vm.warp(CLAIM_START + 1);
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        airdrop.claim(user, CLAIM_AMOUNT, proof);

        assertEq(erc20.balanceOf(user), CLAIM_AMOUNT);
        assertEq(erc20.balanceOf(address(airdrop)), TOTAL_AVAILABLE_FUNDS - CLAIM_AMOUNT);
    }

    function test_revert_claim_twice() public {
        test_claim();
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(user, CLAIM_AMOUNT, proof);
    }

    function test_revert_blacklisted_mint() public {
        vm.warp(CLAIM_START + 1);

        address user = minters[0];
        blacklist.add(user);

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(user, CLAIM_AMOUNT, proof);
    }

    function test_transferOwnership() public {
        assertEq(airdrop.owner(), owner);
        vm.prank(owner);
        airdrop.transferOwnership(minters[0]);
        vm.prank(minters[0]);
        airdrop.acceptOwnership();
        assertEq(airdrop.owner(), minters[0]);
    }
}
