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
        address recipient;
        address proxy;
        uint256 vestAmount;
    }

    ERC20 private tko = ERC20(0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800);

    function run() external {
        vm.startBroadcast();

        string memory path = "/script/tokenVesting/Vest.data.json";
        VestingItem[] memory items = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (VestingItem[])
        );

        for (uint256 i; i < items.length; i++) {
            if (items[i].vestAmount != 0) {
                address proxy = items[i].proxy;
                console2.log("Grantee unlocking contract address:", proxy);
                console2.log("Vest amount (TKO):", items[i].vestAmount);

                require(TokenUnlocking(proxy).owner() == msg.sender, "msg.sender not owner");
                require(
                    TokenUnlocking(proxy).recipient() == items[i].recipient,
                    "inconsistent recipient"
                );

                uint128 vestAmount = uint128(items[i].vestAmount * 1e18);
                require(tko.balanceOf(msg.sender) >= vestAmount, "insufficient TKO balance");

                tko.approve(proxy, vestAmount);
                TokenUnlocking(proxy).vest(vestAmount);

                console2.log("Vested!\n");
            }
        }

        vm.stopBroadcast();
    }
}
