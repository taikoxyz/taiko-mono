// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/AddressManager.sol";
import "../common/LibStrings.sol";
import "./LibRollupAddressCache.sol";

/// @title MainnetRollupAddressManager
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRollupAddressManager is AddressManager {
    uint256[50] private __gap;

    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibRollupAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
