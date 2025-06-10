// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/tokenvault/ERC721Vault.sol";
import "src/layer1/mainnet/libs/LibFasterReentryLock.sol";

/// @title SurgeERC721Vault
/// @notice See the documentation in {ERC721Vault}.
/// @custom:security-contact security@nethermind.io
contract SurgeERC721Vault is ERC721Vault {
    constructor(address _resolver) ERC721Vault(_resolver) { }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
