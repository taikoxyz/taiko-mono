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
        EssentialContract(address(0))
    {
        inbox = IProposeBatch(_inbox);
        forcedInclusionStore = IForcedInclusionStore(_forcedInclusionStore);
        preconfRouter = _preconfRouter;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatch
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        onlyFromOptional(preconfRouter)
        nonReentrant
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        (bytes memory bytesX, bytes memory bytesY) = abi.decode(_params, (bytes, bytes));

        if (bytesX.length == 0) {
            require(!forcedInclusionStore.isOldestForcedInclusionDue(), OldestForcedInclusionDue());
        } else {
            _validateForcedInclusionParams(forcedInclusionStore, bytesX);
            inbox.proposeBatch(bytesX, "");
        }

        // Propose the normal batch after the potential forced inclusion batch.
        ITaikoInbox.BatchParams memory params = abi.decode(bytesY, (ITaikoInbox.BatchParams));
        require(params.blobParams.blobHashes.length == 0, ITaikoInbox.InvalidBlobParams());
        require(params.blobParams.createdIn == 0, ITaikoInbox.InvalidBlobCreatedIn());
        return inbox.proposeBatch(bytesY, _txList);
    }

    function _validateForcedInclusionParams(
        IForcedInclusionStore _forcedInclusionStore,
        bytes memory _bytesX
    )
        internal
    {
        ITaikoInbox.BatchParams memory p = abi.decode(_bytesX, (ITaikoInbox.BatchParams));

        IForcedInclusionStore.ForcedInclusion memory inclusion =
            _forcedInclusionStore.consumeOldestForcedInclusion(p.proposer);

        // Only one block can be built from the request
        require(p.blocks.length == 1, InvalidBlockSize());

        // Need to make sure enough transactions in the forced inclusion request are included.
        require(p.blocks[0].numTransactions >= MIN_TXS_PER_FORCED_INCLUSION, InvalidBlockTxs());
        require(p.blocks[0].timeShift == 0, InvalidTimeShift());
        require(p.blocks[0].signalSlots.length == 0, InvalidSignalSlots());

        require(p.blobParams.blobHashes.length == 1, InvalidBlobHashesSize());
        require(p.blobParams.blobHashes[0] == inclusion.blobHash, InvalidBlobHash());
        require(p.blobParams.byteOffset == inclusion.blobByteOffset, InvalidBlobByteOffset());
        require(p.blobParams.byteSize == inclusion.blobByteSize, InvalidBlobByteSize());
        require(p.blobParams.createdIn == inclusion.blobCreatedIn, InvalidBlobCreatedIn());

        emit ForcedInclusionProcessed(inclusion);
    }
}
