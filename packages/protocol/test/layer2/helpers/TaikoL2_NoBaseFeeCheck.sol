// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/TaikoL2.sol";

contract TaikoL2_NoBaseFeeCheck is TaikoL2 {
    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
