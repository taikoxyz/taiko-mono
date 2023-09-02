package indexer

import (
	"context"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func scanBlocks(ctx context.Context, ethClient ethClient, chainID *big.Int, wg *sync.WaitGroup) error {
	wg.Add(1)

	defer func() {
		wg.Done()
	}()

	headers := make(chan *types.Header)

	sub, err := ethClient.SubscribeNewHead(ctx, headers)
	if err != nil {
		return err
	}

	for {
		select {
		case <-ctx.Done():
			return nil
		case err := <-sub.Err():
			relayer.BlocksScannedError.Inc()
			return err
		case <-headers:
			relayer.BlocksScanned.Inc()
		}
	}
}
