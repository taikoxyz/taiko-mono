// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibInboxMigration
/// @notice Migration state of the Inbox proxy for the move from Shasta to Etna.
/// @dev The Shasta `Inbox` writes `FROZEN` in `freeze()`; the Etna Inbox writes `ETNA_ACTIVE` when it
/// activates. `State` packs into one storage word (slot 258 of the Inbox proxy):
/// `migrationState` bits 0-7, `frozenAtL1Block` bits 8-71, `drainedAtL1Block` bits 72-135.
/// @custom:security-contact security@taiko.xyz
library LibInboxMigration {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The Inbox accepts proposals and forced inclusions.
    uint8 internal constant NONE = 0;

    /// @dev The Inbox rejects new proposals and forced inclusions; proving and bond exits continue.
    uint8 internal constant FROZEN = 1;

    // 2 (drained) is reserved by the Etna specification (taikoxyz/taiko-mono#22262, MIG); this
    // design activates straight from FROZEN.

    /// @dev The Etna Inbox is active.
    uint8 internal constant ETNA_ACTIVE = 3;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev The migration state word. Fits in one storage slot.
    struct State {
        uint8 migrationState; // One of the constants above.
        uint64 frozenAtL1Block; // The L1 block in which the Inbox was frozen.
        uint64 drainedAtL1Block; // The L1 block in which the Etna Inbox was activated.
    }
}
