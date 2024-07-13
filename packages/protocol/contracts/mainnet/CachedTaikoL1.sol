// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1.sol";

/// @title CachedTaikoL1
/// @notice See the documentation in {TaikoL1}.
/// @custom:security-contact security@taiko.xyz
contract CachedTaikoL1 is TaikoL1 {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        if (_chainId == 1) {
            if (_name == LibStrings.B_TAIKO_TOKEN) {
                return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
            }
            if (_name == LibStrings.B_SIGNAL_SERVICE) {
                return 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
            }
            if (_name == LibStrings.B_TIER_ROUTER) {
                return 0x6E997f1F22C40ba37F633B08f3b07E10Ed43155a;
            }
        }
        return super._getAddress(_chainId, _name);
    }
}
