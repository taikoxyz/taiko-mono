// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title EtnaInboxBootstrap
/// @notice The first implementation of the Etna Inbox proxy: it only sets the owner, so the proxy
/// address exists before the registry that fixes it (spec 10 step 1).
/// @dev The owner later upgrades the proxy to `EtnaInbox` and calls its `init` in the same
/// transaction. Until then the proxy reports itself uninitialized, which keeps the registry's
/// exit confirmation and slashing closed. The storage is `EssentialContract`'s alone, so the
/// Inbox slots stay zero.
/// @custom:security-contact security@taiko.xyz
contract EtnaInboxBootstrap is EssentialContract {
    /// @notice Sets the owner of the proxy.
    /// @param _owner The owner; `msg.sender` if zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Returns whether the Etna Inbox is initialized; always false here.
    /// @return False.
    function isInitialized() external pure returns (bool) {
        return false;
    }
}
