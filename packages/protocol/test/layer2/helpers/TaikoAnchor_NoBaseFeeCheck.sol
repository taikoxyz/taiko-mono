// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/TaikoAnchor.sol";

contract TaikoAnchor_NoBaseFeeCheck is TaikoAnchor {
    constructor(
        uint256 _livenessBond,
        uint256 _provabilityBond,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        address _syncedBlockManager,
        address _bondManager,
        uint256 _lowBondProvingReward
    )
        TaikoAnchor(
            _livenessBond,
            _provabilityBond,
            _signalService,
            _pacayaForkHeight,
            _shastaForkHeight,
            _syncedBlockManager,
            _bondManager,
            _lowBondProvingReward
        )
    { }

    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}
