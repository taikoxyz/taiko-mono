// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1.sol";
import "./LibAddressCache.sol";

/// @title MainnetTaikoL1
/// @notice See the documentation in {TaikoL1}.
/// @custom:security-contact security@taiko.xyz
contract MainnetTaikoL1 is TaikoL1 {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
