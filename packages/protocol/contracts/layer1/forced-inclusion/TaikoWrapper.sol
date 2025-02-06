// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "src/layer1/based/TaikoInbox.sol";
import "./ForcedInclusionStore.sol";

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

contract TaikoWrapper is EssentialContract {
    using LibMath for uint256;

    /// @dev Event emitted when a forced inclusion is processed.
    event ForcedInclusionProcessed(IForcedInclusionStore.ForcedInclusion);
    /// @dev Error thrown when the oldest forced inclusion is due.

    error OldestForcedInclusionDue();

    uint16 public constant MAX_FORCED_TXS_PER_FORCED_INCLUSION = 512;

    uint256[50] private __gap;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Proposes a batch of blocks with forced inclusion.
    /// @param _forcedInclusionParams An optional ABI-encoded BlockParams for the forced inclusion
    /// batch.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return info_ The info of the proposed batch.
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatchWithForcedInclusion(
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

            // Overwrite the batch params to have only 1 block and up to
            // MAX_FORCED_TXS_PER_FORCED_INCLUSION transactions
            if (params.blocks.length == 0) {
                params.blocks = new ITaikoInbox.BlockParams[](1);
            }

            if (params.blocks[0].numTransactions < MAX_FORCED_TXS_PER_FORCED_INCLUSION) {
                params.blocks[0].numTransactions = MAX_FORCED_TXS_PER_FORCED_INCLUSION;
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
