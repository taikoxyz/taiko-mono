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
	svc *Service,
	filterOpts *bind.FilterOpts,
) error

// nolint
func L1FilterFunc(
	ctx context.Context,
	chainID *big.Int,
	svc *Service,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	if svc.taikol1 != nil {
		wg.Go(func() error {
			blockProvenEvents, err := svc.taikol1.FilterBlockProven(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "svc.taikol1.FilterBlockProven")
			}

			err = svc.saveBlockProvenEvents(ctx, chainID, blockProvenEvents)
			if err != nil {
				return errors.Wrap(err, "svc.saveBlockProvenEvents")
			}

			return nil
		})

		wg.Go(func() error {
			blockProposedEvents, err := svc.taikol1.FilterBlockProposed(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "svc.taikol1.FilterBlockProposed")
			}

			err = svc.saveBlockProposedEvents(ctx, chainID, blockProposedEvents)
			if err != nil {
				return errors.Wrap(err, "svc.saveBlockProposedEvents")
			}

			return nil
		})

		wg.Go(func() error {
			blockVerifiedEvents, err := svc.taikol1.FilterBlockVerified(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "svc.taikol1.FilterBlockVerified")
			}

			err = svc.saveBlockVerifiedEvents(ctx, chainID, blockVerifiedEvents)
			if err != nil {
				return errors.Wrap(err, "svc.saveBlockVerifiedEvents")
			}

			return nil
		})
	}

	if svc.bridge != nil {
		wg.Go(func() error {
			messagesSent, err := svc.bridge.FilterMessageSent(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "svc.bridge.FilterMessageSent")
			}

			err = svc.saveMessageSentEvents(ctx, chainID, messagesSent)
			if err != nil {
				return errors.Wrap(err, "svc.saveMessageSentEvents")
			}

			return nil
		})
	}

	if svc.indexNfts {
		wg.Go(func() error {
			if err := svc.indexNFTTransfers(ctx, chainID, filterOpts.Start, *filterOpts.End); err != nil {
				return errors.Wrap(err, "svc.indexNFTTransfers")
			}
			return nil
		})
	}

	err := wg.Wait()

	if err != nil {
		if errors.Is(err, context.Canceled) {
			slog.Error("context cancelled")
			return err
		}

		return err
	}

	return nil
}

func L2FilterFunc(
	ctx context.Context,
	chainID *big.Int,
	svc *Service,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	for _, s := range svc.swaps {
		swap := s

		wg.Go(func() error {
			swaps, err := swap.FilterSwap(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "svc.bridge.FilterSwap")
			}

			// only save ones above 0.01 ETH, this is only for Galaxe
			// and we dont care about the rest
			err = svc.saveSwapEvents(ctx, chainID, swaps)
			if err != nil {
				return errors.Wrap(err, "svc.saveSwapEvents")
			}

			return nil
		})

		wg.Go(func() error {
			liquidityAdded, err := swap.FilterMint(filterOpts, nil)

			if err != nil {
				return errors.Wrap(err, "svc.bridge.FilterMint")
			}

			// only save ones above 0.1 ETH, this is only for Galaxe
			// and we dont care about the rest
			err = svc.saveLiquidityAddedEvents(ctx, chainID, liquidityAdded)
			if err != nil {
				return errors.Wrap(err, "svc.saveLiquidityAddedEvents")
			}

			return nil
		})
	}

	if svc.indexNfts {
		wg.Go(func() error {
			if err := svc.indexNFTTransfers(ctx, chainID, filterOpts.Start, *filterOpts.End); err != nil {
				return errors.Wrap(err, "svc.indexNFTTransfers")
			}
			return nil
		})
	}

	err := wg.Wait()
	if err != nil {
		if errors.Is(err, context.Canceled) {
			slog.Error("context cancelled")
			return err
		}

		return err
	}

	return nil
}
