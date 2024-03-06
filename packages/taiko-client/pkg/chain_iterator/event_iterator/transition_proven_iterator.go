package eventiterator

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EndTransitionProvedEventIterFunc ends the current iteration.
type EndTransitionProvedEventIterFunc func()

// OnTransitionProved represents the callback function which will be called when a TaikoL1.TransitionProved event is
// iterated.
type OnTransitionProved func(
	context.Context,
	*bindings.TaikoL1ClientTransitionProved,
	EndTransitionProvedEventIterFunc,
) error

// TransitionProvedIterator iterates the emitted TaikoL1.TransitionProved events in the chain,
// with the awareness of reorganization.
type TransitionProvedIterator struct {
	ctx                context.Context
	taikoL1            *bindings.TaikoL1Client
	blockBatchIterator *chainIterator.BlockBatchIterator
	filterQuery        []*big.Int
	isEnd              bool
}

// TransitionProvenIteratorConfig represents the configs of a TransitionProved event iterator.
type TransitionProvenIteratorConfig struct {
	Client                *rpc.EthClient
	TaikoL1               *bindings.TaikoL1Client
	MaxBlocksReadPerEpoch *uint64
	StartHeight           *big.Int
	EndHeight             *big.Int
	FilterQuery           []*big.Int
	OnTransitionProved    OnTransitionProved
}

// NewTransitionProvedIterator creates a new instance of TransitionProved event iterator.
func NewTransitionProvedIterator(
	ctx context.Context,
	cfg *TransitionProvenIteratorConfig,
) (*TransitionProvedIterator, error) {
	if cfg.OnTransitionProved == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := &TransitionProvedIterator{
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
		OnBlocks: assembleTransitionProvedIteratorCallback(
			cfg.Client,
			cfg.TaikoL1,
			cfg.FilterQuery,
			cfg.OnTransitionProved,
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
// will call the callback when a TransitionProved event is iterated.
func (i *TransitionProvedIterator) Iter() error {
	return i.blockBatchIterator.Iter()
}

// end ends the current iteration.
func (i *TransitionProvedIterator) end() {
	i.isEnd = true
}

// assembleTransitionProvedIteratorCallback assembles the callback which will be used
// by a event iterator's inner block iterator.
func assembleTransitionProvedIteratorCallback(
	client *rpc.EthClient,
	taikoL1Client *bindings.TaikoL1Client,
	filterQuery []*big.Int,
	callback OnTransitionProved,
	eventIter *TransitionProvedIterator,
) chainIterator.OnBlocksFunc {
	return func(
		ctx context.Context,
		start, end *types.Header,
		updateCurrentFunc chainIterator.UpdateCurrentFunc,
		endFunc chainIterator.EndIterFunc,
	) error {
		endHeight := end.Number.Uint64()
		iter, err := taikoL1Client.FilterTransitionProved(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
			filterQuery,
		)
		if err != nil {
			return err
		}
		defer iter.Close()

		for iter.Next() {
			event := iter.Event

			if err := callback(ctx, event, eventIter.end); err != nil {
				return err
			}

			if eventIter.isEnd {
				endFunc()
				return nil
			}

			current, err := client.HeaderByHash(ctx, event.Raw.BlockHash)
			if err != nil {
				return err
			}

			updateCurrentFunc(current)
		}

		return nil
	}
}
