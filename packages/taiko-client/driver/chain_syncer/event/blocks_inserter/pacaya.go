package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	shastaManifest "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/manifest"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// Pacaya is responsible for inserting Pacaya blocks to the L2 execution engine.
type Pacaya struct {
	rpc                  *rpc.Client
	progressTracker      *beaconsync.SyncProgressTracker
	blobDatasource       *rpc.BlobDataSource
	txListDecompressor   *txListDecompressor.TxListDecompressor   // Transactions list decompressor
	anchorConstructor    *anchorTxConstructor.AnchorTxConstructor // TaikoAnchor.anchorV3 transactions constructor
	calldataFetcher      txlistFetcher.TxListFetcher
	blobFetcher          txlistFetcher.TxListFetcher
	latestSeenProposalCh chan *encoding.LastSeenProposal
	mutex                sync.Mutex
}

// NewBlocksInserterPacaya creates a new Pacaya instance.
func NewBlocksInserterPacaya(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	blobDatasource *rpc.BlobDataSource,
	txListDecompressor *txListDecompressor.TxListDecompressor,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	calldataFetcher txlistFetcher.TxListFetcher,
	blobFetcher txlistFetcher.TxListFetcher,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) *Pacaya {
	return &Pacaya{
		rpc:                  rpc,
		progressTracker:      progressTracker,
		blobDatasource:       blobDatasource,
		txListDecompressor:   txListDecompressor,
		anchorConstructor:    anchorConstructor,
		calldataFetcher:      calldataFetcher,
		blobFetcher:          blobFetcher,
		latestSeenProposalCh: latestSeenProposalCh,
	}
}

// FetchTxListBytes fetches the txList bytes from blob sidecars or calldata.
func (i *Pacaya) FetchTxListBytes(
	ctx context.Context,
	meta metadata.TaikoBatchMetaDataPacaya,
) ([]byte, error) {
	if len(meta.GetBlobHashes()) != 0 {
		txListBytes, err := i.blobFetcher.FetchPacaya(ctx, meta)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch tx list from blob: %w", err)
		}
		return txListBytes, nil
	}

	txListBytes, err := i.calldataFetcher.FetchPacaya(ctx, meta)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch tx list from calldata: %w", err)
	}
	return txListBytes, nil
}

// InsertBlocks inserts new Pacaya blocks to the L2 execution engine.
func (i *Pacaya) InsertBlocks(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) (err error) {
	if !metadata.IsPacaya() {
		return errors.New("metadata is not for Pacaya fork")
	}
	txListBytes, err := i.FetchTxListBytes(ctx, metadata.Pacaya())
	if err != nil {
		return err
	}

	return i.InsertBlocksWithTxListBytes(ctx, metadata, txListBytes)
}

// InsertBlocksWithTxListBytes inserts new Pacaya blocks using the provided txList bytes.
func (i *Pacaya) InsertBlocksWithTxListBytes(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	txListBytes []byte,
) (err error) {
	meta := metadata.Pacaya()
	// We assume the proposal won't cause a reorg, if so, we will resend a new proposal
	// to the channel.
	latestSeenProposal := &encoding.LastSeenProposal{
		TaikoProposalMetaData: metadata,
		LastBlockID:           meta.GetLastBlockID(),
	}
	allTxs := i.txListDecompressor.TryDecompress(txListBytes, len(meta.GetBlobHashes()) != 0)

	i.mutex.Lock()
	defer i.mutex.Unlock()

	var (
		parent              *types.Header
		lastPayloadData     *engine.ExecutableData
		batchSafeCheckpoint *verifiedCheckpoint
	)

	log.Debug(
		"Inserting blocks to L2 execution engine",
		"batchID", meta.GetBatchID(),
		"lastBlockID", meta.GetLastBlockID(),
		"assignedProver", meta.GetProposer(),
		"lastTimestamp", meta.GetLastBlockTimestamp(),
		"coinbase", meta.GetCoinbase(),
		"numBlobs", len(meta.GetBlobHashes()),
		"blocks", len(meta.GetBlocks()),
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
				if meta.GetBatchID().Uint64() == i.rpc.PacayaClients.ForkHeights.Pacaya {
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

			lastBlockHeader, isKnown, err := isKnownCanonicalBatchPacaya(
				ctx,
				i.rpc,
				i.anchorConstructor,
				metadata,
				allTxs,
				parent,
			)
			if err != nil {
				return fmt.Errorf("failed to check if Pacaya batch is known in canonical chain: %w", err)
			}
			if isKnown && lastBlockHeader != nil {
				log.Info(
					"🧬 Known Pacaya batch in canonical chain",
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
				if err := updateL1OriginForBatchPacaya(ctx, i.rpc, metadata); err != nil {
					return fmt.Errorf("failed to update L1 origin for batch (%d): %w", meta.GetBatchID().Uint64(), err)
				}

				return nil
			}
		}

		// Otherwise, we need to create a new execution payload and set it as the head block in L2 EE.
		if batchSafeCheckpoint == nil {
			lastVerifiedTS, err := i.rpc.GetLastVerifiedTransitionPacaya(ctx)
			if err != nil {
				return fmt.Errorf("failed to fetch last verified block: %w", err)
			}
			batchSafeCheckpoint = &verifiedCheckpoint{ // Reuse across blocks in this batch.
				BlockID:   new(big.Int).SetUint64(lastVerifiedTS.BlockId),
				BlockHash: lastVerifiedTS.Ts.BlockHash,
			}
		}

		createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaPacaya(
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
				Parent:                          parent,
				VerifiedCheckpoint:              batchSafeCheckpoint,
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

		latestSeenProposal.LastBlockID = lastPayloadData.Number

		metrics.DriverL2HeadHeightGauge.Set(float64(lastPayloadData.Number))
	}

	// Mark the last seen proposal as not preconfirmed and send it to the channel.
	latestSeenProposal.PreconfChainReorged = true
	go i.sendLatestSeenProposal(latestSeenProposal)

	return nil
}

// InsertBlocksWithManifest won't be used for Pacaya blocks, just return an error.
func (i *Pacaya) InsertBlocksWithManifest(
	_ context.Context,
	_ metadata.TaikoProposalMetaData,
	_ *shastaManifest.ShastaDerivationSourcePayload,
	_ eventIterator.EndBatchProposedEventIterFunc,
) (*big.Int, error) {
	return nil, errors.New("not supported in Pacaya")
}

// InsertPreconfBlocksFromEnvelopes inserts preconfirmation blocks from the given envelopes.
func (i *Pacaya) InsertPreconfBlocksFromEnvelopes(
	ctx context.Context,
	envelopes []*preconf.Envelope,
	fromCache bool,
) ([]*types.Header, error) {
	i.mutex.Lock()
	defer i.mutex.Unlock()

	log.Debug(
		"Insert preconfirmation blocks from envelopes",
		"numBlocks", len(envelopes),
		"fromCache", fromCache,
	)

	headers := make([]*types.Header, len(envelopes))
	for j, envelope := range envelopes {
		header, err := i.insertPreconfBlockFromEnvelope(ctx, envelope)
		if err != nil {
			return nil, fmt.Errorf("failed to insert preconfirmation block %d: %w", envelope.Payload.BlockNumber, err)
		}
		log.Info(
			"⏰ New preconfirmation L2 block inserted",
			"blockID", header.Number,
			"hash", header.Hash(),
			"fork", "Pacaya",
			"coinbase", header.Coinbase.Hex(),
			"timestamp", header.Time,
			"baseFee", utils.WeiToGWei(header.BaseFee),
			"withdrawalsHash", header.WithdrawalsHash,
			"gasLimit", header.GasLimit,
			"gasUsed", header.GasUsed,
			"parentHash", header.ParentHash,
			"fromCache", fromCache,
		)
		headers[j] = header
	}

	return headers, nil
}

// insertPreconfBlockFromEnvelope the inner method to insert a preconfirmation block from
// the given envelope.
func (i *Pacaya) insertPreconfBlockFromEnvelope(
	ctx context.Context,
	envelope *preconf.Envelope,
) (*types.Header, error) {
	return InsertPreconfBlockFromEnvelope(ctx, i.rpc, envelope)
}

// sendLatestSeenProposal sends the latest seen proposal to the channel, if it is not nil.
func (i *Pacaya) sendLatestSeenProposal(proposal *encoding.LastSeenProposal) {
	if i.latestSeenProposalCh != nil {
		log.Debug(
			"Sending latest seen pacaya proposal from blocksInserter",
			"batchID", proposal.TaikoProposalMetaData.Pacaya().GetBatchID(),
			"lastBlockID", proposal.TaikoProposalMetaData.Pacaya().GetLastBlockID(),
			"preconfChainReorged", proposal.PreconfChainReorged,
		)

		i.latestSeenProposalCh <- proposal
	}
}
