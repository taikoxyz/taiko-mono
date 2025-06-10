// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/tokenvault/ERC20Vault.sol";
import "src/layer1/mainnet/libs/LibFasterReentryLock.sol";

/// @title SurgeERC20Vault
/// @notice See the documentation in {ERC20Vault}.
/// @custom:security-contact security@nethermind.io
contract SurgeERC20Vault is ERC20Vault {
    constructor(address _resolver) ERC20Vault(_resolver) { }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
