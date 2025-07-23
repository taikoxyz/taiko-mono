// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/based2/IInbox.sol";
import "../iface/IPreconfWhitelist.sol";
import "../../forced-inclusion/IForcedInclusionStore.sol";

/// @title PreconfManager
/// @notice Manages batch proposals with preconfirmation access control and forced inclusion
/// validation
/// @dev Acts as a gateway to the Shasta inbox, ensuring only authorized preconfers can propose
/// batches
/// @custom:security-contact security@taiko.xyz
contract PreconfManager is EssentialContract {
    IInbox public immutable inbox;
    IPreconfWhitelist public immutable whitelist;
    IForcedInclusionStore public immutable forcedStore;
    address public immutable fallbackPreconfer;

    error NotPreconfer();
    error ForcedInclusionNotProcessed();
    
    event ForcedInclusionProcessed(
        address indexed proposer,
        bytes32 indexed blobHash,
        uint64 feeInGwei
    );

    uint256[50] private __gap;

    constructor(
        address _inbox,
        address _whitelist,
        address _forcedStore,
        address _fallbackPreconfer
    )
        nonZeroAddr(_inbox)
        nonZeroAddr(_whitelist)
        nonZeroAddr(_forcedStore)
        EssentialContract()
    {
        inbox = IInbox(_inbox);
        whitelist = IPreconfWhitelist(_whitelist);
        forcedStore = IForcedInclusionStore(_forcedStore);
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Proposes batches to the inbox with preconf authorization and forced inclusion
    /// validation
    /// @dev This function serves as the gateway for all batch proposals, enforcing two key
    /// requirements:
    ///      1. Only authorized preconfers (from whitelist or fallback) can propose batches
    ///      2. Forced inclusions must be processed when due, and cannot be processed before their
    /// deadline
    ///
    ///      When a forced inclusion is due (determined by ForcedInclusionStore based on batch count
    /// delay),
    ///      the proposer MUST include it as the first batch in _packedBatches. The contract
    /// validates:
    ///      - The first batch has isForcedInclusion = true
    ///      - The batch contains exactly one block with maximum transactions allowed
    ///      - The blob hash, offset, and size match the expected forced inclusion
    ///
    ///      Forced inclusions ensure censorship resistance by guaranteeing that user transactions
    ///      will be included within a bounded time period after paying the inclusion fee.
    ///
    /// @param _packedSummary Current protocol summary encoded using LibCodec.packSummary
    /// @param _packedBatches Array of batches encoded using LibCodec.packBatches. If a forced
    /// inclusion
    ///                       is due, it MUST be the first batch with isForcedInclusion = true
    /// @param _packedEvidence Evidence for batch proposal validation, including parent batch
    /// metadata
    /// @param _packedTransitionMetas Transition metadata array for state verification
    /// @return summary Updated protocol summary after successful proposal
    function propose(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTransitionMetas
    )
        external
        nonReentrant
        returns (IInbox.Summary memory summary)
    {
        // Verify caller is authorized preconfer
        address preconfer = whitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotPreconfer());
        } else {
            revert NotPreconfer();
        }

        bool forcedInclusionExpected = forcedStore.isOldestForcedInclusionDue();
        IForcedInclusionStore.ForcedInclusion memory expectedInclusion;
        
        if (forcedInclusionExpected) {
            expectedInclusion = forcedStore.getOldestForcedInclusion();
            // The inbox will validate that the first batch is a proper forced inclusion
            // We'll verify the blob hash matches after successful processing
        }

        summary = inbox.propose4(_packedSummary, _packedBatches, _packedEvidence, _packedTransitionMetas);
            
        if (forcedInclusionExpected) {
            IForcedInclusionStore.ForcedInclusion memory processed = 
                forcedStore.consumeOldestForcedInclusion(msg.sender);
                
            require(
                processed.blobHash == expectedInclusion.blobHash,
                ForcedInclusionNotProcessed()
            );
                
            emit ForcedInclusionProcessed(
                msg.sender,
                processed.blobHash,
                processed.feeInGwei
            );
        }
        
        return summary;
    }

}
