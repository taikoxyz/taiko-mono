// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../team/proving/ProverSet.sol";

/// @title L1ProverSet
/// @notice See the documentation in {ProverSet}.
/// @custom:security-contact security@taiko.xyz
contract L1ProverSet is ProverSet {
    function taikoL1() internal pure override returns (address) {
        return 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    }

    function tkoToken() internal pure override returns (address) {
        return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    }
}
