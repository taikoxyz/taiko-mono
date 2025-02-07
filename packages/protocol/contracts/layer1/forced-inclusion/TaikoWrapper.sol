// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "./ForcedInclusionStore.sol";
import "./ITaikoWrapper.sol";

/// @title TaikoWrapper
/// @dev This contract is part of a delayed inbox implementation to enforce the inclusion of
/// transactions.
/// The current design is a simplified and can be improved with the following ideas:
/// 1. **Fee-Based Request Prioritization**:
///    - Proposers can selectively fulfill pending requests based on transaction fees.
///    - Requests not yet due can be processed earlier if fees are attractive, incentivizing timely
/// execution.
///
/// 2. **Rate Limit Control**:
///    - A rate-limiting mechanism ensures a minimum interval of 12*N seconds between request
/// fulfillments.
///    - Prevents proposers from being overwhelmed during high request volume, ensuring system
/// stability.
///
/// 3. **Calldata and Blob Support**:
///    - Supports both calldata and blobs in the transaction list.
///
/// 4. **Gas-Efficient Request Storage**:
///    - Avoids storing full request data in contract storage.
///    - Saves only the request hash and its timestamp.
///    - Leverages Ethereum events to store request details off-chain.
///    - Proposers can reconstruct requests as needed, minimizing on-chain storage and gas
/// consumption.
///
/// @custom:security-contact security@taiko.xyz
contract TaikoWrapper is EssentialContract, ITaikoWrapper {
    using LibMath for uint256;

    uint16 public constant MAX_FORCED_TXS_PER_FORCED_INCLUSION = 512;

    uint256[50] private __gap;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ITaikoWrapper
    function proposeBatch(
        bytes calldata _forcedInclusionParams,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        nonReentrant
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        ITaikoInbox inbox = ITaikoInbox(resolve(LibStrings.B_TAIKO, false));
        IForcedInclusionStore store =
            IForcedInclusionStore(resolve(LibStrings.B_FORCED_INCLUSION_STORE, false));

        if (_forcedInclusionParams.length == 0) {
            require(!store.isOldestForcedInclusionDue(), OldestForcedInclusionDue());
        } else {
            IForcedInclusionStore.ForcedInclusion memory inclusion =
                store.consumeOldestForcedInclusion(msg.sender);

            ITaikoInbox.BatchParams memory params =
                abi.decode(_forcedInclusionParams, (ITaikoInbox.BatchParams));

            uint256 numBlocks = params.blocks.length;
            require(numBlocks != 0, InvalidForcedInclusionParams());
            for (uint256 i; i < numBlocks; ++i) {
                require(
                    params.blocks[i].numTransactions >= MAX_FORCED_TXS_PER_FORCED_INCLUSION,
                    InvalidForcedInclusionParams()
                );
            }

            params.blobParams.blobHashes = new bytes32[](1);
            params.blobParams.blobHashes[0] = inclusion.blobHash;
            params.blobParams.byteOffset = inclusion.blobByteOffset;
            params.blobParams.byteSize = inclusion.blobByteSize;

            inbox.proposeBatch(abi.encode(params), "");
            emit ForcedInclusionProcessed(inclusion);
        }

        (info_, meta_) = inbox.proposeBatch(_params, _txList);
    }
}
