// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Tokenomics} from "../contracts/L1/libs/LibL2Tokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {
    LibFixedPointMath as M
} from "../contracts/thirdparty/LibFixedPointMath.sol";

contract TestLibL2Tokenomics is Test {
    using SafeCastUpgradeable for uint256;

    // Ethereum offers 15M gas per 12 seconds, if we scale it by 24 times,
    // then each second, Taiko can offer 30M gas.

    uint256 public constant gasTargetPerSecond = 15000000; // 15M gas per second
    uint256 xScale;
    uint256 yScale;
    uint256 gasExcess;

    uint256 maxGasToBuy = gasTargetPerSecond * 512;

    uint256 initialBasefee = 5000000000;

    function setUp() public {
        gasExcess = maxGasToBuy / 2;

        calcScales(maxGasToBuy, initialBasefee);
        console2.log("xScale", xScale);
        console2.log("yScale", yScale);
    }

    function calcScales(uint maxGasToBuy, uint initialBasefee) internal {
        xScale = 135305999368893231588 / maxGasToBuy;
        yScale = 1;
        yScale =
            (ethqty(maxGasToBuy / 2 + 1) - ethqty(maxGasToBuy / 2)) /
            initialBasefee;
    }

    function test1559PurchaseMaxSizeGasWontOverflow() public {
        // buy 30000000 gas
        uint target = 6000000;
        uint pricePrev = initialBasefee;
        for (uint i = 0; i < 10; ++i) {
            uint fee = basefee(target);
            console2.log("fee", fee);
            console2.log("%", (fee * 100) / pricePrev);
            pricePrev = fee;
            gasExcess += target;
        }
    }

    function ethqty(uint excess) internal view returns (uint256) {
        return uint256(M.exp(int256(excess * xScale)));
    }

    function basefee(uint amount) internal view returns (uint256) {
        return (ethqty(gasExcess + amount) - ethqty(gasExcess)) / yScale;
    }
}
