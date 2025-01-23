// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./IFork.sol";
import "./ITaikoInbox.sol";

interface IForcedInclusionStore {
    struct ForcedInclusion {
        uint64 id;
        bytes32 blobhash;
        uint32 blobByteOffset;
        uint32 blobByteSize;
        uint256 priorityFee;
    }

    /// @dev Consume a forced inclusion request.
    /// The inclusion request must be marked as process and the priority fee must be paid to the
    /// caller.
    function consumeForcedInclusion() external returns (ForcedInclusion memory);
}

/// @title TaikoInboxWithForcedTxInclusion
/// @custom:security-contact security@taiko.xyz
contract TaikoInboxWithForcedTxInclusion is EssentialContract {
    using LibMath for uint256;

    event ForcedInclusionProcessed(IForcedInclusionStore.ForcedInclusion);

    uint16 public constant MAX_FORCED_TXS_PER_FORCED_INCLUSION = 512;
    uint256[50] private __gap;

    // External functions ------------------------------------------------------------------------

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Proposes a batch of blocks.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    function proposeBatchWithForcedInclusion(
        bytes calldata _forcedInclusionParams,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        nonReentrant
    {
        ITaikoInbox inbox = ITaikoInbox(resolve("taiko", false));
        inbox.proposeBatch(_params, _txList);

        IForcedInclusionStore.ForcedInclusion memory forcedInclusion =
            IForcedInclusionStore(resolve("forced_inclusion_store", false)).consumeForcedInclusion();

        if (forcedInclusion.id != 0) {
            ITaikoInbox.BatchParams memory params;

            if (_forcedInclusionParams.length != 0) {
                params = abi.decode(_forcedInclusionParams, (ITaikoInbox.BatchParams));
            }

            // Force the batch to have 1 block and up to MAX_FORCED_TXS_PER_FORCED_INCLUSION
            // transactions
            params.blocks = new ITaikoInbox.BlockParams[](1);
            params.blocks[0].numTransactions = MAX_FORCED_TXS_PER_FORCED_INCLUSION;

            // TODO: TaikoInbox should support  `BlobParams2` in  `BatchParams`
            ITaikoInbox.BlobParams2 memory blobParams2;
            blobParams2.byteOffset = forcedInclusion.blobByteOffset;
            blobParams2.byteSize = forcedInclusion.blobByteSize;

            inbox.proposeBatch(abi.encode(params), "");
            LibAddress.sendEtherAndVerify(msg.sender, forcedInclusion.priorityFee, gasleft());
            emit ForcedInclusionProcessed(forcedInclusion);
        }
    }
}
