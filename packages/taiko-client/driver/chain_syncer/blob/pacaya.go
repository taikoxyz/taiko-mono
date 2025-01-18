package blob

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// insertNewHeadPacaya inserts a new Pacaya block to the L2 execution engine.
func (s *Syncer) insertNewHeadPacaya(
	ctx context.Context,
	meta metadata.TaikoBatchMetaDataPacaya,
	tx *types.Transaction,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) error {
	batch, err := s.rpc.GetBatchByID(ctx, meta.GetBatchID())
	if err != nil {
		return fmt.Errorf("failed to fetch batch: %w", err)
	}

	// Decode transactions list.
	var txListFetcher txlistFetcher.TxListFetcher
	if meta.GetNumBlobs() != 0 {
		txListFetcher = txlistFetcher.NewBlobTxListFetcher(s.rpc.L1Beacon, s.blobDatasource)
	} else {
		txListFetcher = txlistFetcher.NewCalldataFetch(s.rpc)
	}
	txListBytes, err := txListFetcher.FetchPacaya(ctx, tx, meta)
	if err != nil {
		return fmt.Errorf("failed to fetch tx list: %w", err)
	}

	txsInBatchBytes := s.txListDecompressor.TryDecompress(
		s.rpc.L2.ChainID,
		meta.GetBatchID(),
		txListBytes,
		meta.GetNumBlobs() != 0,
		true,
	)

	var (
		parent          *types.Header
		lastPayloadData *engine.ExecutableData
		allTxs          types.Transactions
		txListCursor    = 0
	)
	if err = rlp.DecodeBytes(txsInBatchBytes, &allTxs); err != nil {
		return fmt.Errorf("failed to decode tx list: %w", err)
	}

	for i, blockInfo := range meta.GetBlocks() {
		// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
		// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
		if s.progressTracker.Triggered() {
			// Already synced through beacon sync, just skip this event.
			if new(big.Int).SetUint64(batch.LastBlockId).Cmp(s.progressTracker.LastSyncedBlockID()) <= 0 {
				return nil
			}

			parent, err = s.rpc.L2.HeaderByHash(ctx, s.progressTracker.LastSyncedBlockHash())
		} else {
			var parentNumber *big.Int
			if lastPayloadData == nil {
				if batch.BatchId == s.rpc.PacayaClients.ForkHeight {
					parentNumber = new(big.Int).SetUint64(batch.BatchId - 1)
				} else {
					lastBatch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(batch.BatchId-1))
					if err != nil {
						return fmt.Errorf("failed to fetch last batch (%d): %w", batch.BatchId-1, err)
					}
					parentNumber = new(big.Int).SetUint64(lastBatch.LastBlockId)
				}
			} else {
				parentNumber = new(big.Int).SetUint64(lastPayloadData.Number)
			}

			parent, err = s.rpc.L2ParentByCurrentBlockID(ctx, new(big.Int).Add(parentNumber, common.Big1))
		}
		if err != nil {
			return fmt.Errorf("failed to fetch L2 parent block: %w", err)
		}

		log.Debug(
			"Parent block",
			"blockID", parent.Number,
			"hash", parent.Hash(),
			"beaconSyncTriggered", s.progressTracker.Triggered(),
		)

		txListBytes, err := rlp.EncodeToBytes(allTxs[txListCursor:blockInfo.NumTransactions])
		if err != nil {
			return fmt.Errorf("failed to encode tx list: %w", err)
		}
		blockID := new(big.Int).SetUint64(parent.Number.Uint64() + 1)
		difficulty, err := encoding.CalculatePacayaDifficulty(blockID)
		if err != nil {
			return fmt.Errorf("failed to calculate difficulty: %w", err)
		}
		timestamp := meta.GetLastBlockTimestamp()
		for i := len(meta.GetBlocks()) - 1; i >= 0; i-- {
			timestamp = timestamp - uint64(meta.GetBlocks()[i].TimeShift)
		}

		baseFee, err := s.rpc.CalculateBaseFee(
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
			"indexInBatch", i,
		)

		// Assemble a TaikoAnchor.anchorV3 transaction
		anchorBlockHeader, err := s.rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
		if err != nil {
			return fmt.Errorf("failed to fetch anchor block: %w", err)
		}
		anchorTx, err := s.anchorConstructor.AssembleAnchorV3Tx(
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
		if lastPayloadData, err = s.createPayloadAndSetHead(
			ctx,
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
					TxListBytes: txListBytes,
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
			"indexInBatch", i,
		)

		txListCursor += int(blockInfo.NumTransactions)
	}

	return nil
}
