// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "../iface/IInbox.sol";
import { LibHashOptimized } from "./LibHashOptimized.sol";

/// @title LibInboxSetup
/// @notice Library for Inbox setup code (constructor validation, activation).
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

    /// @dev Validates the genesis block hash and computes the initial inbox state.
    /// @param _genesisBlockHash The genesis block hash.
    /// @return activationTimestamp_ The activation timestamp to use.
    /// @return state_ The initial CoreState.
    /// @return proposal_ The genesis proposal.
    /// @return genesisProposalHash_ The hash of the genesis proposal (id=0).
    function initCoreState(bytes32 _genesisBlockHash)
        public
        view
        returns (
            uint48 activationTimestamp_,
            IInbox.CoreState memory state_,
            IInbox.Proposal memory proposal_,
            bytes32 genesisProposalHash_
        )
    {
        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());
        activationTimestamp_ = uint48(block.timestamp);

        // Set lastProposalBlockId to 1 to ensure the first proposal happens at block 2 or later.
        // This prevents reading blockhash(0) in propose(), which would return 0x0 and create
        // an invalid origin block hash. The EVM hardcodes blockhash(0) to 0x0, so we must
        // ensure proposals never reference the genesis block.
        state_.nextProposalId = 1;
        state_.lastProposalBlockId = 1;
        state_.lastFinalizedTimestamp = uint48(block.timestamp);
        state_.lastFinalizedBlockHash = _genesisBlockHash;

        genesisProposalHash_ = LibHashOptimized.hashProposal(proposal_);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BasefeeSharingPctgTooLarge();
    error BondTokenZero();
    error ForcedInclusionFeeDoubleThresholdZero();
    error ForcedInclusionFeeInGweiZero();
    error InvalidGenesisBlockHash();
    error PermissionlessProvingDelayTooSmall();
    error PermissionlessInclusionMultiplierTooSmall();
    error ProofVerifierZero();
    error ProposerCheckerZero();
    error ProvingWindowZero();
    error RingBufferSizeTooSmall();
    error SignalServiceZero();
}
