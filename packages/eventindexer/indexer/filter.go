package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/labstack/gommon/log"
	"github.com/pkg/errors"
	"golang.org/x/sync/errgroup"
)

type FilterFunc func(
	ctx context.Context,
	chainID *big.Int,
	svc *Service,
	filterOpts *bind.FilterOpts,
) error

func L1FilterFunc(
	ctx context.Context,
	chainID *big.Int,
	svc *Service,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

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
		blockProposedEvents, err := svc.taikol1.FilterBlockProposed(filterOpts, nil)
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
		blockVerifiedEvents, err := svc.taikol1.FilterBlockVerified(filterOpts, nil)
		if err != nil {
			return errors.Wrap(err, "svc.taikol1.FilterBlockVerified")
		}

		err = svc.saveBlockVerifiedEvents(ctx, chainID, blockVerifiedEvents)
		if err != nil {
			return errors.Wrap(err, "svc.saveBlockVerifiedEvents")
		}

		return nil
	})

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

	err := wg.Wait()

	if err != nil {
		if errors.Is(err, context.Canceled) {
			log.Error("context cancelled")
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
	}

	return nil
}
