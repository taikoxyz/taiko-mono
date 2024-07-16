// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../signal/SignalService.sol";
import "./LibSharedAddressCache.sol";

/// @title MainnetSignalService
/// @notice See the documentation in {SignalService}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSignalService is SignalService {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibSharedAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
