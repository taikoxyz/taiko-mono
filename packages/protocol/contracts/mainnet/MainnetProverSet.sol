// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../team/proving/ProverSet.sol";

/// @title MainnetProverSet
/// @notice See the documentation in {ProverSet}.
/// @custom:security-contact security@taiko.xyz
contract MainnetProverSet is ProverSet {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        if (_chainId == 1) {
            if (_name == LibStrings.B_TAIKO_TOKEN) {
                return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
            }
            if (_name == LibStrings.B_TAIKO) {
                return 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
            }
        }
        return super._getAddress(_chainId, _name);
    }
}
