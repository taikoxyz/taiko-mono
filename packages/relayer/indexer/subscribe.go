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
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	slog.Info("subscribing to new events")

	errChan := make(chan error)

	go svc.subscribeMessageSent(ctx, chainID, errChan)

	go svc.subscribeMessageStatusChanged(ctx, chainID, errChan)

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

func (svc *Service) subscribeMessageSent(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageSent)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("svc.bridge.WatchMessageSent", "error", err)
		}

		slog.Info("resubscribing to WatchMessageSent events")

		return svc.bridge.WatchMessageSent(&bind.WatchOpts{
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
				err := svc.handleEvent(ctx, chainID, event)

				if err != nil {
					slog.Error("svc.subscribe, svc.handleEvent", "error", err)
					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, chainID)
				if err != nil {
					slog.Error("svc.subscribe, blockRepo.GetLatestBlockProcessedForEvent", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(relayer.SaveBlockOpts{
						Height:    event.Raw.BlockNumber,
						Hash:      event.Raw.BlockHash,
						ChainID:   chainID,
						EventName: relayer.EventNameMessageSent,
					})
					if err != nil {
						slog.Error("svc.subscribe, svc.blockRepo.Save", "error", err)
						return
					}

					relayer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeMessageStatusChanged(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageStatusChanged)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("svc.bridge.WatchMessageStatusChanged", "error", err)
		}
		slog.Info("resubscribing to WatchMessageStatusChanged events")

		return svc.bridge.WatchMessageStatusChanged(&bind.WatchOpts{
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

			if err := svc.saveMessageStatusChangedEvent(ctx, chainID, event); err != nil {
				slog.Error("svc.subscribe, svc.saveMessageStatusChangedEvent", "error", err)
			}
		}
	}
}
