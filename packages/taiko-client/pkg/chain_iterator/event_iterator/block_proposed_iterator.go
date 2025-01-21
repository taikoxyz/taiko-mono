package eventiterator

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EndBlockProposedEventIterFunc ends the current iteration.
type EndBlockProposedEventIterFunc func()

// OnBlockProposedEvent represents the callback function which will be called when a TaikoL1.BlockProposed event is
// iterated.
type OnBlockProposedEvent func(
	context.Context,
	metadata.TaikoBlockMetaData,
	EndBlockProposedEventIterFunc,
) error

// BlockProposedIterator iterates the emitted TaikoL1.BlockProposed events in the chain,
// with the awareness of reorganization.
type BlockProposedIterator struct {
	ctx                context.Context
	taikoL1            *bindings.TaikoL1Client
	blockBatchIterator *chainIterator.BlockBatchIterator
	filterQuery        []*big.Int
	isEnd              bool
}

// BlockProposedIteratorConfig represents the configs of a BlockProposed event iterator.
type BlockProposedIteratorConfig struct {
	Client                *rpc.EthClient
	TaikoL1               *bindings.TaikoL1Client
	MaxBlocksReadPerEpoch *uint64
	StartHeight           *big.Int
	EndHeight             *big.Int
	FilterQuery           []*big.Int
	OnBlockProposedEvent  OnBlockProposedEvent
	BlockConfirmations    *uint64
}

// NewBlockProposedIterator creates a new instance of BlockProposed event iterator.
func NewBlockProposedIterator(ctx context.Context, cfg *BlockProposedIteratorConfig) (*BlockProposedIterator, error) {
	if cfg.OnBlockProposedEvent == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := &BlockProposedIterator{
		ctx:         ctx,
		taikoL1:     cfg.TaikoL1,
		filterQuery: cfg.FilterQuery,
	}

	// Initialize the inner block iterator.
	blockIterator, err := chainIterator.NewBlockBatchIterator(ctx, &chainIterator.BlockBatchIteratorConfig{
		Client:                cfg.Client,
		MaxBlocksReadPerEpoch: cfg.MaxBlocksReadPerEpoch,
		StartHeight:           cfg.StartHeight,
		EndHeight:             cfg.EndHeight,
		BlockConfirmations:    cfg.BlockConfirmations,
		OnBlocks: assembleBlockProposedIteratorCallback(
			cfg.Client,
			cfg.TaikoL1,
			cfg.FilterQuery,
			cfg.OnBlockProposedEvent,
			iterator,
		),
	})
	if err != nil {
		return nil, err
	}

	iterator.blockBatchIterator = blockIterator

	return iterator, nil
}

// Iter iterates the given chain between the given start and end heights,
// will call the callback when a BlockProposed event is iterated.
func (i *BlockProposedIterator) Iter() error {
	return i.blockBatchIterator.Iter()
}

// end ends the current iteration.
func (i *BlockProposedIterator) end() {
	i.isEnd = true
}

// assembleBlockProposedIteratorCallback assembles the callback which will be used
// by a event iterator's inner block iterator.
func assembleBlockProposedIteratorCallback(
	client *rpc.EthClient,
	taikoL1 *bindings.TaikoL1Client,
	filterQuery []*big.Int,
	callback OnBlockProposedEvent,
	eventIter *BlockProposedIterator,
) chainIterator.OnBlocksFunc {
	return func(
		ctx context.Context,
		start, end *types.Header,
		updateCurrentFunc chainIterator.UpdateCurrentFunc,
		endFunc chainIterator.EndIterFunc,
	) error {
		var (
			endHeight   = end.Number.Uint64()
			lastBlockID uint64
		)

		log.Debug("Iterating BlockProposed events", "start", start.Number, "end", endHeight)

		iterOntake, err := taikoL1.FilterBlockProposedV2(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
			filterQuery,
		)
		if err != nil {
			return err
		}
		defer iterOntake.Close()

		for iterOntake.Next() {
			event := iterOntake.Event
			log.Debug("Processing BlockProposedV2 event", "block", event.BlockId, "l1BlockHeight", event.Raw.BlockNumber)

			if lastBlockID != 0 && event.BlockId.Uint64() != lastBlockID+1 {
				log.Warn(
					"BlockProposedV2 event is not continuous, rescan the L1 chain",
					"fromL1Block", start.Number,
					"toL1Block", endHeight,
					"lastScannedBlockID", lastBlockID,
					"currentScannedBlockID", event.BlockId.Uint64(),
				)
				return fmt.Errorf(
					"BlockProposedV2 event is not continuous, lastScannedBlockID: %d, currentScannedBlockID: %d",
					lastBlockID, event.BlockId.Uint64(),
				)
			}

			if err := callback(ctx, metadata.NewTaikoDataBlockMetadataOntake(event), eventIter.end); err != nil {
				log.Warn("Error while processing BlockProposedV2 events, keep retrying", "error", err)
				return err
			}

			if eventIter.isEnd {
				log.Debug("BlockProposedIterator is ended", "start", start.Number, "end", endHeight)
				endFunc()
				return nil
			}

			current, err := client.HeaderByHash(ctx, event.Raw.BlockHash)
			if err != nil {
				return err
			}

			log.Debug("Updating current block cursor for processing BlockProposedV2 events", "block", current.Number)

			lastBlockID = event.BlockId.Uint64()

			updateCurrentFunc(current)
		}

		if err := iterOntake.Error(); err != nil {
			log.Error("Error while iterating BlockProposedV2 events", "error", err)
			return err
		}

		return nil
	}
}
