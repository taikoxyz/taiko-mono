// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/anchor/TaikoAnchor.sol";

contract TaikoAnchor_NoBaseFeeCheck is TaikoAnchor {
    constructor(address _signalService) TaikoAnchor(_signalService, 0, 0) { }

    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
