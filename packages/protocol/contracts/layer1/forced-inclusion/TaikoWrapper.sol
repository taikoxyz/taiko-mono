// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/based/IProposeBatch.sol";
import "./ForcedInclusionStore.sol";

/// @title TaikoWrapper
/// @dev This contract is part of a delayed inbox implementation to enforce the inclusion of
/// transactions.
/// The current design is a simplified and can be improved with the following ideas:
/// 1. Fee-Based Request Prioritization:
///    - Proposers can selectively fulfill pending requests based on transaction fees.
///    - Requests not yet due can be processed earlier if fees are attractive, incentivizing timely
/// execution.
///
/// 2. Rate Limit Control:
///    - A rate-limiting mechanism ensures a minimum interval of 12*N seconds between request
/// fulfillments.
///    - Prevents proposers from being overwhelmed during high request volume, ensuring system
/// stability.
///
/// 3. Calldata and Blob Support:
///    - Supports both calldata and blobs in the transaction list.
///
/// 4. Gas-Efficient Request Storage:
///    - Avoids storing full request data in contract storage.
///    - Saves only the request hash and its timestamp.
///    - Leverages Ethereum events to store request details off-chain.
///    - Proposers can reconstruct requests as needed, minimizing on-chain storage and gas
/// consumption.
///
/// @custom:security-contact security@taiko.xyz
contract TaikoWrapper is EssentialContract, IProposeBatchV2WithForcedInclusion {
    using LibMath for uint256;

    /// @dev Event emitted when a forced inclusion is processed.
    event ForcedInclusionProcessed(IForcedInclusionStore.ForcedInclusion);

    error InvalidBlockTxs();
    error InvalidBlobHashesSize();
    error InvalidBlobHash();
    error InvalidBlobByteOffset();
    error InvalidBlobByteSize();
    error InvalidBlobCreatedIn();
    error InvalidBlockSize();
    error InvalidTimeShift();
    error InvalidSignalSlots();
    error OldestForcedInclusionDue();
    error InvalidProposer();

    uint16 public constant MIN_TXS_PER_FORCED_INCLUSION = 512;
    IProposeBatchV2 public immutable inbox;
    IForcedInclusionStore public immutable forcedInclusionStore;
    address public immutable preconfRouter;

    uint256[50] private __gap;

    constructor(
        address _inbox,
        address _forcedInclusionStore,
        address _preconfRouter
    )
        nonZeroAddr(_inbox)
        nonZeroAddr(_forcedInclusionStore)
        EssentialContract(address(0))
    {
        inbox = IProposeBatchV2(_inbox);
        forcedInclusionStore = IForcedInclusionStore(_forcedInclusionStore);
        preconfRouter = _preconfRouter;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatchV2WithForcedInclusion
    function proposeBatch(
        ITaikoInbox.BatchParams calldata _delayedBatchParams,
        ITaikoInbox.BatchParams calldata _regularBatchParams,
        bytes calldata _txList
    )
        external
        onlyFrom(preconfRouter)
        nonReentrant
        returns (ITaikoInbox.BatchMetadata memory)
    {
        if (_delayedBatchParams.blocks.length == 0) {
            // the proposer did not include any forced inclusion in their proposal
            require(!forcedInclusionStore.isOldestForcedInclusionDue(), OldestForcedInclusionDue());
        } else {
            address proposer = _regularBatchParams.proposer;
            _validateForcedInclusionParams(forcedInclusionStore, _delayedBatchParams, proposer);
            inbox.proposeBatch(_delayedBatchParams, "");
        }

        // Propose the normal batch after the potential forced inclusion batch.
        require(_regularBatchParams.blobParams.blobHashes.length == 0, ITaikoInbox.InvalidBlobParams());
        require(_regularBatchParams.blobParams.createdIn == 0, ITaikoInbox.InvalidBlobCreatedIn());
        return inbox.proposeBatch(_regularBatchParams, _txList);
    }

    /// @dev Validates the forced inclusion params and consumes the oldest forced inclusion.
    /// @param _forcedInclusionStore The forced inclusion store.
    /// @param _delayedBatchParams The delayed batch params.
    /// @param _proposer The proposer of the regular batch.
    function _validateForcedInclusionParams(
        IForcedInclusionStore _forcedInclusionStore,
        ITaikoInbox.BatchParams calldata _delayedBatchParams,
        address _proposer
    )
        internal
    {

        IForcedInclusionStore.ForcedInclusion memory inclusion =
            _forcedInclusionStore.consumeOldestForcedInclusion(_delayedBatchParams.proposer);

        // Ensure the proposer is the same that for the regular batch(which is validated upstream)
        require(_delayedBatchParams.proposer == _proposer, InvalidProposer());

        // Only one block can be built from the request
        require(_delayedBatchParams.blocks.length == 1, InvalidBlockSize());

        // Need to make sure enough transactions in the forced inclusion request are included.
        require(_delayedBatchParams.blocks[0].numTransactions >= MIN_TXS_PER_FORCED_INCLUSION, InvalidBlockTxs());
        require(_delayedBatchParams.blocks[0].timeShift == 0, InvalidTimeShift());
        require(_delayedBatchParams.blocks[0].signalSlots.length == 0, InvalidSignalSlots());

        require(_delayedBatchParams.blobParams.blobHashes.length == 1, InvalidBlobHashesSize());
        require(_delayedBatchParams.blobParams.blobHashes[0] == inclusion.blobHash, InvalidBlobHash());
        require(_delayedBatchParams.blobParams.byteOffset == inclusion.blobByteOffset, InvalidBlobByteOffset());
        require(_delayedBatchParams.blobParams.byteSize == inclusion.blobByteSize, InvalidBlobByteSize());
        require(_delayedBatchParams.blobParams.createdIn == inclusion.blobCreatedIn, InvalidBlobCreatedIn());

        emit ForcedInclusionProcessed(inclusion);
    }
}
