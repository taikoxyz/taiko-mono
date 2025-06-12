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
contract TaikoWrapper is EssentialContract, IProposeBatch {
    using LibMath for uint256;

    /// @dev Event emitted when a forced inclusion is processed but failed to be proposed as a batch
    event ForcedInclusionFailed(IForcedInclusionStore.ForcedInclusion, ITaikoInbox.BatchParams);

    error InvalidBlockTxs();
    error InvalidBlobHashesSize();
    error InvalidBlobHash();
    error InvalidBlobByteOffset();
    error InvalidBlobByteSize();
    error InvalidBlobCreatedIn();
    error InvalidBlockSize();
    error InvalidForcedInclusionProposer();
    error InvalidForcedInclusionProver();
    error InvalidTimeShift();
    error InvalidSignalSlots();
    error OldestForcedInclusionDue();

    uint16 public constant MIN_TXS_PER_FORCED_INCLUSION = 512;
    IProposeBatch public immutable inbox;
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
        EssentialContract()
    {
        inbox = IProposeBatch(_inbox);
        forcedInclusionStore = IForcedInclusionStore(_forcedInclusionStore);
        preconfRouter = _preconfRouter;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatch
    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata
    )
        external
        onlyFromOptional(preconfRouter)
        nonReentrant
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        (bytes memory bytesX, bytes memory bytesY) = abi.decode(_params, (bytes, bytes));

        ITaikoInbox.BatchParams memory params;
        if (bytesX.length == 0) {
            require(!forcedInclusionStore.isOldestForcedInclusionDue(), OldestForcedInclusionDue());
        } else {
            params = abi.decode(bytesX, (ITaikoInbox.BatchParams));
            IForcedInclusionStore.ForcedInclusion memory inclusion =
                _validateForcedInclusionParams(params);

            (bool success, bytes memory returnData) =
                address(inbox).call(abi.encodeCall(ITaikoInbox.v4ProposeBatch, (bytesX, "", "")));

            if (!success) {
                // The forced inclusion proposal might fail if the batch proposer lacks sufficient
                // balance to cover the provability bond. In such cases, an event is emitted to
                // signal the failure, and the forced inclusion is marked as processed.
                emit ForcedInclusionFailed(inclusion, params);
            }

            (info_, meta_) =
                abi.decode(returnData, (ITaikoInbox.BatchInfo, ITaikoInbox.BatchMetadata));

            // We do not check proverAuth, but we need to ensure the assigned prover is not the user
            // himself.
            require(meta_.prover != inclusion.user, InvalidForcedInclusionProver());
        }

        // Propose the normal batch after the potential forced inclusion batch.
        params = abi.decode(bytesY, (ITaikoInbox.BatchParams));

        // Only forced inclusion batches can referene blob hashes that are created in early blocks.
        require(params.blobParams.blobHashes.length == 0, ITaikoInbox.InvalidBlobParams());
        require(params.blobParams.createdIn == 0, ITaikoInbox.InvalidBlobCreatedIn());

        // This normal proposal must not be marked as a forced inclusion batch.
        require(params.isForcedInclusion == false, ITaikoInbox.InvalidForcedInclusion());

        (info_, meta_) = inbox.v4ProposeBatch(bytesY, _txList, "");
    }

    function _validateForcedInclusionParams(ITaikoInbox.BatchParams memory _params)
        internal
        returns (IForcedInclusionStore.ForcedInclusion memory inclusion_)
    {
        inclusion_ = forcedInclusionStore.consumeOldestForcedInclusion(msg.sender);

        // The user who creates the forced inclusion must be he proposer of the batch.
        require(_params.proposer == inclusion_.user, InvalidForcedInclusionProposer());

        // Only one block can be built from the request
        require(_params.blocks.length == 1, InvalidBlockSize());
        require(_params.isForcedInclusion, ITaikoInbox.InvalidForcedInclusion());

        // Need to make sure enough transactions in the forced inclusion request are included.
        require(
            _params.blocks[0].numTransactions >= MIN_TXS_PER_FORCED_INCLUSION, InvalidBlockTxs()
        );
        require(_params.blocks[0].timeShift == 0, InvalidTimeShift());
        require(_params.blocks[0].signalSlots.length == 0, InvalidSignalSlots());

        require(_params.blobParams.blobHashes.length == 1, InvalidBlobHashesSize());
        require(_params.blobParams.blobHashes[0] == inclusion_.blobHash, InvalidBlobHash());
        require(_params.blobParams.byteOffset == inclusion_.blobByteOffset, InvalidBlobByteOffset());
        require(_params.blobParams.byteSize == inclusion_.blobByteSize, InvalidBlobByteSize());
        require(_params.blobParams.createdIn == inclusion_.blobCreatedIn, InvalidBlobCreatedIn());
    }
}
