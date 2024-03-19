package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
)

var (
	minLiquidityAddedAmount = big.NewInt(100000000000000000)
)

func (i *Indexer) saveLiquidityAddedEvents(
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

		if err := i.saveLiquidityAddedEvent(ctx, chainID, event); err != nil {
			eventindexer.LiquidityAddedEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveSwapEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveLiquidityAddedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *swap.SwapMint,
) error {
	tx, _, err := i.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
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

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameMint,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameMint,
		Address:        from.Hex(),
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.LiquidityAddedEventsProcessed.Inc()

	return nil
}
