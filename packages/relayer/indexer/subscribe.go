package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/event"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
)

// subscribe subscribes to latest events
func (i *Indexer) subscribe(ctx context.Context, chainID *big.Int) error {
	slog.Info("subscribing to new events")

	errChan := make(chan error)

	if i.eventName == relayer.EventNameMessageSent {
		go i.subscribeMessageSent(ctx, chainID, errChan)

		go i.subscribeMessageStatusChanged(ctx, chainID, errChan)

		go i.subscribeChainDataSynced(ctx, chainID, errChan)
	} else if i.eventName == relayer.EventNameMessageReceived {
		go i.subscribeMessageReceived(ctx, chainID, errChan)
	}

	// nolint: gosimple
	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return nil
		case err := <-errChan:
			relayer.ErrorsEncounteredDuringSubscription.Inc()

			return errors.Wrap(err, "errChan")
		}
	}
}

func (i *Indexer) subscribeMessageSent(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageSent)

	sub := event.ResubscribeErr(i.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("i.bridge.WatchMessageSent", "error", err)
		}

		slog.Info("resubscribing to WatchMessageSent events")

		return i.bridge.WatchMessageSent(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				slog.Info("new message sent event", "msgHash", common.Hash(event.MsgHash).Hex(), "chainID", chainID.String())
				err := i.handleMessageSentEvent(ctx, chainID, event)

				if err != nil {
					slog.Error("i.subscribe, i.handleMessageSentEvent", "error", err)
					return
				}

				i.mu.Lock()

				defer i.mu.Unlock()

				block, err := i.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, chainID)
				if err != nil {
					slog.Error("i.subscribe, blockRepo.GetLatestBlockProcessedForEvent", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = i.blockRepo.Save(relayer.SaveBlockOpts{
						Height:    event.Raw.BlockNumber,
						Hash:      event.Raw.BlockHash,
						ChainID:   chainID,
						EventName: relayer.EventNameMessageSent,
					})
					if err != nil {
						slog.Error("i.subscribe, i.blockRepo.Save", "error", err)
						return
					}

					relayer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (i *Indexer) subscribeMessageReceived(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageReceived)

	sub := event.ResubscribeErr(i.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("i.bridge.WatchMessageReceived", "error", err)
		}

		slog.Info("resubscribing to WatchMessageReceived events")

		return i.bridge.WatchMessageReceived(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				slog.Info("new message received event", "msgHash", common.Hash(event.MsgHash).Hex(), "chainID", chainID.String())
				err := i.handleMessageReceivedEvent(ctx, chainID, event)

				if err != nil {
					slog.Error("i.subscribe, i.handleMessageReceived", "error", err)
					return
				}

				i.mu.Lock()

				defer i.mu.Unlock()

				block, err := i.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, chainID)
				if err != nil {
					slog.Error("i.subscribe, blockRepo.GetLatestBlockProcessedForEvent", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = i.blockRepo.Save(relayer.SaveBlockOpts{
						Height:    event.Raw.BlockNumber,
						Hash:      event.Raw.BlockHash,
						ChainID:   chainID,
						EventName: relayer.EventNameMessageSent,
					})
					if err != nil {
						slog.Error("i.subscribe, i.blockRepo.Save", "error", err)
						return
					}

					relayer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (i *Indexer) subscribeMessageStatusChanged(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageStatusChanged)

	sub := event.ResubscribeErr(i.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("i.bridge.WatchMessageStatusChanged", "error", err)
		}

		slog.Info("resubscribing to WatchMessageStatusChanged events")

		return i.bridge.WatchMessageStatusChanged(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			slog.Info("new message status changed event",
				"msgHash", common.Hash(event.MsgHash).Hex(),
				"chainID", chainID.String(),
			)

			if err := i.saveMessageStatusChangedEvent(ctx, chainID, event); err != nil {
				slog.Error("i.subscribe, i.saveMessageStatusChangedEvent", "error", err)
			}
		}
	}
}

func (i *Indexer) subscribeChainDataSynced(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *signalservice.SignalServiceChainDataSynced)

	sub := event.ResubscribeErr(i.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("i.signalService.WatchMessageStatusChanged", "error", err)
		}

		slog.Info("resubscribing to WatchMessageStatusChanged events")

		return i.signalService.WatchChainDataSynced(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil, nil, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			slog.Info("new chain data synced event",
				"signal", common.Hash(event.Signal).Hex(),
				"chainID", event.Chainid,
				"blockID", event.BlockId,
				"syncedInBlock", event.Raw.BlockNumber,
			)

			if err := i.handleChainDataSyncedEvent(ctx, i.srcChainId, event); err != nil {
				slog.Error("error handling chain data synced event", "error", err)
				continue
			}

			slog.Info("chainDataSynced event saved")
		}
	}
}
