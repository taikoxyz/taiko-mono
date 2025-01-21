// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/shared/common/EssentialContract.sol";

contract MockTaikoInbox is EssentialContract {
    bytes32 internal metaHash;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_)
    {
        // Decode the batch params
        ITaikoInbox.BatchParams memory params = abi.decode(_params, (ITaikoInbox.BatchParams));

        // Create metadata with minimal required fields for testing
        meta_ = ITaikoInbox.BatchMetadata({
            txListHash: keccak256(_txList),
            extraData: bytes32(0),
            coinbase: params.coinbase == address(0) ? params.proposer : params.coinbase,
            batchId: 0, // Mock value
            gasLimit: 0, // Mock value
            lastBlockTimestamp: params.lastBlockTimestamp,
            parentMetaHash: params.parentMetaHash,
            proposer: params.proposer,
            livenessBond: 0, // Mock value
            proposedAt: uint64(block.timestamp),
            proposedIn: uint64(block.number),
            blobByteOffset: params.blobByteOffset,
            blobByteSize: params.blobByteSize,
            firstBlobIndex: 0,
            numBlobs: params.numBlobs,
            anchorBlockId: params.anchorBlockId,
            anchorBlockHash: bytes32(0), // Mock value
            signalSlots: params.signalSlots,
            blocks: params.blocks,
            anchorInput: params.anchorInput,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 0,
                sharingPctg: 0,
                gasIssuancePerSecond: 0,
                minGasExcess: 0,
                maxGasIssuancePerBlock: 0
            })
        });

        metaHash = keccak256(abi.encode(meta_));
    }
}
