// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ProverSet.sol";

/// @title CachedProverSet
contract CachedProverSet is ProverSet {
    function getTaikoL1Address() internal pure override returns (address) {
        return 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    }

    function getTaikoTokenAddress() internal pure override returns (address) {
        return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    }
}
