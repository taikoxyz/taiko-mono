package blocksinserter

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

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
type BlocksInserterOntake struct {
	rpc                *rpc.Client
	progressTracker    *beaconsync.SyncProgressTracker
	blobDatasource     *rpc.BlobDataSource
	txListDecompressor *txListDecompressor.TxListDecompressor   // Transactions list decompressor
	anchorConstructor  *anchorTxConstructor.AnchorTxConstructor // TaikoL2.anchor transactions constructor
	calldataFetcher    txlistFetcher.TxListFetcher
	blobFetcher        txlistFetcher.TxListFetcher
}

// NewBlocksInserterOntake creates a new BlocksInserterOntake instance.
func NewBlocksInserterOntake(
	rpc *rpc.Client,
	progressTracker *beaconsync.SyncProgressTracker,
	blobDatasource *rpc.BlobDataSource,
	txListDecompressor *txListDecompressor.TxListDecompressor,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	calldataFetcher txlistFetcher.TxListFetcher,
	blobFetcher txlistFetcher.TxListFetcher,
) *BlocksInserterOntake {
	return &BlocksInserterOntake{
		rpc:                rpc,
		progressTracker:    progressTracker,
		blobDatasource:     blobDatasource,
		txListDecompressor: txListDecompressor,
		anchorConstructor:  anchorConstructor,
		calldataFetcher:    calldataFetcher,
		blobFetcher:        blobFetcher,
	}
}

// InsertBlocks inserts a new Ontake block to the L2 execution engine.
func (i *BlocksInserterOntake) InsertBlocks(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) error {
	if metadata.IsPacaya() {
		return fmt.Errorf("metadata is not for Ontake fork")
	}
	// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
	// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
	var (
		meta        = metadata.Ontake()
		parent      *types.Header
		txListBytes []byte
		err         error
	)
	if i.progressTracker.Triggered() {
		// Already synced through beacon sync, just skip this event.
		if meta.GetBlockID().Cmp(i.progressTracker.LastSyncedBlockID()) <= 0 {
			log.Debug("Skip already beacon synced block", "blockID", meta.GetBlockID())
			return nil
		}

		parent, err = i.rpc.L2.HeaderByHash(ctx, i.progressTracker.LastSyncedBlockHash())
	} else {
		parent, err = i.rpc.L2ParentByCurrentBlockID(ctx, meta.GetBlockID())
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

	// Fetch transactions list.
	if meta.GetBlobUsed() {
		if txListBytes, err = i.blobFetcher.FetchOntake(ctx, meta); err != nil {
			return fmt.Errorf("failed to fetch tx list from blob: %w", err)
		}
	} else {
		if txListBytes, err = i.calldataFetcher.FetchOntake(ctx, meta); err != nil {
			return fmt.Errorf("failed to fetch tx list from calldata: %w", err)
		}
	}

	baseFee, err := i.rpc.CalculateBaseFee(
		ctx,
		parent,
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
	anchorBlockHeader, err := i.rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
	if err != nil {
		return fmt.Errorf("failed to fetch anchor block: %w", err)
	}
	anchorTx, err := i.anchorConstructor.AssembleAnchorV2Tx(
		ctx,
		new(big.Int).SetUint64(meta.GetAnchorBlockID()),
		anchorBlockHeader.Root,
		parent.GasUsed,
		meta.GetBaseFeeConfig(),
		new(big.Int).Add(parent.Number, common.Big1),
		baseFee,
	)
	if err != nil {
		return fmt.Errorf("failed to create TaikoL2.anchorV2 transaction: %w", err)
	}

	// Decompress the transactions list and try to insert a new head block to L2 EE.
	payloadData, err := createPayloadAndSetHead(
		ctx,
		i.rpc,
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
				Txs: i.txListDecompressor.TryDecompress(
					i.rpc.L2.ChainID,
					txListBytes,
					meta.GetBlobUsed(),
					false,
				),
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
