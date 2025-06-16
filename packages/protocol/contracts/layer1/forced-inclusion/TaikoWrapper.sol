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

error InvalidForcedInclusionProver();


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
        (bytes memory inclusionProverAuth, bytes memory normalParams) =
            abi.decode(_params, (bytes, bytes));

        ITaikoInbox.BatchParams memory params;

        if (forcedInclusionStore.isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory inclusion =
                forcedInclusionStore.consumeOldestForcedInclusion(msg.sender);

            params = _buildInclusionParams(inclusion, inclusionProverAuth);

            (bool success, bytes memory returnData) = address(inbox).call(
                abi.encodeCall(ITaikoInbox.v4ProposeBatch, (abi.encode(params), "", ""))
            );

            if (!success) {
                // The forced inclusion proposal might fail if the batch proposer lacks sufficient
                // balance to cover the provability bond. In such cases, an event is emitted to
                // signal the failure, and the forced inclusion is marked as processed.
                emit ForcedInclusionFailed(inclusion, params);
            }

            // TODO(daniel): who pays the prover fee? How can we decide he amount of prover fee?
            (info_, meta_) =
                abi.decode(returnData, (ITaikoInbox.BatchInfo, ITaikoInbox.BatchMetadata));

            // We do not check proverAuth directly, but we need to ensure the assigned prover is not
            // the user himself.
            require(meta_.prover != inclusion.user, InvalidForcedInclusionProver());
        }

        // Propose the normal batch after the potential forced inclusion batch.
        params = abi.decode(normalParams, (ITaikoInbox.BatchParams));

        // Only forced inclusion batches can referene blob hashes that were created in early blocks.
        require(params.blobParams.blobHashes.length == 0, ITaikoInbox.InvalidBlobParams());
        require(params.blobParams.createdIn == 0, ITaikoInbox.InvalidBlobCreatedIn());

        // This normal proposal must not be marked as a forced inclusion batch.
        require(params.isForcedInclusion == false, ITaikoInbox.InvalidForcedInclusion());

        (info_, meta_) = inbox.v4ProposeBatch(normalParams, _txList, "");
    }

    function _buildInclusionParams(
        IForcedInclusionStore.ForcedInclusion memory _inclusion,
        bytes memory _inclusionProverAuth
    )
        internal
        returns (ITaikoInbox.BatchParams memory params_)
    {
        params_.proposer = _inclusion.user;
        params_.isForcedInclusion = true;
        params_.proverAuth = _inclusionProverAuth;

        params_.blocks = new ITaikoInbox.BlockParams[](1);
        params_.blocks[0].numTransactions = type(uint16).max;

        params_.blobParams.blobHashes = new bytes32[](1);
        params_.blobParams.blobHashes[0] = _inclusion.blobHash;
        params_.blobParams.byteOffset = _inclusion.blobByteOffset;
        params_.blobParams.byteSize = _inclusion.blobByteSize;
        params_.blobParams.createdIn = _inclusion.blobCreatedIn;

    }
}
