// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/based2/IInbox.sol";
import "../iface/IPreconfWhitelist.sol";
import "../../forced-inclusion/IForcedInclusionStore.sol";
import "src/layer1/based2/IPropose.sol";

/// @title PreconfManager
/// @notice Manages batch proposals with preconfirmation access control and forced inclusion
/// validation
/// @dev Acts as a gateway to the Shasta inbox, ensuring only authorized preconfers can propose
/// batches
/// @custom:security-contact security@taiko.xyz
contract PreconfManager is EssentialContract, IPropose {
    IInbox public immutable inbox;
    IPreconfWhitelist public immutable whitelist;
    IForcedInclusionStore public immutable forcedStore;
    address public immutable fallbackPreconfer;

    error NotPreconfer();
    error ForcedInclusionNotProcessed();

    event ForcedInclusionProcessed(
        address indexed proposer, bytes32 indexed blobHash, uint64 feeInGwei
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

    /// @inheritdoc IPropose
    /// @dev Enforces preconfirmation access control and forced inclusion validation:
    ///      1. Only authorized preconfers (from whitelist or fallback) can propose batches
    ///      2. Forced inclusions MUST be processed when due, and CANNOT be processed before their
    /// deadline
    ///
    ///      When a forced inclusion is due (determined by ForcedInclusionStore), the proposer MUST
    ///      include it as the first batch in _packedBatches with isForcedInclusion = true
    function propose4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTransitionMetas
    )
        external
        nonReentrant
        returns (IInbox.Summary memory summary, bytes32 forcedInclusionBlobHash)
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

        (summary, forcedInclusionBlobHash) =
            inbox.propose4(_packedSummary, _packedBatches, _packedEvidence, _packedTransitionMetas);

        if (forcedStore.isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory expectedInclusion =
                forcedStore.getOldestForcedInclusion();

            // Verify the inbox processed the forced inclusion
            require(forcedInclusionBlobHash != bytes32(0), ForcedInclusionNotProcessed());
            require(
                forcedInclusionBlobHash == expectedInclusion.blobHash, ForcedInclusionNotProcessed()
            );

            // Safe to consume now that we've verified it was processed
            IForcedInclusionStore.ForcedInclusion memory processed =
                forcedStore.consumeOldestForcedInclusion(msg.sender);

            emit ForcedInclusionProcessed(msg.sender, processed.blobHash, processed.feeInGwei);
        }
    }
}
