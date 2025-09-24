package eventiterator

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EndShastaProvedEventIterFunc ends the current iteration.
type EndShastaProvedEventIterFunc func()

// OnShastaProvedEvent represents the callback function which will be called
// when a Shasta Proved event is iterated.
type OnShastaProvedEvent func(
	context.Context,
	*shastaBindings.IInboxProvedEventPayload,
	*types.Log,
	EndShastaProvedEventIterFunc,
) error

// ShastaProvedIterator iterates the emitted Shasta Proved events in the chain,
// with the awareness of reorganization.
type ShastaProvedIterator struct {
	blockBatchIterator *chainIterator.BlockBatchIterator
	isEnd              bool
}

// ShastaProvedIteratorConfig represents the configs of a Shasta Proved event iterator.
type ShastaProvedIteratorConfig struct {
	Client                 *rpc.EthClient
	ShastaTaikoInbox       *shastaBindings.ShastaInboxClient
	ShastaTaikoInboxHelper *shastaBindings.InboxHelperClient
	MaxBlocksReadPerEpoch  *uint64
	StartHeight            *big.Int
	EndHeight              *big.Int
	OnShastaProvedEvent    OnShastaProvedEvent
	BlockConfirmations     *uint64
}

// NewShastaProvedIterator creates a new instance of Shasta Proved event iterator.
func NewShastaProvedIterator(ctx context.Context, cfg *ShastaProvedIteratorConfig) (*ShastaProvedIterator, error) {
	if cfg.OnShastaProvedEvent == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := new(ShastaProvedIterator)

	// Initialize the inner block iterator.
	blockIterator, err := chainIterator.NewBlockBatchIterator(ctx, &chainIterator.BlockBatchIteratorConfig{
		Client:                cfg.Client,
		MaxBlocksReadPerEpoch: cfg.MaxBlocksReadPerEpoch,
		StartHeight:           cfg.StartHeight,
		EndHeight:             cfg.EndHeight,
		BlockConfirmations:    cfg.BlockConfirmations,
		OnBlocks: assembleShastaProvedIteratorCallback(
			cfg.Client,
			cfg.ShastaTaikoInbox,
			cfg.ShastaTaikoInboxHelper,
			cfg.OnShastaProvedEvent,
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
// will call the callback when a Shasta Proved event is iterated.
func (i *ShastaProvedIterator) Iter() error {
	return i.blockBatchIterator.Iter()
}

// end ends the current iteration.
func (i *ShastaProvedIterator) end() {
	i.isEnd = true
}

// assembleShastaProvedIteratorCallback assembles the callback which will be used
// by an event iterator's inner block iterator.
func assembleShastaProvedIteratorCallback(
	client *rpc.EthClient,
	shastaTaikoInbox *shastaBindings.ShastaInboxClient,
	shastaTaikoInboxHelper *shastaBindings.InboxHelperClient,
	callback OnShastaProvedEvent,
	eventIter *ShastaProvedIterator,
) chainIterator.OnBlocksFunc {
	return func(
		ctx context.Context,
		start, end *types.Header,
		updateCurrentFunc chainIterator.UpdateCurrentFunc,
		endFunc chainIterator.EndIterFunc,
	) error {
		endHeight := end.Number.Uint64()

		// Iterate the Shasta Proved events.
		iter, err := shastaTaikoInbox.FilterProved(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
		)
		if err != nil {
			return err
		}
		defer iter.Close()

		for iter.Next() {
			event := iter.Event

			// Decode the Proved event data
			provedEventPayload, err := shastaTaikoInboxHelper.DecodeProvedEvent(&bind.CallOpts{Context: ctx}, event.Data)
			if err != nil {
				log.Error("Failed to decode Shasta Proved event data", "error", err)
				return err
			}

			proposalID := provedEventPayload.ProposalId.Uint64()
			log.Debug("Processing Shasta Proved event", "proposalID", proposalID, "l1BlockHeight", event.Raw.BlockNumber)

			if err := callback(ctx, &provedEventPayload, &event.Raw, eventIter.end); err != nil {
				log.Warn("Error while processing Shasta Proved events, keep retrying", "error", err)
				return err
			}

			if eventIter.isEnd {
				log.Debug("ShastaProvedIterator is ended", "start", start.Number, "end", endHeight)
				endFunc()
				return nil
			}

			current, err := client.HeaderByHash(ctx, event.Raw.BlockHash)
			if err != nil {
				return err
			}

			log.Debug("Updating current block cursor for processing Shasta Proved events", "block", current.Number)
			updateCurrentFunc(current)
		}

		// Check if there is any error during the iteration.
		if iter.Error() != nil {
			return fmt.Errorf("error iterating Shasta Proved events: %w", iter.Error())
		}

		return nil
	}
}
