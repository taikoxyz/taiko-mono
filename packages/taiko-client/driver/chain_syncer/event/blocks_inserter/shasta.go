package blocksinserter

import (
	"context"
	"errors"
	"fmt"

	"log"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/manifest_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Shasta is responsible for inserting Shasta blocks to the L2 execution engine.
type Shasta struct {
	rpc                  *rpc.Client
	progressTracker      *beaconsync.SyncProgressTracker
	blobDatasource       *rpc.BlobDataSource
	decompressor         *manifest_decompressor.ManifestDecompressor // Manifest decompressor
	anchorConstructor    *anchorTxConstructor.AnchorTxConstructor    // ShastaAnchor.updateState transactions constructor
	blobFetcher          txlistFetcher.TxListFetcher
	latestSeenProposalCh chan *encoding.LastSeenProposal
	mutex                sync.Mutex
}

// NewBlocksInserterShasta creates a new Shasta instance.
func NewBlocksInserterShasta(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	blobDatasource *rpc.BlobDataSource,
	decompressor *manifest_decompressor.ManifestDecompressor,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	blobFetcher txlistFetcher.TxListFetcher,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) *Shasta {
	return &Shasta{
		rpc:                  rpc,
		progressTracker:      progressTracker,
		blobDatasource:       blobDatasource,
		decompressor:         decompressor,
		anchorConstructor:    anchorConstructor,
		blobFetcher:          blobFetcher,
		latestSeenProposalCh: latestSeenProposalCh,
	}
}

// InsertBlocks inserts new Shasta blocks to the L2 execution engine.
func (i *Shasta) InsertBlocks(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) (err error) {
	if !metadata.IsShasta() {
		return fmt.Errorf("metadata is not for Shasta fork")
	}
	i.mutex.Lock()
	defer i.mutex.Unlock()

	var (
		// We assume the proposal won't cause a reorg, if so, we will resend a new proposal
		// to the channel.
		latestSeenProposal = &encoding.LastSeenProposal{TaikoProposalMetaData: metadata}
		meta               = metadata.Shasta()
		proposalManifest   = manifest.ProposalManifest{IsDefault: true}
	)

	metadataBytes, err := i.blobFetcher.FetchShasta(ctx, meta)
	if err != nil && !errors.Is(err, pkg.ErrBlobValidationFailed) {
		return err
	} else {
		proposalManifest = i.decompressor.TryDecompressProposalManifest(metadataBytes, int(meta.GetDerivation().BlobSlice.Offset.Int64()))
		// Check Block-level metadata
	}

	if proposalManifest.IsDefault {

	} else {

	}

	log.Debug(
		"Inserting blocks to L2 execution engine",
		"proposalID", meta.GetProposal().Id,
		"assignedProver", meta.GetProposal().Proposer,
		"lastTimestamp", meta.GetLastBlockTimestamp(),
		"coinbase", meta.GetCoinbase(),
		"numBlobs", len(meta.GetBlobHashes()),
	)

	var (
		parent          *types.Header
		lastPayloadData *engine.ExecutableData
	)

	go i.sendLatestSeenProposal(latestSeenProposal)

	for j := range meta.GetBlocks() {
		// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
		// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
		if i.progressTracker.Triggered() {
			// Already synced through beacon sync, just skip this event.
			if new(big.Int).SetUint64(meta.GetLastBlockID()).Cmp(i.progressTracker.LastSyncedBlockID()) <= 0 {
				return nil
			}

			parent, err = i.rpc.L2.HeaderByHash(ctx, i.progressTracker.LastSyncedBlockHash())
		} else {
			var parentNumber *big.Int
			if lastPayloadData == nil {
				if meta.GetBatchID().Uint64() == i.rpc.ShastaClients.ForkHeights.Shasta {
					parentNumber = new(big.Int).SetUint64(meta.GetBatchID().Uint64() - 1)
				} else {
					lastBatch, err := i.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(meta.GetBatchID().Uint64()-1))
					if err != nil {
						return fmt.Errorf("failed to fetch last batch (%d): %w", meta.GetBatchID().Uint64()-1, err)
					}
					parentNumber = new(big.Int).SetUint64(lastBatch.LastBlockId)
				}
			} else {
				parentNumber = new(big.Int).SetUint64(lastPayloadData.Number)
			}

			parent, err = i.rpc.L2ParentByCurrentBlockID(ctx, new(big.Int).Add(parentNumber, common.Big1))
		}
		if err != nil {
			return fmt.Errorf("failed to fetch L2 parent block: %w", err)
		}

		log.Debug(
			"Parent block",
			"blockID", parent.Number,
			"hash", parent.Hash(),
			"beaconSyncTriggered", i.progressTracker.Triggered(),
		)

		// If this is the first block in the batch, we check if the whole batch has been inserted by
		// trying to fetch the last block header from L2 EE. If it is known in canonical,
		// we can skip the rest of the blocks, and only update the L1Origin in L2 EE for each block.
		if j == 0 {
			log.Debug(
				"Checking if batch is in canonical chain",
				"batchID", meta.GetBatchID(),
				"lastBlockID", meta.GetLastBlockID(),
				"assignedProver", meta.GetProposer(),
				"lastTimestamp", meta.GetLastBlockTimestamp(),
				"coinbase", meta.GetCoinbase(),
				"numBlobs", len(meta.GetBlobHashes()),
				"blocks", len(meta.GetBlocks()),
				"parentNumber", parent.Number,
				"parentHash", parent.Hash(),
			)

			lastBlockHeader, err := isKnownCanonicalBatch(
				ctx,
				i.rpc,
				i.anchorConstructor,
				metadata,
				allTxs,
				txListBytes,
				parent,
			)
			if err != nil {
				log.Info("Unknown batch for the current canonical chain", "batchID", meta.GetBatchID(), "reason", err)
			} else if lastBlockHeader != nil {
				log.Info(
					"🧬 Known batch in canonical chain",
					"batchID", meta.GetBatchID(),
					"lastBlockID", meta.GetLastBlockID(),
					"lastBlockHash", lastBlockHeader.Hash(),
					"assignedProver", meta.GetProposer(),
					"lastTimestamp", meta.GetLastBlockTimestamp(),
					"coinbase", meta.GetCoinbase(),
					"numBlobs", len(meta.GetBlobHashes()),
					"blocks", len(meta.GetBlocks()),
					"parentNumber", parent.Number,
					"parentHash", parent.Hash(),
				)

				// Update the L1 origin for each block in the batch.
				if err := updateL1OriginForBatch(ctx, i.rpc, metadata); err != nil {
					return fmt.Errorf("failed to update L1 origin for batch (%d): %w", meta.GetBatchID().Uint64(), err)
				}

				return nil
			}
		}

		// Otherwise, we need to create a new execution payload and set it as the head block in L2 EE.
		createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaShasta(
			ctx,
			i.rpc,
			i.anchorConstructor,
			metadata,
			allTxs,
			parent,
			j,
		)
		if err != nil {
			return fmt.Errorf("failed to assemble execution payload creation metadata: %w", err)
		}

		// Decompress the transactions list and try to insert a new head block to L2 EE.
		if lastPayloadData, err = createPayloadAndSetHead(
			ctx,
			i.rpc,
			&createPayloadAndSetHeadMetaData{
				createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
				AnchorBlockID:                   new(big.Int).SetUint64(meta.GetAnchorBlockID()),
				AnchorBlockHash:                 meta.GetAnchorBlockHash(),
				BaseFeeConfig:                   meta.GetBaseFeeConfig(),
				Parent:                          parent,
			},
			anchorTx,
		); err != nil {
			return fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
		}

		log.Debug("Payload data", "hash", lastPayloadData.BlockHash, "txs", len(lastPayloadData.Transactions))

		// Wait till the corresponding L2 header to be existed in the L2 EE.
		if _, err := i.rpc.WaitL2Header(ctx, new(big.Int).SetUint64(lastPayloadData.Number)); err != nil {
			return fmt.Errorf("failed to wait for L2 header (%d): %w", lastPayloadData.Number, err)
		}

		log.Info(
			"🔗 New L2 block inserted",
			"blockID", lastPayloadData.Number,
			"hash", lastPayloadData.BlockHash,
			"coinbase", lastPayloadData.FeeRecipient.Hex(),
			"transactions", len(lastPayloadData.Transactions),
			"timestamp", lastPayloadData.Timestamp,
			"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
			"withdrawals", len(lastPayloadData.Withdrawals),
			"batchID", meta.GetBatchID(),
			"gasLimit", lastPayloadData.GasLimit,
			"gasUsed", lastPayloadData.GasUsed,
			"parentHash", lastPayloadData.ParentHash,
			"indexInBatch", j,
		)

		metrics.DriverL2HeadHeightGauge.Set(float64(lastPayloadData.Number))
	}

	// Mark the last seen proposal as not preconfirmed and send it to the channel.
	latestSeenProposal.PreconfChainReorged = true
	go i.sendLatestSeenProposal(latestSeenProposal)

	return nil
}

// InsertPreconfBlocksFromEnvelopes inserts preconfirmation blocks from the given envelopes.
func (i *Shasta) InsertPreconfBlocksFromEnvelopes(
	ctx context.Context,
	envelopes []*preconf.Envelope,
	fromCache bool,
) ([]*types.Header, error) {
	panic("To be implemented")
}

// sendLatestSeenProposal sends the latest seen proposal to the channel, if it is not nil.
func (i *Shasta) sendLatestSeenProposal(proposal *encoding.LastSeenProposal) {
	if i.latestSeenProposalCh != nil {
		log.Debug(
			"Sending latest seen proposal from blocksInserter",
			"proposalID", proposal.TaikoProposalMetaData.Shasta().GetProposal().Id,
			"preconfChainReorged", proposal.PreconfChainReorged,
		)

		i.latestSeenProposalCh <- proposal
	}
}
