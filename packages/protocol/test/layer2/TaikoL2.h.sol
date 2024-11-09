// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL2Test.sol";

contract TaikoL2WithoutBaseFeeCheck is TaikoL2 {
    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
