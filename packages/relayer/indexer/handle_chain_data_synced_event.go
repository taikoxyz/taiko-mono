package indexer

import (
	"context"
	"encoding/json"

	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
)

// handleChainDataSyncedEvent handles an individual ChainDataSynced event
func (i *Indexer) handleChainDataSyncedEvent(
	ctx context.Context,
	event *signalservice.SignalServiceChainDataSynced,
	waitForConfirmations bool,
) error {
	slog.Info("chainDataSynced event found for msgHash",
		"signal", common.Hash(event.Signal).Hex(),
		"chainID", event.ChainId,
		"blockID", event.BlockId,
		"txHash", event.Raw.TxHash.Hex(),
	)

	if event.Raw.Removed {
		slog.Info("event is removed")
		return nil
	}

	// we need to wait for confirmations to confirm this event is not being reverted,
	// removed, or reorged now.
	confCtx, confCtxCancel := context.WithTimeout(ctx, i.cfg.ConfirmationTimeout)

	defer confCtxCancel()

	if waitForConfirmations {
		if err := relayer.WaitConfirmations(
			confCtx,
			i.srcEthClient,
			i.confirmations,
			event.Raw.TxHash,
		); err != nil {
			return err
		}
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = i.eventRepo.Save(ctx, &relayer.SaveEventOpts{
		Name:            relayer.EventNameChainDataSynced,
		Event:           relayer.EventNameChainDataSynced,
		Data:            string(marshaled),
		ChainID:         i.srcChainId,
		DestChainID:     i.destChainId,
		SyncedChainID:   event.ChainId,
		BlockID:         event.BlockId,
		EmittedBlockID:  event.Raw.BlockNumber,
		MsgHash:         common.BytesToHash(event.Signal[:]).Hex(),
		SyncData:        common.BytesToHash(event.Data[:]).Hex(),
		Kind:            common.BytesToHash(event.Kind[:]).Hex(),
		SyncedInBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	slog.Info("chainDataSynced event saved",
		"srcChainId", i.srcChainId,
		"destChainId", i.destChainId,
		"SyncedChainID", event.ChainId,
	)

	relayer.ChainDataSyncedEventsIndexed.Inc()

	return nil
}
