// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/core/AddressManager.sol";
import "../../../shared/common/LibStrings.sol";
import "../addrcache/RollupAddressCache.sol";

/// @title MainnetRollupAddressManager
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRollupAddressManager is AddressManager, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
