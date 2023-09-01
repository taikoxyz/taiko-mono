package indexer

import (
	"context"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func scanBlocks(ctx context.Context, ethClient ethClient, chainID *big.Int, wg *sync.WaitGroup) {
	wg.Add(1)

	defer func() {
		wg.Done()
	}()

	headers := make(chan *types.Header)

	sub, err := ethClient.SubscribeNewHead(ctx, headers)
	if err != nil {
		panic(err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case <-sub.Err():
			relayer.BlocksScannedError.Inc()

			scanBlocks(ctx, ethClient, chainID, wg)

			return
		case <-headers:
			relayer.BlocksScanned.Inc()
		}
	}
}
