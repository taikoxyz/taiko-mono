package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/labstack/gommon/log"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/assignmenthook"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

// subscribe subscribes to latest events
func (indxr *Indexer) subscribe(ctx context.Context, chainID *big.Int) error {
	slog.Info("subscribing to new events")

	errChan := make(chan error)

	if indxr.taikol1 != nil {
		go indxr.subscribeTransitionProved(ctx, chainID, errChan)
		go indxr.subscribeTransitionContested(ctx, chainID, errChan)
		go indxr.subscribeBlockProposed(ctx, chainID, errChan)
		go indxr.subscribeBlockVerified(ctx, chainID, errChan)
	}

	if indxr.bridge != nil {
		go indxr.subscribeMessageSent(ctx, chainID, errChan)
	}

	if indxr.swaps != nil {
		for _, swap := range indxr.swaps {
			go indxr.subscribeSwap(ctx, swap, chainID, errChan)
			go indxr.subscribeLiquidityAdded(ctx, swap, chainID, errChan)
		}
	}

	if indxr.assignmentHook != nil {
		go indxr.subscribeBlockAssigned(ctx, chainID, errChan)
	}

	go indxr.subscribeRawBlockData(ctx, chainID, errChan)

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

func (indxr *Indexer) subscribeRawBlockData(
	ctx context.Context,
	chainID *big.Int,
	errChan chan error,
) {
	headers := make(chan *types.Header)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				slog.Error("indxr.SubscribeNewHead", "error", err)
			}

			slog.Info("resubscribing to NewHead events for block data")

			return indxr.ethClient.SubscribeNewHead(ctx, headers)
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
			slog.Info("new header", "header", header.Number)

			go func() {
				if err := indxr.indexRawBlockData(ctx, chainID, header.Number.Uint64(), header.Number.Uint64()+1); err != nil {
					slog.Error("indxr.indexRawBlockData", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeTransitionProved(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1TransitionProved)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				log.Error("indxr.taikoL1.WatchTransitionProved", "error", err)
			}

			log.Info("resubscribing to TransitionProved events")

			return indxr.taikol1.WatchTransitionProved(&bind.WatchOpts{
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
				log.Info("transitionProvenEvent from subscription for prover",
					"prover", event.Prover.Hex(),
					"blockId", event.BlockId.String(),
				)

				if err := indxr.saveTransitionProvedEvent(ctx, chainID, event); err != nil {
					eventindexer.TransitionProvedEventsProcessedError.Inc()

					log.Error("indxr.subscribe, indxr.saveTransitionProvedEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeTransitionContested(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1TransitionContested)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				log.Error("indxr.taikoL1.WatchTransitionContested", "error", err)
			}

			log.Info("resubscribing to TransitionContested events")

			return indxr.taikol1.WatchTransitionContested(&bind.WatchOpts{
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
				log.Info("transitionContestedEvent from subscription for prover",
					"contester", event.Contester.Hex(),
					"blockId", event.BlockId.String(),
					"contestBond", event.ContestBond.String(),
					"tier", event.Tier,
				)

				if err := indxr.saveTransitionContestedEvent(ctx, chainID, event); err != nil {
					eventindexer.TransitionContestedEventsProcessedError.Inc()

					log.Error("indxr.subscribe, indxr.saveTransitionContestedEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeBlockProposed(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockProposed)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				log.Error("indxr.taikoL1.WatchBlockProposed", "error", err)
			}

			log.Info("resubscribing to BlockProposed events")

			return indxr.taikol1.WatchBlockProposed(&bind.WatchOpts{
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

				tx, _, err := indxr.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
				if err != nil {
					slog.Error("indxr.ethClient.TransactionByHash", "error", err)

					return
				}

				sender, err := indxr.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
				if err != nil {
					slog.Error("indxr.ethClient.TransactionSender", "error", err)

					return
				}

				slog.Info("blockProposed", "proposer", sender.Hex(), "blockID", event.BlockId.Uint64())

				if err := indxr.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
					eventindexer.BlockProposedEventsProcessedError.Inc()

					slog.Error("indxr.subscribe, indxr.saveBlockProposedEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeBlockVerified(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockVerified)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				slog.Error("indxr.taikoL1.WatchBlockVerified", "error", err)
			}

			slog.Info("resubscribing to BlockVerified events")

			return indxr.taikol1.WatchBlockVerified(&bind.WatchOpts{
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
			slog.Error("sub.Err()", "error", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				slog.Info("blockVerifiedEvent from subscription", "prover", event.Prover.Hex())

				if err := indxr.saveBlockVerifiedEvent(ctx, chainID, event); err != nil {
					eventindexer.BlockVerifiedEventsProcessedError.Inc()
					slog.Error("indxr.subscribe, indxr.saveBlockVerifiedEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeMessageSent(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageSent)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				slog.Error("indxr.taikoL1.WatchMessageSent", "error", err)
			}

			slog.Info("resubscribing to MessageSent events")

			return indxr.bridge.WatchMessageSent(&bind.WatchOpts{
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

				if err := indxr.saveMessageSentEvent(ctx, chainID, event); err != nil {
					eventindexer.MessageSentEventsProcessedError.Inc()

					slog.Error("indxr.subscribe, indxr.saveMessageSentEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeSwap(ctx context.Context, s *swap.Swap, chainID *big.Int, errChan chan error) {
	sink := make(chan *swap.SwapSwap)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
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
				if err := indxr.saveSwapEvent(ctx, chainID, event); err != nil {
					eventindexer.SwapEventsProcessedError.Inc()

					slog.Error("indxr.subscribe, indxr.saveSwapEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeLiquidityAdded(ctx context.Context, s *swap.Swap, chainID *big.Int, errChan chan error) {
	sink := make(chan *swap.SwapMint)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
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
				if err := indxr.saveLiquidityAddedEvent(ctx, chainID, event); err != nil {
					eventindexer.SwapEventsProcessedError.Inc()

					slog.Error("indxr.subscribe, indxr.saveLiquidityAddedEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) subscribeBlockAssigned(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *assignmenthook.AssignmentHookBlockAssigned)

	sub := event.ResubscribeErr(
		indxr.subscriptionBackoff,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				log.Error("assignmenthook.AssignmentHookBlockAssignedd", "error", err)
			}

			log.Info("resubscribing to TransitionProved events")

			return indxr.assignmentHook.WatchBlockAssigned(&bind.WatchOpts{
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
				log.Info("blockAssigned event from subscription",
					"prover", event.AssignedProver.Hex(),
					"metaId", event.Meta.Id,
				)

				if err := indxr.saveBlockAssignedEvent(ctx, chainID, event); err != nil {
					eventindexer.TransitionProvedEventsProcessedError.Inc()

					log.Error("indxr.subscribe, indxr.saveBlockAssignedEvent", "error", err)

					return
				}

				if err := indxr.saveLatestBlockSeen(ctx, chainID, event.Raw.BlockNumber, event.Raw.BlockHash); err != nil {
					log.Error("indxr.subscribe, indxr.saveLatestBlockSeen", "error", err)
				}
			}()
		}
	}
}

func (indxr *Indexer) saveLatestBlockSeen(
	ctx context.Context,
	chainID *big.Int,
	blockNumber uint64,
	blockHash common.Hash,
) error {
	indxr.blockSaveMutex.Lock()
	defer indxr.blockSaveMutex.Unlock()

	block, err := indxr.processedBlockRepo.GetLatestBlockProcessed(chainID)
	if err != nil {
		slog.Error("indxr.subscribe, indxr.processedBlockRepo.GetLatestBlockProcessed", "error", err)
		return err
	}

	if block.Height < blockNumber {
		err = indxr.processedBlockRepo.Save(eventindexer.SaveProcessedBlockOpts{
			Height:  blockNumber,
			Hash:    blockHash,
			ChainID: chainID,
		})
		if err != nil {
			slog.Error("indxr.subscribe, blockRepo.save", "error", err)
			return err
		}

		eventindexer.BlocksProcessed.Inc()
	}

	return nil
}
