package chainiterator

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	DefaultBlocksReadPerEpoch = 1000
	DefaultRetryInterval      = 12 * time.Second
	DefaultBlockConfirmations = 0
)

var (
	errContinue = errors.New("continue")
)

// OnBlocksFunc represents the callback function which will be called when a batch of blocks in chain are
// iterated. It returns true if it reorged, and false if not.
type OnBlocksFunc func(
	ctx context.Context,
	start, end *types.Header,
	updateCurrentFunc UpdateCurrentFunc,
	endIterFunc EndIterFunc,
) error

// UpdateCurrentFunc updates the iterator.current cursor in the iterator.
type UpdateCurrentFunc func(*types.Header)

// EndIterFunc ends the current iteration.
type EndIterFunc func()

// BlockBatchIterator iterates the blocks in batches between the given start and end heights,
// with the awareness of reorganization.
type BlockBatchIterator struct {
	ctx                context.Context
	client             *rpc.EthClient
	chainID            *big.Int
	blocksReadPerEpoch uint64
	startHeight        uint64
	endHeight          *uint64
	current            *types.Header
	onBlocks           OnBlocksFunc
	isEnd              bool
	reorgRewindDepth   uint64
	retryInterval      time.Duration
	blockConfirmations *uint64
}

// BlockBatchIteratorConfig represents the configs of a block batch iterator.
type BlockBatchIteratorConfig struct {
	Client                *rpc.EthClient
	MaxBlocksReadPerEpoch *uint64
	StartHeight           *big.Int
	EndHeight             *big.Int
	OnBlocks              OnBlocksFunc
	ReorgRewindDepth      *uint64
	RetryInterval         time.Duration
	BlockConfirmations    *uint64
}

// NewBlockBatchIterator creates a new block batch iterator instance.
func NewBlockBatchIterator(ctx context.Context, cfg *BlockBatchIteratorConfig) (*BlockBatchIterator, error) {
	if cfg.Client == nil {
		return nil, errors.New("invalid RPC client")
	}

	if cfg.OnBlocks == nil {
		return nil, errors.New("invalid callback")
	}

	if cfg.StartHeight == nil {
		return nil, errors.New("invalid start height")
	}

	if cfg.EndHeight != nil && cfg.StartHeight.Cmp(cfg.EndHeight) > 0 {
		return nil, fmt.Errorf("start height (%d) > end height (%d)", cfg.StartHeight, cfg.EndHeight)
	}

	startHeader, err := cfg.Client.HeaderByNumber(ctx, cfg.StartHeight)
	if err != nil {
		return nil, fmt.Errorf("failed to get start header, height: %s, error: %w", cfg.StartHeight, err)
	}

	if _, err = cfg.Client.HeaderByNumber(ctx, cfg.EndHeight); err != nil {
		return nil, fmt.Errorf("failed to get end header, height: %s, error: %w", cfg.EndHeight, err)
	}

	iterator := &BlockBatchIterator{
		ctx:                ctx,
		client:             cfg.Client,
		chainID:            cfg.Client.ChainID,
		startHeight:        cfg.StartHeight.Uint64(),
		onBlocks:           cfg.OnBlocks,
		current:            startHeader,
		blockConfirmations: cfg.BlockConfirmations,
	}

	if cfg.MaxBlocksReadPerEpoch != nil {
		iterator.blocksReadPerEpoch = *cfg.MaxBlocksReadPerEpoch
	} else {
		iterator.blocksReadPerEpoch = DefaultBlocksReadPerEpoch
	}

	if cfg.RetryInterval == 0 {
		iterator.retryInterval = DefaultRetryInterval
	} else {
		iterator.retryInterval = cfg.RetryInterval
	}

	if cfg.EndHeight != nil {
		endHeightUint64 := cfg.EndHeight.Uint64()
		iterator.endHeight = &endHeightUint64
	}

	return iterator, nil
}

// Iter iterates the given chain between the given start and end heights,
// will call the callback when a batch of blocks in chain are iterated.
func (i *BlockBatchIterator) Iter() error {
	iterOp := func() error {
		for {
			if i.ctx.Err() != nil {
				log.Warn(
					"Block batch iterator closed",
					"error", i.ctx.Err(),
					"start", i.startHeight,
					"end", i.endHeight,
					"current", i.current.Number,
				)
				break
			}
			if err := i.iter(); err != nil {
				if errors.Is(err, io.EOF) {
					break
				}
				if errors.Is(err, errContinue) {
					continue
				}
				log.Error("Block batch iterator callback error", "error", err)
				return err
			}
		}
		return nil
	}

	if err := backoff.Retry(iterOp, backoff.WithContext(backoff.NewConstantBackOff(i.retryInterval), i.ctx)); err != nil {
		return err
	}

	return i.ctx.Err()
}

// iter is the internal implementation of Iter, which performs the iteration.
func (i *BlockBatchIterator) iter() (err error) {
	if err := i.ensureCurrentNotReorged(); err != nil {
		return fmt.Errorf("failed to check whether iterator.current cursor has been reorged: %w", err)
	}

	var (
		endHeight          uint64
		endHeader          *types.Header
		destHeight         uint64
		isLastEpoch        bool
		blockConfirmations uint64
	)

	if i.blockConfirmations == nil {
		blockConfirmations = DefaultBlockConfirmations
	} else {
		blockConfirmations = *i.blockConfirmations
	}

	if i.endHeight != nil {
		destHeight = *i.endHeight
	} else {
		destHeight, err = i.client.BlockNumber(i.ctx)
		if err != nil {
			return err
		}
		if destHeight > blockConfirmations {
			destHeight -= blockConfirmations
		} else {
			destHeight = 0
		}
	}

	if i.current.Number.Uint64() >= destHeight {
		return io.EOF
	}

	endHeight = i.current.Number.Uint64() + i.blocksReadPerEpoch

	if endHeight >= destHeight {
		endHeight = destHeight
		isLastEpoch = true
	}

	if endHeader, err = i.client.HeaderByNumber(i.ctx, new(big.Int).SetUint64(endHeight)); err != nil {
		return err
	}

	if err := i.onBlocks(i.ctx, i.current, endHeader, i.updateCurrent, i.end); err != nil {
		return err
	}

	if i.isEnd {
		return io.EOF
	}

	i.current = endHeader

	if !isLastEpoch && !i.isEnd {
		return errContinue
	}

	return io.EOF
}

// updateCurrent updates the iterator's current cursor.
func (i *BlockBatchIterator) updateCurrent(current *types.Header) {
	if current == nil {
		log.Warn("Receive a nil header as iterator.current cursor")
		return
	}

	i.current = current
}

// end ends the current iteration.
func (i *BlockBatchIterator) end() {
	i.isEnd = true
}

// ensureCurrentNotReorged checks if the iterator.current cursor was reorged, if was, will
// rewind back `ReorgRewindDepth` blocks.
// reorg is also detected on the iteration of the event later, by checking
// event.Raw.Removed, which will also call `i.rewindOnReorgDetected` to rewind back
func (i *BlockBatchIterator) ensureCurrentNotReorged() error {
	current, err := i.client.HeaderByHash(i.ctx, i.current.Hash())
	if err != nil && !(err.Error() == ethereum.NotFound.Error()) {
		return err
	}

	// Not reorged
	if current != nil {
		return nil
	}

	// reorged
	return i.rewindOnReorgDetected()
}

// rewindOnReorgDetected rewinds back `ReorgRewindDepth` blocks and sets i.current
// to a stable block, or 0 if it's less than `ReorgRewindDepth`.
func (i *BlockBatchIterator) rewindOnReorgDetected() error {
	var newCurrentHeight uint64
	if i.current.Number.Uint64() <= i.reorgRewindDepth {
		newCurrentHeight = 0
	} else {
		newCurrentHeight = i.current.Number.Uint64() - i.reorgRewindDepth
	}

	head, err := i.client.BlockNumber(i.ctx)
	if err != nil {
		return err
	}

	if newCurrentHeight > head {
		newCurrentHeight = head
	}

	current, err := i.client.HeaderByNumber(i.ctx, new(big.Int).SetUint64(newCurrentHeight))
	if err != nil {
		return err
	}

	i.current = current
	return nil
}
