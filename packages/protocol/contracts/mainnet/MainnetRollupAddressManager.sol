// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/AddressManager.sol";
import "../common/LibStrings.sol";
import "./LibAddressCache.sol";

/// @title MainnetRollupAddressManager
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRollupAddressManager is AddressManager {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        address addr = LibAddressCache.getAddress(_chainId, _name);
        return addr != address(0) ? addr : super._getAddress(_chainId, _name);
    }
}
