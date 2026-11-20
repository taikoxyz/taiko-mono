// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Inbox } from "./Inbox.sol";
import { IUnzenProposeCutoff } from "src/layer1/etna/iface/IUnzenProposeCutoff.sol";

/// @title InboxWithEtnaCutoffs
/// @notice Stops Unzen proposals and forced inclusion submissions before the Etna fork.
/// @dev Upgrade the live Unzen Inbox proxy to this implementation using its existing configuration,
/// except that `signalService` names the Etna Inbox proxy: `prove` then saves its checkpoints
/// through the Etna Inbox, which forwards them to the L1 SignalService, and `getConfig()` reports
/// the Etna Inbox. All switch parameters are immutable, so the inherited storage layout, proof
/// verification, bond accounting and core-state numbering are unchanged (START-10-5d). It exposes
/// the propose cutoff through `proposeCutoff()`, which `EtnaInbox.setOrigin` reads.
/// @custom:security-contact security@taiko.xyz
contract InboxWithEtnaCutoffs is Inbox, IUnzenProposeCutoff {
    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice Canonical Etna fork timestamp, shared with the Etna Inbox's `etnaForkTime()`. No L2
    /// contract holds it.
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
    /// @param _config The live Unzen Inbox's configuration with `signalService` set to the Etna
    /// Inbox proxy.
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
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IUnzenProposeCutoff
    /// @dev `PROPOSE_CUTOFF`, never zero: `_checkProposeAllowed` reverts from it on.
    function proposeCutoff() external view returns (uint48) {
        return PROPOSE_CUTOFF;
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
