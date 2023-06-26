// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { ProverPool } from "../contracts/L1/ProverPool.sol";

contract TestProverPool is Test {
    address public constant Alice = 0xa9bcF99f5eb19277f48b71F9b14f5960AEA58a89;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;
    address public constant Carol = 0x300C9b60E19634e12FC6D68B7FEa7bFB26c2E419;
    address public constant Protocol =
        0x400147C0Eb43D8D71b2B03037bB7B31f8f78EF5F;

    AddressManager public addressManager;
    TaikoToken public tko;
    ProverPool public pp;
    uint64 public tokenPerCapacity = 10_000 * 1e8;

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        tko = new TaikoToken();
        registerAddress("taiko_token", address(tko));
        address[] memory premintRecipients;
        uint256[] memory premintAmounts;
        tko.init(
            address(addressManager),
            "TaikoToken",
            "TKO",
            premintRecipients,
            premintAmounts
        );

        // Set protocol broker
        registerAddress("taiko", address(this));
        tko.mint(address(this), 1e9 * 1e8);
        registerAddress("taiko", Protocol);

        pp = new ProverPool();
        pp.init(address(addressManager));
        registerAddress("prover_pool", address(pp));
    }

    function testProverPool__32_stakers_replaced_by_another_32() public {
        uint16 baseCapacity = 128;

        for (uint16 i; i < 32; ++i) {
            address addr = randomAddress(i);
            uint16 capacity = baseCapacity + i;
            depositTaikoToken(addr, tokenPerCapacity * capacity, 1 ether);
            vm.prank(addr, addr);
            pp.stake(uint32(capacity) * 10_000, 10 + i, capacity);
        }

        ProverPool.Prover[] memory provers;
        address[] memory stakers;

        (provers, stakers) = printProvers();
        for (uint16 i; i < provers.length; ++i) {
            assertEq(provers[i].stakedAmount, uint32(baseCapacity + i) * 10_000);
            assertEq(provers[i].rewardPerGas, 10 + i);
            assertEq(provers[i].currentCapacity, baseCapacity + i);
        }

        // The same 32 provers restake
        baseCapacity = 200;
        for (uint16 i; i < provers.length; ++i) {
            address addr = randomAddress(i);
            uint16 capacity = baseCapacity + i;
            depositTaikoToken(addr, tokenPerCapacity * capacity, 1 ether);
            vm.prank(addr, addr);
            pp.stake(uint32(capacity) * 10_000, 10 + i, capacity);
        }

        (provers, stakers) = printProvers();
        for (uint16 i; i < provers.length; ++i) {
            assertEq(provers[i].stakedAmount, uint32(baseCapacity + i) * 10_000);
            assertEq(provers[i].rewardPerGas, 10 + i);
            assertEq(provers[i].currentCapacity, baseCapacity + i);
        }

        // Different 32 provers stake
        baseCapacity = 500;
        for (uint16 i; i < provers.length; ++i) {
            address addr = randomAddress(i + 12_345);
            uint16 capacity = baseCapacity + i;
            depositTaikoToken(addr, tokenPerCapacity * capacity, 1 ether);
            vm.prank(addr, addr);
            pp.stake(uint32(capacity) * 10_000, 10 + i, capacity);
        }

        (provers, stakers) = printProvers();
        for (uint16 i; i < provers.length; ++i) {
            assertEq(provers[i].stakedAmount, uint32(baseCapacity + i) * 10_000);
            assertEq(provers[i].rewardPerGas, 10 + i);
            assertEq(provers[i].currentCapacity, baseCapacity + i);
        }
    }

    // --- helpers ---

    function registerAddress(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(block.chainid, nameHash, addr);
        console2.log(
            block.chainid,
            string(abi.encodePacked(nameHash)),
            unicode"→",
            addr
        );
    }

    function depositTaikoToken(
        address who,
        uint64 amountTko,
        uint256 amountEth
    )
        internal
    {
        vm.deal(who, amountEth);
        tko.transfer(who, amountTko);
    }

    function randomAddress(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }

    function printProvers()
        internal
        view
        returns (ProverPool.Prover[] memory provers, address[] memory stakers)
    {
        (provers, stakers) = pp.getProvers();
        for (uint256 i; i < provers.length; ++i) {
            console2.log(
                string.concat(
                    "prover#",
                    vm.toString(i + 1),
                    ", addr: ",
                    vm.toString(stakers[i]),
                    ": stakedAmount: ",
                    vm.toString(provers[i].stakedAmount),
                    ", rewardPerGas: ",
                    vm.toString(provers[i].rewardPerGas),
                    ", currentCapacity: ",
                    vm.toString(provers[i].currentCapacity)
                )
            );
        }
    }
}
