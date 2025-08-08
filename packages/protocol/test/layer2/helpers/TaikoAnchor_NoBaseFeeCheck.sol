// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/TaikoAnchor.sol";

contract TaikoAnchor_NoBaseFeeCheck is TaikoAnchor {
    constructor(
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight
    )
        TaikoAnchor(_signalService, _pacayaForkHeight, _shastaForkHeight)
    { }

    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
