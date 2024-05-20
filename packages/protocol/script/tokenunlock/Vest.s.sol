// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../contracts/team/tokenunlock/TokenUnlock.sol";

contract VestTokenUnlock is Script {
    using stdJson for string;

    struct VestingItem {
        address recipient;
        address proxy;
        uint256 vestAmount;
    }

    ERC20 private tko = ERC20(0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800);

    function run() external {
        vm.startBroadcast();

        string memory path = "/script/tokenunlock/Vest.data.json";
        VestingItem[] memory items = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (VestingItem[])
        );

        for (uint256 i; i < items.length; i++) {
            if (items[i].vestAmount != 0) {
                address proxy = items[i].proxy;
                console2.log("proxy. :", proxy);
                console2.log("grantee:", items[i].recipient);
                console2.log("vested :", items[i].vestAmount);

                require(TokenUnlock(proxy).owner() == msg.sender, "msg.sender not owner");
                require(
                    TokenUnlock(proxy).recipient() == items[i].recipient, "inconsistent recipient"
                );

                uint128 vestAmount = uint128(items[i].vestAmount * 1e18);
                require(tko.balanceOf(msg.sender) >= vestAmount, "insufficient TKO balance");

                tko.approve(proxy, vestAmount);
                TokenUnlock(proxy).vest(vestAmount);

                console2.log("Vested!\n");
            }
        }

        vm.stopBroadcast();
    }
}
