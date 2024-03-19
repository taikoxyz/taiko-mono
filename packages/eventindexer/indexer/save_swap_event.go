package indexer

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"time"

	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
)

var (
	minTradeAmount = big.NewInt(10000000000000000)
)

func (i *Indexer) saveSwapEvents(
	ctx context.Context,
	chainID *big.Int,
	events *swap.SwapSwapIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no Swap events")
		return nil
	}

	for {
		event := events.Event

		if err := i.saveSwapEvent(ctx, chainID, event); err != nil {
			eventindexer.SwapEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveSwapEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveSwapEvent(
	ctx context.Context,
	chainID *big.Int,
	event *swap.SwapSwap,
) error {
	slog.Info("swap event",
		"sender", fmt.Sprintf("0x%v", common.Bytes2Hex(event.Raw.Topics[2].Bytes()[12:])),
		"amount", event.Amount0In.String(),
	)

	// we only want events with > 0.1 ETH swap
	if event.Amount0In.Cmp(minTradeAmount) <= 0 && event.Amount1Out.Cmp(minTradeAmount) <= 0 {
		slog.Info("skipping skip event, min trade too low",
			"amount0", event.Amount0In.String(),
			"amount1", event.Amount1Out.String(),
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
		Name:           eventindexer.EventNameSwap,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameSwap,
		Address:        fmt.Sprintf("0x%v", common.Bytes2Hex(event.Raw.Topics[2].Bytes()[12:])),
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.SwapEventsProcessed.Inc()

	return nil
}
