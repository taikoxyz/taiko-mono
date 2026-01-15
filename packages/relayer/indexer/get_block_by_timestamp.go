package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
)

const avgBlockTime = 12 // Ethereum average block time in seconds

// getBlockByTimestamp returns the last block whose timestamp is <= the target timestamp.
// It uses estimation based on average block time (~12s) followed by binary search
// for efficient lookup with minimal RPC calls.
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

	// 3. Estimate target block
	timeDiff := latestTimestamp - targetTimestamp
	estimatedBlocksBack := timeDiff / avgBlockTime
	estimatedBlock := latestBlock - estimatedBlocksBack

	// 4. Define search range
	searchMargin := uint64(1000)
	low := uint64(1)
	if estimatedBlock > searchMargin {
		low = estimatedBlock - searchMargin
	}
	high := min(estimatedBlock+searchMargin, latestBlock)

	// 5. Binary search
	var result uint64 = low

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
