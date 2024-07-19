// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/provers/GuardianProver.sol";
import "./LibRollupAddressCache.sol";

/// @title MainnetGuardianProver
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {GuardianProver}.
/// @custom:security-contact security@taiko.xyz
contract MainnetGuardianProver is GuardianProver {
    uint256[50] private __gap;

    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibRollupAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
