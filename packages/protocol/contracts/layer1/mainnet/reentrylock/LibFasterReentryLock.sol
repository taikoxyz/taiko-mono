// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title LibFasterReentryLock
/// @custom:security-contact security@taiko.xyz
library LibFasterReentryLock {
    /// @dev The slot in transient storage of the reentry lock.
    /// This is the result of keccak256("ownerUUPS.reentry_slot") plus 1. The addition aims to
    /// prevent hash collisions with slots defined in EIP-1967, where slots are derived by
    /// keccak256("something") - 1, and with slots in SignalService, calculated directly with
    /// keccak256("something").
    bytes32 private constant _REENTRY_SLOT =
        0xa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721b;

    function storeReentryLock(uint8 _reentry) internal {
        assembly {
            tstore(_REENTRY_SLOT, _reentry)
        }
    }

    function loadReentryLock() internal view returns (uint8 reentry_) {
        assembly {
            reentry_ := tload(_REENTRY_SLOT)
        }
    }
}
