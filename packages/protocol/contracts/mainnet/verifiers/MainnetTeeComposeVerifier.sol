// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/compose/TeeComposeVerifier.sol";
import "../LibRollupAddressCache.sol";

/// @title MainnetTeeComposeVerifier
/// @custom:security-contact security@taiko.xyz
contract MainnetTeeComposeVerifier is TeeComposeVerifier {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibRollupAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
