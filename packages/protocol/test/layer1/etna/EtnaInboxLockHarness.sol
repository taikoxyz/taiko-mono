// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";

/// @title EtnaInboxLockHarness
/// @notice An `EtnaInbox` implementation that can make any call while holding the Inbox's
/// reentrancy lock, the lock `land` and `recover` share (spec 8.3).
/// @dev Adds no storage, so a proxy upgraded to it keeps the appendix B layout. `lockedCall` has
/// no access control: it exists only for tests.
contract EtnaInboxLockHarness is EtnaInbox {
    constructor(Config memory _config) EtnaInbox(_config) { }

    /// @notice Calls `_to` with `_data` while the Inbox's reentrancy lock is held.
    /// @param _to The callee.
    /// @param _data The calldata.
    /// @return ok_ Whether the call succeeded.
    /// @return ret_ The call's return or revert data.
    function lockedCall(
        address _to,
        bytes calldata _data
    )
        external
        nonReentrant
        returns (bool ok_, bytes memory ret_)
    {
        (ok_, ret_) = _to.call(_data);
    }
}
