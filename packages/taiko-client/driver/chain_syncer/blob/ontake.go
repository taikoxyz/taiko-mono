package blob

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// insertNewHeadOntake inserts a new Ontake block to the L2 execution engine.
func (s *Syncer) insertNewHeadOntake(
	ctx context.Context,
	meta metadata.TaikoBlockMetaDataOntake,
	tx *types.Transaction,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) error {
	// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
	// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
	var (
		parent *types.Header
		err    error
	)
	if s.progressTracker.Triggered() {
		// Already synced through beacon sync, just skip this event.
		if meta.GetBlockID().Cmp(s.progressTracker.LastSyncedBlockID()) <= 0 {
			log.Debug("Skip already beacon synced block", "blockID", meta.GetBlockID())
			return nil
		}

		parent, err = s.rpc.L2.HeaderByHash(ctx, s.progressTracker.LastSyncedBlockHash())
	} else {
		parent, err = s.rpc.L2ParentByCurrentBlockID(ctx, meta.GetBlockID())
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

	// Fetch and decode transactions list.
	var txListFetcher txlistFetcher.TxListFetcher
	if meta.GetBlobUsed() {
		txListFetcher = txlistFetcher.NewBlobTxListFetcher(s.rpc.L1Beacon, s.blobDatasource)
	} else {
		txListFetcher = txlistFetcher.NewCalldataFetch(s.rpc)
	}
	txListBytes, err := txListFetcher.FetchOntake(ctx, tx, meta)
	if err != nil {
		return fmt.Errorf("failed to fetch tx list: %w", err)
	}

	baseFee, err := s.rpc.CalculateBaseFee(
		ctx,
		parent,
		new(big.Int).SetUint64(meta.GetAnchorBlockID()),
		false,
		(*pacayaBindings.LibSharedDataBaseFeeConfig)(meta.GetBaseFeeConfig()),
		meta.GetTimestamp(),
	)
	if err != nil {
		return err
	}

	log.Info(
		"L2 baseFee",
		"blockID", meta.GetBlockID(),
		"baseFee", utils.WeiToGWei(baseFee),
		"parentGasUsed", parent.GasUsed,
	)

	// Assemble a TaikoL2.anchorV2 transaction
	anchorBlockHeader, err := s.rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
	if err != nil {
		return fmt.Errorf("failed to fetch anchor block: %w", err)
	}
	anchorTx, err := s.anchorConstructor.AssembleAnchorV2Tx(
		ctx,
		new(big.Int).SetUint64(meta.GetAnchorBlockID()),
		anchorBlockHeader.Root,
		parent.GasUsed,
		(*ontakeBindings.LibSharedDataBaseFeeConfig)(meta.GetBaseFeeConfig()),
		new(big.Int).Add(parent.Number, common.Big1),
		baseFee,
	)
	if err != nil {
		return fmt.Errorf("failed to create TaikoL2.anchorV2 transaction: %w", err)
	}

	// Decompress the transactions list and try to insert a new head block to L2 EE.
	payloadData, err := s.createPayloadAndSetHead(
		ctx,
		&createPayloadAndSetHeadMetaData{
			createExecutionPayloadsMetaData: &createExecutionPayloadsMetaData{
				BlockID:               meta.GetBlockID(),
				ExtraData:             meta.GetExtraData(),
				SuggestedFeeRecipient: meta.GetCoinbase(),
				GasLimit:              uint64(meta.GetGasLimit()),
				Difficulty:            meta.GetDifficulty(),
				Timestamp:             meta.GetTimestamp(),
				ParentHash:            parent.Hash(),
				BaseFee:               baseFee,
				L1Origin: &rawdb.L1Origin{
					BlockID:       meta.GetBlockID(),
					L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
					L1BlockHeight: meta.GetRawBlockHeight(),
					L1BlockHash:   meta.GetRawBlockHash(),
				},
				TxListBytes: txListBytes,
				Withdrawals: make([]*types.Withdrawal, 0),
			},
			AnchorBlockID:   new(big.Int).SetUint64(meta.GetAnchorBlockID()),
			AnchorBlockHash: meta.GetAnchorBlockHash(),
			BaseFeeConfig:   (*pacayaBindings.LibSharedDataBaseFeeConfig)(meta.GetBaseFeeConfig()),
			Parent:          parent,
		},
		anchorTx,
	)
	if err != nil {
		return fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
	}

	log.Debug("Payload data", "hash", payloadData.BlockHash, "txs", len(payloadData.Transactions))

	log.Info(
		"🔗 New L2 block inserted",
		"blockID", meta.GetBlockID(),
		"hash", payloadData.BlockHash,
		"transactions", len(payloadData.Transactions),
		"baseFee", utils.WeiToGWei(payloadData.BaseFeePerGas),
		"withdrawals", len(payloadData.Withdrawals),
	)

	return nil
}
