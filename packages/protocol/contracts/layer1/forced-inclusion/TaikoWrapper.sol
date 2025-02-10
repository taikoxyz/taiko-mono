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

    error NoBlocks();
    error InvalidBlockTxs();
    error InvalidBlobHashesSize();
    error InvalidBlobHash();
    error InvalidBlobByteOffset();
    error InvalidBlobByteSize();
    error OldestForcedInclusionDue();

    uint16 public constant MIN_TXS_PER_FORCED_INCLUSION = 512;

    uint256[50] private __gap;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatch
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        onlyFromNamed(LibStrings.B_PRECONF_ROUTER)
        nonReentrant
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        ITaikoInbox inbox = ITaikoInbox(resolve(LibStrings.B_TAIKO, false));
        IForcedInclusionStore store =
            IForcedInclusionStore(resolve(LibStrings.B_FORCED_INCLUSION_STORE, false));

        (bytes memory bytesX, bytes memory bytesY) = abi.decode(_params, (bytes, bytes));

        if (bytesX.length == 0) {
            require(!store.isOldestForcedInclusionDue(), OldestForcedInclusionDue());
        } else {
            _validateForcedInclusionParams(store, bytesX);
            inbox.proposeBatch(bytesX, "");
        }

        // Propose the normal batch after the potential forced inclusion batch.
        return inbox.proposeBatch(bytesY, _txList);
    }

    function _validateForcedInclusionParams(
        IForcedInclusionStore _store,
        bytes memory _bytesX
    )
        internal
    {
        ITaikoInbox.BatchParams memory p = abi.decode(_bytesX, (ITaikoInbox.BatchParams));

        IForcedInclusionStore.ForcedInclusion memory inclusion =
            _store.consumeOldestForcedInclusion(p.proposer);

        uint256 numBlocks = p.blocks.length;
        require(numBlocks != 0, NoBlocks());

        for (uint256 i; i < numBlocks; ++i) {
            // Need to make sure enough transactions in the forced inclusion request are included.
            require(p.blocks[i].numTransactions >= MIN_TXS_PER_FORCED_INCLUSION, InvalidBlockTxs());
        }

        require(p.blobParams.blobHashes.length == 1, InvalidBlobHashesSize());
        require(p.blobParams.blobHashes[0] == inclusion.blobHash, InvalidBlobHash());
        require(p.blobParams.byteOffset == inclusion.blobByteOffset, InvalidBlobByteOffset());
        require(p.blobParams.byteSize == inclusion.blobByteSize, InvalidBlobByteSize());

        emit ForcedInclusionProcessed(inclusion);
    }
}
