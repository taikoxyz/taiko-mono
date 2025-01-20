package blocks_inserter

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BlocksInserterOntake is responsible for inserting Ontake blocks to the L2 execution engine.
type BlocksInserterPacaya struct {
	rpc                *rpc.Client
	progressTracker    *beaconsync.SyncProgressTracker
	blobDatasource     *rpc.BlobDataSource
	txListDecompressor *txListDecompressor.TxListDecompressor   // Transactions list decompressor
	anchorConstructor  *anchorTxConstructor.AnchorTxConstructor // TaikoL2.anchor transactions constructor
}

// NewBlocksInserterOntake creates a new BlocksInserterOntake instance.
func NewBlocksInserterPacaya(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	blobDatasource *rpc.BlobDataSource,
	txListDecompressor *txListDecompressor.TxListDecompressor,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
) *BlocksInserterPacaya {
	return &BlocksInserterPacaya{
		rpc:                rpc,
		progressTracker:    progressTracker,
		blobDatasource:     blobDatasource,
		txListDecompressor: txListDecompressor,
		anchorConstructor:  anchorConstructor,
	}
}

// InsertBlocks inserts a new Ontake block to the L2 execution engine.
func (i *BlocksInserterPacaya) InsertBlocks(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	proposingTx *types.Transaction,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) error {
	if !metadata.IsPacaya() {
		return fmt.Errorf("metadata is not for Pacaya fork")
	}
	meta := metadata.TaikoBatchMetaDataPacaya()

	batch, err := i.rpc.GetBatchByID(ctx, meta.GetBatchID())
	if err != nil {
		return fmt.Errorf("failed to fetch batch: %w", err)
	}

	// Decode transactions list.
	var txListFetcher txlistFetcher.TxListFetcher
	if meta.GetNumBlobs() != 0 {
		txListFetcher = txlistFetcher.NewBlobTxListFetcher(i.rpc.L1Beacon, i.blobDatasource)
	} else {
		txListFetcher = txlistFetcher.NewCalldataFetch(i.rpc)
	}
	txListBytes, err := txListFetcher.FetchPacaya(ctx, proposingTx, meta)
	if err != nil {
		return fmt.Errorf("failed to fetch tx list: %w", err)
	}

	var (
		allTxs = i.txListDecompressor.TryDecompress(
			i.rpc.L2.ChainID,
			txListBytes,
			meta.GetNumBlobs() != 0,
			true,
		)
		parent          *types.Header
		lastPayloadData *engine.ExecutableData
		txListCursor    = 0
	)

	for j, blockInfo := range meta.GetBlocks() {
		// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
		// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
		if i.progressTracker.Triggered() {
			// Already synced through beacon sync, just skip this event.
			if new(big.Int).SetUint64(batch.LastBlockId).Cmp(i.progressTracker.LastSyncedBlockID()) <= 0 {
				return nil
			}

			parent, err = i.rpc.L2.HeaderByHash(ctx, i.progressTracker.LastSyncedBlockHash())
		} else {
			var parentNumber *big.Int
			if lastPayloadData == nil {
				if batch.BatchId == i.rpc.PacayaClients.ForkHeight {
					parentNumber = new(big.Int).SetUint64(batch.BatchId - 1)
				} else {
					lastBatch, err := i.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(batch.BatchId-1))
					if err != nil {
						return fmt.Errorf("failed to fetch last batch (%d): %w", batch.BatchId-1, err)
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

		blockID := new(big.Int).SetUint64(parent.Number.Uint64() + 1)
		difficulty, err := encoding.CalculatePacayaDifficulty(blockID)
		if err != nil {
			return fmt.Errorf("failed to calculate difficulty: %w", err)
		}
		timestamp := meta.GetLastBlockTimestamp()
		for i := len(meta.GetBlocks()) - 1; i >= 0; i-- {
			timestamp = timestamp - uint64(meta.GetBlocks()[i].TimeShift)
		}

		baseFee, err := i.rpc.CalculateBaseFee(
			ctx,
			parent,
			new(big.Int).SetUint64(meta.GetAnchorBlockID()),
			true,
			(*pacayaBindings.LibSharedDataBaseFeeConfig)(meta.GetBaseFeeConfig()),
			timestamp,
		)
		if err != nil {
			return err
		}

		log.Info(
			"L2 baseFee",
			"blockID", blockID,
			"baseFee", utils.WeiToGWei(baseFee),
			"parentGasUsed", parent.GasUsed,
			"batchID", meta.GetBatchID(),
			"indexInBatch", j,
		)

		// Assemble a TaikoAnchor.anchorV3 transaction
		anchorBlockHeader, err := i.rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
		if err != nil {
			return fmt.Errorf("failed to fetch anchor block: %w", err)
		}
		anchorTx, err := i.anchorConstructor.AssembleAnchorV3Tx(
			ctx,
			new(big.Int).SetUint64(meta.GetAnchorBlockID()),
			anchorBlockHeader.Root,
			meta.GetAnchorInput(),
			parent.GasUsed,
			meta.GetBaseFeeConfig(),
			meta.GetSignalSlots(),
			new(big.Int).Add(parent.Number, common.Big1),
			baseFee,
		)
		if err != nil {
			return fmt.Errorf("failed to create TaikoAnchor.anchorV3 transaction: %w", err)
		}

		// Decompress the transactions list and try to insert a new head block to L2 EE.
		if lastPayloadData, err = createPayloadAndSetHead(
			ctx,
			i.rpc,
			&createPayloadAndSetHeadMetaData{
				createExecutionPayloadsMetaData: &createExecutionPayloadsMetaData{
					BlockID:               blockID,
					ExtraData:             meta.GetExtraData(),
					SuggestedFeeRecipient: meta.GetCoinbase(),
					GasLimit:              uint64(meta.GetGasLimit()),
					Difficulty:            common.BytesToHash(difficulty),
					Timestamp:             timestamp,
					ParentHash:            parent.Hash(),
					L1Origin: &rawdb.L1Origin{
						BlockID:       blockID,
						L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
						L1BlockHeight: meta.GetRawBlockHeight(),
						L1BlockHash:   meta.GetRawBlockHash(),
					},
					Txs:         allTxs[txListCursor:blockInfo.NumTransactions],
					Withdrawals: make([]*types.Withdrawal, 0),
					BaseFee:     baseFee,
				},
				AnchorBlockID:   new(big.Int).SetUint64(meta.GetAnchorBlockID()),
				AnchorBlockHash: meta.GetAnchorBlockHash(),
				BaseFeeConfig:   (*pacayaBindings.LibSharedDataBaseFeeConfig)(meta.GetBaseFeeConfig()),
				Parent:          parent,
			},
			anchorTx,
		); err != nil {
			return fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
		}

		log.Debug("Payload data", "hash", lastPayloadData.BlockHash, "txs", len(lastPayloadData.Transactions))

		log.Info(
			"🔗 New L2 block inserted",
			"blockID", blockID,
			"hash", lastPayloadData.BlockHash,
			"transactions", len(lastPayloadData.Transactions),
			"baseFee", utils.WeiToGWei(lastPayloadData.BaseFeePerGas),
			"withdrawals", len(lastPayloadData.Withdrawals),
			"batchID", meta.GetBatchID(),
			"indexInBatch", j,
		)

		txListCursor += int(blockInfo.NumTransactions)
	}

	return nil
}
