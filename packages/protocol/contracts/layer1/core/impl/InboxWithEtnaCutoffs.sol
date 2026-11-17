// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Inbox } from "./Inbox.sol";

/// @title InboxWithEtnaCutoffs
/// @notice Stops Unzen proposals and forced inclusion submissions before the Etna fork.
/// @dev Upgrade the live Unzen Inbox proxy to this implementation using its existing configuration.
/// All switch parameters are immutable, so the inherited storage layout, proof verification, bond
/// accounting and core-state numbering are unchanged (START-10-5d).
/// @custom:security-contact security@taiko.xyz
contract InboxWithEtnaCutoffs is Inbox {
    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice Canonical Etna fork timestamp, shared with the Etna Inbox and L2 Anchor.
    uint48 public immutable ETNA_FORK_TIME;

    /// @notice Time before the fork at which Unzen proposals stop being accepted.
    uint48 public immutable PROPOSE_MARGIN;

    /// @notice Time before the fork at which Unzen forced inclusion submissions stop being accepted.
    uint48 public immutable FI_MARGIN;

    /// @notice First L1 timestamp at which Unzen proposals revert.
    uint48 public immutable PROPOSE_CUTOFF;

    /// @notice First L1 timestamp at which Unzen forced inclusion submissions revert.
    uint48 public immutable FI_CUTOFF;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Configures an upgrade-compatible Unzen Inbox implementation for the Etna switch.
    /// @dev The propose margin is at least 12 seconds (PARAM-11-12b). Networks with shorter L1
    /// slots need a larger margin that covers the accumulated L2 timestamp lead. The FI margin
    /// includes the forced inclusion delay and a nonzero buffer; deployment must choose a buffer
    /// at least as long as the longest expected gap between proposals.
    /// @param _config The unchanged configuration of the live Unzen Inbox.
    /// @param _etnaForkTime The canonical Etna fork timestamp.
    /// @param _proposeMargin Seconds between the proposal cutoff and the fork.
    /// @param _fiMargin Seconds between the forced inclusion submission cutoff and the fork.
    constructor(
        Config memory _config,
        uint48 _etnaForkTime,
        uint48 _proposeMargin,
        uint48 _fiMargin
    )
        Inbox(_config)
    {
        require(
            _proposeMargin >= 12 seconds
                && uint256(_fiMargin)
                    > uint256(_proposeMargin) + uint256(_config.forcedInclusionDelay)
                && _fiMargin < _etnaForkTime,
            InvalidEtnaCutoffs()
        );

        ETNA_FORK_TIME = _etnaForkTime;
        PROPOSE_MARGIN = _proposeMargin;
        FI_MARGIN = _fiMargin;
        PROPOSE_CUTOFF = _etnaForkTime - _proposeMargin;
        FI_CUTOFF = _etnaForkTime - _fiMargin;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Rejects proposals from the proposal cutoff onward, including the cutoff timestamp.
    function _checkProposeAllowed() internal view override {
        require(block.timestamp < PROPOSE_CUTOFF, ProposalsClosed());
    }

    /// @dev Rejects forced inclusion submissions from their cutoff onward, including the cutoff
    /// timestamp. Previously queued entries and their fees stay in the inherited store.
    function _checkForcedInclusionAllowed() internal view override {
        require(block.timestamp < FI_CUTOFF, ForcedInclusionsClosed());
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidEtnaCutoffs();
    error ProposalsClosed();
    error ForcedInclusionsClosed();
}
