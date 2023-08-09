package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
)

var (
	minLiquidityAddedAmount = big.NewInt(100000000000000000)
)

func (svc *Service) saveLiquidityAddedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *swap.SwapMintIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no LiquidityAdded events")
		return nil
	}

	for {
		event := events.Event

		if err := svc.saveLiquidityAddedEvent(ctx, chainID, event); err != nil {
			eventindexer.LiquidityAddedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveSwapEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveLiquidityAddedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *swap.SwapMint,
) error {
	tx, _, err := svc.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
	if err != nil {
		return err
	}

	from, err := types.Sender(types.LatestSignerForChainID(tx.ChainId()), tx)
	if err != nil {
		return err
	}

	slog.Info("liquidityAdded event for",
		"sender", from.Hex(),
		"amount0", event.Amount0.String(),
		"amount1", event.Amount1.String(),
	)

	// we only want events with > 0.1 ETH swap
	if event.Amount0.Cmp(minLiquidityAddedAmount) <= 0 && event.Amount1.Cmp(minLiquidityAddedAmount) <= 0 {
		slog.Info("skipping liquidityAdded event, min trade too low",
			"amount0", event.Amount0.String(),
			"amount1", event.Amount1.String(),
		)

		return nil
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameMint,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameMint,
		Address: from.Hex(),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.LiquidityAddedEventsProcessed.Inc()

	return nil
}
