package eventiterator

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EndBlockProposedEventIterFunc ends the current iteration.
type EndBlockProposedEventIterFunc func()

// OnBlockProposedEvent represents the callback function which will be called when a TaikoL1.BlockProposed event is
// iterated.
type OnBlockProposedEvent func(
	context.Context,
	metadata.TaikoProposalMetaData,
	EndBlockProposedEventIterFunc,
) error

// BlockProposedIterator iterates the emitted TaikoL1.BlockProposed events in the chain,
// with the awareness of reorganization.
type BlockProposedIterator struct {
	ctx                context.Context
	taikoInbox         *pacayaBindings.TaikoInboxClient
	blockBatchIterator *chainIterator.BlockBatchIterator
	isEnd              bool
}

// BlockProposedIteratorConfig represents the configs of a BlockProposed event iterator.
type BlockProposedIteratorConfig struct {
	Client                *rpc.EthClient
	TaikoInbox            *pacayaBindings.TaikoInboxClient
	PacayaForkHeight      uint64
	MaxBlocksReadPerEpoch *uint64
	StartHeight           *big.Int
	EndHeight             *big.Int
	OnBlockProposedEvent  OnBlockProposedEvent
	BlockConfirmations    *uint64
}

// NewBlockProposedIterator creates a new instance of BlockProposed event iterator.
func NewBlockProposedIterator(ctx context.Context, cfg *BlockProposedIteratorConfig) (*BlockProposedIterator, error) {
	if cfg.OnBlockProposedEvent == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := &BlockProposedIterator{ctx: ctx, taikoInbox: cfg.TaikoInbox}

	// Initialize the inner block iterator.
	blockIterator, err := chainIterator.NewBlockBatchIterator(ctx, &chainIterator.BlockBatchIteratorConfig{
		Client:                cfg.Client,
		MaxBlocksReadPerEpoch: cfg.MaxBlocksReadPerEpoch,
		StartHeight:           cfg.StartHeight,
		EndHeight:             cfg.EndHeight,
		BlockConfirmations:    cfg.BlockConfirmations,
		OnBlocks: assembleBlockProposedIteratorCallback(
			cfg.Client,
			cfg.TaikoInbox,
			cfg.PacayaForkHeight,
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
	taikoInbox *pacayaBindings.TaikoInboxClient,
	pacayaForkHeight uint64,
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
			lastBatchID uint64
		)

		// Iterate the BatchProposed events.
		iterPacaya, err := taikoInbox.FilterBatchProposed(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
		)
		if err != nil {
			return err
		}
		defer iterPacaya.Close()

		for iterPacaya.Next() {
			event := iterPacaya.Event
			log.Debug("Processing BatchProposed event", "batch", event.Meta.BatchId, "l1BlockHeight", event.Raw.BlockNumber)

			if lastBatchID != 0 && event.Meta.BatchId != lastBatchID+1 {
				log.Warn(
					"BatchProposed event is not continuous, rescan the L1 chain",
					"fromL1Block", start.Number,
					"toL1Block", endHeight,
					"lastScannedBatchID", lastBatchID,
					"currentScannedBatchID", event.Meta.BatchId,
				)
				return fmt.Errorf(
					"BatchProposed event is not continuous, lastScannedBatchID: %d, currentScannedBatchID: %d",
					lastBatchID, event.Meta.BatchId,
				)
			}

			if err := callback(ctx, metadata.NewTaikoDataBlockMetadataPacaya(event), eventIter.end); err != nil {
				log.Warn("Error while processing BatchProposed events, keep retrying", "error", err)
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

			log.Debug("Updating current block cursor for processing BatchProposed events", "block", current.Number)

			lastBatchID = event.Meta.BatchId

			updateCurrentFunc(current)
		}

		// Check if there is any error during the iteration.
		if iterPacaya.Error() != nil {
			return iterPacaya.Error()
		}

		return nil
	}
}
