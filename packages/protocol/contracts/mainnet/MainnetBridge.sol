// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../bridge/Bridge.sol";
import "./LibSharedAddressCache.sol";

/// @title MainnetBridge
/// @notice See the documentation in {Bridge}.
/// @custom:security-contact security@taiko.xyz
contract MainnetBridge is Bridge {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibSharedAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
