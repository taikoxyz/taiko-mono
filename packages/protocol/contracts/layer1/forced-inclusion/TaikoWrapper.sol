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
        bytes calldata _proverAuthForForcedInclusion
    )
        external
        onlyFromOptional(preconfRouter)
        nonReentrant
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        ITaikoInbox.BatchParams memory params;

        // TODO: This batch doesn't have an non-zero anchor ID!!!
        if (forcedInclusionStore.isOldestForcedInclusionDue()) {
            params = _consumeForcedInclusion();
            params.proverAuth = _proverAuthForForcedInclusion;
            inbox.v4ProposeBatch(abi.encode(params), "", "");
        } else {
            require(_proverAuthForForcedInclusion.length == 0, "INVALID");
        }

        // Propose the normal batch after the forced inclusion batch.
        params = abi.decode(_params, (ITaikoInbox.BatchParams));
        require(params.isForcedInclusion == false, ITaikoInbox.InvalidForcedInclusion());
        require(params.blobParams.blobHashes.length == 0, ITaikoInbox.InvalidBlobParams());
        require(params.blobParams.createdIn == 0, ITaikoInbox.InvalidBlobCreatedIn());
        return inbox.v4ProposeBatch(_params, _txList, "");
    }

    function _consumeForcedInclusion() internal returns (ITaikoInbox.BatchParams memory params_) {
        IForcedInclusionStore.ForcedInclusion memory inclusion =
            forcedInclusionStore.consumeOldestForcedInclusion(msg.sender);

        // params_.proposer = ??
        params_.blocks = new ITaikoInbox.BlockParams[](1);
        params_.blocks[0].numTransactions = MIN_TXS_PER_FORCED_INCLUSION;
        params_.isForcedInclusion = true;
        params_.blobParams.blobHashes = new bytes32[](1);
        params_.blobParams.blobHashes[0] = inclusion.blobHash;
        params_.blobParams.byteOffset = inclusion.blobByteOffset;
        params_.blobParams.byteSize = inclusion.blobByteSize;
        params_.blobParams.createdIn = inclusion.blobCreatedIn;
    }
}
