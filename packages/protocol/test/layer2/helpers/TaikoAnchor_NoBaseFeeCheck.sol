// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/TaikoAnchor.sol";

contract TaikoAnchor_NoBaseFeeCheck is TaikoAnchor {
    constructor() TaikoAnchor(0) { }

    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
