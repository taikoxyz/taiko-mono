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
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
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
	taikoL1            *ontakeBindings.TaikoL1Client
	taikoInbox         *pacayaBindings.TaikoInboxClient
	blockBatchIterator *chainIterator.BlockBatchIterator
	isEnd              bool
}

// BlockProposedIteratorConfig represents the configs of a BlockProposed event iterator.
type BlockProposedIteratorConfig struct {
	Client                *rpc.EthClient
	TaikoL1               *ontakeBindings.TaikoL1Client
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

	iterator := &BlockProposedIterator{
		ctx:        ctx,
		taikoL1:    cfg.TaikoL1,
		taikoInbox: cfg.TaikoInbox,
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
	taikoL1 *ontakeBindings.TaikoL1Client,
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
			lastBlockID uint64
			lastBatchID uint64
		)

		log.Debug("Iterating BlockProposedV2 / BatchProposed events", "start", start.Number, "end", endHeight)

		// Iterate the BlockProposedV2 events at first.
		iterOntake, err := taikoL1.FilterBlockProposedV2(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
			nil,
		)
		if err != nil {
			return err
		}
		defer iterOntake.Close()

		for iterOntake.Next() {
			event := iterOntake.Event
			log.Debug("Processing BlockProposedV2 event", "block", event.BlockId, "l1BlockHeight", event.Raw.BlockNumber)

			// In case some proposers calling the old contract after Pacaya fork, we should skip the event
			// when the block ID is greater than or equal to the Pacaya fork height.
			if event.BlockId.Uint64() >= pacayaForkHeight {
				log.Warn(
					"BlockProposedV2 event after Pacaya fork, skip this event",
					"block", event.BlockId,
					"pacayaForkHeight", pacayaForkHeight,
					"proposer", event.Meta.Proposer,
					"l1BlockHeight", event.Raw.BlockNumber,
				)
				break
			}

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

		// Check if there is any error during the iteration.
		if iterOntake.Error() != nil {
			return iterOntake.Error()
		}

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
					"lastScannedBlockID", lastBlockID,
					"currentScannedBlockID", event.Meta.BatchId,
				)
				return fmt.Errorf(
					"BatchProposed event is not continuous, lastScannedBatchID: %d, currentScannedBatchID: %d",
					lastBlockID, event.Meta.BatchId,
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

			lastBlockID = event.Meta.BatchId

			updateCurrentFunc(current)
		}

		// Check if there is any error during the iteration.
		if iterPacaya.Error() != nil {
			return iterPacaya.Error()
		}

		return nil
	}
}
