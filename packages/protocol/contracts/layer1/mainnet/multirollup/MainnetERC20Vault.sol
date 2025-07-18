// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20VaultOriginal as ERC20Vault } from "src/shared/tokenvault/ERC20VaultOriginal.sol";
import "../libs/LibFasterReentryLock.sol";

/// @title MainnetERC20Vault
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deployed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {ER20Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC20Vault is ERC20Vault {
    constructor(address _resolver) ERC20Vault(_resolver) { }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
