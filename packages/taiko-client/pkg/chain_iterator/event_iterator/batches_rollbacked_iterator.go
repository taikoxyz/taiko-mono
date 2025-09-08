package eventiterator

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EndBatchesRollBackedEventIterFunc ends the current iteration.
type EndBatchesRollbackedEventIterFunc func()

// OnBatchesRollbackedEvent represents the callback function which will be called when a TaikoInbox.BatchesRollbacked
// event is iterated.
type OnBatchesRollbackedEvent func(
	context.Context,
	*pacayaBindings.TaikoInboxClientBatchesRollbacked,
	EndBatchesRollbackedEventIterFunc,
) error

// BatchesRollbackedIterator iterates the emitted TaikoInbox.BatchesRollbacked events in the chain,
// with the awareness of reorganization.
type BatchesRollbackedIterator struct {
	ctx                context.Context
	taikoInbox         *pacayaBindings.TaikoInboxClient
	blockBatchIterator *chainIterator.BlockBatchIterator
	isEnd              bool
}

// BatchesRollbackedIteratorConfig represents the configs of a BatchesRollbacked event iterator.
type BatchesRollbackedIteratorConfig struct {
	Client                   *rpc.EthClient
	TaikoInbox               *pacayaBindings.TaikoInboxClient
	MaxBlocksReadPerEpoch    *uint64
	StartHeight              *big.Int
	EndHeight                *big.Int
	OnBatchesRollbackedEvent OnBatchesRollbackedEvent
	BlockConfirmations       *uint64
}

// NewBatchesRollbackedIterator creates a new instance of BatchesRollbacked event iterator.
func NewBatchesRollbackedIterator(
	ctx context.Context,
	cfg *BatchesRollbackedIteratorConfig,
) (*BatchesRollbackedIterator, error) {
	if cfg.OnBatchesRollbackedEvent == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := &BatchesRollbackedIterator{ctx: ctx, taikoInbox: cfg.TaikoInbox}

	// Initialize the inner block iterator.
	blockIterator, err := chainIterator.NewBlockBatchIterator(ctx, &chainIterator.BlockBatchIteratorConfig{
		Client:                cfg.Client,
		MaxBlocksReadPerEpoch: cfg.MaxBlocksReadPerEpoch,
		StartHeight:           cfg.StartHeight,
		EndHeight:             cfg.EndHeight,
		BlockConfirmations:    cfg.BlockConfirmations,
		OnBlocks: assembleBatchesRollbackedIteratorCallback(
			cfg.Client,
			cfg.TaikoInbox,
			cfg.OnBatchesRollbackedEvent,
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
// will call the callback when a BatchesRollbacked event is iterated.
func (i *BatchesRollbackedIterator) Iter() error {
	return i.blockBatchIterator.Iter()
}

// end ends the current iteration.
func (i *BatchesRollbackedIterator) end() {
	i.isEnd = true
}

// assembleBatchProposedIteratorCallback assembles the callback which will be used
// by a event iterator's inner block iterator.
func assembleBatchesRollbackedIteratorCallback(
	client *rpc.EthClient,
	taikoInbox *pacayaBindings.TaikoInboxClient,
	callback OnBatchesRollbackedEvent,
	eventIter *BatchesRollbackedIterator,
) chainIterator.OnBlocksFunc {
	return func(
		ctx context.Context,
		start, end *types.Header,
		updateCurrentFunc chainIterator.UpdateCurrentFunc,
		endFunc chainIterator.EndIterFunc,
	) error {
		var (
			endHeight = end.Number.Uint64()
		)

		// Iterate the BatchesRollbacked events.
		iterPacaya, err := taikoInbox.FilterBatchesRollbacked(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
		)
		if err != nil {
			log.Error("Failed to filter BatchesRollbacked events", "error", err)
			return err
		}
		defer iterPacaya.Close()

		for iterPacaya.Next() {
			event := iterPacaya.Event
			log.Debug("Processing BatchesRollbacked event",
				"start batch id", event.StartId,
				"end batch id", event.EndId,
				"l1BlockHeight", event.Raw.BlockNumber,
			)

			if err := callback(ctx, event, eventIter.end); err != nil {
				log.Warn("Error while processing BatchesRollbacked events, keep retrying", "error", err)
				return err
			}

			if eventIter.isEnd {
				log.Debug("BatchesRollbackedIterator is ended", "start", start.Number, "end", endHeight)
				endFunc()
				return nil
			}

			current, err := client.HeaderByHash(ctx, event.Raw.BlockHash)
			if err != nil {
				return err
			}

			log.Debug("Updating current block cursor for processing BatchesRollbacked events", "block", current.Number)

			updateCurrentFunc(current)
		}

		// Check if there is any error during the iteration.
		if iterPacaya.Error() != nil {
			log.Error("Error while iterating BatchesRollbacked events", "error", iterPacaya.Error())
			return iterPacaya.Error()
		}

		return nil
	}
}
