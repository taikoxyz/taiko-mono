// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/Bridge.sol";
import "../libs/LibFasterReentryLock.sol";

/// @title MainnetBridge
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deplyed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {Bridge}.
/// @custom:security-contact security@taiko.xyz
contract MainnetBridge is Bridge {
    /// @dev The slot in transient storage of the call context. This is the keccak256 hash
    /// of "bridge.ctx_slot"
    bytes32 private constant _CTX_SLOT =
        0xe4ece82196de19aabe639620d7f716c433d1348f96ce727c9989a982dbadc2b9;

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }

    /// @inheritdoc Bridge
    function _storeContext(bytes32 _msgHash, address _from, uint64 _srcChainId) internal override {
        assembly {
            tstore(_CTX_SLOT, _msgHash)
            tstore(add(_CTX_SLOT, 1), _from)
            tstore(add(_CTX_SLOT, 2), _srcChainId)
        }
    }

    /// @inheritdoc Bridge
    function _loadContext() internal view override returns (Context memory) {
        bytes32 msgHash;
        address from;
        uint64 srcChainId;
        assembly {
            msgHash := tload(_CTX_SLOT)
            from := tload(add(_CTX_SLOT, 1))
            srcChainId := tload(add(_CTX_SLOT, 2))
        }
        return Context(msgHash, from, srcChainId);
    }
}
