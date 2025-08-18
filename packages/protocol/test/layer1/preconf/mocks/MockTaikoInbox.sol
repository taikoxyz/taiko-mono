// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/based/IProposeBatch.sol";
import "src/shared/common/EssentialContract.sol";

contract MockTaikoInbox is EssentialContract, IProposeBatchV2 {
    bytes32 internal metaHash;

    constructor(address _resolver) EssentialContract(_resolver) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function proposeBatch(
        ITaikoInbox.BatchParams calldata params,
        bytes calldata _txList
    )
        external
        override
        returns (ITaikoInbox.BatchMetadata memory meta_)
    {
        ITaikoInbox.BatchInfo memory info_ = ITaikoInbox.BatchInfo({
            txsHash: keccak256(_txList),
            blobHashes: new bytes32[](0),
            blobByteOffset: 0,
            blobByteSize: 0,
            extraData: bytes32(0),
            coinbase: params.coinbase == address(0) ? params.proposer : params.coinbase,
            gasLimit: 0, // Mock value
            lastBlockId: 0,
            lastBlockTimestamp: 0,
            proposedIn: uint64(block.number),
            blobCreatedIn: 0,
            anchorBlockId: params.anchorBlockId,
            anchorBlockHash: bytes32(0), // Mock value
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 0,
                sharingPctg: 0,
                gasIssuancePerSecond: 0,
                minGasExcess: 0,
                maxGasIssuancePerBlock: 0
            })
        });

        meta_ = ITaikoInbox.BatchMetadata({
            batchId: 0,
            proposer: params.proposer,
            proposedAt: uint64(block.timestamp),
            infoHash: keccak256(abi.encode(info_))
        });

        metaHash = keccak256(abi.encode(meta_));
    }
}
