// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../../layer1/etna/iface/IEtnaInbox.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { ISignalServiceL1 } from "./ISignalServiceL1.sol";
import { SignalService } from "./SignalService.sol";

/// @title SignalServiceL1
/// @notice Accepts Unzen and Etna checkpoints on a network switching to Etna.
/// @dev Upgrades the existing L1 SignalService without adding storage or changing VERSION, so
/// historical checkpoints, received-signal caches and proofs remain usable. The shared base and
/// SignalServiceL2 do not read the Etna Inbox. The Etna proxy may still run EtnaInboxBootstrap,
/// whose etnaStart view reports no start. Any other implementation installed before Unzen proofs
/// resume must expose that view; upgrading and initializing Etna must be atomic. A failed start
/// read reverts the Unzen checkpoint write.
/// @custom:security-contact security@taiko.xyz
contract SignalServiceL1 is SignalService, ISignalServiceL1 {
    /// @inheritdoc ISignalServiceL1
    address public immutable override etnaInbox;

    /// @notice Initializes the immutable identities for the L1 switch implementation.
    /// @dev Both syncers must be distinct, deployed EssentialContract proxies. An implementation
    /// address is rejected because its implementation slot does not point to deployed code.
    /// @param _unzenInbox The existing Unzen Inbox proxy.
    /// @param _etnaInbox The Etna Inbox proxy, which may still use EtnaInboxBootstrap.
    /// @param _remoteSignalService The L2 SignalService whose signal proofs are verified.
    /// @param _pauser Optional additional pause authority.
    constructor(
        address _unzenInbox,
        address _etnaInbox,
        address _remoteSignalService,
        address _pauser
    )
        SignalService(_unzenInbox, _remoteSignalService, _pauser)
    {
        if (_unzenInbox == _etnaInbox) revert SS_INVALID_INBOX();
        _requireInboxProxy(_unzenInbox);
        _requireInboxProxy(_etnaInbox);
        etnaInbox = _etnaInbox;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ISignalServiceL1
    function unzenInbox() external view returns (address unzenInbox_) {
        return _authorizedSyncer;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Authorizes the two L1 syncers and bounds Unzen checkpoints after the Etna start write.
    /// A zero start hash means no start has been written, including during bootstrap. Reading the
    /// current start on every Unzen write also honors a start correction before the first landing.
    /// @param _checkpoint The checkpoint submitted to saveCheckpoint.
    function _authorizeCheckpoint(Checkpoint calldata _checkpoint) internal view override {
        if (msg.sender == etnaInbox) return;
        if (msg.sender != _authorizedSyncer) revert SS_UNAUTHORIZED();

        (uint48 startHeight, bytes32 startHash) = IEtnaInbox(etnaInbox).etnaStart();
        if (startHash != bytes32(0) && _checkpoint.blockNumber > startHeight) {
            revert SS_UNZEN_CHECKPOINT_ABOVE_START();
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Requires a deployed proxy whose implementation slot points to deployed code.
    /// @param _inbox The Inbox proxy address to validate.
    function _requireInboxProxy(address _inbox) private view {
        if (_inbox.code.length == 0 || EssentialContract(_inbox).impl().code.length == 0) {
            revert SS_INVALID_INBOX();
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error SS_INVALID_INBOX();
    error SS_UNZEN_CHECKPOINT_ABOVE_START();
}
