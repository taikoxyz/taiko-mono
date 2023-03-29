// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Tokenomics as T} from "../contracts/L1/libs/LibL2Tokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {
    LibFixedPointMath as M
} from "../contracts/thirdparty/LibFixedPointMath.sol";

contract TestLibL2Tokenomics is Test {
    using SafeCastUpgradeable for uint256;

    function test1559PurchaseMaxSizeGasWontOverflow() public {
        uint64 initialBasefee = 5000000000;
        uint64 maxGasToBuy = 15000000 * 512;
        uint64 target = 6000000;

        (uint64 gasExcess, uint64 xscale, uint256 yscale) = T.calcScales(
            maxGasToBuy,
            initialBasefee,
            target
        );

        uint expectedBaseFeeChange = 11; // 11 %%

        uint64 _basefee = initialBasefee;
        console2.log("basefee", _basefee);
        gasExcess += target;

        for (uint i = 0; i < 10; ++i) {
            uint64 newBasefee = T
                .calc1559Basefee(gasExcess, xscale, yscale << 64, target)
                .toUint64();
            uint ratio = (newBasefee * 100) / _basefee - 100;
            console2.log(
                "basefee",
                newBasefee,
                "+%",
                (newBasefee * 100) / _basefee - 100
            );
            // assertEq(ratio, expectedBaseFeeChange);
            _basefee = newBasefee;
            gasExcess += target;
        }
    }
}
