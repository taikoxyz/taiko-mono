package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"golang.org/x/sync/errgroup"
)

type FilterFunc func(
	ctx context.Context,
	chainID *big.Int,
	indxr *Indexer,
	filterOpts *bind.FilterOpts,
) error

// nolint
func filterFunc(
	ctx context.Context,
	chainID *big.Int,
	indxr *Indexer,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	if indxr.taikol1 != nil {
		wg.Go(func() error {
			blockProvenEvents, err := indxr.taikol1.FilterBlockProven(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "indxr.taikol1.FilterBlockProven")
			}

			err = indxr.saveBlockProvenEvents(ctx, chainID, blockProvenEvents)
			if err != nil {
				return errors.Wrap(err, "indxr.saveBlockProvenEvents")
			}

			return nil
		})

		wg.Go(func() error {
			blockProposedEvents, err := indxr.taikol1.FilterBlockProposed(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "indxr.taikol1.FilterBlockProposed")
			}

			err = indxr.saveBlockProposedEvents(ctx, chainID, blockProposedEvents)
			if err != nil {
				return errors.Wrap(err, "indxr.saveBlockProposedEvents")
			}

			return nil
		})

		wg.Go(func() error {
			blockVerifiedEvents, err := indxr.taikol1.FilterBlockVerified(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "indxr.taikol1.FilterBlockVerified")
			}

			err = indxr.saveBlockVerifiedEvents(ctx, chainID, blockVerifiedEvents)
			if err != nil {
				return errors.Wrap(err, "indxr.saveBlockVerifiedEvents")
			}

			return nil
		})
	}

	if indxr.bridge != nil {
		wg.Go(func() error {
			messagesSent, err := indxr.bridge.FilterMessageSent(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "indxr.bridge.FilterMessageSent")
			}

			err = indxr.saveMessageSentEvents(ctx, chainID, messagesSent)
			if err != nil {
				return errors.Wrap(err, "indxr.saveMessageSentEvents")
			}

			return nil
		})
	}

	if indxr.swaps != nil {
		for _, s := range indxr.swaps {
			swap := s

			wg.Go(func() error {
				swaps, err := swap.FilterSwap(filterOpts, nil, nil)
				if err != nil {
					return errors.Wrap(err, "indxr.bridge.FilterSwap")
				}

				// only save ones above 0.01 ETH, this is only for Galaxe
				// and we dont care about the rest
				err = indxr.saveSwapEvents(ctx, chainID, swaps)
				if err != nil {
					return errors.Wrap(err, "indxr.saveSwapEvents")
				}

				return nil
			})

			wg.Go(func() error {
				liquidityAdded, err := swap.FilterMint(filterOpts, nil)

				if err != nil {
					return errors.Wrap(err, "indxr.bridge.FilterMint")
				}

				// only save ones above 0.1 ETH, this is only for Galaxe
				// and we dont care about the rest
				err = indxr.saveLiquidityAddedEvents(ctx, chainID, liquidityAdded)
				if err != nil {
					return errors.Wrap(err, "indxr.saveLiquidityAddedEvents")
				}

				return nil
			})
		}
	}

	wg.Go(func() error {
		if err := indxr.indexRawBlockData(ctx, chainID, filterOpts.Start, *filterOpts.End); err != nil {
			return errors.Wrap(err, "indxr.indexRawBlockData")
		}
		return nil
	})

	err := wg.Wait()

	if err != nil {
		if errors.Is(err, context.Canceled) {
			slog.Error("filter context cancelled")
			return err
		}

		return err
	}

	return nil
}
