// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/AddressManager.sol";
import "../common/LibStrings.sol";
import "./LibSharedAddressCache.sol";

/// @title MainnetSharedAddressManager
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSharedAddressManager is AddressManager {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return
            _getCachedAddress(_chainId, _name, LibSharedAddressCache.getAddress, super._getAddress);
    }
}
