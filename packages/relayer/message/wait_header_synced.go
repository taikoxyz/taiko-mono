package message

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

func (p *Processor) waitHeaderSynced(ctx context.Context, event *bridge.BridgeMessageSent) error {
	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			log.Infof(
				"msgHash: %v, txHash: %v is waiting to be processable. occurred in block %v",
				common.Hash(event.MsgHash).Hex(),
				event.Raw.TxHash.Hex(),
				event.Raw.BlockNumber,
			)
			// get latest synced header since not every header is synced from L1 => L2,
			// and later blocks still have the storage trie proof from previous blocks.
			latestSyncedHeader, err := p.destHeaderSyncer.GetCrossChainBlockHash(&bind.CallOpts{}, big.NewInt(0))
			if err != nil {
				return errors.Wrap(err, "p.destHeaderSyncer.GetCrossChainBlockHash")
			}

			header, err := p.srcEthClient.HeaderByHash(ctx, latestSyncedHeader)
			if err != nil {
				return errors.Wrap(err, "p.destHeaderSyncer.GetCrossChainBlockHash")
			}

			// header is caught up and processible
			if header.Number.Uint64() >= event.Raw.BlockNumber {
				log.Infof(
					"msgHash: %v, txHash: %v is processable. occurred in block %v, latestSynced is block %v",
					common.Hash(event.MsgHash).Hex(),
					event.Raw.TxHash.Hex(),
					event.Raw.BlockNumber,
					header.Number.Uint64(),
				)

				return nil
			}

			log.Infof(
				"msgHash: %v, txHash: %v is waiting to be processable. occurred in block %v, latestSynced is block %v",
				common.Hash(event.MsgHash).Hex(),
				event.Raw.TxHash.Hex(),
				event.Raw.BlockNumber,
				header.Number.Uint64(),
			)
		}
	}
}
