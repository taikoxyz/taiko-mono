package eventiterator

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	chainIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// EndBlockProposedOnTakeEventIterFunc ends the current iteration.
type EndBlockProposedOntakeEventIterFunc func()

// OnBlockProposedOntakeEvent represents the callback function which will be called when a TaikoL1.BlockProposed2 event
// is iterated.
type OnBlockProposedOntakeEvent func(
	context.Context,
	metadata.TaikoBlockMetaData,
	EndBlockProposedOntakeEventIterFunc,
) error

// BlockProposedOntakeIterator iterates the emitted TaikoL1.BlockProposed2 events in the chain,
// with the awareness of reorganization.
type BlockProposedOntakeIterator struct {
	ctx                context.Context
	taikoL1            *bindings.TaikoL1Client
	blockBatchIterator *chainIterator.BlockBatchIterator
	filterQuery        []*big.Int
	isEnd              bool
}

// BlockProposedOntakeIteratorConfig represents the configs of a TaikoL1.BlockProposed2 event iterator.
type BlockProposedOntakeIteratorConfig struct {
	Client                     *rpc.EthClient
	TaikoL1                    *bindings.TaikoL1Client
	LibProposing               *bindings.LibProposing
	MaxBlocksReadPerEpoch      *uint64
	StartHeight                *big.Int
	EndHeight                  *big.Int
	FilterQuery                []*big.Int
	OnBlockProposedOntakeEvent OnBlockProposedOntakeEvent
	BlockConfirmations         *uint64
}

// NewBlockProposedIterator creates a new instance of BlockProposed event iterator.
func NewBlockProposedOntakeIterator(
	ctx context.Context,
	cfg *BlockProposedOntakeIteratorConfig,
) (*BlockProposedOntakeIterator, error) {
	if cfg.OnBlockProposedOntakeEvent == nil {
		return nil, errors.New("invalid callback")
	}

	iterator := &BlockProposedOntakeIterator{
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
		OnBlocks: assembleBlockProposedOntakeIteratorCallback(
			cfg.Client,
			cfg.LibProposing,
			cfg.FilterQuery,
			cfg.OnBlockProposedOntakeEvent,
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
// will call the callback when a BlockProposed2 event is iterated.
func (i *BlockProposedOntakeIterator) Iter() error {
	return i.blockBatchIterator.Iter()
}

// end ends the current iteration.
func (i *BlockProposedOntakeIterator) end() {
	i.isEnd = true
}

// assembleBlockProposedOntakeIteratorCallback assembles the callback which will be used
// by a event iterator's inner block iterator.
func assembleBlockProposedOntakeIteratorCallback(
	client *rpc.EthClient,
	libProposing *bindings.LibProposing,
	filterQuery []*big.Int,
	callback OnBlockProposedOntakeEvent,
	eventIter *BlockProposedOntakeIterator,
) chainIterator.OnBlocksFunc {
	return func(
		ctx context.Context,
		start, end *types.Header,
		updateCurrentFunc chainIterator.UpdateCurrentFunc,
		endFunc chainIterator.EndIterFunc,
	) error {
		endHeight := end.Number.Uint64()
		iter, err := libProposing.FilterBlockProposed2(
			&bind.FilterOpts{Start: start.Number.Uint64(), End: &endHeight, Context: ctx},
			filterQuery,
		)
		if err != nil {
			return err
		}
		defer iter.Close()

		for iter.Next() {
			event := iter.Event

			if err := callback(ctx, metadata.NewTaikoDataBlockMetadata2(event), eventIter.end); err != nil {
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
