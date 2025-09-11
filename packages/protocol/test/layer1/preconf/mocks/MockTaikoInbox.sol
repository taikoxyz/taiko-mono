// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/shared/common/EssentialContract.sol";

contract MockTaikoInbox is EssentialContract {
    bytes32 internal metaHash;
    mapping(uint64 => ITaikoInbox.Batch) private _batches;
    mapping(uint64 => ITaikoInbox.TransitionState) private _transitions;
    ITaikoInbox.Config private _config;

    constructor(uint64 _chainId) {
        _config = ITaikoInbox.Config({
            chainId: _chainId,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 100,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 30_000_000,
            livenessBond: 1 ether,
            stateRootSyncInternal: 1,
            maxAnchorHeightOffset: 100,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 1,
                sharingPctg: 1,
                gasIssuancePerSecond: 1,
                minGasExcess: 1,
                maxGasIssuancePerBlock: 1
            }),
            provingWindow: 3600,
            cooldownWindow: 300,
            maxSignalsToReceive: 10,
            maxBlocksPerBatch: 100,
            forkHeights: ITaikoInbox.ForkHeights({
                ontake: 0,
                pacaya: 0,
                shasta: 0,
                unzen: 0,
                etna: 0,
                fuji: 0
            })
        });
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // Used by PreconfRouter
    // -------------------------------------------------------------------

    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata /* _additionalData */
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        // Decode the batch params
        ITaikoInbox.BatchParams memory params = abi.decode(_params, (ITaikoInbox.BatchParams));

        info_ = ITaikoInbox.BatchInfo({
            txsHash: keccak256(_txList),
            blobHashes: new bytes32[](0),
            blobByteOffset: 0,
            blobByteSize: 0,
            extraData: 0,
            coinbase: params.coinbase == address(0) ? params.proposer : params.coinbase,
            proposer: params.proposer,
            gasLimit: 0, // Mock value
            lastBlockId: 0,
            lastBlockTimestamp: 0,
            proposedIn: uint64(block.number),
            blobCreatedIn: 0,
            anchorBlockId: params.anchorBlockId,
            anchorBlockHash: bytes32(0), // Mock value
            blocks: params.blocks,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 0,
                sharingPctg: 75,
                gasIssuancePerSecond: 0,
                minGasExcess: 0,
                maxGasIssuancePerBlock: 0
            })
        });

        meta_ = ITaikoInbox.BatchMetadata({
            batchId: 0,
            prover: params.proposer,
            proposedAt: uint64(block.timestamp),
            infoHash: keccak256(abi.encode(info_)),
            firstBlockId: info_.lastBlockId
        });

        metaHash = keccak256(abi.encode(meta_));
    }

    // Used by PreconfSlasher
    // -------------------------------------------------------------------

    function v4GetBatch(uint64 _batchId) external view returns (ITaikoInbox.Batch memory) {
        return _batches[_batchId];
    }

    function v4GetBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (ITaikoInbox.TransitionState memory)
    {
        return _transitions[_batchId];
    }

    function v4GetConfig() external view returns (ITaikoInbox.Config memory) {
        return _config;
    }

    function setBatch(uint64 _batchId, ITaikoInbox.Batch memory _batch) external {
        _batches[_batchId] = _batch;
    }

    function setTransition(
        uint64 _batchId,
        ITaikoInbox.TransitionState memory _transition
    )
        external
    {
        _transitions[_batchId] = _transition;
    }
}
