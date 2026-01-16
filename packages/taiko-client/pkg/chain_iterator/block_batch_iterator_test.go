package chainiterator

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

func getTestClient(t *testing.T) *rpc.EthClient {
	endpoint := os.Getenv("L1_HTTP")
	require.NotEmpty(t, endpoint)

	client, err := rpc.NewEthClient(context.Background(), endpoint, 30*time.Second)
	require.NoError(t, err)
	return client
}

func TestBlockBatchIterator_Iter(t *testing.T) {
	var maxBlocksReadPerEpoch uint64 = 2
	client := getTestClient(t)

	headHeight, err := client.BlockNumber(context.Background())
	require.NoError(t, err)
	require.Greater(t, headHeight, uint64(0))

	lastEnd := common.Big0

	iter, err := NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client:                client,
		MaxBlocksReadPerEpoch: &maxBlocksReadPerEpoch,
		StartHeight:           common.Big0,
		EndHeight:             new(big.Int).SetUint64(headHeight),
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			_ EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			return nil
		},
	})

	require.NoError(t, err)
	require.NoError(t, iter.Iter())
	require.Equal(t, headHeight, lastEnd.Uint64())
}

func TestBlockBatchIterator_IterWithoutSpecifiedEndHeight(t *testing.T) {
	var maxBlocksReadPerEpoch uint64 = 2
	var blockConfirmations uint64 = 6
	client := getTestClient(t)

	headHeight, err := client.BlockNumber(context.Background())
	require.NoError(t, err)
	require.Greater(t, headHeight, uint64(0))

	lastEnd := common.Big0

	iter, err := NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client:                client,
		MaxBlocksReadPerEpoch: &maxBlocksReadPerEpoch,
		StartHeight:           common.Big0,
		BlockConfirmations:    &blockConfirmations,
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			_ EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			return nil
		},
	})

	require.NoError(t, err)
	require.NoError(t, iter.Iter())
	require.GreaterOrEqual(t, lastEnd.Uint64(), headHeight-blockConfirmations)
}

func TestBlockBatchIterator_IterWithLessThanConfirmations(t *testing.T) {
	var maxBlocksReadPerEpoch uint64 = 2
	client := getTestClient(t)

	headHeight, err := client.BlockNumber(context.Background())
	require.NoError(t, err)
	require.Greater(t, headHeight, uint64(0))

	lastEnd := headHeight

	var blockConfirmations = headHeight + 3

	iter, err := NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client:                client,
		MaxBlocksReadPerEpoch: &maxBlocksReadPerEpoch,
		StartHeight:           new(big.Int).SetUint64(headHeight),
		BlockConfirmations:    &blockConfirmations,
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			_ EndIterFunc,
		) error {
			require.Equal(t, lastEnd, start.Number.Uint64())
			lastEnd = end.Number.Uint64()
			return nil
		},
	})

	require.NoError(t, err)
	require.Equal(t, ErrEOF, iter.iter())
	require.Equal(t, headHeight, lastEnd)
}

func TestBlockBatchIterator_IterEndFunc(t *testing.T) {
	var maxBlocksReadPerEpoch uint64 = 2
	client := getTestClient(t)

	headHeight, err := client.BlockNumber(context.Background())
	require.NoError(t, err)
	require.Greater(t, headHeight, maxBlocksReadPerEpoch)

	lastEnd := common.Big0

	iter, err := NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client:                client,
		MaxBlocksReadPerEpoch: &maxBlocksReadPerEpoch,
		StartHeight:           common.Big0,
		EndHeight:             new(big.Int).SetUint64(headHeight),
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			endIterFunc EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			endIterFunc()
			return nil
		},
	})

	require.NoError(t, err)
	require.NoError(t, iter.Iter())
	require.Equal(t, lastEnd.Uint64(), maxBlocksReadPerEpoch)
}

func TestBlockBatchIterator_IterCtxCancel(t *testing.T) {
	lastEnd := common.Big0
	client := getTestClient(t)
	headHeight, err := client.BlockNumber(context.Background())
	require.NoError(t, err)
	ctx, cancel := context.WithCancel(context.Background())

	itr, err := NewBlockBatchIterator(ctx, &BlockBatchIteratorConfig{
		Client:                client,
		MaxBlocksReadPerEpoch: nil,
		RetryInterval:         5 * time.Second,
		StartHeight:           common.Big0,
		EndHeight:             new(big.Int).SetUint64(headHeight),
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			endIterFunc EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			endIterFunc()
			return nil
		},
	})

	require.NoError(t, err)
	cancel()
	require.ErrorContains(t, itr.Iter(), "context canceled")
}

func TestBlockBatchIterator_Config(t *testing.T) {
	// Test nil client
	_, err := NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client: nil,
	})
	require.ErrorContains(t, err, "invalid RPC client")

	// For the rest of the tests, we need a real client
	client := getTestClient(t)

	_, err = NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client:   client,
		OnBlocks: nil,
	})
	require.ErrorContains(t, err, "invalid callback")

	lastEnd := common.Big0
	_, err = NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client: client,
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			endIterFunc EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			endIterFunc()
			return nil
		},
		StartHeight: nil,
	})
	require.ErrorContains(t, err, "invalid start height")

	_, err = NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client: client,
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			endIterFunc EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			endIterFunc()
			return nil
		},
		StartHeight: common.Big2,
		EndHeight:   common.Big0,
	})
	require.ErrorContains(t, err, "start height (2) > end height (0)")

	_, err = NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client: client,
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			endIterFunc EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			endIterFunc()
			return nil
		},
		StartHeight: big.NewInt(1000),
		EndHeight:   big.NewInt(1000),
	})
	require.ErrorContains(t, err, "failed to get start header")

	_, err = NewBlockBatchIterator(context.Background(), &BlockBatchIteratorConfig{
		Client: client,
		OnBlocks: func(
			_ context.Context,
			start, end *types.Header,
			_ UpdateCurrentFunc,
			endIterFunc EndIterFunc,
		) error {
			require.Equal(t, lastEnd.Uint64(), start.Number.Uint64())
			lastEnd = end.Number
			endIterFunc()
			return nil
		},
		StartHeight: common.Big0,
		EndHeight:   big.NewInt(1000),
	})
	require.ErrorContains(t, err, "failed to get end header")
}
