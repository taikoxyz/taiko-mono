// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { ProverPool2 } from "../contracts/L1/ProverPool2.sol";

contract TestProverPool2 is Test {
    address public constant Alice = 0xa9bcF99f5eb19277f48b71F9b14f5960AEA58a89;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;
    address public constant Carol = 0x300C9b60E19634e12FC6D68B7FEa7bFB26c2E419;
    address public constant Protocol =
        0x400147C0Eb43D8D71b2B03037bB7B31f8f78EF5F;

    AddressManager public addressManager;
    TaikoToken public tko;
    ProverPool2 public pp;

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

        pp = new ProverPool2();
        pp.init(address(addressManager));
        registerAddress("prover_pool", address(pp));
    }

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
        console2.log("who", who);
        console2.log("balance:", tko.balanceOf(who));
    }

    function randomAddress(uint256 seed) private pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }

    function testPp2_proverSerialization() public {
        for (uint16 i; i < 32; ++i) {
            address addr = randomAddress(i);
            uint16 capacity = 128 + i;
            depositTaikoToken(addr, uint64(capacity) * 10_000 * 1e8, 1 ether);
            vm.prank(addr, addr);
            pp.stake(uint32(capacity) * 10_000, 10 + i, capacity);
        }

        ProverPool2.Prover[32] memory provers = pp.getProvers();
        for (uint16 i; i < provers.length; ++i) {
            assertEq(provers[i].stakedAmount, uint32(128 + i) * 10_000);
            assertEq(provers[i].rewardPerGas, 10 + i);
            assertEq(provers[i].currentCapacity, 128 + i);
        }
    }
}
