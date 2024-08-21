// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../L1/provers/GuardianProver.sol";
import "../addrcache/RollupAddressCache.sol";

/// @title MainnetGuardianProver
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {GuardianProver}.
/// @custom:security-contact security@taiko.xyz
contract MainnetGuardianProver is GuardianProver, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddressFromCache(_chainId, _name, super._getAddress);
    }
}
