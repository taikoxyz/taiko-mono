// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20Airdrop as Airdrop } from
    "../../../contracts/team/airdrop/ERC20Airdrop.sol";
import { BaseAirdrop } from "../../../contracts/team/airdrop/BaseAirdrop.sol";
import { Test } from "forge-std/Test.sol";
import { ERC20 } from
    "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000e18);
    }
}

contract TestERC20Airdrop is Test {
    address internal Alice = vm.addr(0x1);
    address internal Bob = vm.addr(0x2);
    address internal Carol = vm.addr(0x3);
    address internal Dave = vm.addr(0x4);
    address internal Elvis = vm.addr(0x5);
    address internal ERC20VaultDAO = vm.addr(0x6);

    bytes32 merkleRoot =
        0x78b9f3cb2305b16d69474fab69ae4563cd8ebb2c1e1f8c94f430f1607ef47aef;

    Airdrop airdrop = new Airdrop();

    ERC20 tko = new MyERC20(address(ERC20VaultDAO));

    function setUp() public {
        airdrop.init(ERC20VaultDAO, address(tko), 0x0);

        vm.prank(ERC20VaultDAO, ERC20VaultDAO);
        MyERC20(address(tko)).approve(address(airdrop), 1_000_000_000e18);
    }

    function test_claim_but_merkleRoot_not_set() public {
        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] =
            0x4a842e47f31b02491e870bfd75e4a135e52a2477ce8ea569c1b91c16654da9d5;
        merkleProof[1] =
            0xdc1cd6f194f9454fa91bf28dd2a5c8c389d55b395ad344279846d7d76493e6c1;
        merkleProof[2] =
            0x0f680f2e6f5f3eb7a715a018fc509585176e90c0539dd45783e64b8e4256bdd5;

        Airdrop.ERC20InputParams memory input;
        input.merkleProof = merkleProof;
        input.allowance = 100;

        vm.expectRevert(BaseAirdrop.CLAIM_NOT_STARTED.selector);
        vm.prank(Alice, Alice);
        airdrop.claim(abi.encode(input));
    }

    function test_claim_but_with_invalid_allowance() public {
        airdrop.setMerkleRoot(merkleRoot);

        // These proofs are coming from 'pnpm run buildMerkle'
        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] =
            0x4a842e47f31b02491e870bfd75e4a135e52a2477ce8ea569c1b91c16654da9d5;
        merkleProof[1] =
            0xdc1cd6f194f9454fa91bf28dd2a5c8c389d55b395ad344279846d7d76493e6c1;
        merkleProof[2] =
            0x0f680f2e6f5f3eb7a715a018fc509585176e90c0539dd45783e64b8e4256bdd5;

        Airdrop.ERC20InputParams memory input;
        input.merkleProof = merkleProof;
        input.allowance = 200;

        vm.expectRevert(BaseAirdrop.INCORRECT_PROOF.selector);
        vm.prank(Alice, Alice);
        airdrop.claim(abi.encode(input));
    }

    function test_claimx() public {
        airdrop.setMerkleRoot(merkleRoot);

        // These proofs are coming from 'pnpm run buildMerkle'
        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] =
            0x4a842e47f31b02491e870bfd75e4a135e52a2477ce8ea569c1b91c16654da9d5;
        merkleProof[1] =
            0xdc1cd6f194f9454fa91bf28dd2a5c8c389d55b395ad344279846d7d76493e6c1;
        merkleProof[2] =
            0x0f680f2e6f5f3eb7a715a018fc509585176e90c0539dd45783e64b8e4256bdd5;

        Airdrop.ERC20InputParams memory input;
        input.merkleProof = merkleProof;
        input.allowance = 100;

        vm.prank(Alice, Alice);
        airdrop.claim(abi.encode(input));

        // Check Alice balance
        assertEq(tko.balanceOf(Alice), 100);
    }

    function test_claim_with_same_proofs_twice() public {
        airdrop.setMerkleRoot(merkleRoot);

        // These proofs are coming from 'pnpm run buildMerkle'
        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] =
            0x4a842e47f31b02491e870bfd75e4a135e52a2477ce8ea569c1b91c16654da9d5;
        merkleProof[1] =
            0xdc1cd6f194f9454fa91bf28dd2a5c8c389d55b395ad344279846d7d76493e6c1;
        merkleProof[2] =
            0x0f680f2e6f5f3eb7a715a018fc509585176e90c0539dd45783e64b8e4256bdd5;

        Airdrop.ERC20InputParams memory input;
        input.merkleProof = merkleProof;
        input.allowance = 100;

        vm.prank(Alice, Alice);
        airdrop.claim(abi.encode(input));

        // Check Alice balance
        assertEq(tko.balanceOf(Alice), 100);

        vm.expectRevert(BaseAirdrop.CLAIMED_ALREADY.selector);
        vm.prank(Alice, Alice);
        airdrop.claim(abi.encode(input));
    }

    function test_cannot_set_merkleRoot_if_not_owner() public {
        vm.prank(Bob, Bob);
        vm.expectRevert();
        airdrop.setMerkleRoot(merkleRoot);
    }
}
