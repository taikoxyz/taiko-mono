package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

func (p *Processor) waitHeaderSynced(ctx context.Context, event *bridge.BridgeMessageSent) error {
	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			slog.Info("waitHeaderSynced checking if tx is processable",
				"msgHash", common.Hash(event.MsgHash).Hex(),
				"txHash", event.Raw.TxHash.Hex(),
				"blockNumber", event.Raw.BlockNumber,
			)
			// get latest synced block has via snippet since not every header is synced from L1 => L2,
			// and later blocks still have the storage trie proof from previous blocks.
			latestSyncedSnippet, err := p.destHeaderSyncer.GetSyncedSnippet(&bind.CallOpts{}, 0)
			if err != nil {
				return errors.Wrap(err, "p.destHeaderSyncer.GetSyncedSnippet")
			}

			slog.Info("latestSyncedSnippet",
				"blockHash", common.Bytes2Hex(latestSyncedSnippet.BlockHash[:]),
				"signalRoot", common.Bytes2Hex(latestSyncedSnippet.SignalRoot[:]),
			)

			var ethClient ethClient = p.srcEthClient

			if p.hopChainId != nil {
				ethClient = p.hopEthClient
			}

			header, err := ethClient.HeaderByHash(ctx, latestSyncedSnippet.BlockHash)
			if err != nil {
				return errors.Wrap(err, "ethClient.HeaderByHash")
			}

			// header is caught up and processible
			if header.Number.Uint64() >= event.Raw.BlockNumber {
				slog.Info("waitHeaderSynced processable",
					"msgHash", common.Hash(event.MsgHash).Hex(),
					"txHash", event.Raw.TxHash.Hex(),
					"eventBlockNum", event.Raw.BlockNumber,
					"latestSyncedBlockNum", header.Number.Uint64(),
				)

				return nil
			}

			slog.Info("waitHeaderSynced waiting to be processable",
				"msgHash", common.Hash(event.MsgHash).Hex(),
				"txHash", event.Raw.TxHash.Hex(),
				"eventBlockNum", event.Raw.BlockNumber,
				"latestSyncedBlockNum", header.Number.Uint64(),
			)
		}
	}
}
