// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibBonds
/// @notice Legacy bond storage types retained for migration support.
/// @dev All bond management functions have been removed. Only the struct definitions remain
///      so that Inbox.migrateBond() can read from the legacy _bondStorage mapping.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    /// @dev Legacy bond record. Layout must match the original IBondManager.Bond exactly
    ///      to preserve storage compatibility.
    struct Bond {
        uint64 balance;
        uint48 withdrawalRequestedAt;
    }

    /// @dev Storage layout for legacy bond balances.
    struct Storage {
        mapping(address account => Bond bond) bonds;
    }
}
