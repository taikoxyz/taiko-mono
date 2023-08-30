package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/labstack/gommon/log"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	slog.Info("subscribing to new events")

	errChan := make(chan error)

	if svc.taikol1 != nil {
		go svc.subscribeBlockProven(ctx, chainID, errChan)
		go svc.subscribeBlockProposed(ctx, chainID, errChan)
		go svc.subscribeBlockVerified(ctx, chainID, errChan)
	}

	if svc.bridge != nil {
		go svc.subscribeMessageSent(ctx, chainID, errChan)
	}

	if svc.swaps != nil {
		for _, swap := range svc.swaps {
			go svc.subscribeSwap(ctx, swap, chainID, errChan)
			go svc.subscribeLiquidityAdded(ctx, swap, chainID, errChan)
		}
	}

	if svc.indexNfts {
		go svc.subscribeNftTransfers(ctx, chainID, errChan)
	}

	// nolint: gosimple
	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return nil
		case err := <-errChan:
			eventindexer.ErrorsEncounteredDuringSubscription.Inc()

			return errors.Wrap(err, "errChan")
		}
	}
}

func (svc *Service) subscribeNftTransfers(
	ctx context.Context,
	chainID *big.Int,
	errChan chan error,
) {
	headers := make(chan *types.Header)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("svc.SubscribeNewHead", "error", err)
		}
		slog.Info("resubscribing to NewHead events for nft trasnfers")

		return svc.ethClient.SubscribeNewHead(ctx, headers)
	})

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case header := <-headers:
			go func() {
				if err := svc.indexNFTTransfers(ctx, chainID, header.Number.Uint64(), header.Number.Uint64()); err != nil {
					slog.Error("svc.indexNFTTransfers", "error", err)
				}
			}()
		}
	}
}

func (svc *Service) subscribeBlockProven(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockProven)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Error("svc.taikoL1.WatchBlockProven", "error", err)
		}
		log.Info("resubscribing to BlockProven events")

		return svc.taikol1.WatchBlockProven(&bind.WatchOpts{
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
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				log.Info("blockProvenEvent from subscription for prover",
					"prover", event.Prover.Hex(),
				)

				if err := svc.saveBlockProvenEvent(ctx, chainID, event); err != nil {
					eventindexer.BlockProvenEventsProcessedError.Inc()

					log.Error("svc.subscribe, svc.saveBlockProvenEvent", "error", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					slog.Error("svc.subscribe, svc.blockRepo.GetLatestBlockProcessed", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						slog.Error("svc.subscribe, blockRepo.save", "error", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeBlockProposed(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockProposed)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Error("svc.taikoL1.WatchBlockProposed", "error", err)
		}
		log.Info("resubscribing to BlockProposed events")

		return svc.taikol1.WatchBlockProposed(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				slog.Info("blockProposedEvent from subscription")

				tx, _, err := svc.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
				if err != nil {
					slog.Error("svc.ethClient.TransactionByHash", "error", err)

					return
				}

				sender, err := svc.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
				if err != nil {
					slog.Error("svc.ethClient.TransactionSender", "error", err)

					return
				}

				slog.Info("blockProposed", "proposer", sender.Hex(), "blockID", event.BlockId.Uint64())

				if err := svc.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
					eventindexer.BlockProposedEventsProcessedError.Inc()

					slog.Error("svc.subscribe, svc.saveBlockProposedEvent", "error", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					slog.Error("svc.subscribe, svc.blockRepo.GetLatestBlockProcessed", "error", err)

					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						slog.Error("svc.subscribe, blockRepo.save", "error", err)

						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeBlockVerified(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockVerified)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("svc.taikoL1.WatchBlockVerified", "error", err)
		}

		slog.Info("resubscribing to BlockVerified events")

		return svc.taikol1.WatchBlockVerified(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				slog.Info("blockVerifiedEvent from subscription", "prover", event.Prover.Hex())

				if err := svc.saveBlockVerifiedEvent(ctx, chainID, event); err != nil {
					eventindexer.BlockVerifiedEventsProcessedError.Inc()
					slog.Error("svc.subscribe, svc.saveBlockVerifiedEvent", "error", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					slog.Error("svc.subscribe, svc.blockRepo.GetLatestBlockProcessed", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						slog.Error("svc.subscribe, blockRepo.save", "error", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeMessageSent(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageSent)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("svc.taikoL1.WatchMessageSent", "error", err)
		}

		slog.Info("resubscribing to MessageSent events")

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
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				slog.Info("messageSentEvent", "owner", event.Message.From.Hex())

				if err := svc.saveMessageSentEvent(ctx, chainID, event); err != nil {
					eventindexer.MessageSentEventsProcessedError.Inc()

					slog.Error("svc.subscribe, svc.saveMessageSentEvent", "error", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					slog.Error("svc.subscribe, svc.blockRepo.GetLatestBlockProcessed", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						slog.Error("svc.subscribe, blockRepo.save", "error", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeSwap(ctx context.Context, s *swap.Swap, chainID *big.Int, errChan chan error) {
	sink := make(chan *swap.SwapSwap)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("s.WatchSwap", "error", err)
		}
		slog.Info("resubscribing to Swap events")

		return s.WatchSwap(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				if err := svc.saveSwapEvent(ctx, chainID, event); err != nil {
					eventindexer.SwapEventsProcessedError.Inc()

					slog.Error("svc.subscribe, svc.saveSwapEvent", "error", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					slog.Error("svc.subscribe, svc.blockRepo.GetLatestBlockProcessed", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						slog.Error("svc.subscribe, blockRepo.save", "error", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeLiquidityAdded(ctx context.Context, s *swap.Swap, chainID *big.Int, errChan chan error) {
	sink := make(chan *swap.SwapMint)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("s.WatchMint", "error", err)
		}
		slog.Info("resubscribing to Swap events")

		return s.WatchMint(&bind.WatchOpts{
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
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				if err := svc.saveLiquidityAddedEvent(ctx, chainID, event); err != nil {
					eventindexer.SwapEventsProcessedError.Inc()

					slog.Error("svc.subscribe, svc.saveLiquidityAddedEvent", "error", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					slog.Error("svc.subscribe, blockRepo.GetLatestBlockProcessed", "error", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						slog.Error("svc.subscribe, svc.blockRepo.Save", "error", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}
