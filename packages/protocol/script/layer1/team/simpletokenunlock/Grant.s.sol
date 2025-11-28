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
        string memory path = "/script/simpletokenunlock/Grant.data.json";
        GrantingItem[] memory items = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (GrantingItem[])
        );

        uint256 total;
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

            total += SafeCastUpgradeable.toUint128(items[i].grantAmount * 1e18);
        }

        console2.log("total:", total / 1e18);

        vm.startBroadcast();
        require(tko.balanceOf(msg.sender) >= total, "insufficient TKO balance");
        for (uint256 i; i < items.length; i++) {
            uint128 grantAmount = uint128(items[i].grantAmount * 1e18);
            tko.approve(items[i].proxy, grantAmount);
            SimpleTokenUnlock(items[i].proxy).grant(grantAmount);
        }
        vm.stopBroadcast();
    }

}
