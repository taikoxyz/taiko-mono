package utils

import (
	"context"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

const (
	headPollInterval   = 10 * time.Second
	headRequestTimeout = 10 * time.Second
)

type headClient interface {
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
}

func ScanBlocks(ctx context.Context, ethClient headClient, wg *sync.WaitGroup) error {
	wg.Add(1)
	defer wg.Done()

	return scanBlocks(ctx, ethClient, headPollInterval, headRequestTimeout)
}

func scanBlocks(
	ctx context.Context,
	ethClient headClient,
	pollInterval time.Duration,
	requestTimeout time.Duration,
) error {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	var (
		haveHead bool
		lastHead common.Hash
	)

	for {
		requestCtx, cancel := context.WithTimeout(ctx, requestTimeout)
		header, err := ethClient.HeaderByNumber(requestCtx, nil)
		cancel()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}

		headHash := header.Hash()
		if !haveHead {
			haveHead = true
			lastHead = headHash
		} else if headHash != lastHead {
			relayer.BlocksScanned.Inc()
			lastHead = headHash
		}

		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
		}
	}
}
