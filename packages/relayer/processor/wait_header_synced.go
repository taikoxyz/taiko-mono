package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (p *Processor) waitHeaderSynced(
	ctx context.Context,
	headerSyncer relayer.HeaderSyncer,
	ethClient ethClient,
	blockNum uint64,
) (uint64, error) {
	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return 0, ctx.Err()
		case <-ticker.C:
			slog.Info("waitHeaderSynced checking if tx is processable",
				"blockNumber", blockNum,
			)
			// get latest synced block has via snippet since not every header is synced from L1 => L2,
			// and later blocks still have the storage trie proof from previous blocks.
			latestSyncedSnippet, err := headerSyncer.GetSyncedSnippet(&bind.CallOpts{
				Context: ctx,
			}, 0)
			if err != nil {
				return 0, errors.Wrap(err, "p.destHeaderSyncer.GetSyncedSnippet")
			}

			slog.Info("latestSyncedSnippet",
				"blockHash", common.Bytes2Hex(latestSyncedSnippet.BlockHash[:]),
				"stateRoot", common.Bytes2Hex(latestSyncedSnippet.StateRoot[:]),
			)

			header, err := ethClient.HeaderByHash(ctx, latestSyncedSnippet.BlockHash)
			if err != nil {
				return 0, errors.Wrap(err, "ethClient.HeaderByHash")
			}

			// header is caught up
			if header.Number.Uint64() >= blockNum {
				slog.Info("waitHeaderSynced caughtUp",
					"blockNum", blockNum,
					"latestSyncedBlockNum", header.Number.Uint64(),
				)

				return header.Number.Uint64(), nil
			}

			slog.Info("waitHeaderSynced waiting to be caughtUp",
				"blockNum", blockNum,
				"latestSyncedBlockNum", header.Number.Uint64(),
			)
		}
	}
}
