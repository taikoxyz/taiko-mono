// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/layer1/team/SimpleTokenUnlock.sol";

contract GrantSimpleTokenUnlock is Script {
    using stdJson for string;

    struct GrantingItem {
        address proxy;
        address recipient;
        uint256 grantAmount;
    }

    ERC20 private tko = ERC20(0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800);

    function run() external {
        string memory path = "/script/layer1/team/simpletokenunlock/Grant.data.json";
        GrantingItem[] memory items = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (GrantingItem[])
        );

        uint256 total;
        uint128[] memory grants = new uint128[](items.length);
        for (uint256 i; i < items.length; i++) {
            address proxy = items[i].proxy;
            address recipient = items[i].recipient;
            uint256 grantAmount = uint256(items[i].grantAmount);

            console2.log("proxy:", proxy);
            console2.log("recipient:", recipient);
            console2.log("grantAmount:", grantAmount);
            console2.log("");

            SimpleTokenUnlock target = SimpleTokenUnlock(proxy);

            require(target.recipient() == recipient, "recipient mismatch");
            require(target.owner() == 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F, "owner mismatch");

            uint256 grantWei = grantAmount * 1e18;
            require(grantWei <= type(uint128).max, "grant exceeds uint128");
            grants[i] = SafeCastUpgradeable.toUint128(grantWei);
            total += grantWei;
        }

        console2.log("total:", total / 1e18);

        vm.startBroadcast();
        address sender = msg.sender;
        require(tko.balanceOf(sender) >= total, "insufficient TKO balance");
        for (uint256 i; i < items.length; i++) {
            uint128 grantAmount = grants[i];
            uint256 proxyAllowance = tko.allowance(sender, items[i].proxy);
            if (proxyAllowance < grantAmount) {
                tko.approve(items[i].proxy, type(uint256).max);
            }
            SimpleTokenUnlock(items[i].proxy).grant(grantAmount);
        }
        vm.stopBroadcast();
    }
}
