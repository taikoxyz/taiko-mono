package indexer

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	v4 "github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/signalservice"
)

// handleCheckpointSavedEvent handles an individual CheckpointSaved event.
func (i *Indexer) handleCheckpointSavedEvent(
	ctx context.Context,
	event *v4.SignalServiceCheckpointSaved,
	waitForConfirmations bool,
) error {
	slog.Info("checkpointSaved event found",
		"blockNumber", event.BlockNumber.Uint64(),
		"blockHash", common.Hash(event.BlockHash).Hex(),
		"stateRoot", common.Hash(event.StateRoot).Hex(),
		"txHash", event.Raw.TxHash.Hex(),
	)

	if event.Raw.Removed {
		slog.Info("event is removed")
		return nil
	}

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
		Name:            relayer.EventNameCheckpointSaved,
		Event:           relayer.EventNameCheckpointSaved,
		Data:            string(marshaled),
		ChainID:         i.srcChainId,
		DestChainID:     i.destChainId,
		SyncedChainID:   i.destChainId.Uint64(),
		BlockID:         event.BlockNumber.Uint64(),
		EmittedBlockID:  event.Raw.BlockNumber,
		SyncData:        common.Hash(event.StateRoot).Hex(),
		SyncedInBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	slog.Info("checkpointSaved event saved",
		"srcChainId", i.srcChainId,
		"destChainId", i.destChainId,
		"blockNumber", event.BlockNumber.Uint64(),
	)

	relayer.CheckpointSavedEventsIndexed.Inc()

	return nil
}
