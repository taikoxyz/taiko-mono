// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../contracts/tokenUnlocking/TokenUnlocking.sol";

contract VestTokenUnlocking is Script {
    using stdJson for string;

    struct VestingItem {
        bytes32 name; // Conversion from json "string" to bytes32 will take place in foundry,
            // cannot use string here, as json parser cannot interpret string from json, everything
            // is bytes-chunks. It is more of informational to script executor anyways.
        address recipient;
        address proxy;
        uint256 vestAmount;
    }

    ERC20 private tko = ERC20(vm.envAddress("TAIKO_TOKEN"));

    function run() external {
        vm.startBroadcast();

        string memory path = "/script/tokenVesting/Vest.data.json";
        VestingItem[] memory items = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (VestingItem[])
        );

        for (uint256 i; i < items.length; i++) {
            address proxy = items[i].proxy;
            console2.logBytes32(items[i].name);
            console2.log("Grantee unlocking contract address:", proxy);
            console2.log("Vest amount (TKO):", items[i].vestAmount);

            require(TokenUnlocking(proxy).owner() == msg.sender, "msg.sender not owner");
            require(
                TokenUnlocking(proxy).recipient() == items[i].recipient, "inconsistent recipient"
            );

            uint128 vestAmount = uint128(items[i].vestAmount * 1e18);
            require(tko.balanceOf(msg.sender) >= vestAmount, "insufficient TKO balance");

            tko.approve(proxy, vestAmount);
            TokenUnlocking(proxy).deposit(vestAmount);

            console2.log("Vested!\n");
        }

        vm.stopBroadcast();
    }
}
