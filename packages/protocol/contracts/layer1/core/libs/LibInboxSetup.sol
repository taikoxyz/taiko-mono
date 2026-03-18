// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "../iface/IInbox.sol";

/// @title LibInboxSetup
/// @notice Library for Inbox setup code (constructor validation).
/// @dev Using public functions in a library forces external linking, reducing deployment size
///      of the main contract at the cost of a small runtime gas overhead for the DELEGATECALL.
/// @custom:security-contact security@taiko.xyz
library LibInboxSetup {
    // ---------------------------------------------------------------
    // Public Functions (externally linked)
    // ---------------------------------------------------------------

    /// @dev Minimum ring buffer size to keep one slot reserved in capacity calculations.
    uint48 public constant MIN_RING_BUFFER_SIZE = 2;

    /// @dev Validates the Inbox configuration parameters.
    /// @param _config The configuration to validate.
    function validateConfig(IInbox.Config memory _config) public pure {
        // Validate in the order fields are defined in Config struct.
        require(_config.proofVerifier != address(0), ProofVerifierZero());
        require(_config.proposerChecker != address(0), ProposerCheckerZero());
        require(_config.signalService != address(0), SignalServiceZero());
        require(_config.bondToken != address(0), BondTokenZero());
        require(_config.provingWindow != 0, ProvingWindowZero());
        require(
            _config.permissionlessProvingDelay > _config.provingWindow,
            PermissionlessProvingDelayTooSmall()
        );
        require(_config.ringBufferSize >= MIN_RING_BUFFER_SIZE, RingBufferSizeTooSmall());
        require(_config.basefeeSharingPctg <= 100, BasefeeSharingPctgTooLarge());
        require(_config.forcedInclusionFeeInGwei != 0, ForcedInclusionFeeInGweiZero());
        require(
            _config.forcedInclusionFeeDoubleThreshold != 0, ForcedInclusionFeeDoubleThresholdZero()
        );
        require(
            _config.permissionlessInclusionMultiplier > 1,
            PermissionlessInclusionMultiplierTooSmall()
        );
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BasefeeSharingPctgTooLarge();
    error BondTokenZero();
    error ForcedInclusionFeeDoubleThresholdZero();
    error ForcedInclusionFeeInGweiZero();
    error PermissionlessProvingDelayTooSmall();
    error PermissionlessInclusionMultiplierTooSmall();
    error ProofVerifierZero();
    error ProposerCheckerZero();
    error ProvingWindowZero();
    error RingBufferSizeTooSmall();
    error SignalServiceZero();
}
