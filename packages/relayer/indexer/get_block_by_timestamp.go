package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
)

// getBlockByTimestamp returns the last block whose timestamp is <= the target timestamp.
// Targets before block 1 return block 1. The full block range is searched because
// variable block times can make an average-based estimate exclude the correct block.
func (i *Indexer) getBlockByTimestamp(ctx context.Context, targetTimestamp uint64) (uint64, error) {
	// 1. Get latest block header
	latestHeader, err := i.srcEthClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return 0, errors.Wrap(err, "srcEthClient.HeaderByNumber(latest)")
	}

	latestBlock := latestHeader.Number.Uint64()
	latestTimestamp := latestHeader.Time

	// 2. Boundary checks
	if targetTimestamp >= latestTimestamp {
		return latestBlock, nil
	}

	genesisHeader, err := i.srcEthClient.HeaderByNumber(ctx, big.NewInt(1))
	if err != nil {
		return 0, errors.Wrap(err, "srcEthClient.HeaderByNumber(block 1)")
	}

	if targetTimestamp < genesisHeader.Time {
		return 1, nil
	}

	// 3. Binary search the full range to avoid assumptions about block times.
	low := uint64(1)
	high := latestBlock
	result := low

	for low <= high {
		mid := low + (high-low)/2

		midHeader, err := i.srcEthClient.HeaderByNumber(ctx, new(big.Int).SetUint64(mid))
		if err != nil {
			return 0, errors.Wrap(err, "srcEthClient.HeaderByNumber(mid)")
		}

		if midHeader.Time <= targetTimestamp {
			result = mid
			low = mid + 1
		} else {
			high = mid - 1
		}
	}

	return result, nil
}
