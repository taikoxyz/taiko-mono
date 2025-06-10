// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/tokenvault/ERC1155Vault.sol";
import "src/layer1/mainnet/libs/LibFasterReentryLock.sol";

/// @title SurgeERC1155Vault
/// @notice See the documentation in {ERC1155Vault}.
/// @custom:security-contact security@nethermind.io
contract SurgeERC1155Vault is ERC1155Vault {
    constructor(address _resolver) ERC1155Vault(_resolver) { }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
