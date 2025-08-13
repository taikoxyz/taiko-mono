// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/TaikoAnchor.sol";

contract TaikoAnchor_NoBaseFeeCheck is TaikoAnchor {
    constructor(
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        address _syncedBlockManager,
        address _bondManager,
        uint48 _lowBondProvingRewardGwei
    )
        TaikoAnchor(
            _livenessBondGwei,
            _provabilityBondGwei,
            _signalService,
            _pacayaForkHeight,
            _shastaForkHeight,
            _syncedBlockManager,
            _bondManager,
            _lowBondProvingRewardGwei
        )
    { }

    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
