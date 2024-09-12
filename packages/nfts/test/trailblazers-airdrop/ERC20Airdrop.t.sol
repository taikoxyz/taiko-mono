// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { AirdropVault } from "../../contracts/trailblazers-airdrop/AirdropVault.sol";
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

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];
    bytes32[] public leaves = new bytes32[](minters.length);

    uint256 constant BADGE_ID = 5;

    Merkle tree = new Merkle();

    address mintSigner;
    uint256 mintSignerPk;

    ///////////////////////////////
    uint256 constant CLAIM_START = 100;
    uint256 constant CLAIM_END = 200;

    ERC20Mock public erc20;

    MockBlacklist public blacklist;

    AirdropVault public vault;

    uint256 constant TOTAL_AVAILABLE_FUNDS = 1000 ether;

    uint256 constant CLAIM_AMOUNT = 10 ether;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();
        // create whitelist merkle tree
        vm.startBroadcast(owner);
        bytes32 root = tree.getRoot(leaves);

        // deploy supplementary contracts
        erc20 = new ERC20Mock();

        blacklist = new MockBlacklist();

        vault = new AirdropVault(erc20);

        // fund the vault
        erc20.mint(address(vault), TOTAL_AVAILABLE_FUNDS);

        // deploy airdrop with empty root
        address impl = address(new ERC20Airdrop());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    ERC20Airdrop.initialize, (CLAIM_START, CLAIM_END, root, erc20, blacklist, vault)
                )
            )
        );

        airdrop = ERC20Airdrop(proxy);

        // update the merkle tree
        for (uint256 i = 0; i < minters.length; i++) {
            leaves[i] = airdrop.leaf(minters[i], CLAIM_AMOUNT);
        }
        // update the root
        root = tree.getRoot(leaves);
        airdrop.updateRoot(root);

        // authorize the airdrop to interact with the vault
        vault.approveAirdropContractAsSpender(address(airdrop), TOTAL_AVAILABLE_FUNDS);

        vm.stopBroadcast();
    }

    function test_canClaim() public view {
        for (uint256 i = 0; i < minters.length; i++) {
            assertTrue(airdrop.canClaim(minters[i], CLAIM_AMOUNT));
        }
    }

    function test_revert_claim_beforeClaimStart() public {
        vm.warp(CLAIM_START - 1);
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(CLAIM_AMOUNT, proof);
    }

    function test_revert_claim_afterClaimEnd() public {
        vm.warp(CLAIM_END + 1);
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(CLAIM_AMOUNT, proof);
    }

    function test_claim() public {
        vm.warp(CLAIM_START + 1);
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        assertTrue(airdrop.canClaim(user, CLAIM_AMOUNT));

        vm.prank(user);
        airdrop.claim(CLAIM_AMOUNT, proof);

        assertEq(erc20.balanceOf(user), CLAIM_AMOUNT);
        assertEq(erc20.balanceOf(address(vault)), TOTAL_AVAILABLE_FUNDS - CLAIM_AMOUNT);
        assertFalse(airdrop.canClaim(user, CLAIM_AMOUNT));
    }

    function test_revert_claim_twice() public {
        test_claim();
        address user = minters[0];

        bytes32[] memory proof = tree.getProof(leaves, 0);

        assertFalse(airdrop.canClaim(user, CLAIM_AMOUNT));

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(CLAIM_AMOUNT, proof);
    }

    function test_revert_blacklisted_mint() public {
        vm.warp(CLAIM_START + 1);

        address user = minters[0];
        blacklist.add(user);

        bytes32[] memory proof = tree.getProof(leaves, 0);

        vm.prank(user);
        vm.expectRevert();
        airdrop.claim(CLAIM_AMOUNT, proof);
    }
}
